################################################################################
# Question 3.2: AE Visualizations using {ggplot2}
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

### Sourcing dev_functions.R script  
source("utils/dev_functions.R")

### Reading in ADaMs
adsl <- pharmaverse_in("adsl", domain_type = "ADaM") 
adae <- pharmaverse_in("adae", domain_type = "ADaM")   


################################################################################
### Plot 1: AE severity distribution by treatment arm  (stacked bar)
################################################################################

## Filter adae and defensively encoding AESEV/ACTARMs as factors to ensure desired ordering on plot
sev_levels <- c("MILD", "MODERATE", "SEVERE")

adae0 <- adae |>
  dplyr::filter(!is.na(AESEV) ) |>
  dplyr::mutate(
    AESEV  = factor(AESEV, levels = sev_levels),
    ACTARM = factor(ACTARM)
  )

## Create stacked AE severity distribution by trt arm plot using ggplot2 with gen_time function 
ae_sev_plot <- adae0 |>
  ggplot2::ggplot(aes(x = ACTARM, fill = AESEV) ) +
  geom_bar() + 
  labs(
    title = "AE Severity Distribution by Treatment Arm" , 
    x = "Treatment Arm" , 
    y = "Count of AEs" , 
    fill  = "Severity/Intensity" ,
    caption = gen_time()
  ) 

### Exporting ae_sev_plot to .png file 
ggplot2:: ggsave(
  filename = "question_3_tlg/output/ae_severity_by_treatment.png",
  plot = ae_sev_plot, 
  width = 8, 
  height = 5
)

################################################################################
### Plot 2: Top 10 most frequent AEs with 95% CIs (Forest Plot)
################################################################################

## Total subjects from ADSL wit SAFFL=="Y" for incidence denominator 
n_subjects <- adsl |>
  filter(SAFFL == "Y") |>
  dplyr::distinct(USUBJID) |>
  nrow()

## Using dplyr functions on adae to obtain top 10 counts for AETERM
  ## filter for non-missing(AETERM) and SAFFL=="Y" / Sort by desc n 
aeterm_counts <- adae |>
  filter(!is.na(AETERM) & SAFFL == "Y" ) |>
  dplyr::distinct(USUBJID, AETERM) |> 
  dplyr::count(AETERM, name="n_ae") |> 
  dplyr::slice_max(n_ae, n=10, with_ties=FALSE ) |> 
  dplyr::arrange(desc(n_ae))

## Generate Clopper-Pearson 95% CIs for each term's incidence proportion
  # Debugged with Claude
aeterm_ci <- aeterm_counts |>
  dplyr::rowwise() |>
  mutate(
    pct = n_ae / n_subjects ,
    ci  = list(binom.test(n_ae, n_subjects)$conf.int),
    lcl = ci[[1]],
    ucl = ci[[2]]
  ) |>
  dplyr::ungroup() |>
  dplyr::select(-ci) |>
  # Defensive: order factor so the most frequent AE sits at the top of the plot
  mutate(AETERM = factor(AETERM, levels = rev(aeterm_counts$AETERM)))

## Generate forest plot
forest_plot <- aeterm_ci |>
  ggplot(aes(x = pct, y = AETERM) ) + 
  ggplot2::geom_errorbar(aes(xmin = lcl, xmax = ucl), width = 0.3) +
  ggplot2::geom_point(size = 4) + 
  ggplot2::scale_x_continuous(
    labels = scales::percent_format(accuracy = 1) 
  ) +
  labs(
    title = "Top 10 Most Frequent Adverse Events" ,
    subtitle = paste0("n = ", n_subjects, " subjects; 95% Clopper-Pearson CIs" ) ,
    x = "Percentage of Patients (%)",
    y = NULL, 
    caption = gen_time()
  )

### Exporting forest_plot to .png file 
ggsave(
  filename = "question_3_tlg/output/top10_ae_incidence.png",
  plot = forest_plot, 
  width = 8, 
  height = 5 
)




