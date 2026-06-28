"""
Test script for the ClinicalTrialDataAgent 
========================================================
Runs three example reviewer questions end-to-end and prints the structured
plan + matching subjects for each.

Runs with NO API key (deterministic mock path) so it is reproducible for a reviewer out of the box. 
If ANTHROPIC_API_KEY is set in the environment (or a .env file), it will instead route through Claude automatically.

Usage:
    python test_queries.py
    
Date: 27JUN2026
Author: utdfaithful07 
"""

import os
import pandas as pd

# Optional: load a local .env so ANTHROPIC_API_KEY is picked up if present.
try:
    from dotenv import load_dotenv, find_dotenv
    load_dotenv(find_dotenv())
    
except ImportError:
    pass  # dotenv is optional; the mock path needs no key at all.

from clinical_data_agent import ClinicalTrialDataAgent


def main() -> None:
    
    ## Loading in adae.csv (phamraversesdtm::ae) and running ClinicalTrialDataAgent
    df = pd.read_csv("question_4_py_llm/data/adae.csv")
    
    agent = ClinicalTrialDataAgent(df)

    print(f"Loaded ADAE: {len(df)} rows, {df['USUBJID'].nunique()} subjects.")
    print(f"Agent mode: {'live-llm' if agent._client else 'mock-llm'}\n")

    questions = [
        "Give me the subjects who had Adverse events of Mild severity.",
        "Which patients experienced a Headache?",
        "Show me subjects with cardiac events.",
    ]

    for i, q in enumerate(questions, start=1):
        print(f"--- Query {i} ---")
        print(f"Q: {q}")
        
        try:
            res = agent.query(q)
            print(f"  routed to : {res['target_column']} == '{res['filter_value']}'")
            print(f"  subjects  : {res['n_subjects']} -> {res['subjects']}")
            
        except Exception as e:  # surface any pipeline failure clearly
            print(f"  ERROR: {e}")
        print()


if __name__ == "__main__":
    main()
