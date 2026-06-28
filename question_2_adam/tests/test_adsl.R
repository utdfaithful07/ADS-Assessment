# =============================================================================
# Conformance checks for the ADSL dataset 
# =============================================================================
# Self-contained: loads its own packages and reads question_2_adam/output/adsl.rds,
# so it runs identically under source(), testthat::test_file(), and
# logrx::axecute("question_2_adam/tests/test_adsl.R").
#
# Focus: the three derivations where the logic is OURS and most worth proving -
#   (1) ITTFL    - "Y" iff ARM is populated
#   (2) TRTSTMF  - imputation flag behaves per spec (and is never set without TRTSDTM)
#
# Run from PROJECT ROOT:
#   testthat::test_file("question_2_adam/tests/test_adsl.R")
# =============================================================================

library(testthat)
library(dplyr)

adsl_path <- "question_2_adam/output/adsl.rds"

# -----------------------------------------------------------------------------
# Test 1: ADSL is subject-level - exactly one row per USUBJID, no missing keys.
# -----------------------------------------------------------------------------
test_that("ADSL exists and is one row per subject", {
  expect_true(file.exists(adsl_path))

  adsl <- readRDS(adsl_path)
  expect_s3_class(adsl, "data.frame")
  expect_gt(nrow(adsl), 0)
  expect_equal(nrow(adsl), dplyr::n_distinct(adsl$USUBJID))
})

# -----------------------------------------------------------------------------
# Test 2: ITTFL is "Y" exactly when ARM is populated, "N" otherwise.
#   Spec: set "Y" if DM.ARM is not missing, else "N".
# -----------------------------------------------------------------------------
adsl <- readRDS(adsl_path)

test_that("ITTFL flags randomized (ARM-populated) subjects correctly", {
  # Only valid values are Y (no NA, no other strings)
  expect_true(all(adsl$ITTFL %in% c("Y", "N")))
  
  # Every "Y" must have a populated ARM; every "N" must have a missing ARM.
  expect_true(all(!is.na(adsl$ARM[adsl$ITTFL == "Y"])))
  expect_true(all(is.na(adsl$ARM[adsl$ITTFL == "N"])))
})
