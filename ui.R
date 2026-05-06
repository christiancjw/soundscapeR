fluidPage(
  useShinyjs(),
  
  tags$head(
    tags$script(src = "js/wavesurfer.min.js"),
    tags$script(src = "js/spectrogram.min.js"),
    tags$link(
      rel  = "stylesheet",
      href = "https://cdnjs.cloudflare.com/ajax/libs/noUiSlider/15.7.1/nouislider.min.css"
    ),
    tags$script(
      src = "https://cdnjs.cloudflare.com/ajax/libs/noUiSlider/15.7.1/nouislider.min.js"
    ),
    tags$style(HTML("

      *, *::before, *::after { box-sizing: border-box; }

      body, html {
        overflow-x: hidden;
        height: 100%;
        margin: 0;
        padding: 0;
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
      }

      .app-wrapper {
        display: flex;
        height: 100vh;
        overflow: hidden;
      }

      .sidebar {
        width: 240px;
        min-width: 160px;
        max-width: 400px;
        flex-shrink: 0;
        background: #f7f7f5;
        display: flex;
        flex-direction: column;
        overflow: hidden;
        position: relative;
        z-index: 20;
      }

      .sidebar-inner {
        flex: 1;
        overflow-y: auto;
        overflow-x: hidden;
        padding: 12px 14px;
      }

      #sidebar_resize {
        width: 5px;
        flex-shrink: 0;
        background: #e0e0dc;
        cursor: ew-resize;
        display: flex;
        align-items: center;
        justify-content: center;
        transition: background 0.15s;
        position: relative;
        z-index: 21;
      }

      #sidebar_resize:hover, #sidebar_resize.dragging {
        background: #b3c8f7;
      }

      #sidebar_resize::after {
        content: '';
        width: 1px;
        height: 32px;
        background: #aaa;
        border-radius: 1px;
      }

      .main-panel {
        flex: 1;
        min-width: 0;
        display: flex;
        flex-direction: column;
        overflow: hidden;
        padding: 12px;
        gap: 0;
        height: 100vh;
      }

      #main_setup {
        flex: 1;
        min-height: 0;
        overflow-y: auto;
      }

      #main_analysis {
        flex: 1;
        min-height: 0;
        display: flex;
        flex-direction: column;
      }

      #plot_pane {
        min-height: 200px;
        overflow: hidden;
        padding-bottom: 4px;
        position: relative;
      }

      #corr_overlay {
        display: none;
        position: absolute;
        top: 0; left: 0;
        width: 100%; height: 100%;
        background: white;
        z-index: 10;
      }

      #corr_overlay .corr-loading {
        display: flex;
        align-items: center;
        justify-content: center;
        height: 100%;
        flex-direction: column;
        gap: 12px;
        color: #aaa;
        font-size: 13px;
      }

      .spinner {
        width: 28px;
        height: 28px;
        border: 3px solid #e0e0dc;
        border-top-color: #1a56db;
        border-radius: 50%;
        animation: spin 0.8s linear infinite;
      }

      @keyframes spin { to { transform: rotate(360deg); } }

      #plot_computing {
        display: none;
        position: absolute;
        top: 0; left: 0;
        width: 100%; height: 100%;
        background: rgba(255,255,255,0.75);
        z-index: 11;
        align-items: center;
        justify-content: center;
        flex-direction: column;
        gap: 12px;
        color: #888;
        font-size: 13px;
      }

      #h_splitter {
        height: 6px;
        background: #f0f0ec;
        border-top: 0.5px solid #e0e0dc;
        border-bottom: 0.5px solid #e0e0dc;
        cursor: ns-resize;
        flex-shrink: 0;
        display: flex;
        align-items: center;
        justify-content: center;
        user-select: none;
        transition: background 0.15s;
      }

      #h_splitter:hover, #h_splitter.dragging {
        background: #d8e4f5;
        border-color: #b3c8f7;
      }

      #h_splitter::after {
        content: '';
        width: 32px;
        height: 2px;
        border-radius: 1px;
        background: #ccc;
      }

      #bottom_row {
        display: flex;
        min-height: 150px;
        overflow: hidden;
        padding-top: 4px;
        gap: 0;
      }

      #bottom_left {
        min-width: 200px;
        display: flex;
        flex-direction: column;
        overflow: hidden;
        padding-right: 4px;
      }

      #bottom_right {
        min-width: 200px;
        display: flex;
        flex-direction: column;
        overflow: hidden;
        padding-left: 4px;
      }

      #v_splitter {
        width: 6px;
        background: #f0f0ec;
        border-left: 0.5px solid #e0e0dc;
        border-right: 0.5px solid #e0e0dc;
        cursor: ew-resize;
        flex-shrink: 0;
        display: flex;
        align-items: center;
        justify-content: center;
        user-select: none;
        transition: background 0.15s;
      }

      #v_splitter:hover, #v_splitter.dragging {
        background: #d8e4f5;
        border-color: #b3c8f7;
      }

      #v_splitter::after {
        content: '';
        width: 2px;
        height: 32px;
        border-radius: 1px;
        background: #ccc;
      }

      .bl-tabs {
        display: flex;
        gap: 3px;
        margin-bottom: 6px;
        flex-shrink: 0;
      }

      .bl-tab {
        font-size: 10px;
        padding: 3px 8px;
        border-radius: 4px;
        border: 0.5px solid #d0d0cc;
        background: white;
        color: #888;
        cursor: pointer;
        user-select: none;
        white-space: nowrap;
      }

      .bl-tab.active {
        background: #e8f0fe;
        color: #1a56db;
        border-color: #b3c8f7;
        font-weight: 500;
      }

      .bl-panel {
        flex: 1;
        min-height: 0;
        overflow-y: auto;
        display: none;
      }

      .bl-panel.active { display: block; }

      .now-playing {
        background: #f7f7f5;
        border: 0.5px solid #e0e0dc;
        border-radius: 8px;
        padding: 8px 12px;
        font-size: 12px;
        color: #444;
        position: relative;
        line-height: 1.6;
        overflow-y: auto;
        flex-shrink: 0;
        max-height: 100px;
        margin-bottom: 6px;
      }

      .pca-summary-box {
        flex: 1;
        min-height: 0;
        overflow-y: auto;
        background: #f7f7f5;
        border: 0.5px solid #e0e0dc;
        border-radius: 8px;
        padding: 8px;
        font-size: 11px;
      }

      #waveform {
        width: 100%;
        flex: 1;
        min-height: 60px;
        border: 0.5px solid #e0e0dc;
        border-radius: 6px;
        overflow: hidden;
      }

      #spectrogram {
        width: 100%;
        flex: 2;
        min-height: 80px;
        border: 0.5px solid #e0e0dc;
        border-radius: 6px;
        overflow: hidden;
        margin-top: 6px;
      }

      .sidebar-tabs {
        display: flex;
        gap: 4px;
        margin-bottom: 10px;
      }

      .sidebar-tab {
        flex: 1;
        font-size: 11px;
        padding: 4px 0;
        text-align: center;
        border-radius: 5px;
        border: 0.5px solid #d0d0cc;
        background: white;
        color: #666;
        cursor: pointer;
        user-select: none;
      }

      .sidebar-tab.active {
        background: #e8f0fe;
        color: #1a56db;
        border-color: #b3c8f7;
        font-weight: 500;
      }

      .disabled-tab {
        opacity: 0.4;
        cursor: not-allowed !important;
        pointer-events: none;
      }

      .section-divider {
        font-size: 9px;
        font-weight: 600;
        color: #1a56db;
        letter-spacing: 0.08em;
        text-transform: uppercase;
        margin-top: 12px;
        margin-bottom: 4px;
        padding-bottom: 3px;
        border-bottom: 0.5px solid #d8e4f5;
        display: block;
      }

      .s-label {
        font-size: 10px;
        color: #aaa;
        letter-spacing: 0.04em;
        margin-top: 8px;
        margin-bottom: 3px;
        display: block;
      }

      .sidebar .form-group { margin-bottom: 4px; }

      .btn-compute {
        width: 100%;
        margin-top: 12px;
        background: #1a56db;
        color: white;
        border: none;
        border-radius: 6px;
        padding: 6px 0;
        font-size: 12px;
        cursor: pointer;
        transition: opacity 0.15s;
      }

      .btn-compute:disabled {
        opacity: 0.5;
        cursor: not-allowed;
      }

      .setup-card {
        background: #f7f7f5;
        border: 0.5px solid #e0e0dc;
        border-radius: 10px;
        padding: 14px 16px;
        margin-bottom: 10px;
      }

      .setup-card-title {
        font-size: 12px;
        font-weight: 500;
        color: #333;
        margin-bottom: 10px;
      }

      .filter-header {
        display: flex;
        justify-content: space-between;
        align-items: center;
        margin-top: 8px;
        margin-bottom: 3px;
      }

      .filter-header-links { display: flex; gap: 6px; }

      .filter-link {
        font-size: 9px;
        color: #1a56db;
        cursor: pointer;
        text-decoration: none;
        user-select: none;
        background: none;
        border: none;
        padding: 0;
      }

      .filter-link.none { color: #999; }

      .index-selector-box {
        background: white;
        border: 0.5px solid #e0e0dc;
        border-radius: 6px;
        padding: 6px 8px;
        max-height: 130px;
        overflow-y: auto;
        margin-right: 2px;
      }

      .meta-filter-box {
        background: white;
        border: 0.5px solid #e0e0dc;
        border-radius: 6px;
        padding: 4px 8px;
        max-height: 90px;
        overflow-y: auto;
        margin-bottom: 2px;
        margin-right: 2px;
      }

      .cb-row {
        display: flex;
        align-items: center;
        gap: 6px;
        padding: 1px 0;
        cursor: pointer;
        user-select: none;
      }

      .cb-row input[type='checkbox'] {
        width: 11px;
        height: 11px;
        flex-shrink: 0;
        cursor: pointer;
        accent-color: #1a56db;
        margin: 0;
      }

      .cb-row span {
        font-size: 10px;
        color: #333;
        line-height: 1.3;
      }

      .index-selector-box .shiny-input-checkboxgroup {
        margin: 0 !important;
        padding: 0 !important;
      }

      .index-selector-box .checkbox {
        margin: 0 !important;
        padding: 0 !important;
        min-height: 0 !important;
      }

      .index-selector-box .checkbox label {
        display: flex !important;
        align-items: center !important;
        gap: 6px !important;
        font-size: 10px !important;
        font-weight: 400 !important;
        color: #333 !important;
        min-height: 0 !important;
        padding: 1px 0 !important;
        cursor: pointer !important;
      }

      .index-selector-box .checkbox input[type='checkbox'] {
        position: static !important;
        margin: 0 !important;
        float: none !important;
        width: 11px !important;
        height: 11px !important;
        flex-shrink: 0 !important;
        accent-color: #1a56db !important;
      }

      .pca-axes-row {
        display: flex;
        gap: 4px;
        margin-right: 2px;
      }

      .pca-axes-row .form-group {
        flex: 1;
        margin-bottom: 0 !important;
      }

      .pca-axes-row label {
        font-size: 9px !important;
        color: #aaa !important;
        margin-bottom: 2px !important;
      }

      .pca-axes-row .selectize-input {
        font-size: 10px !important;
        min-height: 24px !important;
        padding: 2px 5px !important;
      }

      .date-range-row {
        display: flex;
        gap: 6px;
        margin-right: 2px;
      }

      .date-range-row .form-group {
        flex: 1;
        margin-bottom: 0 !important;
      }

      .date-range-row input[type='date'] {
        font-size: 10px !important;
        padding: 3px 5px !important;
        height: 26px !important;
        border: 0.5px solid #e0e0dc !important;
        border-radius: 4px !important;
        width: 100% !important;
      }

      .date-range-row label {
        font-size: 9px !important;
        color: #aaa !important;
        margin-bottom: 2px !important;
      }

      .sidebar .selectize-input {
        font-size: 11px !important;
        min-height: 28px !important;
        padding: 3px 7px !important;
      }

      /* ── noUiSlider theme ────────────────────────────────────────────────── */
      .time-range-label {
        font-size: 11px;
        color: #555;
        text-align: center;
        margin-top: 4px;
        margin-bottom: 6px;
      }

      #time_range_slider,
      #plot_time_range_slider {
        margin: 10px 8px 4px 8px;
      }

      .noUi-target {
        background: #e0e0dc;
        border: none;
        box-shadow: none;
        height: 4px;
        border-radius: 2px;
      }

      .noUi-connect {
        background: #1a56db;
        border-radius: 2px;
      }

      .noUi-handle {
        width: 4px !important;
        height: 18px !important;
        right: -2px !important;
        top: -7px !important;
        border-radius: 2px !important;
        background: #1a56db !important;
        border: none !important;
        box-shadow: none !important;
        cursor: ew-resize !important;
      }

      .noUi-handle:before,
      .noUi-handle:after {
        display: none !important;
      }

      .noUi-handle:hover,
      .noUi-handle.noUi-active {
        background: #0f3ba8 !important;
        height: 22px !important;
        top: -9px !important;
      }

      .noUi-touch-area {
        cursor: ew-resize;
      }

      .hidden { display: none; }
    "))
  ),
  
  div(class = "app-wrapper",
      
      div(id = "sidebar", class = "sidebar",
          div(class = "sidebar-inner",
              
              div(class = "sidebar-tabs",
                  div(id = "tab_setup", class = "sidebar-tab active", "Setup",
                      onclick = "switchTab('setup')"),
                  div(id = "tab_analysis", class = "sidebar-tab disabled-tab", "Analysis",
                      onclick = "if(!this.classList.contains('disabled-tab')) switchTab('analysis')")
              ),
              
              div(id = "panel_setup",
                  projectUI("project")
              ),
              
              div(id = "panel_analysis", style = "display: none;",
                  
                  # ── 1. Acoustic indices ───────────────────────────────────────────
                  div(class = "filter-header",
                      span(class = "s-label", style = "margin: 0;", "Acoustic indices"),
                      div(class = "filter-header-links",
                          tags$button(class = "filter-link",
                                      onclick = "selectAllIndices()", "all"),
                          tags$button(class = "filter-link none",
                                      onclick = "deselectAllIndices()", "none")
                      )
                  ),
                  div(class = "index-selector-box",
                      checkboxGroupInput("selected_indices", label = NULL,
                                         choices = NULL, selected = NULL,
                                         width = "100%")
                  ),
                  
                  # ── 2. Plot type ──────────────────────────────────────────────────
                  span(class = "s-label", "Plot type"),
                  selectInput("plot_type", label = NULL,
                              choices = c("Scatter 3D", "Scatter 2D",
                                          "Diel Line 2D", "Diel Line 3D",
                                          "Boxplot", "Index Correlation"),
                              selected = "Scatter 3D", width = "100%"),
                  
                  # ── 3. PCA axes ───────────────────────────────────────────────────
                  conditionalPanel(
                    condition = "input.plot_type == 'Scatter 3D'",
                    span(class = "s-label", "PCA axes"),
                    div(class = "pca-axes-row",
                        selectInput("pca_x", "X", choices = paste0("PC", 1:10),
                                    selected = "PC1", width = "100%"),
                        selectInput("pca_y", "Y", choices = paste0("PC", 1:10),
                                    selected = "PC2", width = "100%"),
                        selectInput("pca_z", "Z", choices = paste0("PC", 1:10),
                                    selected = "PC3", width = "100%")
                    )
                  ),
                  conditionalPanel(
                    condition = "input.plot_type == 'Scatter 2D'",
                    span(class = "s-label", "PCA axes"),
                    div(class = "pca-axes-row",
                        selectInput("pca_x", "X", choices = paste0("PC", 1:10),
                                    selected = "PC1", width = "100%"),
                        selectInput("pca_y", "Y", choices = paste0("PC", 1:10),
                                    selected = "PC2", width = "100%")
                    )
                  ),
                  conditionalPanel(
                    condition = "input.plot_type == 'Diel Line 2D' ||
                         input.plot_type == 'Diel Line 3D' ||
                         input.plot_type == 'Boxplot'",
                    span(class = "s-label", "PC axis"),
                    div(class = "pca-axes-row",
                        selectInput("pca_y", "Y", choices = paste0("PC", 1:10),
                                    selected = "PC1", width = "100%"),
                        conditionalPanel(
                          condition = "input.plot_type == 'Diel Line 3D'",
                          selectInput("pca_z", "Z", choices = paste0("PC", 1:10),
                                      selected = "PC2", width = "100%")
                        )
                    )
                  ),
                  
                  # ── 4. Colour by ──────────────────────────────────────────────────
                  span(class = "s-label", "Colour by"),
                  selectInput("color_by", label = NULL,
                              choices = NULL, width = "100%"),
                  
                  # ── 5. Compute ────────────────────────────────────────────────────
                  actionButton("compute", "Compute", class = "btn-compute"),
                  
                  # ── 6. Dataframe selection ────────────────────────────────────────
                  span(class = "section-divider", "Dataframe selection"),
                  
                  span(class = "s-label", "Date range"),
                  div(class = "date-range-row",
                      dateInput("date_from", label = "From",
                                value = Sys.Date() - 365, width = "100%"),
                      dateInput("date_to", label = "To",
                                value = Sys.Date(), width = "100%")
                  ),
                  
                  span(class = "s-label", "Time range"),
                  div(id = "time_range_slider"),
                  div(class = "time-range-label", id = "time_range_label_txt",
                      "00:00 - 23:59"),
                  
                  span(class = "s-label", "Metadata filters"),
                  div(id = "analysis_filters_container"),
                  
                  # ── 7. Plotting selection ─────────────────────────────────────────
                  span(class = "section-divider", "Plotting selection"),
                  
                  span(class = "s-label", "Date range"),
                  div(class = "date-range-row",
                      dateInput("plot_date_from", label = "From",
                                value = Sys.Date() - 365, width = "100%"),
                      dateInput("plot_date_to", label = "To",
                                value = Sys.Date(), width = "100%")
                  ),
                  
                  span(class = "s-label", "Time range"),
                  div(id = "plot_time_range_slider"),
                  div(class = "time-range-label", id = "plot_time_range_label_txt",
                      "00:00 - 23:59"),
                  
                  span(class = "s-label", "Metadata filters"),
                  div(id = "plot_filters_container")
              )
          )
      ),
      
      div(id = "sidebar_resize"),
      
      div(class = "main-panel",
          
          div(id = "main_setup",
              setupUI("setup")
          ),
          
          div(id = "main_analysis", style = "display: none;",
              
              uiOutput("analysis_lock_msg"),
              
              div(id = "plot_pane",
                  div(id = "plot_computing",
                      div(class = "spinner"),
                      span("Computing...")
                  ),
                  plotlyOutput("main_plot", height = "100%"),
                  div(id = "corr_overlay",
                      div(style = "position: absolute; top: 8px; right: 8px; z-index: 20;",
                          downloadButton("download_corr", "Save",
                                         class = "btn-sm",
                                         style = "font-size: 9px; padding: 2px 8px;
                                      height: auto; line-height: 1.4;
                                      display: none;",
                                         id = "download_corr_btn")
                      ),
                      div(id = "corr_loading", class = "corr-loading",
                          div(class = "spinner"),
                          span("Computing correlation matrix...")
                      ),
                      div(id = "corr_plot_wrap",
                          style = "display: none; width: 100%; height: 100%;",
                          plotOutput("corr_plot", height = "100%")
                      )
                  )
              ),
              
              div(id = "h_splitter"),
              
              div(id = "bottom_row",
                  
                  div(id = "bottom_left",
                      
                      div(class = "now-playing",
                          span(id = "now_playing_text",
                               style = "font-size: 11px;", "Now playing: -"),
                          div(id = "buttons_container", class = "hidden",
                              style = "position: absolute; top: 8px; right: 8px;
                           display: flex; gap: 4px;",
                              actionButton("play_pause", label = NULL,
                                           icon = icon("play"),
                                           class = "btn-primary btn-sm"),
                              actionButton("open_file", label = NULL,
                                           icon = icon("folder-open"),
                                           class = "btn-secondary btn-sm")
                          )
                      ),
                      
                      div(class = "bl-tabs",
                          div(class = "bl-tab active", "PCA Summary",
                              onclick = "switchBLTab('pca')"),
                          div(class = "bl-tab", "Summary Stats",
                              onclick = "switchBLTab('stats')"),
                          div(class = "bl-tab", "Correlation",
                              onclick = "switchBLTab('corr_tab')")
                      ),
                      
                      div(id = "bl_pca", class = "bl-panel active",
                          div(style = "display: flex; justify-content: space-between;
                           align-items: center; margin-bottom: 6px;",
                              span(style = "font-size: 10px; color: #aaa;
                              letter-spacing: 0.04em;", "PCA summary"),
                              downloadButton("download_pca", "Export",
                                             class = "btn-sm",
                                             style = "font-size: 9px; padding: 2px 8px;
                                        height: auto; line-height: 1.4;")
                          ),
                          verbatimTextOutput("pca_summary")
                      ),
                      
                      div(id = "bl_stats", class = "bl-panel",
                          uiOutput("summary_stats")
                      ),
                      
                      div(id = "bl_corr_tab", class = "bl-panel",
                          div(style = "padding: 8px; font-size: 11px; color: #aaa;",
                              "Switch plot type to 'Index Correlation' and click Compute
                 to render the full correlation matrix above.")
                      )
                  ),
                  
                  div(id = "v_splitter"),
                  
                  div(id = "bottom_right",
                      div(id = "waveform"),
                      div(id = "spectrogram")
                  )
              )
          )
      )
  ),
  
  tags$script(src = "js/soundscapeR.js")
)