################################################################################
# Question 2: ADaM ADSL Creation using {admiral}
################################################################################
# Objective : Create the ADaM ADSL using admiral package whenever possible 
#
# Vars needed for derivation: AGEGR9/AGEGR9N, TRTSDTM, TRTSTMF, ITTFL, LSTAVLDT
# 
# Date: 26JUN2026
# Author: utdfaithful07 
################################################################################

### Importing libraries and sdtm data from pharmaversesdtm
library(dplyr)
library(lubridate)
library(stringr)
library(haven)
library(pharmaversesdtm)
library(admiral)
library(metatools)
library(labelled)

### Sourcing dev_functions.R script  
source("utils/dev_functions.R")

### Reading in SDTMs
dm <- pharmaverse_in("dm")
suppdm <- pharmaverse_in("suppdm")
ex <- pharmaverse_in("ex")
vs <- pharmaverse_in("vs")
ds <- pharmaverse_in("ds")
ae <- pharmaverse_in("ae")

## Combine DM and SUPPDM for ADSL base  
dm_suppdm <- metatools::combine_supp(dm, suppdm)


### Using DM as base for ADSL
  ### Deriving ITTFL here as well using mutate
adsl0 <- dm_suppdm |>
  dplyr::mutate(
    ITTFL = if_else(!is.na(ARM), "Y", "N")
  ) |>
  dplyr::select(-DOMAIN) 


### Deriving AGEGR9/AGEGR9N (need to use DM.AGE) with admiral functions 
  # sum(is.na(adsl0$AGE)) == 0 (in real example, guard for missing AGE)   
agegr9_lookup <- admiral::exprs(
  ~condition,            ~AGEGR9,    ~AGEGR9N,
  is.na(AGE),            NA_character_,    NA ,
  AGE < 18,              "<18",            1L,
  AGE >= 18 & AGE <= 50, "18 - 50",        2L,
  AGE > 50,              ">50",            3L
)

adsl1 <- adsl0 |>
  admiral::derive_vars_cat(
    definition = agegr9_lookup
  )


### Deriving TRTSDTM/TRTSTMF using EX domain
ex0 <- ex |>
  
  ## convert EXSTDTC to a datetime, impute missing time only 
  admiral::derive_vars_dtm(
    new_vars_prefix  = "EXST",
    dtc              = EXSTDTC,
    highest_imputation = "h",
    time_imputation = "first",
    flag_imputation = "time" ,
    ignore_seconds_flag = TRUE
  ) |>
  
  ## convert EXENDTC to a datetime for ADSL.TRTEDTM derivation due to downstream use for LSTAVLDT
  derive_vars_dtm(
    new_vars_prefix  = "EXEN",
    dtc              = EXENDTC,
    highest_imputation = "h",
    time_imputation = "last",
    flag_imputation = "time" ,
    ignore_seconds_flag = TRUE
  ) 


adsl2 <- adsl1 |>
  
  ## Using admiral::derive_vars_merged to derive TRTSDTM/TRTSTMF
  admiral::derive_vars_merged(
    dataset_add = ex0 ,
    filter_add  = (EXDOSE > 0 | 
                     (EXDOSE == 0 & str_detect(EXTRT, "PLACEBO"))) & 
                    !is.na(EXSTDTM),
    new_vars    = exprs(TRTSDTM = EXSTDTM, TRTSTMF = EXSTTMF),
    order       = exprs(EXSTDTM, EXSEQ),
    mode        = "first",
    by_vars     = exprs(STUDYID, USUBJID)
  ) |>
  
  ## Using admiral::derive_vars_merged to derive TRTEDTM/TRTETMF
  derive_vars_merged(
    dataset_add = ex0 ,
    filter_add  = (EXDOSE > 0 |
                     (EXDOSE == 0 & str_detect(EXTRT, "PLACEBO"))) &
                    !is.na(EXENDTM),
    new_vars    = exprs(TRTEDTM = EXENDTM, TRTETMF = EXENTMF),
    order       = exprs(EXENDTM, EXSEQ),
    mode        = "last",
    by_vars     = exprs(STUDYID, USUBJID)
  ) |>
  
  ## Converting above TRTSDTM and TRTEDTM from datetimes to dates 
  admiral::derive_vars_dtm_to_dt(
    source_vars = exprs(TRTSDTM, TRTEDTM)
  )


