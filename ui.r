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