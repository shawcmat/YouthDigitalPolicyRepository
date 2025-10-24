# Load required libraries
library(shiny)
library(leaflet)
library(dplyr)
library(readr)
library(plotly)
library(sf)
library(htmltools)

ucdavis_blue <- "#092852"
ucdavis_gold <- "#fabd00"

red <- "#C64756"
yellow <- "#FAD586"
green  <- "#184D47"
other <- "#808080"

# Read the data (Using testdata right now)
bills <- read_csv("./data/testdata.csv")

# Load USA state geometry.
load("./data/state_boundaries.Rdata")
state_boundaries$name
state_centers <- st_centroid(state_boundaries) %>% st_coordinates() %>% as.data.frame()
state_boundaries$center.x <- state_centers$X
state_boundaries$center.y <- state_centers$Y

# Merge bill data with state boundaries
bills_map <- merge(bills, state_boundaries, by.x="state", by.y="name", all.x=TRUE, all.y = TRUE) %>% st_as_sf()

bills_map$year <- as.character(bills_map$year)
bills_map$year <- coalesce(bills_map$year, "none")
bills_map$statute_number <- coalesce(bills_map$statute_number, "none")
bills_map$status <- coalesce(bills_map$status, "none")

# Get unique state names for a state filter
unique_states <- sort(unique(bills$state))
