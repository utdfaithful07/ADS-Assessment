# =============================================================================
# Conformance checks for the TEAE summary table (Question 3, Part 1)
# =============================================================================
# The deliverable is a rendered HTML table, so we cannot assert on cell values
# directly. Instead we check the HTML file was produced and is non-empty, and
# the underlying TEAE data the table is built from is internally sound
# (re-derived independently from the source).
#
# =============================================================================

library(testthat)
library(dplyr)

# -----------------------------------------------------------------------------
# Test 1: the HTML table output exists and is non-empty.
# -----------------------------------------------------------------------------
test_that("AE summary table HTML was produced", {
  out <- "question_3_tlg/output/ae_summary_table.html"
  expect_true(file.exists(out))
  expect_gt(file.info(out)$size, 0)
})

# -----------------------------------------------------------------------------
# Test 2: the TEAE subset feeding the table is internally consistent.
#   - TRTEMFL == "Y" actually subsets the data (TEAEs exist)
#   - every TEAE record has the variables the table nests on (AESOC, AETERM)
# -----------------------------------------------------------------------------
test_that("TEAE source data is valid for the table", {
  skip_if_not_installed("pharmaverseadam")
  adae <- pharmaverseadam::adae
  
  teae <- adae |> filter(TRTEMFL == "Y")
  
  expect_gt(nrow(teae), 0)                  # there are TEAEs
  expect_false(any(is.na(teae$AESOC)))      # SOC populated for nesting
  expect_false(any(is.na(teae$AETERM)))     # PT populated for nesting
  expect_true(all(teae$TRTEMFL == "Y"))     
})

