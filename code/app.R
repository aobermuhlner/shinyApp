library(shiny)
library(shinyWidgets)
library(data.table)
library(ggplot2)
library(dplyr)
library(shinythemes)

source("data_reader.R")

# Frequency of drugnames
drug_freq <- table(DRUG$drugname)
# Sort by frequency (in decreasing order) and get the names of the drugs
unique_drugs<- names(drug_freq)[order(drug_freq, decreasing = TRUE)]

age_min <- min(DEMO$age, na.rm = TRUE)
age_max <- max(DEMO$age, na.rm = TRUE)

fluidrow_width = 11

# The data frame doesn't exist, so therefore a handmade list is created
custom_column <- c("primaryid","caseid","drug_seq","drugname","prod_ai", "route","year","quarter","age", "sex","reporter_country","outcome_decoded", "indi_pt", "drug_rec_act")
# UI
# -----------------------------------------------------------------------------
ui <- fluidPage(
  theme = shinytheme("superhero"),
  titlePanel("Adverse Event Reporting"),
  sidebarLayout(
    sidebarPanel(
    width = 3, # Changes SidePanel width
      selectizeInput(
        inputId = "drug_select",
        label = "Select a drug",
        choices = NULL, # keep NULL, gets updated in server-side
        multiple = FALSE, 
        selected = NULL,
        # custom change in options
        options = list(
          placeholder = "Select a drug",
          maxOptions = 10
        , width = 2
        )
      ),
      # Filter by Gender
      selectInput(inputId = "sex_filter",
                  label = "Filter by sex",
                  choices = c("All", "Male" = "M", "Female" = "F"),
                  selected = "All"
      ),
      # Filter by Year
      selectInput(inputId = "year_filter",
                  label = "Filter by year",
                  choices = c("All", "2022", "2023"),
                  selected = "All"
      ),
      # Filter by Sequence
      sliderInput(inputId = "sequence_filter",
                  label = "Filter by sequence",
                  min = 1,
                  max = 150,
                  value = c(1, 150)
      ),
      # Filter by Age
      sliderInput(inputId = "age_filter",
                  label = "Filter by age",
                  min = age_min,
                  max = age_max,
                  value = c(age_min, age_max)
      ),
      # Conditional Filter by Therapy Duration
      conditionalPanel(
        condition = "input.tabPanelId == 'plotTabId' && input.plots_tab == 'Therapy Duration' && input.drug_select != ''", # JavaScript syntax
        selectInput(inputId = "therapy_filter",
                    label = "Filter by therapy duration",
                    choices = c("All", "Short term","Medium term", "Long term"),
                    selected = "All"
        )
      ),
      # Conditional Filter by Column
      conditionalPanel(
        condition = "input.tabPanelId == 'data_table_tab'", # JavaScript syntax
        checkboxGroupInput(inputId = "df_column_filter",
                           label = "Columns in table to show:",
                           choices = custom_column,
                           selected = custom_column
        )
      )
    ),
    # Main Panel
    mainPanel(
      width = 9, # Width of Main Panel
      tabsetPanel(
        
        id = "tabPanelId",
        tabPanel("Plots",
                 value = "plotTabId",
                 conditionalPanel(
                   condition = "input.drug_select", # JavaScript syntax
                   tabsetPanel(
                     id = "plots_tab",
                     tabPanel("Reports per Quarter",
                              fluidRow(
                                column(fluidrow_width, plotOutput("reports_per_quarter_plot"))),
                              tags$style(".reports-padding { padding-top: 20px; }"),
                              fluidRow(class = "reports-padding",
                                column(fluidrow_width, dataTableOutput("reports_per_quarter_data")))),
                     tabPanel("Reports per Sequence",
                              fluidRow(
                                column(fluidrow_width, plotOutput("reports_per_sequence_plot"))),
                              tags$style(".reports-padding { padding-top: 20px; }"),
                              fluidRow(class = "reports-padding",
                                       column(fluidrow_width, dataTableOutput("reports_per_sequence_data")))),
                     tabPanel("Therapy Duration",
                              fluidRow(
                                column(fluidrow_width, value="therapy_tab", plotOutput("therapy_durations_plot")))),
                     tabPanel("Indications",
                              fluidRow(
                                column(fluidrow_width, plotOutput("top_indications_plot"))),
                              tags$style(".reports-padding { padding-top: 20px; }"),
                              fluidRow(class = "reports-padding",
                                       column(fluidrow_width, dataTableOutput("top_indications_data")))),
                     tabPanel("Outcome Distribution",
                              fluidRow(
                                column(fluidrow_width, plotOutput("outcome_distribution_plot"))),
                              tags$style(".reports-padding { padding-top: 20px; }"),
                              fluidRow(class = "reports-padding",
                                       column(fluidrow_width, dataTableOutput("outcome_distribution_data")))),
                     tabPanel("Drug Reaction",
                              fluidRow(
                                column(fluidrow_width, plotOutput("drug_reaction_plot"))),
                              tags$style(".reports-padding { padding-top: 20px; }"),
                              fluidRow(class = "reports-padding",
                                       column(fluidrow_width, dataTableOutput("drug_reaction_data")))),
                     tabPanel("Medication mix",
                              fluidRow(class = "reports-padding",
                                column(fluidrow_width, dataTableOutput("medication_mix_data")))),
                     tabPanel("Manufacturers",
                              fluidRow(
                                column(fluidrow_width, plotOutput("top_manufacturers_plot"))),
                              tags$style(".reports-padding { padding-top: 20px; }"),
                              fluidRow(class = "reports-padding",
                                       column(fluidrow_width, dataTableOutput("top_manufacturers_data")))),
                     
                   )
                 )
        ),
        # Additional tab in main panel for the data table
        tabPanel("Table",value="data_table_tab", dataTableOutput("filtered_drug_table")),
        tabPanel("Info", uiOutput("info_text")),
        )
      )
      )
    )

