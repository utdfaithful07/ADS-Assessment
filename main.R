############################################################################################
## Name: main.R  
## Purpose: Driver script to run all scripts and generate logs for each question/tests 
## Date: 27JUN2026
## Author: utdfaithful07
############################################################################################


# main.R — run from project root
library(logrx)


# Q1: Create the DS domain (logged)
logrx::axecute(
  "question_1_sdtm/01_create_ds_domain.R",
  log_name = "01_create_ds_domain.log",
  log_path = "question_1_sdtm/logs"
)

# Q1: Conformance checks (logged separately)
axecute(
  "question_1_sdtm/tests/test_ds.R",
  log_name = "test_ds.log",
  log_path = "question_1_sdtm/logs"
)

# Q2: Build the ADSL (logged)
axecute(
  file     = "question_2_adam/create_adsl.R",
  log_name = "create_adsl.log",
  log_path = "question_2_adam/logs"
)

# Q2: Conformance checks against the saved ADSL (logged separately)
axecute(
  file     = "question_2_adam/tests/test_adsl.R",
  log_name = "test_adsl.log",
  log_path = "question_2_adam/logs"
)