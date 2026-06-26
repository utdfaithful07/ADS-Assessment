# =============================================================================
# Conformance checks for the ADSL dataset (Question 2)
# =============================================================================
# Self-contained: loads its own packages and reads question_2_adam/output/adsl.rds,
# so it runs identically under source(), testthat::test_file(), and
# logrx::axecute("question_2_adam/tests/test_adsl.R").
#
# Focus: the three derivations where the logic is OURS and most worth proving -
#   (1) ITTFL    - "Y" iff ARM is populated
#   (2) TRTSTMF  - imputation flag behaves per spec (and is never set without TRTSDTM)
#   (3) LSTAVLDT - equals the max across the four contributing source dates
#
# Run from PROJECT ROOT:
#   testthat::test_file("question_2_adam/tests/test_adsl.R")
# =============================================================================

library(testthat)
library(dplyr)

adsl_path <- "question_2_adam/output/adsl.rds"

# ---- Sanity: the deliverable exists, one row per subject ---------------------
test_that("ADSL exists and is one row per subject", {
  expect_true(file.exists(adsl_path))
  adsl <- readRDS(adsl_path)
  expect_s3_class(adsl, "data.frame")
  expect_gt(nrow(adsl), 0)
  expect_equal(nrow(adsl), dplyr::n_distinct(adsl$USUBJID))
})

adsl <- readRDS(adsl_path)

# -----------------------------------------------------------------------------
# Test 1: ITTFL is "Y" exactly when ARM is populated, "N" otherwise.
#   Spec: set "Y" if DM.ARM is not missing, else "N".
# -----------------------------------------------------------------------------
test_that("ITTFL flags randomized (ARM-populated) subjects correctly", {
  # Only valid values are Y / N (no NA, no other strings)
  expect_true(all(adsl$ITTFL %in% c("Y", "N")))
  
  # Every "Y" must have a populated ARM; every "N" must have a missing ARM.
  expect_true(all(!is.na(adsl$ARM[adsl$ITTFL == "Y"])))
  expect_true(all(is.na(adsl$ARM[adsl$ITTFL == "N"])))
})

# -----------------------------------------------------------------------------
# Test 2: TRTSTMF (time imputation flag) integrity.
#   - The flag must never be set on a record with no treatment start datetime
#     (can't have imputed a time that doesn't exist).
#   - Where TRTSTMF is populated it only takes admiral's recognised flag values.
#   - ignore_seconds_flag = TRUE means a seconds-only imputation does NOT flag;
#     we assert the flag domain rather than re-deriving, since the raw seconds
#     state isn't carried into ADSL.
# -----------------------------------------------------------------------------
test_that("TRTSTMF is consistent with TRTSDTM and uses valid flag values", {
  # No flag without a datetime to flag.
  no_dtm <- is.na(adsl$TRTSDTM)
  expect_true(all(is.na(adsl$TRTSTMF[no_dtm])))
  
  # Flag domain: admiral uses "H"/"M"/"S" style chars, or NA when not imputed.
  expect_true(all(is.na(adsl$TRTSTMF) | adsl$TRTSTMF %in% c("H", "M", "S")))
})

# -----------------------------------------------------------------------------
# Test 3: LSTAVLDT equals the maximum of the four contributing source dates.
#   Rebuild the four per-subject source maxima independently from the SAME SDTM
#   inputs, take their row-wise max, and confirm it matches the derived LSTAVLDT.
#   This is an INDEPENDENT recomputation (different code path than the script),
#   so it genuinely validates the derive_vars_extreme_event() result.
# -----------------------------------------------------------------------------
test_that("LSTAVLDT is the max across VS / AE / DS / EX source dates", {
  skip_if_not_installed("pharmaversesdtm")
  skip_if_not_installed("admiral")
  library(admiral); library(pharmaversesdtm); library(lubridate)
  
  vs <- convert_blanks_to_na(pharmaversesdtm::vs)
  ae <- convert_blanks_to_na(pharmaversesdtm::ae)
  ds <- convert_blanks_to_na(pharmaversesdtm::ds)
  
  # Independent per-subject source maxima (plain dplyr, no admiral event engine).
  vs_max <- vs |>
    filter(!(is.na(VSSTRESN) & is.na(VSSTRESC)), !is.na(VSDTC)) |>
    mutate(d = ymd(substr(VSDTC, 1, 10))) |>
    filter(!is.na(d)) |>
    group_by(USUBJID) |>
    summarise(vs_d = max(d), .groups = "drop")
  
  ae_max <- ae |>
    filter(!is.na(AESTDTC)) |>
    mutate(d = ymd(substr(AESTDTC, 1, 10))) |>
    filter(!is.na(d)) |>
    group_by(USUBJID) |>
    summarise(ae_d = max(d), .groups = "drop")
  
  ds_max <- ds |>
    filter(!is.na(DSSTDTC)) |>
    mutate(d = ymd(substr(DSSTDTC, 1, 10))) |>
    filter(!is.na(d)) |>
    group_by(USUBJID) |>
    summarise(ds_d = max(d), .groups = "drop")
  
  # EX contribution comes via TRTEDT already on ADSL (the script's 4th source).
  ex_max <- adsl |> select(USUBJID, ex_d = TRTEDT)
  
  expected <- adsl |>
    select(USUBJID, LSTAVLDT) |>
    left_join(vs_max, by = "USUBJID") |>
    left_join(ae_max, by = "USUBJID") |>
    left_join(ds_max, by = "USUBJID") |>
    left_join(ex_max, by = "USUBJID") |>
    rowwise() |>
    mutate(exp_lstavldt = suppressWarnings(
      max(c(vs_d, ae_d, ds_d, ex_d), na.rm = TRUE))) |>
    ungroup() |>
    # max() of all-NA returns -Inf; treat those as NA for comparison.
    mutate(exp_lstavldt = if_else(is.infinite(exp_lstavldt),
                                  as.Date(NA), exp_lstavldt))
  
  # Compare derived vs independently recomputed, allowing both-NA to match.
  mismatch <- expected |>
    filter(!( (is.na(LSTAVLDT) & is.na(exp_lstavldt)) |
                (LSTAVLDT == exp_lstavldt) ))
  
  expect_equal(nrow(mismatch), 0)
})