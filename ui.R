fluidPage(
  useShinyjs(),
  
  tags$head(
    tags$script(src = "js/wavesurfer.min.js"),
    tags$script(src = "js/spectrogram.min.js"),
    tags$style(HTML("

      body, html {
        overflow-x: hidden;
        height: 100%;
        margin: 0;
        padding: 0;
      }

      .app-wrapper {
        display: flex;
        height: 100vh;
        overflow: hidden;
      }

      .sidebar {
        width: 220px;
        min-width: 220px;
        flex-shrink: 0;
        background: #f7f7f5;
        border-right: 0.5px solid #e0e0dc;
        display: flex;
        flex-direction: column;
        padding: 12px 10px;
        transition: width 0.2s ease, min-width 0.2s ease, padding 0.2s ease;
        overflow-x: hidden;
        overflow-y: auto;
        position: relative;
        z-index: 20;
      }

      .sidebar.collapsed {
        width: 0;
        min-width: 0;
        padding: 0;
      }

      .sidebar-toggle {
        position: absolute;
        top: 50%;
        transform: translateY(-50%);
        left: 220px;
        width: 14px;
        height: 48px;
        flex-shrink: 0;
        background: #f7f7f5;
        border: 0.5px solid #e0e0dc;
        border-left: none;
        border-radius: 0 6px 6px 0;
        cursor: pointer;
        z-index: 30;
        display: flex;
        align-items: center;
        justify-content: center;
        font-size: 10px;
        color: #999;
        transition: left 0.2s ease;
        user-select: none;
      }

      .sidebar-toggle.collapsed { left: 0; }

      .main-panel {
        flex: 1;
        min-width: 0;
        display: flex;
        flex-direction: column;
        overflow: hidden;
        padding: 12px;
        gap: 0;
        height: 100vh;
        box-sizing: border-box;
        transition: all 0.2s ease;
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

      /* ── Plot pane ──────────────────────────────────────────────────────── */
      #plot_pane {
        min-height: 200px;
        overflow: hidden;
        padding-bottom: 4px;
      }

      /* ── Horizontal splitter (between plot and bottom row) ──────────────── */
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

      /* ── Bottom row ─────────────────────────────────────────────────────── */
      #bottom_row {
        display: flex;
        min-height: 150px;
        overflow: hidden;
        padding-top: 4px;
        gap: 0;
      }

      /* ── Bottom left and right panes ────────────────────────────────────── */
      #bottom_left {
        min-width: 200px;
        display: flex;
        flex-direction: column;
        gap: 6px;
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

      /* ── Vertical splitter (between left and right bottom panes) ────────── */
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
      }

      .sidebar .form-group { margin-bottom: 4px; }

      .btn-compute {
        width: 100%;
        margin-top: auto;
        background: #1a56db;
        color: white;
        border: none;
        border-radius: 6px;
        padding: 6px 0;
        font-size: 12px;
        cursor: pointer;
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
        max-height: 120px;
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

      .checkbox-filter-list {
        background: white;
        border: 0.5px solid #e0e0dc;
        border-radius: 6px;
        padding: 3px 6px;
        max-height: 90px;
        overflow-y: auto;
        margin-bottom: 2px;
      }

      .checkbox-filter-list .checkbox,
      .index-selector-box .checkbox {
        margin: 0 !important;
        padding: 0 !important;
        line-height: 1.2 !important;
      }

      .checkbox-filter-list .checkbox label,
      .index-selector-box .checkbox label {
        font-size: 10px !important;
        color: #444;
        font-weight: 400 !important;
        padding-left: 4px !important;
        min-height: 0 !important;
        line-height: 1.3 !important;
      }

      .checkbox-filter-list .checkbox input[type='checkbox'],
      .index-selector-box .checkbox input[type='checkbox'] {
        accent-color: #1a56db;
        width: 10px;
        height: 10px;
        margin-top: 2px !important;
      }

      .checkbox-filter-list .shiny-input-checkboxgroup,
      .index-selector-box .shiny-input-checkboxgroup {
        margin: 0 !important;
        padding: 0 !important;
      }

      .index-selector-box {
        background: white;
        border: 0.5px solid #e0e0dc;
        border-radius: 6px;
        padding: 5px 6px;
        max-height: 130px;
        overflow-y: auto;
      }

      .date-range-row {
        display: flex;
        gap: 6px;
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

      .filter-header {
        display: flex;
        justify-content: space-between;
        align-items: center;
        margin-top: 8px;
        margin-bottom: 2px;
      }

      .filter-header-links {
        display: flex;
        gap: 6px;
      }

      .filter-link {
        font-size: 9px;
        color: #1a56db;
        cursor: pointer;
        text-decoration: none;
        user-select: none;
      }

      .filter-link.none { color: #999; }

      .hidden { display: none; }
      .time-slider .irs-grid-text { font-size: 9px; }
    "))
  ),
  
  div(class = "app-wrapper",
      
      # ── Sidebar ───────────────────────────────────────────────────────────────
      div(id = "sidebar", class = "sidebar",
          
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
              # Indices
              div(class = "filter-header",
                  span(class = "s-label", style = "margin: 0;", "Acoustic indices"),
                  div(class = "filter-header-links",
                      tags$a(class = "filter-link",
                             onclick = "Shiny.setInputValue('indices_select_all', Math.random())",
                             "all"),
                      tags$a(class = "filter-link none",
                             onclick = "Shiny.setInputValue('indices_deselect_all', Math.random())",
                             "none")
                  )
              ),
              div(class = "index-selector-box",
                  checkboxGroupInput("selected_indices", label = NULL,
                                     choices = NULL, selected = NULL,
                                     width = "100%")
              ),
              # Date Range
              div(class = "s-label", "Date range"),
              div(class = "date-range-row",
                  dateInput("date_from", label = "From",
                            value = Sys.Date() - 365, width = "100%"),
                  dateInput("date_to", label = "To",
                            value = Sys.Date(), width = "100%")
              ),
              # Time Range
              div(class = "s-label", "Time range"),
              sliderInput("time_range", label = NULL,
                          min = 0, max = 1410, value = c(0, 1410),
                          step = 30, ticks = FALSE),
              uiOutput("time_range_label"),
              # Metadata filters
              uiOutput("dynamic_meta_filters"),
              # Colour by
              div(class = "s-label", "Colour by"),
              selectInput("color_by", label = NULL,
                          choices = NULL, width = "100%"),
              # Plot type
              div(class = "s-label", "Plot type"),
              selectInput("plot_type", label = NULL,
                          choices = c("Scatter 3D", "Scatter 2D",
                                      "Diel Line 2D", "Diel Line 3D",
                                      "Boxplot"),
                          selected = "Scatter 3D", width = "100%"),
              # PCA axes — conditional on plot type
              conditionalPanel(
                condition = "input.plot_type == 'Scatter 3D'",
                div(class = "s-label", "PCA axes"),
                selectInput("pca_x", "X", choices = paste0("PC", 1:10),
                            selected = "PC1", width = "100%"),
                selectInput("pca_y", "Y", choices = paste0("PC", 1:10),
                            selected = "PC2", width = "100%"),
                selectInput("pca_z", "Z", choices = paste0("PC", 1:10),
                            selected = "PC3", width = "100%")
              ),
              conditionalPanel(
                condition = "input.plot_type == 'Scatter 2D'",
                div(class = "s-label", "PCA axes"),
                selectInput("pca_x", "X", choices = paste0("PC", 1:10),
                            selected = "PC1", width = "100%"),
                selectInput("pca_y", "Y", choices = paste0("PC", 1:10),
                            selected = "PC2", width = "100%")
              ),
              conditionalPanel(
                condition = "input.plot_type == 'Diel Line 2D' ||
                       input.plot_type == 'Diel Line 3D' ||
                       input.plot_type == 'Boxplot'",
                div(class = "s-label", "PC (Y axis)"),
                selectInput("pca_y", "Y", choices = paste0("PC", 1:10),
                            selected = "PC1", width = "100%")
              ),
              conditionalPanel(
                condition = "input.plot_type == 'Diel Line 3D'",
                selectInput("pca_z", "Z", choices = paste0("PC", 1:10),
                            selected = "PC2", width = "100%")
              ),
              
              actionButton("compute", "Compute",
                           class = "btn-compute",
                           style = "margin-top: 12px;")
          )
      ),
      
      # ── Collapse toggle ───────────────────────────────────────────────────────
      div(id = "sidebar_toggle", class = "sidebar-toggle", "‹",
          onclick = "toggleSidebar()"),
      
      # ── Main panel ────────────────────────────────────────────────────────────
      div(class = "main-panel",
          
          div(id = "main_setup",
              setupUI("setup")
          ),
          
          div(id = "main_analysis", style = "display: none;",
              
              uiOutput("analysis_lock_msg"),
              
              # ── Plot pane ────────────────────────────────────────────────────────
              div(id = "plot_pane",
                  plotlyOutput("main_plot", height = "100%")
              ),
              
              # ── Horizontal splitter ───────────────────────────────────────────────
              div(id = "h_splitter"),
              
              # ── Bottom row ────────────────────────────────────────────────────────
              div(id = "bottom_row",
                  
                  # Left: now playing + PCA summary
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
                      
                      div(class = "pca-summary-box",
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
                      )
                  ),
                  
                  # Vertical splitter
                  div(id = "v_splitter"),
                  
                  # Right: waveform + spectrogram
                  div(id = "bottom_right",
                      div(id = "waveform"),
                      div(id = "spectrogram")
                  )
              )
          )
      )
  ),
  
  # ── JavaScript ────────────────────────────────────────────────────────────────
  tags$script(HTML("

    // ── State ─────────────────────────────────────────────────────────────────
    var splitterState = {
      plotPct:   0.6,   // plot gets 60% of main_analysis height
      leftPct:   0.5,   // left gets 50% of bottom_row width
      dragging:  null
    };

    // ── Layout applier ────────────────────────────────────────────────────────
    function applyLayout() {
      var analysis  = document.getElementById('main_analysis');
      var plotPane  = document.getElementById('plot_pane');
      var bottomRow = document.getElementById('bottom_row');
      var bottomLeft  = document.getElementById('bottom_left');
      var bottomRight = document.getElementById('bottom_right');
      var hSplit    = document.getElementById('h_splitter');
      var vSplit    = document.getElementById('v_splitter');

      if (!analysis || analysis.style.display === 'none') return;

      var totalH    = analysis.clientHeight;
      var hSplitH   = hSplit ? hSplit.offsetHeight : 6;
      var remaining = totalH - hSplitH - 8; // 8px for padding gaps

      var plotH   = Math.max(200, Math.round(remaining * splitterState.plotPct));
      var bottomH = Math.max(150, remaining - plotH);

      plotPane.style.height  = plotH + 'px';
      bottomRow.style.height = bottomH + 'px';

      // Horizontal split within bottom row
      var totalW   = bottomRow.clientWidth;
      var vSplitW  = vSplit ? vSplit.offsetWidth : 6;
      var availW   = totalW - vSplitW;
      var leftW    = Math.max(200, Math.round(availW * splitterState.leftPct));
      var rightW   = Math.max(200, availW - leftW);

      bottomLeft.style.width  = leftW + 'px';
      bottomLeft.style.flexShrink = '0';
      bottomRight.style.width = rightW + 'px';
      bottomRight.style.flexShrink = '0';

      resizePlotly();
    }

    function resizePlotly() {
      setTimeout(function() {
        var plots = document.querySelectorAll('.js-plotly-plot');
        plots.forEach(function(p) { Plotly.Plots.resize(p); });
      }, 30);
    }

    // ── Horizontal splitter drag ──────────────────────────────────────────────
    document.addEventListener('DOMContentLoaded', function() {

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

      document.addEventListener('mousemove', function(e) {
        if (!splitterState.dragging) return;

        if (splitterState.dragging === 'h') {
          var analysis = document.getElementById('main_analysis');
          var rect     = analysis.getBoundingClientRect();
          var hSplitH  = document.getElementById('h_splitter').offsetHeight;
          var totalH   = analysis.clientHeight - hSplitH - 8;
          var relY     = e.clientY - rect.top;
          splitterState.plotPct = Math.min(0.85,
                                   Math.max(0.15, relY / analysis.clientHeight));

        } else if (splitterState.dragging === 'v') {
          var bottomRow = document.getElementById('bottom_row');
          var rect      = bottomRow.getBoundingClientRect();
          var vSplitW   = document.getElementById('v_splitter').offsetWidth;
          var totalW    = bottomRow.clientWidth - vSplitW;
          var relX      = e.clientX - rect.left;
          splitterState.leftPct = Math.min(0.85,
                                   Math.max(0.15, relX / bottomRow.clientWidth));
        }

        applyLayout();
      });

      document.addEventListener('mouseup', function() {
        if (splitterState.dragging) {
          document.getElementById('h_splitter').classList.remove('dragging');
          document.getElementById('v_splitter').classList.remove('dragging');
          splitterState.dragging = null;
          resizePlotly();
        }
      });

      // Initial layout
      applyLayout();
      window.addEventListener('resize', applyLayout);
    });

    // ── Tab switching ─────────────────────────────────────────────────────────
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

      if (tab === 'analysis') {
        setTimeout(applyLayout, 50);
      }
    }

    // ── Sidebar toggle ────────────────────────────────────────────────────────
    function toggleSidebar() {
      var sidebar = document.getElementById('sidebar');
      var toggle  = document.getElementById('sidebar_toggle');
      var collapsed = sidebar.classList.toggle('collapsed');
      toggle.classList.toggle('collapsed', collapsed);
      toggle.innerHTML = collapsed ? '›' : '‹';
      setTimeout(function() {
        applyLayout();
        resizePlotly();
      }, 220);
    }

    // ── Wavesurfer ────────────────────────────────────────────────────────────
    $(document).ready(function() {

      var wavesurfer = WaveSurfer.create({
        container: '#waveform',
        waveColor: '#a78bfa',
        progressColor: '#7c3aed',
        cursorColor: '#333',
        height: 80,
        sampleRate: 44100,
        plugins: [
          WaveSurfer.Spectrogram.create({
            container: '#spectrogram',
            fftSamples: 512,
            labels: true,
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