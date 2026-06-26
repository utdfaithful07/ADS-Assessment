################################################################################
# Question 1: SDTM Disposition (DS) Domain Creation using {sdtm.oak}
################################################################################
# Objective : Create the SDTM DS domain from pharmaverseraw::ds_raw using the
#             {sdtm.oak} package, study controlled terminology, and the mapping
#             rules specified in the Subject Disposition aCRF.
#
# Target vars: STUDYID, DOMAIN, USUBJID, DSSEQ, DSTERM, DSDECOD, DSCAT,
#              VISITNUM, VISIT, DSDTC, DSSTDTC, DSSTDY
#
# Date: 24JUN2026
# Author: utdfaithful07 
################################################################################


### Importing libraries and raw data from pharmaverseraw::ds_raw for mapping
library(dplyr)
library(haven)
library(sdtm.oak)
library(pharmaverse)
library(pharmaverseraw)
library(pharmaversesdtm)
library(labelled)

ds_raw <- pharmaverseraw::ds_raw

### Reading in pharmaversesdtm::dm for downstream DSSTDY derivation 
dm <- pharmaversesdtm::dm

### Reading in sdtm_ct.csv (study controlled terminology) using readr::read_csv
study_ct <- readr::read_csv("question_1_sdtm/sdtm_ct.csv")

### Using sdtm.oak::generate_oak_id_vars to generate oak_id_vars for downstream traceability  
ds_raw <- ds_raw |>
  sdtm.oak::generate_oak_id_vars(
    pat_var = "PATNUM" ,
    raw_src = "ds_raw"
  )


#### Using pharmaverse DS aCRF on GitHub for assistance in variable mapping

## Mapping DSTERM + DSDECOD
ds0 <- 
  # DSTERM - logic displayed on aCRF (need to use OTHERSP) here 
  sdtm.oak::assign_no_ct(
    raw_dat = condition_add(ds_raw, is.na(OTHERSP) ) ,
    raw_var = "IT.DSTERM",
    tgt_var = "DSTERM",
    id_vars = oak_id_vars()
  ) |>

  assign_no_ct(
    raw_dat = condition_add(ds_raw, !is.na(OTHERSP) ) ,
    raw_var = "OTHERSP",
    tgt_var = "DSTERM",
    id_vars = oak_id_vars()
  ) |>
  
  # DSDECOD - logic displayed on aCRF (need to utilize )
    # when is.na(OTHERSP)
  sdtm.oak::assign_ct(
    raw_dat = condition_add(ds_raw, is.na(OTHERSP) ) ,
    raw_var = "IT.DSDECOD" ,
    tgt_var = "DSDECOD" ,
    ct_spec = study_ct , 
    ct_clst = "C66727" , 
    id_vars = oak_id_vars()
  ) |>
  
    # when !is.na(OTHERSP) - map value to DSDECOD
  assign_no_ct(
    raw_dat = condition_add(ds_raw, !is.na(OTHERSP) ) ,
    raw_var = "OTHERSP",
    tgt_var = "DSDECOD",
    id_vars = oak_id_vars()
  ) 

## Mapping DSCAT
ds1 <- ds0 |>
  
  ## DSCAT - utilizing OTHERSP and DSDECOD for derivation

  # OTHERSP condition - using sdtm.oak::hardcode_no_ct for hardcoding logic
  sdtm.oak::hardcode_no_ct(
    raw_dat = condition_add(ds_raw, !is.na(OTHERSP) ) ,
    raw_var = "OTHERSP", 
    tgt_var = "DSCAT" ,
    tgt_val = "OTHER EVENT" ,
    id_vars = oak_id_vars()
  ) |>
  
  # DSDECOD logic - IT.DSDECOD == "Randomized"
  hardcode_no_ct(
    raw_dat = condition_add(ds_raw, is.na(OTHERSP) & IT.DSDECOD == "Randomized" ) ,
    raw_var = "IT.DSDECOD" ,
    tgt_var = "DSCAT" ,
    tgt_val = "PROTOCOL MILESTONE" , 
    id_vars = oak_id_vars()
  ) |> 
  
  # DSDECOD logic - IT.DSDECOD != "Randomized"
  hardcode_no_ct(
    raw_dat = condition_add(ds_raw, is.na(OTHERSP) & IT.DSDECOD != "Randomized" ) ,
    raw_var = "IT.DSDECOD" ,
    tgt_var = "DSCAT" ,
    tgt_val = "DISPOSITION EVENT" , 
    id_vars = oak_id_vars()
  ) 

