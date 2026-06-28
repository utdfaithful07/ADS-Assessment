############################################################################################
## Name:    main.R
## Purpose: Driver script to run all R question scripts and their conformance tests,
##          generating a validated {logrx} run log for each.
##
## Date:    27JUN2026
## Author:  utdfaithful07
##
## Run from the PROJECT ROOT. Each script is executed in a clean environment by
## logrx::axecute(), which writes a per-script log (session info, timings,
## warnings, errors) to the question's logs/ folder. Creation scripts are run
## before their tests, since the tests read the saved output datasets/files.
##
## Note: axecute() logs a failing script and continues to the next call rather
## than halting the driver - so review each log's Errors/Warnings section after a
## full run; a completed driver does not by itself guarantee clean output.
############################################################################################


library(logrx)

### Ensure log directories exist (so a fresh clone runs without error) 
log_dirs <- c(
  "question_1_sdtm/logs",
  "question_2_adam/logs",
  "question_3_tlg/logs"
)

for (d in log_dirs) dir.create(d, recursive = TRUE, showWarnings = FALSE)


############################################################################################
## Question 1: SDTM DS domain
############################################################################################

# Create the DS domain
axecute(
  file     = "question_1_sdtm/01_create_ds_domain.R",
  log_name = "01_create_ds_domain.log",
  log_path = "question_1_sdtm/logs"
)

# Conformance checks against the saved DS domain
axecute(
  file     = "question_1_sdtm/tests/test_ds.R",
  log_name = "test_ds.log",
  log_path = "question_1_sdtm/logs"
)


############################################################################################
## Question 2: ADaM ADSL
############################################################################################

# Build the ADSL
axecute(
  file     = "question_2_adam/create_adsl.R",
  log_name = "create_adsl.log",
  log_path = "question_2_adam/logs"
)

# Conformance checks against the saved ADSL
axecute(
  file     = "question_2_adam/tests/test_adsl.R",
  log_name = "test_adsl.log",
  log_path = "question_2_adam/logs"
)


############################################################################################
## Question 3: TLG - AE summary table + visualizations
############################################################################################

# Create the TEAE summary table
axecute(
  file     = "question_3_tlg/01_create_ae_summary_table.R",
  log_name = "01_create_ae_summary_table.log",
  log_path = "question_3_tlg/logs"
)

# Create the AE visualizations
axecute(
  file     = "question_3_tlg/02_create_visualizations.R",
  log_name = "02_create_visualizations.log",
  log_path = "question_3_tlg/logs"
)

# Conformance checks against the saved table output
axecute(
  file     = "question_3_tlg/tests/test_ae_summary_table.R",
  log_name = "test_ae_summary_table.log",
  log_path = "question_3_tlg/logs"
)

# Conformance checks against the saved visualization outputs
axecute(
  file     = "question_3_tlg/tests/test_visualizations.R",
  log_name = "test_visualizations.log",
  log_path = "question_3_tlg/logs"
)

############################################################################################
## End of driver. Q4 (Python/LLM) runs separately - see question_4_python/README.md.
############################################################################################



