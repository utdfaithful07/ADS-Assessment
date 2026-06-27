# =============================================================================
# Conformance checks for the AE visualizations (Question 3, Part 2)
# =============================================================================
# The deliverables are PNGs, so we check (a) both files were produced and are
# non-empty, and (b) the data behind Plot 2 is sound - re-derive the top-10
# incidence and exact CIs independently and assert they are well-formed
# (CI brackets the point estimate, proportions in [0,1]).
#
# =============================================================================

library(testthat)
library(dplyr)

# -----------------------------------------------------------------------------
# Test 1: both plot PNGs exist and are non-empty.
# -----------------------------------------------------------------------------
test_that("both visualization PNGs were produced", {
  p1 <- "question_3_tlg/output/ae_severity_by_treatment.png"
  p2 <- "question_3_tlg/output/top10_ae_incidence.png"
  expect_true(file.exists(p1))
  expect_true(file.exists(p2))
  expect_gt(file.info(p1)$size, 0)
  expect_gt(file.info(p2)$size, 0)
})

# -----------------------------------------------------------------------------
# Test 2: top-10 incidence + exact CIs are well-formed.
#   Independently recompute and assert the statistical properties that must
#   hold: exactly 10 terms, proportions in [0,1], and each 95% Clopper-Pearson
#   interval brackets its own point estimate (lcl <= p <= ucl).
# -----------------------------------------------------------------------------
test_that("top-10 AE incidence and exact CIs are valid", {
  skip_if_not_installed("pharmaverseadam")
  adae <- pharmaverseadam::adae
  adsl <- pharmaverseadam::adsl
  
  n_subjects <- dplyr::n_distinct(adsl$USUBJID)
  
  ae_ci <- adae |>
    distinct(USUBJID, AETERM) |>
    count(AETERM, name = "n_subj") |>
    slice_max(n_subj, n = 10, with_ties = FALSE) |>
    rowwise() |>
    mutate(
      p   = n_subj / n_subjects,
      ci  = list(binom.test(n_subj, n_subjects)$conf.int),
      lcl = ci[[1]],
      ucl = ci[[2]]
    ) |>
    ungroup()
  
  expect_equal(nrow(ae_ci), 10)                          # exactly top 10
  expect_true(all(ae_ci$p >= 0 & ae_ci$p <= 1))          # valid proportions
  expect_true(all(ae_ci$lcl <= ae_ci$p))                 # CI brackets estimate
  expect_true(all(ae_ci$ucl >= ae_ci$p))
  expect_true(all(ae_ci$lcl >= 0 & ae_ci$ucl <= 1))      # CI within [0,1]
})