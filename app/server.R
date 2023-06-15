###
# Code for the RShiny server.
###
library(shiny)
library(leaflet)


# Define server
server <- function(input, output) {
  
  # Render the map
  output$map <- renderLeaflet({
    leaflet() %>%
      addTiles("http://wxs.ign.fr/essentiels/wmts?REQUEST=GetTile&SERVICE=WMTS&VERSION=1.0.0&STYLE=normal&TILEMATRIXSET=PM&FORMAT=image/jpeg&LAYER=ORTHOIMAGERY.ORTHOPHOTOS&TILEMATRIX={z}&TILEROW={y}&TILECOL={x}") %>%
      setView(lng = -1.4932577154775046, lat = 46.46946179131805, zoom = 12)
  })
  
  # Connect to database
  cnx <- connect_to_db()
  
  # Initialize a reactive value for storing the selected point
  selectedPoint <- reactiveValues(lat = NULL, lng = NULL)
  
  # Handle click event on the map
  observeEvent(input$map_click, {
    
    clickData <- input$map_click
    if (!is.null(clickData)) {
      # Store selected point
      selectedPoint$lat <- clickData$lat
      selectedPoint$lng <- clickData$lng
      
      buffer_radius <- input$buffer_radius
      sf <- query_db(cnx, selectedPoint$lat, selectedPoint$lng, buffer_radius)

      # Update the map with the marker at the selected point
      leafletProxy("map") %>%
        clearMarkers() %>%
        clearShapes() %>%
        addMarkers(lng = selectedPoint$lng, lat = selectedPoint$lat) %>%
        plot_surroundings(sf)
      
      # Computations on queried data
      df <- compute_stats(sf)
      
      # Update rendered table
      output$table <- renderTable({
        df
      })
    }
  })
  
  observeEvent(input$buffer_radius, {
    # Check if a point has been selected
    if (!is.null(selectedPoint$lat) && !is.null(selectedPoint$lng)) {
      # Perform computations based on the selected point and new radius
      buffer_radius <- input$buffer_radius
      sf <- query_db(cnx, selectedPoint$lat, selectedPoint$lng, buffer_radius)
      
      # Update the map with the new polygons
      leafletProxy("map") %>%
        clearShapes() %>%
        plot_surroundings(sf)
      
      # Computations on queried data
      df <- compute_stats(sf)
      
      # Update rendered table
      output$table <- renderTable({
        df
      })
    }
  })
}
