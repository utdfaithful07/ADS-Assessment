# Analytical Data Science Programmer - Coding Assessment

Clinical reporting pipeline built on the **pharmaverse** ecosystem: the full
SDTM -> ADaM -> TLG flow in R, plus a bonus GenAI data assistant in Python.

| # | Deliverable | Stack |
|---|-------------|-------|
| 1 | SDTM Disposition (DS) domain | `{sdtm.oak}` |
| 2 | ADaM Subject-Level (ADSL) dataset | `{admiral}` + tidyverse |
| 3 | TLG: TEAE summary table + AE plots | `{gtsummary}`, `{ggplot2}` |
| 4 | *(Bonus)* NL -> structured-query AE assistant | Python, Anthropic API |
 
## Repository structure

```
.
├── main.R                      # Driver: runs all R scripts + tests under {logrx}
├── renv.lock                   # Pinned package versions
├── utils/dev_functions.R       # Shared helpers (data loaders, gen_time())
│
├── question_1_sdtm/
│   ├── 01_create_ds_domain.R
│   ├── sdtm_ct.csv             # Study controlled terminology
│   ├── tests/test_ds.R
│   ├── output/                 # ds.rds, ds.xpt
│   └── logs/
│
├── question_2_adam/
│   ├── create_adsl.R
│   ├── diagnostics.R           # LSTAVLDT duplicate-tie investigation
│   ├── tests/test_adsl.R
│   ├── output/                 # adsl.rds, adsl.xpt (+ diagnostic artifacts*)
│   └── logs/
│
├── question_3_tlg/
│   ├── 01_create_ae_summary_table.R
│   ├── 02_create_visualizations.R
│   ├── tests/                  # test_ae_summary_table.R, test_visualizations.R
│   ├── output/                 # ae_summary_table.html + two PNGs
│   └── logs/
│
└── question_4_py_llm/
    ├── clinical_data_agent.py
    ├── test_queries.py
    ├── data/adae.csv
    └── README.md               # Python setup + run instructions
```

\* `question_2_adam/output/` also contains `dups.rds` and an `intermediate/`
folder: deliberate diagnostic artifacts from the LSTAVLDT work (see Question 2),
kept as evidence rather than stray output.

## Running it

**R pipeline (Q1-3).** The environment is pinned with `renv`. From the project
root:

```r
renv::restore()   # install exact versions from renv.lock
source("main.R")  # run all creation scripts + tests under {logrx}
```

`main.R` runs each script in a clean environment via `logrx::axecute()`, writing
a run log to each question's `logs/` folder. Creation scripts run before their
tests (the tests read the saved outputs). Note that `axecute()` logs a failing
script and continues rather than halting, so the logs are the source of truth
for a clean run.

**Python assistant (Q4).** Runs independently. See
[`question_4_py_llm/README.md`](question_4_py_llm/README.md). It runs with no
credentials (mock) or against live Claude when an `ANTHROPIC_API_KEY` is set.

## Question 1: SDTM DS Domain

Creates the Disposition domain from `pharmaverseraw::ds_raw` per the Subject
Disposition aCRF.

* DSTERM, DSDECOD, and DSCAT are conditioned on whether the free-text `OTHERSP`
  field is populated, using `condition_add()` with mutually exclusive conditions
  so each record maps once and OTHERSP precedence holds by construction.
* DSCAT is three-way: `OTHER EVENT` (OTHERSP populated), `PROTOCOL MILESTONE`
  (randomization), else `DISPOSITION EVENT`.
* DSDECOD is decoded against codelist C66727 via `assign_ct()` using
  `sdtm_ct.csv`.
* The aCRF labels the disposition date `IT.DSSDAT`, but the raw column is
  `IT.DSSTDAT`; the script maps to the actual raw name.

Outputs: `ds.rds`, `ds.xpt`. Tests: structure, key uniqueness, CT conformance,
DSCAT logic.

## Question 2: ADaM ADSL

Builds the subject-level dataset from a DM (+ SUPPDM) base, deriving four
required variables.

* **AGEGR9 / AGEGR9N** via `derive_vars_cat()` (the `18 - 50` bucket is
  inclusive of both endpoints, per the literal labels).
* **TRTSDTM / TRTSTMF** with `ignore_seconds_flag = TRUE`, implementing the spec
  edge case: a seconds-only missing time does not set the imputation flag.
* **LSTAVLDT** as the max across four sources (VS, AE, DS, last exposure), using
  the current `event()` + `derive_vars_extreme_event()` API (the deprecated
  `derive_var_extreme_dt()` was avoided).
* The duplicate-records warning from `derive_vars_extreme_event()` was
  investigated (`diagnostics.R`, `dups.rds`) and found to be benign cross-source
  date ties (final vitals, last dose, and disposition on the same end-of-study
  day). It was documented rather than suppressed, since a tiebreaker would imply
  a source preference that does not exist for a max-of-dates derivation.

Outputs: `adsl.rds`, `adsl.xpt`. Tests: one-row-per-subject, ITTFL/ARM
consistency.

## Question 3: TLG - AE Reporting

**Summary table:** TEAEs nested System Organ Class -> Preferred Term, by
treatment arm, with an overall column.

* `tbl_hierarchical()` with `variables = c(AESOC, AETERM)`; `id = USUBJID` counts
  subjects with at least one event, with `denominator = adsl` for correct
  per-arm percentages.
* Restricted to the safety population (`SAFFL == "Y"`), standard for TEAE
  summaries.
* Dynamic generation timestamp added as a source note.

**Visualizations:**

* Plot 1: AE severity by treatment (stacked bar), ordered MILD/MODERATE/SEVERE.
* Plot 2: Top-10 AEs by subject incidence with 95% Clopper-Pearson (exact
  binomial) CIs via `binom.test()`, matching the spec's named interval.

Outputs: `ae_summary_table.html`, two PNGs. Tests: output existence, TEAE data
validity, exact-CI well-formedness.

## Question 4: GenAI Clinical Data Assistant *(bonus)*

A natural-language to structured-query agent: a reviewer asks free-text
questions ("which subjects had moderate events?"), the agent maps intent to the
right column and value via an LLM, returns structured JSON, then executes the
pandas filter.

* The LLM call sits behind one interface with a deterministic mock fallback, so
  the full Prompt -> Parse -> Execute flow runs with or without credentials.
* Column meanings are described to the model, which decides the routing (live
  path); the mock uses light heuristics for the offline path only.
* The JSON is parsed and key-checked before execution, so a malformed response
  fails at the parse step rather than corrupting the filter.

See [`question_4_py_llm/README.md`](question_4_py_llm/README.md) for setup.

## Reproducibility

* `renv` pins all R package versions; `renv::restore()` recreates the
  environment.
* `{logrx}` produces a run log per script under `*/logs/`.
* Conformance tests per question verify outputs against the spec.
* `main.R` runs the whole R pipeline from a clean session.