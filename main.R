# main.R — run from project root
library(logrx)
library(testthat)


# ---- Q1: create the DS domain (logged) ----
logrx::axecute(
  "question_1_sdtm/01_create_ds_domain.R",
  log_name = "01_create_ds_domain.log",
  log_path = "question_1_sdtm/logs"
)

# ---- Q1: conformance checks (logged separately) ----
axecute(
  "question_1_sdtm/tests/test_ds.R",
  log_name = "test_ds.log",
  log_path = "question_1_sdtm/logs"
)