### Mapping date/datetime/visit vars: DSSTDTC, DSDTC, VISIT, VISITNUM
ds2 <- ds1 |> 
  
  ## DSSTDTC - ISO601 format utilized
  sdtm.oak::assign_datetime(
    tgt_var = "DSSTDTC",
    raw_dat = ds_raw , 
    raw_var = "IT.DSSTDAT" ,
    # raw_fmt = "mm-dd-yy",
    raw_fmt = "m-d-y",
    id_vars = oak_id_vars()
  ) |>
  
  ## DSDTC - need to utilize DSDTCOL and DSTMCOL for mapping 
  assign_datetime(
    tgt_var = "DSDTC",
    raw_dat = ds_raw , 
    raw_var = c("DSDTCOL", "DSTMCOL"),
    raw_fmt = c("m-d-y", "H:M") ,
    #raw_fmt = c("mm-dd-yy", "H:M") ,
    id_vars = oak_id_vars()
  ) |> 
  
  # VISIT - using study_ct
  assign_ct(
    raw_dat = ds_raw, 
    raw_var = "INSTANCE",
    tgt_var = "VISIT",
    ct_spec = study_ct,
    ct_clst = "VISIT",
    id_vars = oak_id_vars()
  ) |>
  
  # VISITNUM - using study_ct
  assign_ct(
    raw_dat = ds_raw, 
    raw_var = "INSTANCE",
    tgt_var = "VISITNUM",
    ct_spec = study_ct,
    ct_clst = "VISITNUM",
    id_vars = oak_id_vars()
  ) 


## Deriving STUDYID, DOMAIN, USUBJID, DSSEQ
ds3 <- ds2 |>
  dplyr::mutate(
    STUDYID = ds_raw$STUDY ,
    DOMAIN = "DS" ,
    USUBJID = paste0(STUDYID, "-", patient_number )
  ) |>
  
  ## Using sdtm.oak::derive_study_day to derive DSSTDY
  sdtm.oak::derive_study_day(
    dm_domain = dm,
    tgdt = "DSSTDTC",
    refdt = "RFXSTDTC",
    study_day_var = "DSSTDY"
  ) |>
  
  ## Using sdtm.oak::derive_seq to derive DSSEQ
  sdtm.oak::derive_seq(
    tgt_var = "DSSEQ" ,
    rec_vars = c("USUBJID", "DSDECOD", "DSSTDTC" )
  )


### Final structure of DS data frame 
ds <- ds3 |>
  dplyr::select(
    STUDYID, DOMAIN, USUBJID, DSSEQ, DSTERM, DSDECOD, DSCAT, 
    VISITNUM, VISIT, DSDTC,DSSTDTC, DSSTDY
  ) |>
  dplyr::arrange(USUBJID, DSSEQ)

## Adding corresponding variable labels using SDTM IG 3.4 as reference 
  ## labelled::var_label() utilized for cleaner code 
labelled::var_label(ds) <- list(
  STUDYID = "Study Identifier" ,
  DOMAIN = "Domain Abbreviation" ,
  USUBJID = "Unique Subject Identifier" ,
  DSSEQ = "Sequence Number" ,
  DSTERM = "Reported Term for the Disposition Event" ,
  DSDECOD = "Standardized Disposition Term" ,
  DSCAT = "Category for Disposition Event" ,
  VISITNUM = "Visit Number" ,
  VISIT = "Visit Name" , 
  DSDTC = "Date/Time of Collection" ,
  DSSTDTC = "Start Date/Time of Disposition Event" ,
  DSSTDY = "Study Day of Start of Disposition Event"
)

## Adding Disposition label to ds
comment(ds) <- "Disposition"

   
################################################################################
### Exporting DS as .rds and .xpt  
################################################################################
saveRDS(ds, "question_1_sdtm/output/ds.rds")
haven::write_xpt(ds, "question_1_sdtm/output/ds.xpt")

