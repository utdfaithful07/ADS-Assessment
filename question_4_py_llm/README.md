# Question 4: GenAI Clinical Data Assistant

A natural-language to structured-query agent over an adverse-event (AE) dataset.
A reviewer asks free-text questions ("which subjects had moderate events?") and
the agent maps the question to the correct column and value via an LLM, returns
the mapping as structured JSON, then executes the pandas filter and reports the
matching subjects.

## Files

* `clinical_data_agent.py`: the `ClinicalTrialDataAgent` class (schema -> prompt
  -> parse -> execute), with a swappable LLM call.
* `test_queries.py`: runs three example reviewer questions and prints results.
* `data/adae.csv`: the AE dataset (export of `pharmaversesdtm::ae`).
* `requirements.txt`: dependencies (only `pandas` is needed for the mock path).

## Running it

No API key required. The agent falls back to a deterministic mock so the full
Prompt -> Parse -> Execute flow runs out of the box:

```bash
pip install -r requirements.txt
python test_queries.py
```

### Optional: run against live Claude

Set an Anthropic API key and the agent routes through Claude automatically:

```bash
export ANTHROPIC_API_KEY=sk-ant-...   # or put it in a .env file (gitignored)
python test_queries.py
```

When a key is found the output shows `Agent mode: live-llm`; otherwise
`mock-llm`. Both paths produce the same structured result.

### Running on Posit Cloud (via reticulate)

Posit Cloud is R-first, so the simplest way to run the Python there is through
`reticulate` from the R console:

```r
library(reticulate)
py_install(c("pandas", "anthropic", "python-dotenv"))  # one-time setup
source_python("question_4_py_llm/test_queries.py")      # runs the test harness
```

`source_python()` executes the script in reticulate's managed Python
environment. For the live path, make sure `ANTHROPIC_API_KEY` is available to
that environment (e.g. set it in the R session with
`Sys.setenv(ANTHROPIC_API_KEY = "sk-ant-...")` before sourcing, or via a `.env`
file).

## Design notes

* **LLM as a swappable component.** The model call lives behind one method with
  a mock fallback, so the pipeline is reproducible without credentials while
  still doing real intent-mapping when a key is present.
* **Validated structured output.** The JSON is parsed and key-checked (both
  `target_column` and `filter_value` present and non-empty) before execution, so
  a malformed response fails at the parse step rather than corrupting the filter.
* **Schema-driven routing, not hard-coded rules.** Column meanings are described
  to the model, which decides the mapping on the live path. The mock uses light
  keyword heuristics for the offline path only.