### Deriving LSTAVLDT

## Looking into this, and it seems I need to use admiral::derive_vars_extreme_event()
  ## This requires numeric date vars - and not character dates 
  ## Need to then feed a event() input into derive_vars_extreme_event() to derivee 

## Filtering VS and creating date var of VSDTC
vs_dt <- vs |>
  dplyr::filter(!(is.na(VSSTRESN) & (is.na(VSSTRESC) ))) |>
  admiral::derive_vars_dt(
    dtc = VSDTC, 
    new_vars_prefix = "VS"
  ) |>
  filter(!is.na(VSDT) ) |>
  dplyr::group_by(STUDYID, USUBJID) |>
  dplyr::slice_max(VSDT, n = 1, with_ties = FALSE) |>
  ungroup()

## Creating numeric date var for AE and filtering for non-missing date var
ae_dt <- ae |>
  derive_vars_dt(
    dtc = AESTDTC ,
    new_vars_prefix = "AST"
  ) |>
  filter(!is.na(ASTDT ) ) |>
  group_by(STUDYID, USUBJID) |>
  slice_max(ASTDT, n = 1, with_ties = FALSE) |>
  ungroup()

## Creating numeric date var for DS and filtering for non-missing date var
ds_dt <- ds |>
  derive_vars_dt(dtc = DSSTDTC, new_vars_prefix = "DSST") |>
  filter(!is.na(DSSTDT)) |>
  group_by(STUDYID, USUBJID) |>
  slice_max(DSSTDT, n = 1, with_ties = FALSE) |>
  ungroup()


## Creation of event() lists (which point to a source data frame and the date column to consider)
  ## These lists are then feed into derive_vars_extreme_event() downstream
vs_event <- admiral::event(
  dataset_name = "vs",
  set_values_to = exprs(LSTAVLDT = VSDT)
)

ae_event <- event(
  dataset_name = "ae",
  set_values_to = exprs(LSTAVLDT = ASTDT)
)

ds_event <- event(
  dataset_name = "ds",
  set_values_to = exprs(LSTAVLDT = DSSTDT)
)

trt_event <- event(
  dataset_name = "adsl",
  condition     = !is.na(TRTEDT),
  set_values_to = exprs(LSTAVLDT = TRTEDT)    
)

adsl3 <- adsl2 |>
  admiral::derive_vars_extreme_event(
    by_vars      = exprs(STUDYID, USUBJID),
    events       = list(vs_event, ae_event, ds_event, trt_event) ,
    source_datasets  = list(
      vs   = vs_dt,
      ae   = ae_dt,
      ds   = ds_dt,
      adsl = adsl2
    ),
    tmp_event_nr_var = event_nr,
    order            = exprs(LSTAVLDT),
    mode             = "last",
    new_vars         = exprs(LSTAVLDT)
  )

## The duplicate-records warning reflects benign cross-source date agreement 
  # e.g. last dose and last disposition on the same day — and does not affect LSTAVLDT
  # Please see question_2_adam/diagnostics.R for further investigation 


### Output ADSL
adsl <- adsl3 |>
  dplyr::arrange(STUDYID, USUBJID)



####################################################################################
### Adding labels to ADSL using labelled::var_label and exporting as .rds and .xpt  
#####################################################################################
labelled::var_label(adsl) <- list(
  AGEGR9 = "Pooled Age Group 9" ,
  AGEGR9N = "Pooled Age Group 9 (N)" ,
  ITTFL = "Intent-To-Treat Population Flag" ,
  TRTSDTM = "Datetime of First Exposure to Treatment" ,
  TRTSTMF = "Time Imputation Flag for TRTSDTM" ,
  TRTSDT = "Date of First Exposure to Treatment" ,
  TRTEDTM = "Datetime of Last Exposure to Treatment" ,
  TRTEDT = "Date of Last Exposure to Treatment" ,
  LSTAVLDT = "Last Known Alive Date"
)
  
comment(adsl) <- "Subject-Level Analysis Dataset"

saveRDS(adsl, "question_2_adam/output/adsl.rds")
haven::write_xpt(adsl, "question_2_adam/output/adsl.xpt")


