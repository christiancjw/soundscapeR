library(shiny)
library(plotly)
library(dplyr)
library(lubridate)
library(stringr)
library(shinyjs)

## Setup --------------------------------------------------------------------------------------
### Data Read in ------------------

global_singledevice_RL    <- read.csv("projects/cardamom_riparian_acoustics/data/globalRL_singledevice_data.csv")

### Store datasets in a named list ------------------
datasets <- list(
  "[RL] Global Single Device"       = global_singledevice_RL
)

### Functions  --------------------------------------------------------------------------------------------------------

#### Function to add leading zeros to time values for seeking audio files  ------------------
format_time_for_seeking <- function(time_value) {
  sprintf("%06d", as.numeric(time_value))  # Ensure time is always 6 digits long
}

# Ensures that time column is numeric for all datasets
global_singledevice_RL     <- global_singledevice_RL     %>% mutate(Time = as.numeric(Time))


#### Define available dataframes   -----------------------------
dataframes <- c(
  "[RL] Global Single Device"
)

#### Define recording periods (deployments)  -----------------------------
recording_periods <- list(
  "All Periods" = c(0, 99999999),
  "Nov 2023" = c(20231116, 20231203),
  "Jan 2024" = c(20231230, 20240208),
  "Apr 2024" = c(20240401, 20240501),
  "Jun 2024" = c(20240607, 20240707),
  "Jun 2025" = c(20250605, 20250716)
)

#### Define Seasonality  -----------------------------
assign_season <- function(date_int) {
  dplyr::case_when(
    date_int >= 20231116 & date_int <= 20231203 ~ "Monsoon",
    date_int >= 20231230 & date_int <= 20240208 ~ "Dry",
    date_int >= 20240401 & date_int <= 20240501 ~ "Dry",
    date_int >= 20240607 & date_int <= 20240707 ~ "Monsoon",
    date_int >= 20250605 & date_int <= 20250716 ~ "Monsoon",
    TRUE ~ NA_character_
  )
}

season_colors <- c(
  "Monsoon" = "#4E9AF1",
  "Dry"     = "#E8A838"
)

#### Define available acoustic indices  -----------------------------
acoustic_indices <- c("AcousticComplexity", "TemporalEntropy", "Ndsi", "EventsPerSecond", 
                      "LowFreqCover", "MidFreqCover", "HighFreqCover", "ClusterCount", "ThreeGramCount")

sampling_sites <- c("TaCheyHill", "TaChey", "Arai", "Oda", 
                    "KnaongBatSa", "TaSay", "Kronomh", "DamFive", 
                    "TangRang", "Kravanh Bridge", "PursatTown")

#### Define Site Ordering:   -----------------------
site_order <- c("TaCheyHill", "TaChey", "Arai", "Oda", 
                "KnaongBatSa", "TaSay", "Kronomh", 
                "DamFive", "TangRang", "Kravanh Bridge", "PursatTown")

#### Define a fixed color palette for each site  -----------------------
site_colors <- c(
  "TaCheyHill" = "#103004",
  "TaChey" = "#103F96",
  "Arai" = "#3DA9C7", 
  "Oda" = "#53D4FF",
  "KnaongBatSa" = "#1d601d",
  "TaSay" = "#7DBC62", 
  "Kronomh" = "#74EAA3", 
  "DamFive" = "#b2a539",  
  "TangRang" = "#e8d642",
  "Kravanh Bridge" = "#b5473a",  
  "PursatTown" = "#f87060"   
)

site_colors2 <- c(
  "TaCheyHill" = "#2b4c0e",
  "TaChey" = "#26870f",
  "Arai" = "#30c111", 
  "Oda" = "#afbc1e",
  "KnaongBatSa" = "#007376",
  "TaSay" = "#3bb7b9", 
  "Kronomh" = "#2cb897", 
  "DamFive" = "#b2a539",  
  "TangRang" = "#d1e027",
  "Kravanh Bridge" = "#cf6f31",  
  "PursatTown" = "#bb431d"   
)

#### Month Colours  -----------------------
month_levels <- month.name
month_anchors <- c(
  "January"   = "#5cd66b",
  "April"     = "#f46d43",
  "June"      = "#48a4d3",
  "July"      = "#629dff",
  "December"  = "#62ffe3"
)
month_colors <- colorRampPalette(month_anchors)(12)
names(month_colors) <- month_levels

#### Period Colours  -----------------------
period_anchors <- c(
  "Nov 2023" = "blue",
  "Jan 2024" = "purple",
  "Apr 2024" = "cyan",
  "Jun 2024" = "green",
  "Jun 2025" = "pink"
)

#### QBR Colors -----------------------
qbr_order <- c("Natural (95–100)", "Good (75–90)", "Fair (55–70)", "Poor (30–50)", "Bad (<25)")
strahler_order <- c("1st Order", "2nd Order", "3rd Order", "4th Order", "5th Order")

qbr_colors <- c(
  "Natural (95–100)" = "#006BA6",
  "Good (75–90)"     = "#22A122",
  "Fair (55–70)"     = "#DBCB43",
  "Poor (30–50)"     = "#FF7134",
  "Bad (<25)"        = "#AF3245"
)

strahler_colors <- c(
  "1st Order" = "#266489",
  "2nd Order" = "#68B9C0",
  "3rd Order" = "#90D585",
  "4th Order" = "#F3C151",
  "5th Order" = "#F37F64"
)

# -----------------------------------
# Helper: convert slider minutes-since-midnight to HHMMSS integer
minutes_to_hhmmss <- function(mins) {
  h <- mins %/% 60
  m <- mins %% 60
  as.numeric(sprintf("%02d%02d%02d", h, m, 0))
}

# Helper: format minutes as HH:MM for display
minutes_to_label <- function(mins) {
  sprintf("%02d:%02d", mins %/% 60, mins %% 60)
}

