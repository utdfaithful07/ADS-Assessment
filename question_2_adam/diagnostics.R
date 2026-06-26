#################################################################################################################
### Purpose: Investigate error from admiral::derive_vars_extreme_event() with Claude to determine root cause
###          Error = Check duplicates: the dataset which consists of all records selected for any of the events 
###          defined by `events` contains duplicate records with respect to `STUDYID`, `USUBJID`, and `LSTAVLDT` 
###                 
###   
### Date: 26JUN2026 
### Author: utdfaithful07
#################################################################################################################

# NOTE on the "duplicate records STUDYID/USUBJID/LSTAVLDT" warning:
  # This warning is expected and benign here. Each source is already collapsed to
  # one row per subject (slice_max above), so the duplicates are NOT within a
  # source, they are CROSS-source ties: two or more domains independently report
  # the same last date for a subject. Diagnosed across all flagged groups, every
  # case is a cross-source tie (most commonly DS+VS and DS+EX+VS), which is the
  # normal end-of-study pattern: final vitals, last dose, and disposition fall on
  # the same final-visit day. Because we extract only the date and the tied records
  # carry identical dates, LSTAVLDT is correct and deterministic regardless of
  # which tied record is kept. 


# --- Diagnostic: find what's actually duplicated across the stacked sources ---
library(dplyr)

int_path <- "question_2_adam/output/intermediate/"

vs_dt <- readRDS(paste0(int_path, "vs_dt.rds"))
ae_dt <- readRDS(paste0(int_path, "ae_dt.rds"))
ds_dt <- readRDS(paste0(int_path, "ds_dt.rds"))
adsl2 <- readRDS(paste0(int_path, "adsl2.rds"))


stacked <- bind_rows(
  vs_dt |> transmute(STUDYID, USUBJID, LSTAVLDT = VSDT,    SRC = "VS"),
  ae_dt |> transmute(STUDYID, USUBJID, LSTAVLDT = ASTDT,  SRC = "AE"),
  ds_dt |> transmute(STUDYID, USUBJID, LSTAVLDT = DSSTDT, SRC = "DS"),
  adsl2  |> filter(!is.na(TRTEDT)) |>
    transmute(STUDYID, USUBJID, LSTAVLDT = TRTEDT, SRC = "EX")
)

dups <- stacked |>
  group_by(STUDYID, USUBJID, LSTAVLDT) |>
  filter(n() > 1) |>
  arrange(USUBJID, LSTAVLDT) |>
  ungroup()

print(dups)

## Save dups
saveRDS(dups, "question_2_adam/output/dups.rds")

 

