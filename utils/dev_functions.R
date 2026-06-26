### Purpose: Centralized location to store functions that are used across questions
### Date: 26JUN2026
### Author: utdfaithful07

#### sdtm_in function 
## Purpose: load SDTMs from pharmaversesdtm and admiral::convert_blanks_to_na() all with one function
sdtm_in <- function(sdtm_name) {
  getExportedValue("pharmaversesdtm", sdtm_name) |>
    admiral::convert_blanks_to_na()
}
