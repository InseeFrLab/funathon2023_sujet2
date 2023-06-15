###
# Code for the RShiny UI.
###
library(shiny)


# Define UI
ui <- fluidPage(
  leafletOutput("map", height = 800),
  numericInput("buffer_radius", "Rayon (en km) :", value = 5),
  tableOutput("table")
)
