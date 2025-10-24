ui <- fluidPage(
  includeCSS("www/styles.css"),
  h2("US Media Policy Dataset Dashboard"),
  br(),
  sidebarLayout(
    sidebarPanel(
      selectInput("year", "Select Year:", 
        choices = c("All", sort(unique(bills$year))), 
        selected = "All"),
      selectInput("status", "Select Status:", 
        choices = c("All", unique(bills$status)), 
        selected = "All"),
      selectInput("state_filter", "Select State:", 
        choices = c("All", unique_states), # Use the variable from global.r
        selected = "All")
    ),
    mainPanel(
      tags$div(class = "card", leafletOutput("map", height = 400)),
      br(),
      tags$div(class = "card", plotlyOutput("pie", height = 300)),
      br(),
      tags$div(class = "card", tableOutput("table"))
    )
  )
)