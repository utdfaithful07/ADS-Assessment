################################################################################
# Question 3.1: TEAE Summary Table using {gtsummary}
################################################################################
# Objective : Summary table of treatment-emergent adverse events (TEAEs) 
#             nested System Organ Class (SOC) -> Preferred Term (PT), by treatment arm,
#             with an overall (all-subjects) column.  
#
# Input     : pharmaverseadam::adae, pharmaverseadam::adsl 
# Output    : question_3_tlg/output/ae_summary_table.html 
# 
# Date: 26JUN2026
# Author: utdfaithful07 
################################################################################

### Importing libraries and ADaM data from pharmaverseadam
library(dplyr)
library(admiral)
library(gt)
library(gtsummary)
library(pharmaverseadam)

### Sourcing dev_functions.R script  
source("utils/dev_functions.R")

### Reading in ADaMs
adsl <- pharmaverse_in("adsl", domain_type = "ADaM") 
adae <- pharmaverse_in("adae", domain_type = "ADaM")   


## Data subsetting - using SAFFL == "Y" as a guard to avoid screen failures in ADAE
teae <- adae |>
  dplyr::filter(TRTEMFL == "Y" & SAFFL == "Y")

## Filtering ADSL by SAFFL == "Y" 
adsl0 <- adsl |>
  filter(SAFFL == "Y")


### TLF production
ae_tbl <- teae |>
  gtsummary::tbl_hierarchical(
    variables = c(AESOC, AETERM) ,
    by = ACTARM,
    id = USUBJID ,
    denominator = adsl0, 
    overall_row = TRUE ,
    label = list(..ard_hierarchical_overall.. = "Subjects with at least one TEAE")
  ) |>
  
  # Including total column per instructions with gtsummary::add_overall
  gtsummary::add_overall(last = TRUE, col_label = "**Total** N = {N}") |>
  
  # Sorting by descending frequency using gtsummary::sort_hierarchical
  gtsummary::sort_hierarchical(sort="descending") |> 

  # Adding TLF header with gtsummary::modify_caption
  gtsummary::modify_caption("**Treatment-Emergent Adverse Events by System Organ Class and Preferred Term**")
  
  
### Exporting as HTML with dynamic footnote letting reviewer know when TLF is generated 
gen_time <- format(Sys.time(), "%d%b%Y %H:%M %Z", tz="America/New_York" )
path <- "question_3_tlg/output/"
  
ae_tbl |>
  gtsummary::as_gt() |>
  gt::tab_source_note(
    source_note = gt::md(paste0("*Output generated: ", gen_time, "*"))
  ) |>
  gt::gtsave(filename = "question_3_tlg/output/ae_summary_table.html")  



