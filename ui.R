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

      /* ── Sidebar ─────────────────────────────────────────────────────────── */
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

      /* ── Sidebar resize handle ───────────────────────────────────────────── */
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

      /* ── Main panel ──────────────────────────────────────────────────────── */
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

      /* ── Labels ──────────────────────────────────────────────────────────── */
      .s-label {
        font-size: 10px;
        color: #aaa;
        letter-spacing: 0.04em;
        margin-top: 8px;
        margin-bottom: 3px;
        display: block;
      }

      .sidebar .form-group { margin-bottom: 4px; }

      /* ── Compute button ──────────────────────────────────────────────────── */
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
      }

      /* ── Setup cards ─────────────────────────────────────────────────────── */
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

      /* ── Filter header ───────────────────────────────────────────────────── */
      .filter-header {
        display: flex;
        justify-content: space-between;
        align-items: center;
        margin-top: 8px;
        margin-bottom: 3px;
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
        background: none;
        border: none;
        padding: 0;
      }

      .filter-link.none { color: #999; }

      /* ── Index selector box ──────────────────────────────────────────────── */
      .index-selector-box {
        background: white;
        border: 0.5px solid #e0e0dc;
        border-radius: 6px;
        padding: 6px 8px;
        max-height: 130px;
        overflow-y: auto;
        margin-right: 2px;
      }

      /* ── Metadata filter box ─────────────────────────────────────────────── */
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

      /* ── Custom checkbox rows — built from scratch, no Bootstrap ─────────── */
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

      /* ── Date range ──────────────────────────────────────────────────────── */
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
        box-sizing: border-box !important;
      }

      .date-range-row label {
        font-size: 9px !important;
        color: #aaa !important;
        margin-bottom: 2px !important;
      }

      /* ── Shiny selectInput sizing ─────────────────────────────────────────── */
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
      
      # ── Sidebar ───────────────────────────────────────────────────────────────
      div(id = "sidebar", class = "sidebar",
          
          div(class = "sidebar-inner",
              
              div(class = "sidebar-tabs",
                  div(id = "tab_setup", class = "sidebar-tab active", "Setup",
                      onclick = "switchTab('setup')"),
                  div(id = "tab_analysis", class = "sidebar-tab disabled-tab", "Analysis",
                      onclick = "if(!this.classList.contains('disabled-tab')) switchTab('analysis')")
              ),
              
              # ── Setup panel ──────────────────────────────────────────────────────
              div(id = "panel_setup",
                  projectUI("project")
              ),
              
              # ── Analysis panel ───────────────────────────────────────────────────
              div(id = "panel_analysis", style = "display: none;",
                  
                  # Acoustic indices
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
                  
                  # Date range
                  span(class = "s-label", "Date range"),
                  div(class = "date-range-row",
                      dateInput("date_from", label = "From",
                                value = Sys.Date() - 365, width = "100%"),
                      dateInput("date_to", label = "To",
                                value = Sys.Date(), width = "100%")
                  ),
                  
                  # Time range
                  span(class = "s-label", "Time range"),
                  sliderInput("time_range", label = NULL,
                              min = 0, max = 1410, value = c(0, 1410),
                              step = 30, ticks = FALSE),
                  uiOutput("time_range_label"),
                  
                  # Metadata filters — rendered by JS from combination table
                  span(class = "s-label", "Metadata filters"),
                  div(id = "meta_filters_container"),
                  
                  # Colour by
                  span(class = "s-label", "Colour by"),
                  selectInput("color_by", label = NULL,
                              choices = NULL, width = "100%"),
                  
                  # Plot type
                  span(class = "s-label", "Plot type"),
                  selectInput("plot_type", label = NULL,
                              choices = c("Scatter 3D", "Scatter 2D",
                                          "Diel Line 2D", "Diel Line 3D",
                                          "Boxplot"),
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
      
      # ── Sidebar resize handle ─────────────────────────────────────────────────
      div(id = "sidebar_resize"),
      
      # ── Main panel ────────────────────────────────────────────────────────────
      div(class = "main-panel",
          
          div(id = "main_setup",
              setupUI("setup")
          ),
          
          div(id = "main_analysis", style = "display: none;",
              
              uiOutput("analysis_lock_msg"),
              
              div(id = "plot_pane",
                  plotlyOutput("main_plot", height = "100%")
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
                  
                  div(id = "v_splitter"),
                  
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

    // ── Splitter state ────────────────────────────────────────────────────────
    var splitterState = {
      plotPct:  0.6,
      leftPct:  0.5,
      dragging: null
    };

    // ── Layout ────────────────────────────────────────────────────────────────
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

    // ── Cascade filter state ──────────────────────────────────────────────────
    var filterCombos   = [];   // array of objects: [{Col1: v1, Col2: v2, ...}]
    var filterCols     = [];   // ordered column names
    var filterSelected = {};   // {col: Set of selected values}

    // Called from server when analysis loads
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

    // Compute available values for a column given all OTHER columns' selections
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

    // Render all filter boxes
      function renderFilters() {
        var container = document.getElementById('meta_filters_container');
        if (!container) return;
        container.innerHTML = '';
      
        filterCols.forEach(function(col) {
          var available = availableFor(col);
          var allVals   = Array.from(new Set(
            filterCombos.map(function(r) { return r[col]; })
          )).sort();
      
          // NO auto-deselect — each column only filters others, never itself
      
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
            if (!isAvailable) cb.style.cursor = 'not-allowed';
      
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

    // Push current selections to Shiny as named inputs
      function pushFiltersToShiny() {
        filterCols.forEach(function(col) {
          var available = availableFor(col);
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

    // ── Index selector all/none ───────────────────────────────────────────────
    function selectAllIndices() {
      Shiny.setInputValue('indices_select_all', Math.random());
    }
    function deselectAllIndices() {
      Shiny.setInputValue('indices_deselect_all', Math.random());
    }

    // ── Sidebar resize ────────────────────────────────────────────────────────
    document.addEventListener('DOMContentLoaded', function() {

      var sidebar       = document.getElementById('sidebar');
      var resizeHandle  = document.getElementById('sidebar_resize');
      var resizeDragging = false;

      resizeHandle.addEventListener('mousedown', function(e) {
        resizeDragging = true;
        resizeHandle.classList.add('dragging');
        e.preventDefault();
      });
      
      document.addEventListener('mousemove', function(e) {
        if (!resizeDragging) return;
        var newW = Math.min(400, Math.max(160, e.clientX));
        sidebar.style.width = newW + 'px';
        applyLayout();
        resizePlotly();
      });

      document.addEventListener('mouseup', function() {
        if (resizeDragging) {
          resizeDragging = false;
          resizeHandle.classList.remove('dragging');
          resizePlotly();
        }
      });

      // ── Plot/bottom splitters ───────────────────────────────────────────────
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
          splitterState.plotPct = Math.min(0.85, Math.max(0.15,
            (e.clientY - analysis.getBoundingClientRect().top) /
            analysis.clientHeight));
        } else if (splitterState.dragging === 'v') {
          var bottomRow = document.getElementById('bottom_row');
          splitterState.leftPct = Math.min(0.85, Math.max(0.15,
            (e.clientX - bottomRow.getBoundingClientRect().left) /
            bottomRow.clientWidth));
        }
        applyLayout();
        resizePlotly();
      });

      document.addEventListener('mouseup', function() {
        if (splitterState.dragging) {
          document.getElementById('h_splitter').classList.remove('dragging');
          document.getElementById('v_splitter').classList.remove('dragging');
          splitterState.dragging = null;
          resizePlotly();
        }
      });

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
      if (tab === 'analysis') setTimeout(applyLayout, 50);
    }

    // ── Wavesurfer ────────────────────────────────────────────────────────────
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