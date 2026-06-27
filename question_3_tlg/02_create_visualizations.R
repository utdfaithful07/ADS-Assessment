################################################################################
# Question 3.2: TEAE Summary Table using {gtsummary}
################################################################################
# Objective : Two regulatory-style AE plots.
#   Plot 1 - AE severity distribution by treatment arm  
#   Plot 2 - Top 10 most frequent AEs with 95% CIs
#
#
# Input     : pharmaverseadam::adae, pharmaverseadam::adsl 
# Output : question_3_tlg/output/ae_severity_by_treatment.png
#          question_3_tlg/output/top10_ae_incidence.png
# 
# Date: 26JUN2026
# Author: utdfaithful07 
################################################################################

### Importing libraries and ADaM data from pharmaverseadam
library(dplyr)
library(admiral)
library(pharmaverseadam)
library(ggplot2)
library(tidyr)

### Sourcing dev_functions.R script  
source("utils/dev_functions.R")

### Reading in ADaMs
adsl <- pharmaverse_in("adsl", domain_type = "ADaM") 
adae <- pharmaverse_in("adae", domain_type = "ADaM")   


################################################################################
### Plot 1: AE severity distribution by treatment arm  (stacked bar)
################################################################################

## Filter adae and defensively encoding AESEV/ACTARMs as factors 
sev_levels <- c("MILD", "MODERATE", "SEVERE")

adae0 <- adae |>
  dplyr::filter(!is.na(AESEV) ) |>
  dplyr::mutate(
    AESEV  = factor(AESEV, levels = sev_levels),
    ACTARM = factor(ACTARM)
  )



## Create stacked AE severity distribution by trt arm plot using ggplot2

ae_sev_plot <- adae0 |>
  ggplot2::ggplot(aes(x = ACTARM, fill = AESEV) ) +
  geom_bar() + 
  labs(
    title = "AE Severity Distribution by Treatment Arm" , 
    x = "Treatment Arm" , 
    y = "Count of AEs" , 
    fill  = "Severity/Intensity" ,
    caption = 
  ) 

## Exporting ae_sev_plot to .png file
  ## iron out tomorrow 
ggplot2:: ggsave(
  filename = "question_3_tlg/output/ae_severity_by_treatment.png",
  plot = ae_sev_plot, 
  width = 8, 
  height = 5
)


### Plot 2: Top 10 most frequent AEs with 95% CIs






