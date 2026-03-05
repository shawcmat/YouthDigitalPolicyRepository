# Load required libraries
library(shiny)
library(leaflet)
library(dplyr)
library(readr)
library(plotly)
library(sf)
library(htmltools)
library(bslib)

red <- "#C64756"
yellow <- "#FAD586"
green  <- "#184D47"
other <- "#808080"

# Read the data (Using testdata right now)
bills <- read.csv("./data/testdata.csv")

# Load USA state geometry.
state_boundaries <- st_read("./data/state_boundaries.geojson")

# Merge bill data with state boundaries
bills_map <- merge(bills, state_boundaries, by.x="state", by.y="name", all.x=TRUE, all.y = TRUE) %>% st_as_sf()

bills_map$year <- as.character(bills_map$year)
bills_map$year <- coalesce(bills_map$year, "none")
bills_map$statute_number <- coalesce(bills_map$statute_number, "none")
bills_map$status <- coalesce(bills_map$status, "none")

# Get unique state names for a state filter
unique_states <- sort(unique(bills$state))


#----------------------------------------
#
#      UI SECTION
#
#----------------------------------------


ui <- bslib::page_navbar(
  # Main site title
  title = "YDPR",
  # Include CSS in the header
  header = tags$head(
    includeCSS("www/styles.css")
  ),
  bslib::nav_spacer(),
  bslib::nav_panel(
    title = "Dashboard", # The title that appears in the navbar tab
    h1("Youth Digital Policy Repository"),
    p("Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."),
    h4("Last Update: June 2025"),
    tags$div(leafletOutput("map", height = 600)),
    fluidRow(
      column(4, selectInput("year", "Select Year:", 
                  choices = c("All", sort(unique(bills$year))), 
                  selected = "All")),
      column(4, selectInput("status", "Select Status:", 
                  choices = c("All", unique(bills$status)), 
                  selected = "All")),
      column(4, selectInput("state_filter", "Select State:", 
                  choices = c("All", unique_states), # Use the variable from global.r
                  selected = "All"))),
    #br(),
    #tags$div(class = "card", plotlyOutput("pie", height = 300)),
    #br(),
    tags$div(class = "card", tableOutput("table"))
  ),
  bslib::nav_panel(
    title = "About",
    h1("About"),
    p("Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.")
  ),
)

#----------------------------------------
#
#      SERVER SECTION
#
#----------------------------------------

server <- function(input, output, session) {  
  filtered <- reactive({
    req(input$year, input$status, input$state_filter)
    filt_out <- bills_map
    if(input$year != "All"){filt_out <- filt_out %>% filter(year == input$year)}
    if(input$status != "All"){filt_out <- filt_out %>% filter(status == input$status)}
    if(input$state_filter != "All"){filt_out <- filt_out %>% filter(state == input$state_filter)}

    return(filt_out)
  })

  state_summary <- reactive({
      df <- filtered() %>% group_by(state)
      summarized_df <- dplyr::summarise(df,
        popup = paste(
          paste0(statute_number, " (", year, ") - ", status),
          collapse = "<br>"),
        status = case_when(
            any(status == "passed") ~ "passed",
            any(status == "in progress") ~ "in progress",
            any(status == "none") ~ "none",
            TRUE ~ "failed")
    )
    summarized_df$popup <- paste0(summarized_df$state, "<br>", "----", "<br>", summarized_df$popup)
    summarized_df$popup[summarized_df$status == "none"] <- paste0(summarized_df$state, "<br>", "No policies")
    return(summarized_df)
  })

  #observe for map clicks
  observeEvent(input$map_shape_click, {
    click <- input$map_shape_click
    if(is.null(click))
      return()
    
    # event$id contains the 'layerId' of the clicked polygon, which we set to the state name.
    # Update the 'state_filter' select input.
    # If the current filter is already the clicked state, set it back to "All" (optional toggle).
    # Otherwise, set it to the clicked state.
    
    if(input$state_filter != "All"){
      isolate({updateSelectInput(session, "state_filter", selected = "All")})
    }else{
      isolate({updateSelectInput(session, "state_filter", selected = click$id)})
    }

  })


  output$map <- renderLeaflet({
    df <- state_summary()
    conus_bounds <- c(-125, 25, -66, 50)
    if(nrow(df) == 0){
      leaflet() %>%
        addProviderTiles(providers$CartoDB.Positron) %>%
        fitBounds(conus_bounds[1], conus_bounds[2], conus_bounds[3], conus_bounds[4])
    }else{
      leaflet() %>%
      addProviderTiles(providers$CartoDB.Positron) %>%
        fitBounds(conus_bounds[1], conus_bounds[2], conus_bounds[3], conus_bounds[4]) %>%
      addPolygons(data = df,
                  layerId = ~state,
                  label=~lapply(popup, htmltools::HTML),
                       fillColor=~case_when(
                         status == "passed" ~ green,
                         status == "failed" ~ red,
                         status == "in progress" ~ yellow,
                         status == "none" ~ other
                       ),
                       fillOpacity=1,
                       color = "black",
                       weight = 1)
    }
    
  })

  output$pie <- renderPlotly(
    {
        df <- filtered() %>% as.data.frame() %>% count(status)
        df <- df %>% filter(status != "none")
        status_colors <- c(
            "passed" = green,
            "failed" = red,
            "in progress" = yellow
        )
        df$color <- status_colors[df$status]
        plot_ly(df, labels = ~status, values = ~n, type = 'pie', hole = 0.4,
                marker = list(colors = ~color, line = list(color = "white", width = 2))) %>%
                 layout(title = "Policy Status Distribution", legend = list(orientation = "h", xanchor = "center", x = 0.5, valign = "middle"))

    }
  )

  output$table <- renderTable({
    filtered() %>% as.data.frame() %>% select(state, statute_number, year, status) %>% filter(status != "none")
  })
}

shinyApp(ui, server)