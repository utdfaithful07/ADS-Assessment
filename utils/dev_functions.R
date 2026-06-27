########################################################################################
### Purpose: Centralized location to store functions that are used across questions
### Date: 26JUN2026
### Author: utdfaithful07
########################################################################################

################################################################
### pharmaverse_in function
## Purpose: identify whether SDTMs or ADaMs need to be loaded and then run admiral::convert_blanks_to_na()  
##   args:  data_name: data frame you would like imported 
##          domain_type: either SDTM or ADaM (SDTM is default)
##
##   returns: data frame
################################################################
pharmaverse_in <- function(data_name, domain_type = "sdtm") {
  # Normalize input to lowercase for consistency
  domain_type <- tolower(domain_type)
  
  # Determine the appropriate package name
  pkg_name <- switch(
    domain_type,
    "sdtm" = "pharmaversesdtm", 
    "adam" = "pharmaverseadam",
    stop("Invalid domain_type. Please use either 'sdtm' or 'adam'.")
  )
  
  # Fetch the dataset and convert blanks to NA
  getExportedValue(pkg_name, data_name) |>
    admiral::convert_blanks_to_na()
}

################################################################
### gen_time function
## Purpose: used to create dynamic generated date footnote for outputs 
##
##   returns: current date/time in EST
################################################################
gen_time <- function() paste0("Generated on: ", format(Sys.time(), "%d%b%Y %H:%M %Z", tz="America/New_York"))