# -----------------------------------------------------------------------------
# SERVER-SIDE
# -----------------------------------------------------------------------------
server <- function(input, output, session) {
  # Updates medicament name filter
  updateSelectizeInput(session,
                       inputId = 'drug_select',
                       selected = "",
                       choices = unique_drugs,
                       # Handles choices server side, improves performance
                       server = TRUE, 
                       options = list(
                         placeholder = "Select a drug",
                         maxOptions = 10
                       ))

  # Filter Data Table by Medicament Name
  drug_data <- reactive({
    data <- join_data_drug(v_drugname = input$drug_select)
    return(data)
  })
  
  # Filter by custom Filters
  filtered_data <- reactive({
    data <- filter_data(drug_data(),
                      v_sex = input$sex_filter,
                      v_age_min = input$age_filter[1],
                      v_age_max = input$age_filter[2],
                      v_year = input$year_filter,
                      v_sequence_min = input$sequence_filter[1],
                      v_sequence_max = input$sequence_filter[2])
    
    
    
    return(data)
    
  })
  
  # Output data table
  output$filtered_drug_table <- renderDataTable({
    data <- filtered_data()
    new_df <- data %>%
      select(input$df_column_filter)
    return(new_df)
    
  }, options = list(
    pageLength = 10, # Only show 10 (custom start)
    searching = TRUE, # Global search
    columnDefs = list(
      list(
        searchable = FALSE, # Deactivate Column searchbar
        targets = "_all" # Choose which column searchbar
      )
    )))
  
  # Hints and Instructions Text
  output$info_text <- renderUI({

      tags$div(
        "Instructions", tags$br(),
        tags$br(),
        "Filters:", tags$br(),
        "Select a medication either from the dropdown menu displaying the top 10 most commonly occurring medications or enter a specific medication.", tags$br(),
        "Filter by gender and year using the dropdown menus.", tags$br(),
        "Enter desired ranges for sequences and age.", tags$br(),
        tags$br(),
        "Under the Plots tab:", tags$br(),
        "You will find multiple tabs providing information on side effects. Some tabs include tables that can be sorted and filtered.", tags$br(),
        "For Therapy Duration, you can additionally filter by the category of therapy type (Short term, medium term, and long term).", tags$br(),
        "There is an additional tab named Table where you can directly search for content within the table.", tags$br(),
        tags$br(),
        "Note: This instruction has been translated from German to English."
      
    )
  })
  
  
  # Every plot outsourced and handled in data_reader.R

  # Render reports per quarter plot
  output$reports_per_quarter_plot <- renderPlot({
    plot_reports_per_quarter(filtered_data())
  })
  
  output$reports_per_quarter_data <- renderDataTable({
    num_reports_per_quarter(filtered_data())
  }, options = list(
    searching = TRUE,
    pageLength = 10,
    columnDefs = list(
      list(
        searchable = FALSE,
        targets = "_all"
      )
      ,
      list(
        orderable = TRUE,
        targets = 0 
      ),
      list(
        orderable = FALSE,
        targets = "_all"
      )
    ),
    order = list(list(0, "asc")) 
  )
  )
  #----------------------------------------------------------------------

  # Render reports per sequence plot
  output$reports_per_sequence_plot <- renderPlot({
    plot_reports_per_sequence(filtered_data())
  })
  
  output$reports_per_sequence_data <- renderDataTable({
    num_reports_per_sequence(filtered_data())
  }, options = list(
      searching = TRUE,
      pageLength = 10,
      columnDefs = list(
        list(
          searchable = FALSE,
          targets = "_all"
        ),
        list(
          orderable = TRUE,
          targets = 0  
        ),
        list(
          orderable = FALSE,
          targets = "_all"
        )
      ),
      order = list(list(0, "asc"))  
  )
  )
  #----------------------------------------------------------------------

  # Render therapy duration plot
  output$therapy_durations_plot <- renderPlot({
    plot_therapy_durations(filtered_data(), input$therapy_filter)
  })
  
  #----------------------------------------------------------------------

  # Render top 10 indications plot
  output$top_indications_plot <- renderPlot({
    plot_top_indications(filtered_data())
  })
  
  output$top_indications_data <- renderDataTable({
    top_indications(filtered_data())
  }, options = list(
    searching = TRUE,
    pageLength = 10,
    columnDefs = list(
      list(
        searchable = FALSE,
        targets = "_all"
      )
      ,
      list(
        orderable = TRUE,
        targets = 1  
      ),
      list(
        orderable = FALSE,
        targets = "_all"
      )
    ),
    order = list(list(1, "desc"))
  )
  )
  #----------------------------------------------------------------------

  # Render outcome distribution plot
  output$outcome_distribution_plot <- renderPlot({
    plot_outcome_distribution(filtered_data())
  })
  
  output$outcome_distribution_data <- renderDataTable({
    outcome_distribution(filtered_data())
  }, options = list(
    searching = TRUE,
    pageLength = 10,
    columnDefs = list(
      list(
        searchable = FALSE,
        targets = "_all"
      )
      ,
      list(
        orderable = TRUE,
        targets = 1  
      ),
      list(
        orderable = FALSE,
        targets = "_all"
      )
    ),
    order = list(list(1, "desc"))
  )
  )
  #----------------------------------------------------------------------
  
  # Render outcome drug_reaction_plot
  output$drug_reaction_plot <- renderPlot({
    plot_drug_reaction(filtered_data())
  })
  
  output$drug_reaction_data <- renderDataTable({
    drug_react_distribution(filtered_data())
  }, options = list(
    pageLength = 10,
    searching = TRUE,
    columnDefs = list(
      list(
        searchable = FALSE,
        targets = "_all"
      )
      ,
      list(
        orderable = TRUE,
        targets = 1  
      ),
      list(
        orderable = FALSE,
        targets = "_all"
      )
    ),
    order = list(list(1, "desc"))
  )
  )
  #----------------------------------------------------------------------

  output$medication_mix_data <- renderDataTable({
    prod_ai_distribution(filtered_data())
  }, options = list(
    pageLength = 10,
    searching = TRUE,
    columnDefs = list(
      list(
        searchable = FALSE,
        targets = "_all"
      )
      ,
      list(
        orderable = TRUE,
        targets = 1  
      ),
      list(
        orderable = FALSE,
        targets = "_all"
      )
    ),
    order = list(list(1, "desc"))
  )
  )
  
  #----------------------------------------------------------------------
  
  # Render outcome Medication mix
  output$top_manufacturers_plot <- renderPlot({
    plot_manufactorer_distribution(filtered_data())
  })
  
  output$top_manufacturers_data <- renderDataTable({
    manufactorer_distribution(filtered_data())
  }, options = list(
    searching = TRUE,
    pageLength = 10,
    columnDefs = list(
      list(
        searchable = FALSE,
        targets = "_all"
      )
      ,
      list(
        orderable = TRUE,
        targets = 1  
      ),
      list(
        orderable = FALSE,
        targets = "_all"
      )
    ),
    order = list(list(1, "desc"))
  )
  )
}

# -----------------------------------------------------------------------------

# Run the app
shinyApp(ui, server)
