fluidPage(
  useShinyjs(),
  tags$head(
    tags$script(src = "js/wavesurfer.min.js"),
    tags$script(src = "js/spectrogram.min.js"),
    tags$style(HTML("#waveform { 
                    width: 100% !important; 
                    height: 100px !important; 
                    margin-top: 10px; 
                    border: 1px solid #ccc; 
                    } 
                    #spectrogram { 
                    width: 100% !important; 
                    height: 150px !important; 
                    margin-top: 10px; 
                    border: 1px solid #ccc; 
                    } 
                    #now_playing { 
                    margin-top: 20px; 
                    padding: 10px; 
                    background-color: #f9f9f9; 
                    border: 1px solid #ccc; 
                    font-size: 14px; 
                    width: 100%; 
                    }")),
    tags$style(HTML("
    .hidden { display: none; }
    /* Style the time slider to be compact */
    .time-slider .irs-grid-text { font-size: 9px; }
  "))
  ),
  
  # Main plot row
  fluidRow(
    column(12, 
           div(style = "position: absolute; top: 10px; left: 10px; 
            background: rgba(255,255,255,0.85);
            padding: 10px; border-radius: 8px; 
            box-shadow: 0 2px 6px rgba(0,0,0,0.2); 
            z-index: 10; width: 270px;",
               
               actionButton("toggle_controls", label = NULL,
                            style = "
                   width: 100%; 
                   height: 8px; 
                   padding: 0; 
                   margin-bottom: 5px;
                   background-color: #002FA7; 
                   border: none;
                   border-radius: 4px;
                   cursor: pointer;
                 "),
               
               div(id = "controls_panel",
                   
                   # Select Dataframe
                   div("Select Dataframe:", style = "font-size: 12px; margin-bottom: 2px;"),
                   selectInput("selected_dataframe", label = NULL, choices = dataframes, selected = dataframes[1]),
                   
                   # Recording Period
                   div("Recording Period:", style = "font-size: 12px; margin-bottom: 2px; margin-top: 5px;"),
                   selectInput("selected_period", label = NULL, choices = names(recording_periods), selected = recording_periods),
                   
                   # Season Filter
                   div("Season:", style = "font-size: 12px; margin-bottom: 2px; margin-top: 5px;"),
                   selectInput("selected_season", label = NULL,
                               choices = c("All", "Monsoon", "Dry"),
                               selected = "All"),
                   
                   # ── NEW: Time Range Slider ──────────────────────────────
                   div("Time Range:", style = "font-size: 12px; margin-bottom: 2px; margin-top: 5px;"),
                   # Values are minutes since midnight (0–1410 in 30-min steps)
                   sliderInput(
                     "time_range",
                     label    = NULL,
                     min      = 0,
                     max      = 1410,        # 23:30
                     value    = c(0, 1410),  # default: full day
                     step     = 30,
                     ticks    = FALSE,
                     # Custom tick labels via post/pre not available directly;
                     # we use a JS hook below to show HH:MM in the bubble
                     animate  = FALSE
                   ),
                   # Live label showing selected range in HH:MM
                   uiOutput("time_range_label"),
                   # ────────────────────────────────────────────────────────
                   
                   # Select Site(s)
                   div("Select Site(s):", style = "font-size: 12px; margin-bottom: 2px; margin-top: 5px;"),
                   selectInput("selected_sites", label = NULL, choices = sampling_sites, 
                               selected = sampling_sites, multiple = TRUE),
                   
                   # Acoustic Indices
                   div("Acoustic Indices:", style = "font-size: 12px; margin-bottom: 2px; margin-top: 5px;"),
                   selectInput("selected_indices", label = NULL, choices = acoustic_indices, multiple = TRUE),
                   
                   # Colour By
                   div("Colour By:", style = "font-size: 12px; margin-bottom: 2px; margin-top: 5px;"),
                   selectInput("color_by", label = NULL, choices = c("Site", "Month", "Season", "QBR_Class", "Strahler_Class"), selected = "Site"),
                   
                   actionButton("compute", "Compute", class = "btn-primary")
               )
           ),
           plotlyOutput("main_plot", height = "600px")
    )
  ),
  
  # PCA Popup panel
  div(style = "position: absolute; top: 10px; left: 300px; 
           background: rgba(255,255,255,0.85);
           padding: 10px; border-radius: 8px; 
           box-shadow: 0 2px 6px rgba(0,0,0,0.2); 
           z-index: 10; width: 250px;",
      
      conditionalPanel(
        condition = "input.selected_indices != null && input.selected_indices.length > 3",
        actionButton("toggle_pca_controls", label = NULL,
                     style = "
                     width: 100%; height: 8px; padding: 0; margin-bottom: 5px;
                     background-color: #002FA7; border: none;
                     border-radius: 4px; cursor: pointer;"),
        
        div(id = "pca_controls_panel",
            div("Plot Type:", style = "font-size: 12px; margin-bottom: 2px;"),
            selectInput("plot_type", label = NULL, 
                        choices = c("Scatter 3D", "Scatter 2D", "Diel Line 2D", "Diel Line 3D", "Boxplot"), 
                        selected = "Scatter 3D"),
            
            div("PCA Axes:", style = "font-size: 12px; margin-bottom: 2px; margin-top: 5px;"),
            
            conditionalPanel(
              condition = "input.plot_type == 'Scatter 3D'",
              selectInput("pca_x", "X-axis", choices = paste0("PC", 1:10), selected = "PC1"),
              selectInput("pca_y", "Y-axis", choices = paste0("PC", 1:10), selected = "PC2"),
              selectInput("pca_z", "Z-axis", choices = paste0("PC", 1:10), selected = "PC3")
            ),
            
            conditionalPanel(
              condition = "input.plot_type == 'Scatter 2D'",
              selectInput("pca_x", "X-axis", choices = paste0("PC", 1:10), selected = "PC1"),
              selectInput("pca_y", "Y-axis", choices = paste0("PC", 1:10), selected = "PC2")
            ),
            
            conditionalPanel(
              condition = "input.plot_type == 'Diel Line 2D'",
              selectInput("pca_y", "Y-axis (PC)", choices = paste0("PC", 1:10), selected = "PC1")
            ),
            
            conditionalPanel(
              condition = "input.plot_type == 'Diel Line 3D'",
              selectInput("pca_y", "Y-axis (PC)", choices = paste0("PC", 1:10), selected = "PC1"),
              selectInput("pca_z", "Z-axis (PC)", choices = paste0("PC", 1:10), selected = "PC2")
            ),
            
            conditionalPanel(
              condition = "input.plot_type == 'Boxplot'",
              selectInput("pca_y", "PC for Boxplot", choices = paste0("PC", 1:10), selected = "PC1")
            ),
            
            actionButton("compute", label = NULL,
                         style = "
                   width: 100%; 
                   height: 8px; 
                   padding: 0; 
                   margin-bottom: 5px;
                   background-color: #002FA7; 
                   border: none;
                   border-radius: 4px;
                   cursor: pointer;
                 ")
        )
      )
  ),
  
  # Bottom row
  fluidRow(
    column(4, 
           div(id = "now_playing",
               span(id = "now_playing_text", "Now Playing: "),
               div(id = "buttons_container", class = "hidden",
                   style = "position: absolute; top: 10px; right: 10px; display: flex; flex-direction: column;",
                   actionButton("play_pause", label = NULL, icon = icon("play"), class = "btn-primary btn-sm", style = "margin-bottom: 5px;"),
                   actionButton("open_file", label = NULL, icon = icon("folder-open"), class = "btn-secondary btn-sm")
               ),
               style = "position: relative; padding: 10px; background-color: #f9f9f9; 
               border: 1px solid #ccc; font-size: 14px; width: 100%; border-radius: 8px;"
           ), 
           div(style = "height: 200px; overflow-y: auto; padding: 10px; border-radius: 8px;", verbatimTextOutput("pca_summary")),
           div(
             id = "pca_results_panel",
             style = "margin-top: 15px;",
             h4("PCA Results"),
             verbatimTextOutput("pca_results"),
             downloadButton("download_pca", "Export PCA Results")
           ),
    ),
    column(8, 
           div(id = "waveform"),
           div(id = "spectrogram")
    )
  )
)
