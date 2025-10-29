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
