"""
Question 4: GenAI Clinical Data Assistant
==========================================
A natural-language -> structured-query agent over an adverse-event (AE) dataset.

A clinical safety reviewer asks free-text questions ("which subjects had moderate
events?", "show me cardiac AEs") without knowing column names. The agent uses an
LLM to map the question to the correct ADAE column and filter value, returns
that mapping as STRUCTURED JSON, then executes the corresponding pandas filter
and reports the matching subjects.

Design
------
* The LLM is ONE swappable component behind a stable interface (`_call_llm`).
  When ANTHROPIC_API_KEY is set, it calls Claude. When it is not, it falls back
  to a deterministic mock that returns the same JSON schema. This makes the full
  Prompt -> Parse -> Execute flow runnable WITHOUT any credentials, while still
  exercising real intent-mapping when a key is present.
  
* The structured output is parsed and validated with plain json + a key check,
  so a malformed LLM response fails loudly at the parse step rather than
  corrupting the pandas execution step.
  
* No hard-coded keyword rules drive the mapping: the schema is described to the
  LLM and the model decides the routing. (The mock approximates this for the
  offline path only.)

Date: 27JUN2026
Author: utdfaithful07
"""

from __future__ import annotations

import json
import os
import re
from typing import Optional

import pandas as pd


# ----------------------------------------------------------------------------
# The agent
# ----------------------------------------------------------------------------
class ClinicalTrialDataAgent:
    """Maps a free-text question to a structured ADAE filter and executes it."""

    # Columns we expose to the LLM, with plain-language hints. 
      # This is the "schema definition" the question asks for 
      # Described to the model so it can route intent without hard-coded rules.
    SCHEMA: dict[str, str] = {
        "AESEV": "Severity or intensity of the adverse event "
                 "(e.g. MILD, MODERATE, SEVERE).",
        "AETERM": "The specific reported adverse event term / condition "
                  "(e.g. HEADACHE, NAUSEA, DIARRHOEA).",
        "AESOC": "The body system / System Organ Class the event belongs to "
                 "(e.g. CARDIAC DISORDERS, SKIN AND SUBCUTANEOUS TISSUE DISORDERS).",
        "USUBJID": "Unique subject identifier.",
    }

    MODEL_NAME = "claude-sonnet-4-6"

    def __init__(self, df: pd.DataFrame, api_key: Optional[str] = None) -> None:
        """
        Args:
            df: The ADAE dataframe to query (must contain a USUBJID column).
            api_key: Optional Anthropic key. If omitted, falls back to the
                     ANTHROPIC_API_KEY env var; if that is also absent, the agent
                     runs in deterministic mock mode (no live LLM call).
        Returns:
            None.
        """
        
        self.df = df
        
        # Prefer an explicit key, else the environment. None => offline/mock mode.
        self.api_key = api_key or os.environ.get("ANTHROPIC_API_KEY")
        self._client = None
        
        if self.api_key:
            try:
                import anthropic  # imported lazily so the mock path needs no dep
                self._client = anthropic.Anthropic(api_key=self.api_key)
            except ImportError:
                # SDK not installed -> stay in mock mode rather than crashing.
                self._client = None

    # ---- Prompt construction ------------------------------------------------
    def _build_prompt(self, question: str) -> str:
        """Assemble the LLM prompt: schema + routing guidance + the question.

        Args:
            question: The reviewer's free-text question.
        Returns:
            The full prompt string instructing the model to return JSON.
        """
        
        schema_lines = "\n".join(f"- {col}: {desc}" for col, desc in self.SCHEMA.items())
        
        return (
            "You map a clinical reviewer's free-text question about an adverse-event "
            "dataset to a single column and filter value.\n\n"
            f"Available columns:\n{schema_lines}\n\n"
            "Routing guidance:\n"
            "- severity / intensity / how bad -> AESEV\n"
            "- a specific condition or symptom -> AETERM\n"
            "- a body system or organ class -> AESOC\n\n"
            f'Question: "{question}"\n\n'
            "Respond with ONLY a JSON object, no prose, of the form:\n"
            '{"target_column": "<COLUMN>", "filter_value": "<VALUE>"}\n'
            "Use uppercase for filter_value to match the dataset conventions."
        )

    # ---- LLM call (real or mock) -------------------------------------------
    def _call_llm(self, question: str) -> str:
        """Get the model's raw JSON string for a question.

        Real Claude call when a client exists; otherwise the deterministic mock.

        Args:
            question: The reviewer's free-text question.
        Returns:
            A raw string expected to contain a JSON object with keys
            target_column and filter_value.
        """
        
        if self._client is not None:
            msg = self._client.messages.create(
                model=self.MODEL_NAME,
                max_tokens=200,
                messages=[{"role": "user", "content": self._build_prompt(question)}],
            )
            # Concatenate any text blocks in the response.
            return "".join(
                block.text for block in msg.content if getattr(block, "type", None) == "text"
            )
        return self._mock_llm(question)

    def _mock_llm(self, question: str) -> str:
        """
        Offline stand-in for the LLM. Approximates intent routing so the full
        Prompt -> Parse -> Execute flow runs with no API key. This is the ONLY
        place with keyword heuristics, and it exists solely for the offline path.
        """
        
        q = question.lower()
        
        severity_words = {"mild": "MILD", "moderate": "MODERATE", "severe": "SEVERE"}
        
        for word, val in severity_words.items():
            if word in q:
                return json.dumps({"target_column": "AESEV", "filter_value": val})

        if any(w in q for w in ("severity", "intensity")):
            return json.dumps({"target_column": "AESEV", "filter_value": "MODERATE"})

        # Body-system cues -> AESOC
        soc_cues = {"cardiac": "CARDIAC DISORDERS",
                    "heart": "CARDIAC DISORDERS",
                    "skin": "SKIN AND SUBCUTANEOUS TISSUE DISORDERS",
                    "gastro": "GASTROINTESTINAL DISORDERS"}
        for cue, val in soc_cues.items():
            if cue in q:
                return json.dumps({"target_column": "AESOC", "filter_value": val})

        # Otherwise assume a specific condition term -> AETERM. 
          # Prefer a quoted phrase; else take the last "content" word, skipping common question /
          # stop words so we don't grab a sentence-initial "Which"/"Show"/etc.
          # (The live LLM path handles this robustly; this heuristic only serves the offline mock.)
        
        stop = {"which", "what", "who", "show", "give", "me", "the", "a", "an",
                "subjects", "patients", "had", "have", "experienced", "with",
                "of", "events", "event", "adverse", "ae", "aes", "any"}
                
        quoted = re.search(r'"([^"]+)"', question)
        
        if quoted:
            value = quoted.group(1)
        else:
            tokens = re.findall(r"[A-Za-z]+", question)
            content = [t for t in tokens if t.lower() not in stop]
            value = content[-1] if content else (tokens[-1] if tokens else "")
        return json.dumps({"target_column": "AETERM", "filter_value": value.upper()})

    # ---- Parse + validate ---------------------------------------------------
    def _parse_plan(self, raw: str) -> dict:
        """
        Parse and validate the model's output into a plan dict.

        Strips code fences, isolates the first {...} block if the model added
        prose, then confirms both required keys are present.

        Args:
            raw: The raw string returned by _call_llm.
        Returns:
            A dict with keys 'target_column' and 'filter_value'.
        Raises:
            ValueError: if valid JSON with both required keys cannot be parsed.
        """
        
        cleaned = raw.strip().removeprefix("```json").removeprefix("```").removesuffix("```").strip()
        
        # If the model wrapped JSON in prose, grab the first {...} block.
        if not cleaned.startswith("{"):
            m = re.search(r"\{.*\}", cleaned, re.DOTALL)
            if m:
                cleaned = m.group(0)
        try:
            data = json.loads(cleaned)
        except json.JSONDecodeError as e:
            raise ValueError(f"LLM output was not valid JSON: {raw!r}") from e

        # Minimal validation: both keys present and non-empty strings.
        for key in ("target_column", "filter_value"):
            if key not in data or not isinstance(data[key], str) or not data[key]:
                raise ValueError(f"LLM output missing/invalid '{key}': {raw!r}")
        return {"target_column": data["target_column"],
                "filter_value": data["filter_value"]}

    # ---- Execute ------------------------------------------------------------
    def _execute(self, plan: dict) -> dict:
        """
        Apply the plan as a pandas filter and summarise the matches.

        Args:
            plan: Dict with 'target_column' and 'filter_value' (from _parse_plan).
        Returns:
            A dict with target_column, filter_value, n_subjects, and the sorted
            list of matching USUBJIDs.
        Raises:
            KeyError: if target_column is not a column in the dataset.
        """
        
        col = plan["target_column"]
        if col not in self.df.columns:
            raise KeyError(f"target_column '{col}' is not in the dataset.")

        # Case-insensitive exact match on the column (AE values are categorical).
        mask = self.df[col].astype(str).str.upper() == plan["filter_value"].upper()
        matched = self.df.loc[mask]
        subjects = sorted(matched["USUBJID"].unique().tolist())

        return {
            "target_column": col,
            "filter_value": plan["filter_value"],
            "n_subjects": len(subjects),
            "subjects": subjects,
        }

    # ---- Public entry point -------------------------------------------------
    def query(self, question: str) -> dict:
        """
        Run the full pipeline for one question: Prompt -> LLM -> Parse -> Execute.

        Args:
            question: The reviewer's free-text question.
        Returns:
            The _execute result dict, plus the original question and the run
            mode ('live-llm' or 'mock-llm').
        """
        
        raw = self._call_llm(question)
        plan = self._parse_plan(raw)
        result = self._execute(plan)
        result["question"] = question
        result["mode"] = "live-llm" if self._client is not None else "mock-llm"
        return result
