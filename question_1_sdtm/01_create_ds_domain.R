### Purpose: Create DS from raw clinical data using R (pharmaverse/sdtm.oak) 
### Date: 22JUN2026
### Author: utdfaithful07 


### Importing libraries
library(dplyr)
library(haven)
library(sdtm.oak)
library(pharmaverse)
library(pharmaverseraw)
library(pharmaversesdtm)


### Reading in ds_raw using pharmaverseraw
ds_raw <- pharmaverseraw::ds_raw

### Reading in sdtm_ct.csv (study controlled terminology) using readr::read_csv
study_ct <- readr::read_csv("question_1_sdtm/sdtm_ct.csv")

### Using sdtm.oak::generate_oak_id_vars to generate oak_id_vars for downstream traceability  
ds_raw <- ds_raw |>
  sdtm.oak::generate_oak_id_vars(
    pat_var = "PATNUM" ,
    raw_src = "ds_raw"
  )

#### Using pharmaverse DS aCRF on GitHub for assistance in variable mapping

ds <- 
  # DSTERM
  sdtm.oak::assign_no_ct(
    raw_dat = ds_raw,
    raw_var = "IT.DSTERM",
    tgt_var = "DSTERM",
    id_vars = oak_id_vars()
  ) |>
  
  # DSDECOD 
  sdtm.oak::assign_ct(
    raw_dat = ds_raw ,
    raw_var = "IT.DSDECOD" , 
    tgt_var = "DSDECOD" , 
    ct_spec = study_ct , 
    ct_clst = "C66727" ,
    id_vars = oak_id_vars()
    
  )





### Reading in dm from pharmaversesdtm
dm <- pharmaversesdtm::dm

 




## Exporting Ds as .rds, .xpt, .csv
# haven::write_xpt()