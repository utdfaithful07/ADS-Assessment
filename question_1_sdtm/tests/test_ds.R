# =============================================================================
# Conformance checks for the SDTM DS domain (Question 1)
# =============================================================================
# The below tests are conformance checks on the OUTPUT dataset (question_1_sdtm/output/ds.rds). 
#
# Self-contained by design: loads its own packages and reads the saved output,
# so it runs using logrx::axecute("question_1_sdtm/tests/test_ds.R").
#
# Run:
#   testthat::test_file("question_1_sdtm/tests/test_ds.R")             # report
#   testthat::test_file("question_1_sdtm/tests/test_ds.R",
#                       stop_on_failure = TRUE)                        # hard fail
# =============================================================================

### Libraries 
library(testthat)
library(dplyr)
library(haven)


# -----------------------------------------------------------------------------
# 1. Ensuring DS.xpt exists and is non-empty
# -----------------------------------------------------------------------------
ds_path <- "question_1_sdtm/output/ds.xpt"
  
test_that("DS.xpt exists", {
  expect_true(file.exists(ds_path)) 
  ds <- haven::read_xpt(ds_path)
  expect_gt(nrow(ds), 0)
})


# -----------------------------------------------------------------------------
# 2. Structure: required variables present, in correct names
# -----------------------------------------------------------------------------
test_that("all required SDTM variables are present", {
  required_vars <- c(
    "STUDYID", "DOMAIN", "USUBJID", "DSSEQ", "DSTERM", "DSDECOD",
    "DSCAT", "VISITNUM", "VISIT", "DSDTC", "DSSTDTC", "DSSTDY"
  )
  expect_true(all(required_vars %in% names(ds)))
})


# -----------------------------------------------------------------------------
# 3. Key integrity: DSSEQ unique within USUBJID, no missing keys
# -----------------------------------------------------------------------------
test_that("USUBJID + DSSEQ uniquely identifies each record", {
  expect_false(any(is.na(ds$USUBJID)))
  expect_false(any(is.na(ds$DSSEQ)))
  dup <- ds |> count(USUBJID, DSSEQ) |> filter(n > 1)
  expect_equal(nrow(dup), 0)
})

test_that("DSSEQ is a positive integer-valued sequence", {
  expect_true(all(ds$DSSEQ >= 1))
  expect_true(all(ds$DSSEQ == as.integer(ds$DSSEQ)))
})


# -----------------------------------------------------------------------------
# 4. Every record must have a DSTERM - checking to ensure this
# -----------------------------------------------------------------------------
test_that("Every record has a non-missing DSTERM", {
  expect_false(any(is.na(ds$DSTERM)))
})



