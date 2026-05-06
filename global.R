library(shiny)
library(plotly)
library(dplyr)
library(lubridate)
library(stringr)
library(shinyjs)
library(jsonlite)
library(data.table)
library(GGally)

# ── Time helpers ──────────────────────────────────────────────────────────────
minutes_to_hhmmss <- function(mins) {
  h <- mins %/% 60
  m <- mins %% 60
  as.numeric(sprintf("%02d%02d%02d", h, m, 0))
}

minutes_to_label <- function(mins) {
  sprintf("%02d:%02d", mins %/% 60, mins %% 60)
}

# ── Null coalescing operator ──────────────────────────────────────────────────
`%||%` <- function(a, b) {
  if (!is.null(a) && nchar(trimws(as.character(a))) > 0) a else b
}