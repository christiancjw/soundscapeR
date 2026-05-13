fluidPage(
  useShinyjs(),
  
  tags$head(
    tags$script(src = "js/wavesurfer.min.js"),
    tags$script(src = "js/spectrogram.min.js"),
    tags$script(HTML("
      function toggleSection(headerId, bodyId) {
        var header = document.getElementById(headerId);
        var body   = document.getElementById(bodyId);
        if (!header || !body) return;
        var collapsed = body.classList.toggle('collapsed');
        header.classList.toggle('collapsed', collapsed);
      }
    ")),
    tags$style(HTML("

      /* ── CSS variables — light theme — purple accents ───────────────────── */
      :root {
        --bg-app:        #ffffff;
        --bg-sidebar:    #f7f7f5;
        --bg-subtle:     #f0f0ec;
        --bg-card:       #f7f7f5;
        --bg-input:      #ffffff;
        --bg-hover:      #ede9f7;
        --border:        #e0e0dc;
        --border-light:  #d0d0cc;
        --border-focus:  #c4b5f7;
        --border-accent: #e5dff7;
        --text-primary:  #1a1a1a;
        --text-secondary:#444;
        --text-muted:    #777;
        --text-faint:    #aaa;
        --text-input:    #1a1a1a;
        --accent:        #7c3aed;
        --accent-hover:  #6d28d9;
        --accent-light:  #ede9f7;
        --accent-border: #c4b5f7;
        --accent-text:   #7c3aed;
        --purple:        #7c3aed;
        --purple-wave:   #a78bfa;
        --shadow:        rgba(0,0,0,0.06);
        --scrollbar:     #d0d0cc;
      }

      /* ── Dark theme — orange accents ─────────────────────────────────────── */
      body.dark {
        --bg-app:        #111113;
        --bg-sidebar:    #18181b;
        --bg-subtle:     #1c1c1f;
        --bg-card:       #1c1c1f;
        --bg-input:      #27272a;
        --bg-hover:      #2e2e32;
        --border:        #3a3a3e;
        --border-light:  #4a4a50;
        --border-focus:  #f97316;
        --border-accent: #3d2a1a;
        --text-primary:  #f0f0f0;
        --text-secondary:#c0c0c0;
        --text-muted:    #909090;
        --text-faint:    #606060;
        --text-input:    #f0f0f0;
        --accent:        #f97316;
        --accent-hover:  #ea6a0a;
        --accent-light:  #2d1a0a;
        --accent-border: #7a3a0a;
        --accent-text:   #fb923c;
        --purple:        #c084fc;
        --purple-wave:   #d8b4fe;
        --shadow:        rgba(0,0,0,0.4);
        --scrollbar:     #3f3f46;
      }

      *, *::before, *::after { box-sizing: border-box; }

      body, html {
        overflow-x: hidden;
        height: 100%;
        margin: 0;
        padding: 0;
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
        background: var(--bg-app);
        color: var(--text-primary);
        transition: background 0.2s, color 0.2s;
      }

      /* Prevent flash — start dark, JS removes class if user prefers light */
      body { }

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
        background: var(--bg-sidebar);
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
        background: var(--bg-hover);
        cursor: ew-resize;
        display: flex;
        align-items: center;
        justify-content: center;
        transition: background 0.15s;
        position: relative;
        z-index: 21;
      }

      #sidebar_resize:hover, #sidebar_resize.dragging {
        background: var(--border-focus);
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
        padding: 8px 0 0 0;
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
        background: var(--bg-input);
        z-index: 10;
      }

      #corr_overlay .corr-loading {
        display: flex;
        align-items: center;
        justify-content: center;
        height: 100%;
        flex-direction: column;
        gap: 12px;
        color: var(--text-faint);
        font-size: 13px;
      }

      .spinner {
        width: 28px;
        height: 28px;
        border: 3px solid #e0e0dc;
        border-top-color: var(--accent-text);
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
        color: var(--text-muted);
        font-size: 13px;
      }

      #h_splitter {
        height: 6px;
        background: var(--bg-subtle);
        border-top: 0.5px solid var(--border);
        border-bottom: 0.5px solid var(--border);
        cursor: ns-resize;
        flex-shrink: 0;
        display: flex;
        align-items: center;
        justify-content: center;
        user-select: none;
        transition: background 0.15s;
      }

      #h_splitter:hover, #h_splitter.dragging {
        background: var(--border-accent);
        border-color: var(--border-focus);
      }

      #h_splitter::after {
        content: '';
        width: 32px;
        height: 2px;
        border-radius: 1px;
        background: var(--scrollbar);
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
        background: var(--bg-subtle);
        border-left: 0.5px solid var(--border);
        border-right: 0.5px solid var(--border);
        cursor: ew-resize;
        flex-shrink: 0;
        display: flex;
        align-items: center;
        justify-content: center;
        user-select: none;
        transition: background 0.15s;
      }

      #v_splitter:hover, #v_splitter.dragging {
        background: var(--border-accent);
        border-color: var(--border-focus);
      }

      #v_splitter::after {
        content: '';
        width: 2px;
        height: 32px;
        border-radius: 1px;
        background: var(--scrollbar);
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
        border: 0.5px solid var(--border-light);
        background: var(--bg-input);
        color: var(--text-muted);
        cursor: pointer;
        user-select: none;
        white-space: nowrap;
      }

      .bl-tab.active {
        background: var(--accent-light);
        color: var(--accent-text);
        border-color: var(--border-focus);
        font-weight: 500;
      }

      .bl-panel {
        flex: 1;
        min-height: 0;
        overflow-y: auto;
        display: none;
      }

      .bl-panel.active { display: block; }

      /* ── Now playing box ──────────────────────────────────────────────────── */
      .now-playing {
        background: var(--bg-sidebar);
        border: 0.5px solid var(--border);
        border-radius: 8px;
        font-size: 11px;
        color: var(--text-primary);
        position: relative;
        flex-shrink: 0;
        height: 90px;
        margin-bottom: 6px;
        display: flex;
        overflow: visible;
      }

      /* text area: scrollable */
      #now_playing_text {
        flex: 1;
        min-width: 0;
        padding: 8px 10px;
        overflow-y: auto;
        line-height: 1.5;
      }

      /* right-side controls — two columns: buttons | slider */
      #now_playing_controls {
        display: none;
        flex-direction: row;
        align-items: stretch;
        flex-shrink: 0;
        border-left: 0.5px solid var(--border);
        background: var(--bg-subtle);
        border-radius: 0 8px 8px 0;
        height: 90px;
        box-sizing: border-box;
        overflow: hidden;
      }

      /* audio linked indicator */
      #audio_linked_row {
        display: flex;
        align-items: center;
        gap: 6px;
        padding: 5px 8px;
        border-top: 0.5px solid var(--border);
        background: var(--bg-sidebar);
      }

      #audio_linked_dot {
        width: 6px;
        height: 6px;
        border-radius: 50%;
        background: var(--scrollbar);
        flex-shrink: 0;
      }

      #audio_linked_label {
        font-size: 9px;
        color: var(--text-faint);
        letter-spacing: 0.05em;
        user-select: none;
      }

      /* left sub-column: play/pause on top, open-file on bottom */
      #now_playing_btn_col {
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: space-between;
        padding: 6px 4px;
        flex-shrink: 0;
      }

      /* right sub-column: volume slider centred vertically */
      #now_playing_vol_col {
        display: flex;
        align-items: center;
        justify-content: center;
        padding: 6px 4px;
        border-left: 0.5px solid var(--border);
        flex-shrink: 0;
      }

      .vol-btn {
        background: none;
        border: none;
        padding: 2px;
        cursor: pointer;
        color: var(--text-muted);
        font-size: 12px;
        line-height: 1;
        display: flex;
        align-items: center;
        justify-content: center;
        width: 26px;
        height: 26px;
        flex-shrink: 0;
      }

      #waveform {
        width: 100%;
        height: 90px;
        flex-shrink: 0;
        border: 0.5px solid var(--border);
        border-radius: 6px;
        overflow: hidden;
      }

      #spectrogram {
        width: 100%;
        flex: 1;
        min-height: 0;
        border: 0.5px solid var(--border);
        border-radius: 6px;
        overflow: hidden;
        margin-top: 6px;
      }



      .sidebar-tabs {
        display: flex;
        gap: 4px;
        margin-bottom: 10px;
      }

      /* Dark mode toggle */
      #dark_toggle {
        background: none;
        border: 0.5px solid var(--border);
        border-radius: 5px;
        padding: 3px 7px;
        cursor: pointer;
        font-size: 11px;
        color: var(--text-muted);
        line-height: 1;
        flex-shrink: 0;
        transition: background 0.1s;
      }
      #dark_toggle:hover { background: var(--bg-hover); }

      .sidebar-tab {
        flex: 1;
        font-size: 11px;
        padding: 4px 0;
        text-align: center;
        border-radius: 5px;
        border: 0.5px solid var(--border-light);
        background: var(--bg-input);
        color: var(--text-muted);
        cursor: pointer;
        user-select: none;
      }

      .sidebar-tab.active {
        background: var(--accent-light);
        color: var(--accent-text);
        border-color: var(--border-focus);
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
        color: var(--accent-text);
        letter-spacing: 0.08em;
        text-transform: uppercase;
        margin-top: 12px;
        margin-bottom: 4px;
        padding-bottom: 3px;
        border-bottom: 0.5px solid var(--border-accent);
        display: flex;
        align-items: center;
        justify-content: space-between;
        cursor: pointer;
        user-select: none;
      }

      .section-divider:hover { opacity: 0.75; }

      .section-divider .collapse-arrow {
        font-size: 10px;
        transition: transform 0.2s;
        flex-shrink: 0;
      }

      .section-divider.collapsed .collapse-arrow {
        transform: rotate(-90deg);
      }

      .collapsible-section {
        overflow: hidden;
        transition: max-height 0.25s ease, opacity 0.2s ease;
        max-height: 2000px;
        opacity: 1;
      }

      .collapsible-section.collapsed {
        max-height: 0 !important;
        opacity: 0;
      }

      .s-label {
        font-size: 10px;
        color: var(--text-faint);
        letter-spacing: 0.04em;
        margin-top: 8px;
        margin-bottom: 3px;
        display: block;
      }

      .sidebar .form-group { margin-bottom: 4px; }

      .btn-compute {
        width: 100%;
        margin-top: 12px;
        background: var(--accent);
        color: #fff;
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
        background: var(--bg-sidebar);
        border: 0.5px solid var(--border);
        border-radius: 10px;
        padding: 14px 16px;
        margin-bottom: 10px;
      }

      .setup-card-title {
        font-size: 12px;
        font-weight: 500;
        color: var(--text-primary);
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
        color: var(--accent-text);
        cursor: pointer;
        text-decoration: none;
        user-select: none;
        background: none;
        border: none;
        padding: 0;
      }

      .filter-link.none { color: var(--text-faint); }

      .index-selector-box {
        background: var(--bg-input);
        border: 0.5px solid var(--border);
        border-radius: 6px;
        padding: 6px 8px;
        max-height: 130px;
        overflow-y: auto;
        margin-right: 2px;
      }

      .meta-filter-box {
        background: var(--bg-input);
        border: 0.5px solid var(--border);
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
        accent-color: var(--accent-text);
        margin: 0;
      }

      .cb-row span {
        font-size: 10px;
        color: var(--text-primary);
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
        color: var(--text-primary) !important;
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
        accent-color: var(--accent-text) !important;
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
        color: var(--text-faint) !important;
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
        border: 0.5px solid var(--border) !important;
        border-radius: 4px !important;
        width: 100% !important;
      }

      .date-range-row label {
        font-size: 9px !important;
        color: var(--text-faint) !important;
        margin-bottom: 2px !important;
      }

      .sidebar .selectize-input {
        font-size: 11px !important;
        min-height: 28px !important;
        padding: 3px 7px !important;
      }

      /* ── Shiny slider ──────────────────────────────────────────────────────── */
      .irs--shiny .irs-bar {
        background: var(--accent) !important;
        border-top: none !important;
        border-bottom: none !important;
        height: 4px !important;
        top: 25px !important;
      }

      .irs--shiny .irs-line {
        background: var(--bg-hover) !important;
        border: none !important;
        height: 4px !important;
        top: 25px !important;
        border-radius: 2px !important;
      }

      .irs--shiny .irs-handle {
        background: var(--accent) !important;
        border: none !important;
        box-shadow: none !important;
        width: 10px !important;
        height: 18px !important;
        border-radius: 3px !important;
        top: 19px !important;
        cursor: ew-resize !important;
      }

      .irs--shiny .irs-handle:hover,
      .irs--shiny .irs-handle.state_hover {
        background: var(--accent-hover) !important;
      }

      .irs--shiny .irs-from,
      .irs--shiny .irs-to,
      .irs--shiny .irs-single,
      .irs--shiny .irs-min,
      .irs--shiny .irs-max,
      .irs--shiny .irs-grid {
        display: none !important;
      }

      .irs { height: 36px !important; }
      .sidebar .irs-with-grid { margin-bottom: 0 !important; }

      .hidden { display: none; }

      /* Accent buttons */
      .btn-accent {
        background: var(--accent) !important;
        color: #fff !important;
        border: none !important;
        border-radius: 6px;
        font-size: 12px;
        cursor: pointer;
        transition: opacity 0.15s;
        width: 100%;
      }
      .btn-accent:hover { opacity: 0.88; }
      .btn-accent:active { opacity: 0.75; }

      /* ── Dark mode element overrides ────────────────────────────────────── */
      body.dark .setup-card          { background: var(--bg-card); border-color: var(--border); }
      body.dark .setup-card-title    { color: var(--text-primary); }
      body.dark .now-playing         { background: var(--bg-card); border-color: var(--border); }
      body.dark #now_playing_controls{ background: var(--bg-subtle); border-color: var(--border); }
      body.dark #now_playing_btn_col { border-color: var(--border); }
      body.dark .vol-btn             { color: var(--text-muted); }
      body.dark .bl-tab              { background: var(--bg-input); border-color: var(--border); color: var(--text-muted); }
      body.dark .bl-tab.active       { background: var(--accent-light); color: var(--accent-text); border-color: var(--accent-border); }
      body.dark .sidebar-tab         { background: var(--bg-input); border-color: var(--border); color: var(--text-muted); }
      body.dark .sidebar-tab.active  { background: var(--accent-light); color: var(--accent-text); border-color: var(--accent-border); }
      body.dark .index-selector-box  { background: var(--bg-input); border-color: var(--border); }
      body.dark .meta-filter-box     { background: var(--bg-input); border-color: var(--border); }
      body.dark .cb-row span         { color: var(--text-primary); }
      body.dark #waveform            { border-color: var(--border); }
      body.dark #spectrogram         { border-color: var(--border); }
      body.dark .selectize-input     { background: var(--bg-input) !important; color: var(--text-input) !important; border-color: var(--border) !important; }
      body.dark .selectize-dropdown  { background: var(--bg-input) !important; border-color: var(--border) !important; color: var(--text-input) !important; }
      body.dark .selectize-dropdown-content .option { color: var(--text-input) !important; background: transparent !important; }
      body.dark .selectize-dropdown-content .option:hover  { background: var(--bg-hover) !important; color: var(--text-primary) !important; }
      body.dark .selectize-dropdown-content .option.active { background: var(--bg-hover) !important; color: var(--text-primary) !important; }
      body.dark .selectize-dropdown-content .option.selected { background: transparent !important; color: var(--text-primary) !important; }
      body.dark input[type='date']   { background: var(--bg-input); color: var(--text-input); border-color: var(--border) !important; }
      body.dark .irs--shiny .irs-line { background: var(--border) !important; }
      body.dark .irs--shiny .irs-bar  { background: var(--accent) !important; }
      body.dark .irs--shiny .irs-handle { background: var(--accent) !important; }
      body.dark .btn-compute         { background: var(--accent); }
      body.dark .shiny-notification  { background: var(--bg-card); border-color: var(--border); color: var(--text-primary); }
      body.dark #audio_linked_row    { background: var(--bg-subtle); border-color: var(--border); }
      body.dark .section-divider     { color: var(--accent-text); border-color: var(--border-accent); }
      body.dark .s-label             { color: var(--text-faint); }
      body.dark .filter-link         { color: var(--accent-text); }
      body.dark pre, body.dark .shiny-text-output { background: var(--bg-subtle); color: var(--text-primary); border-color: var(--border); }

      /* Remove blue text selection highlight in dark mode */
      body.dark ::selection          { background: rgba(249,115,22,0.25); color: var(--text-primary); }
      body.dark *:focus              { outline-color: var(--accent); }

      /* All white input boxes → dark in dark mode */
      body.dark input[type='text'],
      body.dark input[type='number'],
      body.dark input[type='search'],
      body.dark input[type='password'],
      body.dark input[type='email'],
      body.dark textarea,
      body.dark select,
      body.dark .form-control         { background: var(--bg-input) !important; color: var(--text-input) !important; border-color: var(--border) !important; }
      body.dark .shiny-input-container .form-control { background: var(--bg-input) !important; color: var(--text-input) !important; }
      body.dark .selectize-input.items { background: var(--bg-input) !important; color: var(--text-input) !important; border-color: var(--border) !important; }
      body.dark .selectize-input .item { background: var(--bg-hover) !important; color: var(--text-primary) !important; border: none !important; box-shadow: none !important; }
      body.dark .well                  { background: var(--bg-card) !important; border-color: var(--border) !important; }

      /* Scrollbars */
      body.dark ::-webkit-scrollbar       { width: 6px; height: 6px; }
      body.dark ::-webkit-scrollbar-track { background: var(--bg-subtle); }
      body.dark ::-webkit-scrollbar-thumb { background: var(--scrollbar); border-radius: 3px; }

      /* Palette panel dark mode */
      body.dark .pal-preset-btn          { background: var(--bg-input) !important; border-color: var(--border) !important; color: var(--text-muted) !important; }
      body.dark .pal-level-row           { background: var(--bg-subtle) !important; border-color: var(--border) !important; }
      body.dark .pal-level-row:hover     { background: var(--bg-hover) !important; }
      body.dark .pal-hex-label           { color: var(--text-muted) !important; }
      body.dark .pal-col-header          { color: var(--text-primary) !important; border-color: var(--border-accent) !important; }
      body.dark .pal-save-btn            { background: var(--accent) !important; }
      body.dark [id*=pal_pbtn_]        { background: var(--bg-input) !important; border-color: var(--border) !important; }
      body.dark [id*=pal_pbtn_] span   { color: var(--text-muted) !important; }
    "))
  ),
  
  div(class = "app-wrapper",
      
      div(id = "sidebar", class = "sidebar",
          div(class = "sidebar-inner",
              
              div(style = "display:flex; align-items:center; gap:4px; margin-bottom:10px;",
                  div(id = "tab_setup", class = "sidebar-tab active",
                      style = "flex:1; margin-bottom:0;",
                      "Setup", onclick = "switchTab('setup')"),
                  div(id = "tab_analysis", class = "sidebar-tab disabled-tab",
                      style = "flex:1; margin-bottom:0;",
                      "Analysis",
                      onclick = "if(!this.classList.contains('disabled-tab')) switchTab('analysis')"),
                  tags$button(id = "dark_toggle", onclick = "toggleDark()",
                              title = "Toggle dark mode", "☽")
              ),
              
              div(id = "audio_linked_row",
                  div(id = "audio_linked_dot"),
                  div(id = "audio_linked_label", "no project open")
              ),
              
              div(id = "panel_setup",
                  projectUI("project")
              ),
              
              div(id = "panel_analysis", style = "display:none;",
                  
                  # ── Acoustic indices ──────────────────────────────────────────────
                  div(class = "filter-header",
                      span(class = "s-label", style = "margin:0;", "Acoustic indices"),
                      div(class = "filter-header-links",
                          tags$button(class = "filter-link", onclick = "selectAllIndices()", "all"),
                          tags$button(class = "filter-link none", onclick = "deselectAllIndices()", "none")
                      )
                  ),
                  div(class = "index-selector-box",
                      checkboxGroupInput("selected_indices", label = NULL,
                                         choices = NULL, selected = NULL, width = "100%")
                  ),
                  
                  # ── Plot type ─────────────────────────────────────────────────────
                  span(class = "s-label", "Plot type"),
                  uiOutput("plot_type_ui"),
                  
                  # ── PCA axes — uiOutput to avoid duplicate IDs ──────────────────
                  uiOutput("pca_axes_ui"),
                  
                  # ── Diel bin ──────────────────────────────────────────────────────
                  conditionalPanel(
                    condition = "input.plot_type == 'Diel Line 2D' ||
                         input.plot_type == 'Diel Line 3D'",
                    span(class = "s-label", "Time bin size"),
                    sliderInput("diel_bin_mins", label = NULL,
                                min = 5, max = 360, value = 30,
                                step = 5, ticks = FALSE, width = "100%"),
                    uiOutput("diel_bin_label")
                  ),
                  
                  # ── Colour by ─────────────────────────────────────────────────────
                  span(class = "s-label", "Colour by"),
                  selectInput("color_by", label = NULL, choices = NULL, width = "100%"),
                  
                  # ── Compute ───────────────────────────────────────────────────────
                  actionButton("compute", "Compute", class = "btn-compute"),
                  
                  # ── Dataframe selection ───────────────────────────────────────────
                  tags$div(class = "section-divider", id = "df_header",
                           onclick = "toggleSection('df_header','df_body')",
                           "Dataframe selection",
                           span(class = "collapse-arrow", "▾")
                  ),
                  div(id = "df_body", class = "collapsible-section",
                      
                      conditionalPanel(
                        condition = "input.server_use_datetime",
                        span(class = "s-label", "Date range"),
                        div(class = "date-range-row",
                            dateInput("date_from", label = "From",
                                      value = Sys.Date() - 365, width = "100%"),
                            dateInput("date_to", label = "To",
                                      value = Sys.Date(), width = "100%")
                        ),
                        span(class = "s-label", "Time range"),
                        sliderInput("time_range", label = NULL,
                                    min = 0, max = 1440, value = c(0, 1440),
                                    step = 15, ticks = FALSE, width = "100%"),
                        uiOutput("time_range_label")
                      ),
                      
                      span(class = "s-label", "Metadata filters"),
                      div(id = "analysis_filters_container")
                  ),
                  
                  # ── Plotting selection ────────────────────────────────────────────
                  tags$div(class = "section-divider", id = "plot_header",
                           onclick = "toggleSection('plot_header','plot_body')",
                           "Plotting selection",
                           span(class = "collapse-arrow", "▾")
                  ),
                  div(id = "plot_body", class = "collapsible-section",
                      
                      conditionalPanel(
                        condition = "input.server_use_datetime",
                        span(class = "s-label", "Date range"),
                        div(class = "date-range-row",
                            dateInput("plot_date_from", label = "From",
                                      value = Sys.Date() - 365, width = "100%"),
                            dateInput("plot_date_to", label = "To",
                                      value = Sys.Date(), width = "100%")
                        ),
                        span(class = "s-label", "Time range"),
                        sliderInput("plot_time_range", label = NULL,
                                    min = 0, max = 1440, value = c(0, 1440),
                                    step = 15, ticks = FALSE, width = "100%"),
                        uiOutput("plot_time_range_label")
                      ),
                      
                      span(class = "s-label", "Metadata filters"),
                      div(id = "plot_filters_container")
                  )
              )
          )
      ),
      
      div(id = "sidebar_resize"),
      
      div(class = "main-panel",
          
          div(id = "main_setup",
              setupUI("setup")
          ),
          
          div(id = "main_analysis", style = "display:none;",
              
              uiOutput("analysis_lock_msg"),
              
              div(id = "plot_pane",
                  div(id = "plot_computing",
                      div(class = "spinner"),
                      span("Computing...")
                  ),
                  plotlyOutput("main_plot", height = "100%"),
                  div(id = "corr_overlay",
                      div(id = "corr_loading", class = "corr-loading",
                          div(class = "spinner"),
                          div(style = "text-align:center;",
                              div(style = "font-size:13px; color:#555; margin-bottom:6px;",
                                  "Computing correlation matrix..."),
                              div(style = "font-size:11px; color:#aaa;",
                                  "This may take a moment for large datasets.")
                          )
                      ),
                      div(id = "corr_plot_wrap",
                          style = "display:none; width:100%; height:100%;",
                          plotOutput("corr_plot", height = "100%")
                      )
                  )
              ),
              
              div(id = "h_splitter"),
              
              div(id = "bottom_row",
                  
                  div(id = "bottom_left",
                      
                      # ── Now playing box ─────────────────────────────────────────────
                      div(class = "now-playing",
                          
                          # Left: text content
                          div(id = "now_playing_text",
                              style = "font-size:11px;",
                              "Now playing: —"),
                          
                          # Right: controls — button column + volume column
                          div(id = "now_playing_controls",
                              
                              # Button col: play/pause top, open-file bottom
                              div(id = "now_playing_btn_col",
                                  tags$button(
                                    id = "play_pause_btn", class = "vol-btn",
                                    HTML('<svg width="12" height="12" viewBox="0 0 12 12" fill="currentColor"><polygon points="2,1 10,6 2,11"/></svg>')
                                  ),
                                  tags$button(
                                    id = "open_file_btn", class = "vol-btn",
                                    HTML('<svg width="12" height="12" viewBox="0 0 12 12" fill="none" stroke="currentColor" stroke-width="1.5"><rect x="1" y="3" width="10" height="8" rx="1"/><path d="M1 5h10M4 3V2a1 1 0 011-1h2a1 1 0 011 1v1"/></svg>')
                                  )
                              ),
                              
                              # Right col: vertical volume slider
                              div(id = "now_playing_vol_col",
                                  tags$input(
                                    type = "range", id = "volume_slider",
                                    min = "0", max = "2", value = "1", step = "0.02",
                                    style = "writing-mode:vertical-lr;direction:rtl;
                             height:70px;width:18px;
                             accent-color:#7c3aed;cursor:pointer;"
                                  )
                              )
                          )
                      ),
                      
                      # ── Bottom-left tabs ────────────────────────────────────────────
                      div(class = "bl-tabs",
                          div(class = "bl-tab active", "PCA Summary",
                              onclick = "switchBLTab('pca')"),
                          div(class = "bl-tab", "Summary Stats",
                              onclick = "switchBLTab('stats')")
                      ),
                      
                      div(id = "bl_pca", class = "bl-panel active",
                          div(style = "display:flex; justify-content:space-between;
                           align-items:center; margin-bottom:6px;",
                              span(style = "font-size:10px; color:#aaa; letter-spacing:0.04em;",
                                   "PCA summary"),
                              downloadButton("download_pca", "Export",
                                             class = "btn-sm",
                                             style = "font-size:9px; padding:2px 8px;
                                        height:auto; line-height:1.4;")
                          ),
                          verbatimTextOutput("pca_summary")
                      ),
                      
                      div(id = "bl_stats", class = "bl-panel",
                          uiOutput("summary_stats")
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