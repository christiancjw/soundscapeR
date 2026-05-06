fluidPage(
  useShinyjs(),
  
  tags$head(
    tags$script(src = "js/wavesurfer.min.js"),
    tags$script(src = "js/spectrogram.min.js"),
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

      /* ── Correlation overlay ─────────────────────────────────────────────── */
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

      @keyframes spin {
        to { transform: rotate(360deg); }
      }

      /* ── Computing overlay on plotly ─────────────────────────────────────── */
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

      /* ── Bottom left tabs ────────────────────────────────────────────────── */
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

      /* ── Now playing ─────────────────────────────────────────────────────── */
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

      /* ── Sidebar tabs ────────────────────────────────────────────────────── */
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

      /* ── Index checkboxes — override Bootstrap ───────────────────────────── */
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

      .hidden { display: none; }
      .time-slider .irs-grid-text { font-size: 9px; }
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
                  
                  span(class = "s-label", "Date range"),
                  div(class = "date-range-row",
                      dateInput("date_from", label = "From",
                                value = Sys.Date() - 365, width = "100%"),
                      dateInput("date_to", label = "To",
                                value = Sys.Date(), width = "100%")
                  ),
                  
                  span(class = "s-label", "Time range"),
                  sliderInput("time_range", label = NULL,
                              min = 0, max = 1410, value = c(0, 1410),
                              step = 30, ticks = FALSE),
                  uiOutput("time_range_label"),
                  
                  span(class = "s-label", "Metadata filters"),
                  div(id = "meta_filters_container"),
                  
                  span(class = "s-label", "Colour by"),
                  selectInput("color_by", label = NULL,
                              choices = NULL, width = "100%"),
                  
                  span(class = "s-label", "Plot type"),
                  selectInput("plot_type", label = NULL,
                              choices = c("Scatter 3D", "Scatter 2D",
                                          "Diel Line 2D", "Diel Line 3D",
                                          "Boxplot", "Index Correlation"),
                              selected = "Scatter 3D", width = "100%"),
                  
                  conditionalPanel(
                    condition = "input.plot_type == 'Scatter 3D'",
                    span(class = "s-label", "PCA axes"),
                    selectInput("pca_x", "X", choices = paste0("PC", 1:10),
                                selected = "PC1", width = "100%"),
                    selectInput("pca_y", "Y", choices = paste0("PC", 1:10),
                                selected = "PC2", width = "100%"),
                    selectInput("pca_z", "Z", choices = paste0("PC", 1:10),
                                selected = "PC3", width = "100%")
                  ),
                  conditionalPanel(
                    condition = "input.plot_type == 'Scatter 2D'",
                    span(class = "s-label", "PCA axes"),
                    selectInput("pca_x", "X", choices = paste0("PC", 1:10),
                                selected = "PC1", width = "100%"),
                    selectInput("pca_y", "Y", choices = paste0("PC", 1:10),
                                selected = "PC2", width = "100%")
                  ),
                  conditionalPanel(
                    condition = "input.plot_type == 'Diel Line 2D' ||
                         input.plot_type == 'Diel Line 3D' ||
                         input.plot_type == 'Boxplot'",
                    span(class = "s-label", "PC (Y axis)"),
                    selectInput("pca_y", "Y", choices = paste0("PC", 1:10),
                                selected = "PC1", width = "100%")
                  ),
                  conditionalPanel(
                    condition = "input.plot_type == 'Diel Line 3D'",
                    selectInput("pca_z", "Z", choices = paste0("PC", 1:10),
                                selected = "PC2", width = "100%")
                  ),
                  
                  actionButton("compute", "Compute", class = "btn-compute")
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
              
              # Plot pane — plotly always present, corr overlay on top
              div(id = "plot_pane",
                  
                  # Computing overlay — shown for all plot types while computing
                  div(id = "plot_computing",
                      div(class = "spinner"),
                      span("Computing…")
                  ),
                  
                  # Plotly — always in DOM
                  plotlyOutput("main_plot", height = "100%"),
                  
                  # Correlation overlay — shown on top when plot_type == Index Correlation
                  div(id = "corr_overlay",
                      # Download button — top right corner
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
                          span("Computing correlation matrix…")
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
                               style = "font-size: 11px;", "Now playing: —"),
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
  
  tags$script(HTML("

    // ── Bottom-left tab switching ─────────────────────────────────────────────
    function switchBLTab(tab) {
      document.querySelectorAll('.bl-tab').forEach(function(t) {
        t.classList.remove('active');
      });
      document.querySelectorAll('.bl-panel').forEach(function(p) {
        p.classList.remove('active');
      });
      var tabEl   = document.querySelector('.bl-tab[onclick*=\"' + tab + '\"]');
      var panelEl = document.getElementById('bl_' + tab);
      if (tabEl)   tabEl.classList.add('active');
      if (panelEl) panelEl.classList.add('active');
    }

    // ── Splitter state ────────────────────────────────────────────────────────
    var splitterState = {
      plotPct:  0.6,
      leftPct:  0.5,
      dragging: null
    };

    function applyLayout() {
      var analysis    = document.getElementById('main_analysis');
      var plotPane    = document.getElementById('plot_pane');
      var bottomRow   = document.getElementById('bottom_row');
      var bottomLeft  = document.getElementById('bottom_left');
      var bottomRight = document.getElementById('bottom_right');
      var hSplit      = document.getElementById('h_splitter');
      var vSplit      = document.getElementById('v_splitter');

      if (!analysis || analysis.style.display === 'none') return;

      var totalH    = analysis.clientHeight;
      var hSplitH   = hSplit ? hSplit.offsetHeight : 6;
      var remaining = totalH - hSplitH - 8;
      var plotH     = Math.max(200, Math.round(remaining * splitterState.plotPct));
      var bottomH   = Math.max(150, remaining - plotH);

      plotPane.style.height  = plotH + 'px';
      bottomRow.style.height = bottomH + 'px';

      var totalW  = bottomRow.clientWidth;
      var vSplitW = vSplit ? vSplit.offsetWidth : 6;
      var availW  = totalW - vSplitW;
      var leftW   = Math.max(200, Math.round(availW * splitterState.leftPct));
      var rightW  = Math.max(200, availW - leftW);

      bottomLeft.style.width      = leftW + 'px';
      bottomLeft.style.flexShrink = '0';
      bottomRight.style.width     = rightW + 'px';
      bottomRight.style.flexShrink = '0';

      resizePlotly();
    }

    function resizePlotly() {
      setTimeout(function() {
        document.querySelectorAll('.js-plotly-plot').forEach(function(p) {
          Plotly.Plots.resize(p);
        });
      }, 30);
    }

    // ── Compute button state ──────────────────────────────────────────────────
    function setComputing(on) {
      var btn = document.getElementById('compute');
      var computing = document.getElementById('plot_computing');
      if (on) {
        btn.disabled    = true;
        btn.textContent = 'Computing…';
        computing.style.display = 'flex';
      } else {
        btn.disabled    = false;
        btn.textContent = 'Compute';
        computing.style.display = 'none';
      }
    }

    Shiny.addCustomMessageHandler('compute_done', function(msg) {
      setComputing(false);
      if (msg.is_corr) {
        document.getElementById('corr_loading').style.display    = 'none';
        document.getElementById('corr_plot_wrap').style.display  = 'block';
        document.getElementById('download_corr_btn').style.display = 'inline-block';
      }
    });
    
    Shiny.addCustomMessageHandler('show_corr', function(msg) {
      var overlay  = document.getElementById('corr_overlay');
      var loading  = document.getElementById('corr_loading');
      var plotWrap = document.getElementById('corr_plot_wrap');
      var dlBtn    = document.getElementById('download_corr_btn');
      if (msg.show) {
        overlay.style.display   = 'block';
        loading.style.display   = 'flex';
        plotWrap.style.display  = 'none';
        dlBtn.style.display     = 'none';
      } else {
        overlay.style.display   = 'none';
        dlBtn.style.display     = 'none';
      }
    });

    // ── Correlation overlay show/hide ─────────────────────────────────────────
    Shiny.addCustomMessageHandler('show_corr', function(msg) {
      var overlay  = document.getElementById('corr_overlay');
      var loading  = document.getElementById('corr_loading');
      var plotWrap = document.getElementById('corr_plot_wrap');
      if (msg.show) {
        overlay.style.display  = 'block';
        loading.style.display  = 'flex';
        plotWrap.style.display = 'none';
      } else {
        overlay.style.display  = 'none';
      }
    });

    // ── Cascade filter state ──────────────────────────────────────────────────
    var filterCombos   = [];
    var filterCols     = [];
    var filterSelected = {};

    Shiny.addCustomMessageHandler('init_filters', function(msg) {
      filterCombos   = msg.combos;
      filterCols     = msg.cols;
      filterSelected = {};
      filterCols.forEach(function(col) {
        var allVals = new Set(filterCombos.map(function(r) { return r[col]; }));
        filterSelected[col] = new Set(allVals);
      });
      renderFilters();
      pushFiltersToShiny();
    });

    function availableFor(col) {
      var otherCols = filterCols.filter(function(c) { return c !== col; });
      var available = new Set();
      filterCombos.forEach(function(row) {
        var passOthers = otherCols.every(function(c) {
          return filterSelected[c].has(row[c]);
        });
        if (passOthers) available.add(row[col]);
      });
      return available;
    }

    function renderFilters() {
      var container = document.getElementById('meta_filters_container');
      if (!container) return;
      container.innerHTML = '';

      filterCols.forEach(function(col) {
        var available = availableFor(col);
        var allVals   = Array.from(new Set(
          filterCombos.map(function(r) { return r[col]; })
        )).sort();

        var header = document.createElement('div');
        header.className = 'filter-header';
        header.style.marginTop = '8px';

        var label = document.createElement('span');
        label.className = 's-label';
        label.style.margin = '0';
        label.textContent = col;

        var links = document.createElement('div');
        links.className = 'filter-header-links';

        var allBtn = document.createElement('button');
        allBtn.className = 'filter-link';
        allBtn.textContent = 'all';
        allBtn.onclick = (function(c, avail) {
          return function() {
            filterSelected[c] = new Set(avail);
            renderFilters();
            pushFiltersToShiny();
          };
        })(col, Array.from(available));

        var noneBtn = document.createElement('button');
        noneBtn.className = 'filter-link none';
        noneBtn.textContent = 'none';
        noneBtn.onclick = (function(c) {
          return function() {
            filterSelected[c] = new Set();
            renderFilters();
            pushFiltersToShiny();
          };
        })(col);

        links.appendChild(allBtn);
        links.appendChild(noneBtn);
        header.appendChild(label);
        header.appendChild(links);
        container.appendChild(header);

        var box = document.createElement('div');
        box.className = 'meta-filter-box';

        allVals.forEach(function(val) {
          var isAvailable = available.has(val);
          var isChecked   = filterSelected[col].has(val);

          var row = document.createElement('label');
          row.className = 'cb-row';
          if (!isAvailable) {
            row.style.opacity = '0.35';
            row.style.cursor  = 'not-allowed';
          }

          var cb = document.createElement('input');
          cb.type     = 'checkbox';
          cb.checked  = isChecked;
          cb.disabled = !isAvailable;

          cb.onchange = (function(c, v) {
            return function() {
              if (this.checked) {
                filterSelected[c].add(v);
              } else {
                filterSelected[c].delete(v);
              }
              renderFilters();
              pushFiltersToShiny();
            };
          })(col, val);

          var lbl = document.createElement('span');
          lbl.textContent = val;
          if (!isAvailable) lbl.style.color = '#bbb';

          row.appendChild(cb);
          row.appendChild(lbl);
          box.appendChild(row);
        });

        container.appendChild(box);
      });
    }

    function pushFiltersToShiny() {
      filterCols.forEach(function(col) {
        var available  = availableFor(col);
        var activeVals = Array.from(filterSelected[col]).filter(function(v) {
          return available.has(v);
        });
        Shiny.setInputValue(
          'meta_filter_' + col,
          activeVals,
          {priority: 'event'}
        );
      });
    }

    function selectAllIndices() {
      Shiny.setInputValue('indices_select_all', Math.random());
    }
    function deselectAllIndices() {
      Shiny.setInputValue('indices_deselect_all', Math.random());
    }

    // ── DOMContentLoaded ──────────────────────────────────────────────────────
    document.addEventListener('DOMContentLoaded', function() {

      var sidebar        = document.getElementById('sidebar');
      var resizeHandle   = document.getElementById('sidebar_resize');
      var resizeDragging = false;

      resizeHandle.addEventListener('mousedown', function(e) {
        resizeDragging = true;
        resizeHandle.classList.add('dragging');
        e.preventDefault();
      });

      // Intercept compute click to show loading state
      document.getElementById('compute').addEventListener('click', function() {
        setComputing(true);
        // Hide corr overlay until server tells us to show it
        document.getElementById('corr_overlay').style.display = 'none';
      });

      document.addEventListener('mousemove', function(e) {
        if (resizeDragging) {
          var newW = Math.min(400, Math.max(160, e.clientX));
          sidebar.style.width = newW + 'px';
          applyLayout();
          resizePlotly();
        }
        if (splitterState.dragging === 'h') {
          var analysis = document.getElementById('main_analysis');
          splitterState.plotPct = Math.min(0.85, Math.max(0.15,
            (e.clientY - analysis.getBoundingClientRect().top) /
            analysis.clientHeight));
          applyLayout();
          resizePlotly();
        } else if (splitterState.dragging === 'v') {
          var bottomRow = document.getElementById('bottom_row');
          splitterState.leftPct = Math.min(0.85, Math.max(0.15,
            (e.clientX - bottomRow.getBoundingClientRect().left) /
            bottomRow.clientWidth));
          applyLayout();
          resizePlotly();
        }
      });

      document.addEventListener('mouseup', function() {
        if (resizeDragging) {
          resizeDragging = false;
          resizeHandle.classList.remove('dragging');
          resizePlotly();
        }
        if (splitterState.dragging) {
          document.getElementById('h_splitter').classList.remove('dragging');
          document.getElementById('v_splitter').classList.remove('dragging');
          splitterState.dragging = null;
          resizePlotly();
        }
      });

      var hSplit = document.getElementById('h_splitter');
      var vSplit = document.getElementById('v_splitter');

      hSplit.addEventListener('mousedown', function(e) {
        splitterState.dragging = 'h';
        hSplit.classList.add('dragging');
        e.preventDefault();
      });

      vSplit.addEventListener('mousedown', function(e) {
        splitterState.dragging = 'v';
        vSplit.classList.add('dragging');
        e.preventDefault();
      });

      applyLayout();
      window.addEventListener('resize', applyLayout);
    });

    function switchTab(tab) {
      document.getElementById('tab_setup').classList.remove('active');
      document.getElementById('tab_analysis').classList.remove('active');
      document.getElementById('tab_' + tab).classList.add('active');
      document.getElementById('panel_setup').style.display =
        tab === 'setup' ? 'block' : 'none';
      document.getElementById('panel_analysis').style.display =
        tab === 'analysis' ? 'block' : 'none';
      document.getElementById('main_setup').style.display =
        tab === 'setup' ? 'block' : 'none';
      document.getElementById('main_analysis').style.display =
        tab === 'analysis' ? 'flex' : 'none';
      if (tab === 'analysis') setTimeout(applyLayout, 50);
    }

    $(document).ready(function() {

      var wavesurfer = WaveSurfer.create({
        container:     '#waveform',
        waveColor:     '#a78bfa',
        progressColor: '#7c3aed',
        cursorColor:   '#333',
        height:        80,
        sampleRate:    44100,
        plugins: [
          WaveSurfer.Spectrogram.create({
            container:    '#spectrogram',
            fftSamples:   512,
            labels:       true,
            frequencyMax: 22050
          })
        ]
      });

      var isPlaying = false;

      $('#play_pause').click(function() {
        isPlaying ? wavesurfer.pause() : wavesurfer.play();
        isPlaying = !isPlaying;
      });

      Shiny.addCustomMessageHandler('update_audio', function(msg) {
        wavesurfer.load(msg.src);
        wavesurfer.on('ready', function() {
          wavesurfer.play();
          isPlaying = true;
        });
      });

      Shiny.addCustomMessageHandler('update_now_playing', function(msg) {
        $('#now_playing_text').html(msg.info);
        $('#buttons_container').removeClass('hidden');
      });

      Shiny.addCustomMessageHandler('set_analysis_enabled', function(msg) {
        var tab = document.getElementById('tab_analysis');
        if (msg.enabled) {
          tab.classList.remove('disabled-tab');
        } else {
          tab.classList.add('disabled-tab');
        }
      });

    });
  "))
)