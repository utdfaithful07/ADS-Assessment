# Question 4 — GenAI Clinical Data Assistant

A natural-language → structured-query agent over an adverse-event (ADAE) dataset.
A reviewer asks free-text questions ("which subjects had moderate events?") and
the agent maps the question to the correct column + value via an LLM, returns the
mapping as structured JSON, then executes the pandas filter and reports subjects.

## Files
- `clinical_data_agent.py` — the `ClinicalTrialDataAgent` class (schema → prompt →
  parse → execute), with a Pydantic-validated `QueryPlan` and a swappable LLM call.
- `test_queries.py` — runs three example reviewer questions and prints results.
- `data/adae.csv` — the AE dataset (export of `pharmaverseadam::adae`).

## Running it

No API key required — the agent falls back to a deterministic mock so the full
Prompt → Parse → Execute flow runs out of the box:

```bash
pip install -r requirements.txt
python test_queries.py
```

### Optional: run against real Claude
Set an Anthropic API key and the agent routes through Claude automatically:

```bash
export ANTHROPIC_API_KEY=sk-ant-...   # or put it in a .env file (gitignored)
python test_queries.py
```

(On Posit Cloud: use the RStudio Terminal tab for the commands above.)

## Design notes
- **LLM as a swappable component.** The model call lives behind one method with a
  mock fallback, so the pipeline is reproducible without credentials while still
  exercising real intent-mapping when a key is present.
- **Structured output validated with Pydantic** — a malformed LLM response fails
  at the parse step rather than corrupting the pandas execution.
- **No hard-coded routing rules on the live path** — the schema is described to
  the LLM and the model decides. (The mock uses light heuristics for offline use only.)
