function(input, output, session) {
  
  current_audio  <- reactiveVal(NULL)
  last_click_key <- reactiveVal(NULL)
  corr_plot_obj  <- reactiveVal(NULL)
  bottom_trigger <- reactiveVal(0)
  
  # Dark mode — updated by JS on toggle, defaults to TRUE
  is_dark <- reactive({
    val <- input$dark_mode
    if (is.null(val)) TRUE else as.logical(val)
  })
  
  plotly_theme <- reactive({
    dark <- is_dark()
    if (dark) {
      ax <- list(
        gridcolor     = "#525258",
        linecolor     = "#606068",
        tickcolor     = "#606068",
        zerolinecolor = "#606068",
        tickfont      = list(color = "#c0c0c0", size = 10),
        titlefont     = list(color = "#f0f0f0", size = 11),
        title         = list(font = list(color = "#f0f0f0", size = 11))
      )
      scene_ax <- list(
        gridcolor     = "#525258",
        linecolor     = "#606068",
        tickcolor     = "#606068",
        zerolinecolor = "#606068",
        backgroundcolor = "#111113",
        tickfont      = list(color = "#c0c0c0", size = 10),
        titlefont     = list(color = "#f0f0f0", size = 11)
      )
      list(
        paper_bgcolor = "#111113",
        plot_bgcolor  = "#111113",
        font          = list(color = "#f0f0f0", size = 11),
        xaxis         = ax,
        yaxis         = ax,
        scene         = list(
          bgcolor     = "#111113",
          domain      = list(x = c(0, 1), y = c(0, 1)),
          aspectmode  = "cube",
          xaxis       = scene_ax,
          yaxis       = scene_ax,
          zaxis       = scene_ax
        ),
        legend        = list(bgcolor = "rgba(17,17,19,0.92)", borderwidth = 0,
                             font = list(size = 10, color = "#f0f0f0"),
                             x = 1, y = 1, xanchor = "right", yanchor = "top",
                             traceorder = "normal", itemsizing = "constant")
      )
    } else {
      ax <- list(
        gridcolor     = "#d8d8d4",
        linecolor     = "#c8c8c4",
        tickcolor     = "#c8c8c4",
        zerolinecolor = "#c8c8c4",
        tickfont      = list(color = "#555", size = 10),
        titlefont     = list(color = "#1a1a1a", size = 11),
        title         = list(font = list(color = "#1a1a1a", size = 11))
      )
      scene_ax <- list(
        gridcolor     = "#d8d8d4",
        linecolor     = "#c8c8c4",
        tickcolor     = "#c8c8c4",
        zerolinecolor = "#c8c8c4",
        tickfont      = list(color = "#555", size = 10),
        titlefont     = list(color = "#1a1a1a", size = 11)
      )
      list(
        paper_bgcolor = "rgba(0,0,0,0)",
        plot_bgcolor  = "rgba(0,0,0,0)",
        font          = list(color = "#1a1a1a", size = 11),
        xaxis         = ax,
        yaxis         = ax,
        scene         = list(
          domain      = list(x = c(0, 1), y = c(0, 1)),
          aspectmode  = "cube",
          xaxis       = scene_ax,
          yaxis       = scene_ax,
          zaxis       = scene_ax
        ),
        legend        = list(bgcolor = "rgba(255,255,255,0.9)", borderwidth = 0,
                             font = list(size = 10, color = "#1a1a1a"),
                             x = 1, y = 1, xanchor = "right", yanchor = "top",
                             traceorder = "normal", itemsizing = "constant")
      )
    }
  })
  
  # ── Disable analysis tab on startup ──────────────────────────────────────────
  session$onFlushed(function() {
    session$sendCustomMessage("set_analysis_enabled", list(enabled = FALSE))
  }, once = TRUE)
  
  # ── Activate audio when test links confirms root is accessible ────────────────
  observeEvent(confirmed_audio_root(), {
    root <- confirmed_audio_root()
    req(!is.null(root) && nchar(root) > 0)
    addResourcePath("audio", root)
    cache_audio_root(root)
    # Re-trigger compute so plot traces get key= re-attached with has_audio=TRUE
    if (cache_applied()) {
      shinyjs::click("compute")
    }
  })
  
  # ── Poll audio root accessibility every 5s ────────────────────────────────────
  observeEvent(input$audio_link_poll, {
    root <- cache_audio_root()
    # Only check if a root was previously confirmed
    if (is.null(root) || nchar(root) == 0) return()
    if (dir.exists(root)) {
      session$sendCustomMessage("set_audio_linked", list(status = "linked"))
    } else {
      cache_audio_root("")
      session$sendCustomMessage("set_audio_linked", list(status = "unlinked"))
    }
  }, ignoreInit = TRUE)
  
  # ── Module wiring ─────────────────────────────────────────────────────────────
  active_config     <- projectServer("project")
  setup_out            <- setupServer("setup", active_config)
  app_data             <- setup_out$app_data
  reactive_palettes    <- setup_out$reactive_palettes
  use_datetime_live    <- setup_out$use_datetime
  confirmed_audio_root <- setup_out$confirmed_audio_root
  
  # ── Flat cache ────────────────────────────────────────────────────────────────
  cache_df             <- reactiveVal(NULL)
  cache_index_cols     <- reactiveVal(character(0))
  cache_meta_cols      <- reactiveVal(character(0))
  cache_filter_choices <- reactiveVal(list())
  cache_audio_root     <- reactiveVal("")
  cache_audio_mode     <- reactiveVal("folder_structure")
  cache_folder_pattern <- reactiveVal("{Site}/{Device}/{Date}")
  cache_path_col       <- reactiveVal("")
  cache_filename_col   <- reactiveVal("")
  cache_date_col       <- reactiveVal("Date")
  cache_time_col       <- reactiveVal("Time")
  cache_date_range     <- reactiveVal(NULL)
  cache_applied        <- reactiveVal(FALSE)
  # Live — responds immediately to checkbox, no Apply needed
  cache_use_datetime <- reactive({
    fn <- use_datetime_live
    if (is.null(fn)) return(TRUE)
    val <- fn()
    if (is.null(val)) TRUE else as.logical(val)
  })
  
  observeEvent(app_data(), {
    ad <- app_data()
    if (is.null(ad)) return()
    
    showNotification("Loading into analysis...", id = "cache_msg", duration = NULL)
    
    if (nchar(ad$audio_root) > 0 && dir.exists(ad$audio_root)) {
      addResourcePath("audio", ad$audio_root)
      cache_audio_root(ad$audio_root)
      session$sendCustomMessage("set_audio_linked", list(status = "linked"))
    } else if (nchar(ad$audio_root) > 0) {
      cache_audio_root("")
      session$sendCustomMessage("set_audio_linked", list(status = "unlinked"))
      showNotification(
        "Audio root not accessible - analysis available, audio playback disabled.",
        type = "warning", duration = 6
      )
    } else {
      cache_audio_root("")
      session$sendCustomMessage("set_audio_linked", list(status = "no_audio"))
    }
    
    cache_df(ad$df)
    cache_index_cols(ad$index_cols)
    cache_meta_cols(ad$meta_cols)
    cache_date_col(ad$date_col)
    cache_time_col(ad$time_col)
    cache_audio_mode(ad$audio_mode)
    cache_folder_pattern(ad$folder_pattern)
    cache_path_col(ad$path_col)
    cache_filename_col(ad$filename_col)
    
    date_col <- ad$date_col
    if (date_col %in% colnames(ad$df)) {
      dates    <- as.integer(ad$df[[date_col]])
      dates    <- dates[!is.na(dates)]
      min_date <- as.Date(as.character(min(dates)), format = "%Y%m%d")
      max_date <- as.Date(as.character(max(dates)), format = "%Y%m%d")
      cache_date_range(c(min_date, max_date))
      updateDateInput(session, "date_from",      value = min_date,
                      min = min_date, max = max_date)
      updateDateInput(session, "date_to",        value = max_date,
                      min = min_date, max = max_date)
      updateDateInput(session, "plot_date_from", value = min_date,
                      min = min_date, max = max_date)
      updateDateInput(session, "plot_date_to",   value = max_date,
                      min = min_date, max = max_date)
    }
    
    updateSliderInput(session, "time_range",      value = c(0, 1440))
    updateSliderInput(session, "plot_time_range", value = c(0, 1440))
    
    filter_cols <- ad$meta_cols[!ad$meta_cols %in% c(ad$date_col, ad$time_col)]
    filter_cols <- filter_cols[sapply(filter_cols, function(col) {
      length(unique(ad$df[[col]])) <= 200
    })]
    
    choices <- setNames(
      lapply(filter_cols, function(col)
        sort(unique(as.character(ad$df[[col]])))),
      filter_cols
    )
    cache_filter_choices(choices)
    
    if (length(filter_cols) > 0) {
      combo_df <- unique(ad$df[, filter_cols, drop = FALSE])
      combo_df <- as.data.frame(lapply(combo_df, as.character),
                                stringsAsFactors = FALSE)
      combos   <- lapply(seq_len(nrow(combo_df)), function(i)
        as.list(combo_df[i, , drop = FALSE]))
      session$sendCustomMessage("init_filters", list(
        cols   = filter_cols,
        combos = combos
      ))
    }
    
    updateCheckboxGroupInput(session, "selected_indices",
                             choices  = ad$index_cols,
                             selected = ad$index_cols)
    updateSelectInput(session, "color_by",
                      choices  = ad$meta_cols,
                      selected = ad$meta_cols[1])
    
    cache_applied(TRUE)
    session$sendCustomMessage("set_analysis_enabled", list(enabled = TRUE))
    removeNotification("cache_msg")
    showNotification("Analysis ready.", type = "message", duration = 2)
    
    shinyjs::delay(200, {
      bottom_trigger(isolate(bottom_trigger()) + 1)
    })
  })
  
  # ── Fire bottom trigger on compute ───────────────────────────────────────────
  observeEvent(input$compute, {
    bottom_trigger(bottom_trigger() + 1)
  })
  
  # ── Analysis lock message ─────────────────────────────────────────────────────
  output$analysis_lock_msg <- renderUI({
    if (cache_applied()) return(NULL)
    div(style = "padding:2rem; text-align:center; color:#aaa; font-size:13px;",
        "Open a project and click Apply in Setup first.")
  })
  outputOptions(output, "analysis_lock_msg", suspendWhenHidden = FALSE)
  
  # ── Push use_datetime to client for conditionalPanel ─────────────────────────
  observeEvent(cache_use_datetime(), {
    shinyjs::runjs(sprintf(
      "Shiny.setInputValue('server_use_datetime', %s);",
      tolower(as.character(cache_use_datetime()))
    ))
  }, ignoreInit = FALSE)
  
  # ── Plot type UI — exclude diel when no datetime ─────────────────────────────
  output$plot_type_ui <- renderUI({
    use_dt  <- cache_use_datetime()
    choices <- if (use_dt)
      c("Scatter 3D", "Scatter 2D", "Diel Line 2D", "Diel Line 3D",
        "Boxplot", "Index Correlation")
    else
      c("Scatter 3D", "Scatter 2D", "Boxplot", "Index Correlation")
    cur <- isolate(input$plot_type)
    sel <- if (!is.null(cur) && cur %in% choices) cur else choices[1]
    selectInput("plot_type", label = NULL,
                choices = choices, selected = sel, width = "100%")
  })
  outputOptions(output, "plot_type_ui", suspendWhenHidden = FALSE)
  
  # ── PCA axes UI ───────────────────────────────────────────────────────────────
  output$pca_axes_ui <- renderUI({
    pt <- input$plot_type
    if (is.null(pt)) pt <- "Scatter 3D"
    
    pc_choices <- paste0("PC", 1:10)
    x_sel <- if (!is.null(input$pca_x)) input$pca_x else "PC1"
    y_sel <- if (!is.null(input$pca_y)) input$pca_y else "PC2"
    z_sel <- if (!is.null(input$pca_z)) input$pca_z else "PC3"
    
    row_style <- "display:flex; gap:4px;"
    
    if (pt == "Scatter 3D") {
      tagList(
        span(class = "s-label", "PCA axes"),
        div(style = row_style,
            div(style = "flex:1;",
                selectInput("pca_x", "X", choices = pc_choices,
                            selected = x_sel, width = "100%")),
            div(style = "flex:1;",
                selectInput("pca_y", "Y", choices = pc_choices,
                            selected = y_sel, width = "100%")),
            div(style = "flex:1;",
                selectInput("pca_z", "Z", choices = pc_choices,
                            selected = z_sel, width = "100%"))
        )
      )
    } else if (pt == "Scatter 2D") {
      tagList(
        span(class = "s-label", "PCA axes"),
        div(style = row_style,
            div(style = "flex:1;",
                selectInput("pca_x", "X", choices = pc_choices,
                            selected = x_sel, width = "100%")),
            div(style = "flex:1;",
                selectInput("pca_y", "Y", choices = pc_choices,
                            selected = y_sel, width = "100%"))
        )
      )
    } else if (pt %in% c("Diel Line 2D", "Boxplot")) {
      tagList(
        span(class = "s-label", "PC axis"),
        div(style = row_style,
            div(style = "flex:1;",
                selectInput("pca_y", "Y", choices = pc_choices,
                            selected = y_sel, width = "100%"))
        )
      )
    } else if (pt == "Diel Line 3D") {
      tagList(
        span(class = "s-label", "PC axes"),
        div(style = row_style,
            div(style = "flex:1;",
                selectInput("pca_y", "Y", choices = pc_choices,
                            selected = y_sel, width = "100%")),
            div(style = "flex:1;",
                selectInput("pca_z", "Z", choices = pc_choices,
                            selected = z_sel, width = "100%"))
        )
      )
    } else {
      NULL  # Index Correlation — no axes needed
    }
  })
  outputOptions(output, "pca_axes_ui", suspendWhenHidden = FALSE)
  
  # ── Diel bin label ────────────────────────────────────────────────────────────
  output$diel_bin_label <- renderUI({
    req(input$diel_bin_mins)
    div(paste0(input$diel_bin_mins, " min bins"),
        style = "font-size:10px; color:#888; text-align:center;
                 margin-top:-6px; margin-bottom:4px;")
  })
  outputOptions(output, "diel_bin_label", suspendWhenHidden = FALSE)
  
  # ── Select all / none for indices ─────────────────────────────────────────────
  observeEvent(input$indices_select_all, {
    updateCheckboxGroupInput(session, "selected_indices",
                             selected = cache_index_cols())
  })
  observeEvent(input$indices_deselect_all, {
    updateCheckboxGroupInput(session, "selected_indices",
                             selected = character(0))
  })
  
  # ── Helpers ───────────────────────────────────────────────────────────────────
  apply_time_filter <- function(df, range_mins) {
    if (!cache_use_datetime()) return(df)
    time_col <- cache_time_col()
    if (!time_col %in% colnames(df)) return(df)
    if (is.null(range_mins) || length(range_mins) < 2) return(df)
    if (anyNA(range_mins)) return(df)
    if (range_mins[1] <= 0 && range_mins[2] >= 1440) return(df)
    t_start <- minutes_to_hhmmss(range_mins[1])
    t_end   <- minutes_to_hhmmss(range_mins[2])
    if (is.na(t_start) || is.na(t_end)) return(df)
    if (t_start <= t_end)
      subset(df, df[[time_col]] >= t_start & df[[time_col]] <= t_end)
    else
      subset(df, df[[time_col]] >= t_start | df[[time_col]] <= t_end)
  }
  
  apply_date_filter <- function(df, from_input, to_input) {
    if (!cache_use_datetime()) return(df)
    date_col   <- cache_date_col()
    if (!date_col %in% colnames(df)) return(df)
    date_range <- cache_date_range()
    if (is.null(date_range)) return(df)
    from_int <- if (!is.null(from_input) && !is.na(from_input))
      as.integer(format(from_input, "%Y%m%d"))
    else
      as.integer(format(date_range[1], "%Y%m%d"))
    to_int <- if (!is.null(to_input) && !is.na(to_input))
      as.integer(format(to_input, "%Y%m%d"))
    else
      as.integer(format(date_range[2], "%Y%m%d"))
    df[df[[date_col]] >= from_int & df[[date_col]] <= to_int, ]
  }
  
  apply_analysis_meta_filters <- function(df) {
    choices <- cache_filter_choices()
    if (length(choices) == 0) return(df)
    for (col in names(choices)) {
      val <- input[[paste0("analysis_filter_", col)]]
      if (is.null(val) || length(val) == 0) return(df[0, ])
      if (!setequal(val, choices[[col]]))
        df <- df[df[[col]] %in% val, ]
    }
    df
  }
  
  apply_plot_meta_filters <- function(df) {
    choices <- cache_filter_choices()
    if (length(choices) == 0) return(df)
    for (col in names(choices)) {
      val <- input[[paste0("plot_filter_", col)]]
      if (is.null(val) || length(val) == 0) return(df[0, ])
      if (!setequal(val, choices[[col]]))
        df <- df[df[[col]] %in% val, ]
    }
    df
  }
  
  build_composite_key <- function(df) {
    tokens  <- regmatches(cache_folder_pattern(),
                          gregexpr("(?<=\\{)[^}]+(?=\\})",
                                   cache_folder_pattern(), perl = TRUE))[[1]]
    id_cols <- unique(c(tokens, cache_filename_col()))
    id_cols <- id_cols[id_cols %in% colnames(df)]
    if (length(id_cols) == 0) return(rep(NA_character_, nrow(df)))
    apply(df[, id_cols, drop = FALSE], 1, paste, collapse = "|")
  }
  
  resolve_audio_path <- function(row) {
    root <- cache_audio_root()
    if (nchar(root) == 0) return(NULL)
    mode   <- cache_audio_mode()
    fn_col <- cache_filename_col()
    if (mode == "csv_paths") {
      path_col <- cache_path_col()
      if (path_col %in% colnames(row)) return(row[[path_col]][1])
      return(NULL)
    }
    pattern <- cache_folder_pattern()
    tokens  <- regmatches(pattern,
                          gregexpr("(?<=\\{)[^}]+(?=\\})", pattern, perl = TRUE))[[1]]
    p <- pattern
    for (tok in tokens) {
      if (!tok %in% colnames(row)) return(NULL)
      p <- gsub(paste0("\\{", tok, "\\}"), as.character(row[[tok]][1]), p)
    }
    filename <- if (fn_col %in% colnames(row))
      trimws(as.character(row[[fn_col]][1])) else return(NULL)
    
    # Strip any existing extension so filenames with or without work identically
    filename_base <- tools::file_path_sans_ext(filename)
    root_esc      <- gsub("([.|()\\^{}+$*?]|\\[|\\])", "\\\\\1", root)
    
    to_url <- function(lp) {
      paste0("audio/", sub(paste0("^", root_esc, "/?"), "", lp))
    }
    
    # Try common audio extensions in order of likelihood
    for (ext in c(".wav", ".WAV", ".mp3", ".MP3",
                  ".flac", ".FLAC", ".ogg", ".OGG",
                  ".aif", ".aiff", ".AIFF")) {
      lp <- file.path(root, p, paste0(filename_base, ext))
      if (file.exists(lp)) return(to_url(lp))
    }
    
    # Fallback: try filename exactly as stored (may already include extension)
    lp <- file.path(root, p, filename)
    if (file.exists(lp)) return(to_url(lp))
    
    NULL
  }
  
  # ── Add time bins ─────────────────────────────────────────────────────────────
  add_time_bins <- function(df, time_range, bin_mins = 30) {
    if (!cache_use_datetime()) return(df)
    time_col <- cache_time_col()
    if (!time_col %in% colnames(df)) return(df)
    plot_tr  <- if (!is.null(time_range)) time_range else c(0, 1440)
    df       <- apply_time_filter(df, plot_tr)
    df %>%
      mutate(
        Time_posix  = as.POSIXct(
          sprintf("%06d", as.numeric(.data[[time_col]])),
          format = "%H%M%S", tz = "UTC"),
        Time_bin    = floor((hour(Time_posix) * 60 +
                               minute(Time_posix)) / bin_mins) * bin_mins,
        Time_centre = Time_bin + bin_mins / 2,
        Time_label  = sprintf("%02d:%02d",
                              Time_centre %/% 60,
                              as.integer(Time_centre) %% 60)
      )
  }
  
  # ── Now playing builder ───────────────────────────────────────────────────────
  build_now_playing <- function(row, url) {
    meta_cols <- cache_meta_cols()
    
    meta_items <- sapply(meta_cols, function(col) {
      if (!col %in% colnames(row)) return(NULL)
      paste0(
        "<div style='white-space:nowrap; overflow:hidden; text-overflow:ellipsis;'>",
        "<span style='color:#bbb;'>", col, ":</span> ", row[[col]][1],
        "</div>"
      )
    })
    
    pc_cols    <- grep("^PC", colnames(row), value = TRUE)
    active_pcs <- unique(c(
      if (!is.null(input$pca_x)) input$pca_x,
      if (!is.null(input$pca_y)) input$pca_y,
      if (!is.null(input$pca_z)) input$pca_z
    ))
    active_pcs <- active_pcs[active_pcs %in% pc_cols]
    
    value_items <- if (length(active_pcs) > 0) {
      sapply(active_pcs, function(pc) {
        paste0("<div><span style='color:#bbb;'>", pc, ":</span> ",
               round(row[[pc]][1], 3), "</div>")
      })
    } else {
      inds <- input$selected_indices
      if (!is.null(inds) && length(inds) > 0) {
        sapply(inds, function(idx) {
          if (!idx %in% colnames(row)) return(NULL)
          paste0("<div><span style='color:#bbb;'>", idx, ":</span> ",
                 round(as.numeric(row[[idx]][1]), 3), "</div>")
        })
      } else character(0)
    }
    
    paste0(
      "<div style='font-weight:500; margin-bottom:3px; white-space:nowrap;",
      " overflow:hidden; text-overflow:ellipsis;'>Now playing: ",
      basename(url), "</div>",
      "<div style='display:grid; grid-template-columns:1fr 1fr; gap:0 10px;",
      " font-size:10px; line-height:1.5;'>",
      "<div>", paste(Filter(Negate(is.null), meta_items),  collapse = ""), "</div>",
      "<div>", paste(Filter(Negate(is.null), value_items), collapse = ""), "</div>",
      "</div>"
    )
  }
  
  # ── Palette helper ────────────────────────────────────────────────────────────
  get_palette <- function(df, colvar, custom_palettes = NULL,
                          palette_order = NULL) {
    vals <- unique(as.character(df[[colvar]]))
    
    if (!is.null(palette_order) && !is.null(palette_order[[colvar]])) {
      raw <- palette_order[[colvar]]
      ord <- if (is.list(raw) && !is.null(raw$level_order))
        unlist(raw$level_order) else unlist(raw)
      if (length(ord) > 0)
        vals <- c(ord[ord %in% vals], setdiff(vals, ord))
    }
    
    pal <- NULL
    if (!is.null(custom_palettes) && !is.null(custom_palettes[[colvar]])) {
      pal_raw <- custom_palettes[[colvar]]
      pal <- if (is.list(pal_raw) && !is.null(pal_raw$colours))
        unlist(pal_raw$colours) else unlist(pal_raw)
      if (length(pal) == 0) pal <- NULL
    }
    
    if (!is.null(pal)) {
      npg <- c("#4DBBD5","#E64B35","#00A087","#3C5488",
               "#F39B7F","#8491B4","#91D1C2","#DC0000","#7E6148","#B09C85")
      assigned <- sapply(seq_along(vals), function(i) {
        v <- vals[i]
        if (!is.null(pal[v]) && !is.na(pal[v]) && nchar(pal[v]) > 0) pal[v]
        else npg[((i - 1) %% length(npg)) + 1]
      })
      return(setNames(assigned, vals))
    }
    
    base_cols <- c("#4DBBD5","#E64B35","#00A087","#3C5488",
                   "#F39B7F","#8491B4","#91D1C2","#DC0000","#7E6148","#B09C85")
    setNames(rep_len(base_cols, length(vals)), vals)
  }
  
  # ── Core data reactives ───────────────────────────────────────────────────────
  analysis_data <- reactive({
    df <- cache_df()
    req(df)
    anal_tr <- if (!is.null(input$time_range)) input$time_range else c(0, 1440)
    df <- apply_date_filter(df, input$date_from, input$date_to)
    df <- apply_time_filter(df, anal_tr)
    df <- apply_analysis_meta_filters(df)
    df$.row_key <- build_composite_key(df)
    df
  })
  
  full_pca_data <- reactive({
    df <- cache_df()
    req(df)
    inds <- input$selected_indices
    if (is.null(inds) || length(inds) <= 3) return(NULL)
    anal_tr <- if (!is.null(input$time_range)) input$time_range else c(0, 1440)
    df      <- apply_date_filter(df, input$date_from, input$date_to)
    df      <- apply_time_filter(df, anal_tr)
    df      <- apply_analysis_meta_filters(df)
    pca     <- prcomp(df %>% select(all_of(inds)), center = TRUE, scale. = TRUE)
    scores  <- as.data.frame(pca$x)
    scores  <- bind_cols(df, scores[, !(names(scores) %in% names(df)), drop = FALSE])
    list(scores = scores, pca = pca)
  })
  
  plot_data <- reactive({
    inds    <- input$selected_indices
    n       <- length(inds)
    plot_tr <- if (!is.null(input$plot_time_range)) input$plot_time_range
    else c(0, 1440)
    
    if (n <= 3) {
      df <- cache_df()
      req(df)
      df <- apply_date_filter(df, input$plot_date_from, input$plot_date_to)
      df <- apply_time_filter(df, plot_tr)
      df <- apply_plot_meta_filters(df)
      df$.row_key <- build_composite_key(df)
      return(df)
    }
    
    req(full_pca_data())
    scores <- full_pca_data()$scores
    scores <- apply_date_filter(scores, input$plot_date_from, input$plot_date_to)
    scores <- apply_plot_meta_filters(scores)
    scores <- apply_time_filter(scores, plot_tr)
    scores$.row_key <- build_composite_key(scores)
    scores
  })
  
  # ── Hover text builders ───────────────────────────────────────────────────────
  make_text_2d <- function(d, i1, i2, colvar, date_col, time_fmt_col) {
    paste0(colvar, ": ", d[[colvar]],
           "<br>", i1, ": ", round(d[[i1]], 3),
           "<br>", i2, ": ", round(d[[i2]], 3),
           if (date_col %in% colnames(d)) paste0("<br>Date: ", d[[date_col]]),
           "<br>Time: ", d[[time_fmt_col]])
  }
  
  make_text_3d <- function(d, i1, i2, i3, colvar, date_col, time_fmt_col) {
    paste0(colvar, ": ", d[[colvar]],
           "<br>", i1, ": ", round(d[[i1]], 3),
           "<br>", i2, ": ", round(d[[i2]], 3),
           "<br>", i3, ": ", round(d[[i3]], 3),
           if (date_col %in% colnames(d)) paste0("<br>Date: ", d[[date_col]]),
           "<br>Time: ", d[[time_fmt_col]])
  }
  
  make_text_pca_2d <- function(d, px, py, colvar, date_col, time_fmt_col) {
    paste0(colvar, ": ", d[[colvar]],
           "<br>", px, ": ", round(d[[px]], 3),
           "<br>", py, ": ", round(d[[py]], 3),
           if (date_col %in% colnames(d)) paste0("<br>Date: ", d[[date_col]]),
           "<br>Time: ", d[[time_fmt_col]])
  }
  
  make_text_pca_3d <- function(d, px, py, pz, colvar, date_col, time_fmt_col) {
    paste0(colvar, ": ", d[[colvar]],
           "<br>", px, ": ", round(d[[px]], 3),
           "<br>", py, ": ", round(d[[py]], 3),
           "<br>", pz, ": ", round(d[[pz]], 3),
           if (date_col %in% colnames(d)) paste0("<br>Date: ", d[[date_col]]),
           "<br>Time: ", d[[time_fmt_col]])
  }
  
  make_text_diel_2d <- function(d, py, colvar) {
    paste0("Time: ", d$Time_label,
           "<br>", py, ": ", round(d$mean_val, 3),
           "<br>", colvar, ": ", d[[colvar]])
  }
  
  make_text_diel_3d <- function(d, py, pz, colvar) {
    paste0("Time: ", d$Time_label,
           "<br>", py, ": ", round(d$mean_y, 3),
           "<br>", pz, ": ", round(d$mean_z, 3),
           "<br>", colvar, ": ", d[[colvar]])
  }
  
  # ── Main plot ─────────────────────────────────────────────────────────────────
  plot_results <- eventReactive(list(input$compute, input$dark_mode), {
    req(cache_applied())
    pt <- input$plot_type
    req(!is.null(pt) && nchar(pt) > 0)
    inds    <- input$selected_indices
    n_inds  <- length(inds)
    colvar  <- input$color_by
    is_corr <- pt == "Index Correlation"
    
    session$sendCustomMessage("show_corr", list(show = is_corr))
    
    if (is_corr) {
      session$sendCustomMessage("compute_done", list(is_corr = TRUE))
      return(NULL)
    }
    
    if (is.null(inds) || n_inds == 0) {
      session$sendCustomMessage("compute_done", list(is_corr = FALSE))
      return(NULL)
    }
    
    data <- plot_data()
    if (is.null(data) || nrow(data) == 0) {
      session$sendCustomMessage("compute_done", list(is_corr = FALSE))
      return(NULL)
    }
    
    cfg        <- active_config()
    pal_config <- if (!is.null(cfg)) cfg$palettes else NULL
    
    if (!is.null(colvar) && colvar %in% colnames(data)) {
      color_vec <- factor(data[[colvar]])
      pal       <- get_palette(data, colvar, reactive_palettes(), pal_config)
    } else {
      color_vec <- factor(rep("data", nrow(data)))
      pal       <- c("data" = "#4DBBD5")
    }
    
    time_col  <- cache_time_col()
    date_col  <- cache_date_col()
    has_audio <- nchar(cache_audio_root()) > 0
    
    data$Time_fmt <- if (cache_use_datetime() && time_col %in% colnames(data))
      sprintf("%06d", as.numeric(data[[time_col]])) else ""
    
    plot_tr  <- if (!is.null(input$plot_time_range)) input$plot_time_range
    else c(0, 1440)
    bin_mins <- if (!is.null(input$diel_bin_mins)) input$diel_bin_mins else 30
    
    if (n_inds == 1) {
      p <- plot_ly(data,
                   x = ~color_vec, y = data[[inds[1]]],
                   type = "box", color = color_vec, colors = pal,
                   hovertemplate = paste0(colvar, ": %{x}<br>",
                                          inds[1], ": %{y}<extra></extra>"))
      
    } else if (n_inds == 2) {
      data$hover <- make_text_2d(data, inds[1], inds[2],
                                 colvar, date_col, "Time_fmt")
      p <- plot_ly(data,
                   x = data[[inds[1]]], y = data[[inds[2]]],
                   type = "scatter", mode = "markers",
                   marker = list(size = 2),
                   color = color_vec, colors = pal,
                   text = ~hover,
                   hovertemplate = "%{text}<extra></extra>",
                   key = if (has_audio) ~.row_key else NULL) %>%
        layout(xaxis = list(title = inds[1]),
               yaxis = list(title = inds[2]))
      
    } else if (n_inds == 3) {
      data$hover <- make_text_3d(data, inds[1], inds[2], inds[3],
                                 colvar, date_col, "Time_fmt")
      p <- plot_ly(data,
                   x = data[[inds[1]]], y = data[[inds[2]]],
                   z = data[[inds[3]]],
                   type = "scatter3d", mode = "markers",
                   marker = list(size = 2),
                   color = color_vec, colors = pal,
                   text = ~hover,
                   hovertemplate = "%{text}<extra></extra>",
                   key = if (has_audio) ~.row_key else NULL) %>%
        layout(scene = list(xaxis = list(title = inds[1]),
                            yaxis = list(title = inds[2]),
                            zaxis = list(title = inds[3])))
      
    } else {
      scores  <- data
      pca_obj <- full_pca_data()$pca
      var_exp <- round(100 * (pca_obj$sdev^2 / sum(pca_obj$sdev^2)), 1)
      
      pcx <- if (!is.null(input$pca_x) && nchar(input$pca_x) > 0)
        input$pca_x else "PC1"
      pcy <- if (!is.null(input$pca_y) && nchar(input$pca_y) > 0)
        input$pca_y else "PC2"
      pcz <- if (!is.null(input$pca_z) && nchar(input$pca_z) > 0)
        input$pca_z else "PC3"
      
      available_pcs <- grep("^PC", colnames(data), value = TRUE)
      if (pt %in% c("Scatter 3D", "Diel Line 3D") &&
          !all(c(pcy, pcz) %in% available_pcs)) {
        session$sendCustomMessage("compute_done", list(is_corr = FALSE))
        return(NULL)
      }
      if (pt %in% c("Scatter 2D", "Diel Line 2D") &&
          !pcy %in% available_pcs) {
        session$sendCustomMessage("compute_done", list(is_corr = FALSE))
        return(NULL)
      }
      
      xlab <- paste0(pcx, " (", var_exp[as.numeric(sub("PC", "", pcx))], "%)")
      ylab <- paste0(pcy, " (", var_exp[as.numeric(sub("PC", "", pcy))], "%)")
      zlab <- paste0(pcz, " (", var_exp[as.numeric(sub("PC", "", pcz))], "%)")
      
      if (pt == "Scatter 3D") {
        scores$hover <- make_text_pca_3d(scores, pcx, pcy, pcz,
                                         colvar, date_col, "Time_fmt")
        p <- plot_ly(scores,
                     x = scores[[pcx]], y = scores[[pcy]], z = scores[[pcz]],
                     type = "scatter3d", mode = "markers",
                     marker = list(size = 2),
                     color = color_vec, colors = pal,
                     text = ~hover,
                     hovertemplate = "%{text}<extra></extra>",
                     key = if (has_audio) ~.row_key else NULL) %>%
          layout(scene = list(xaxis = list(title = xlab),
                              yaxis = list(title = ylab),
                              zaxis = list(title = zlab)))
        
      } else if (pt == "Scatter 2D") {
        scores$hover <- make_text_pca_2d(scores, pcx, pcy,
                                         colvar, date_col, "Time_fmt")
        p <- plot_ly(scores,
                     x = scores[[pcx]], y = scores[[pcy]],
                     type = "scatter", mode = "markers",
                     marker = list(size = 2),
                     color = color_vec, colors = pal,
                     text = ~hover,
                     hovertemplate = "%{text}<extra></extra>",
                     key = if (has_audio) ~.row_key else NULL) %>%
          layout(xaxis = list(title = xlab),
                 yaxis = list(title = ylab))
        
      } else if (pt == "Diel Line 2D") {
        scores <- add_time_bins(scores, plot_tr, bin_mins = bin_mins)
        avg <- scores %>%
          group_by(Time_label, Time_bin, !!sym(colvar)) %>%
          summarise(mean_val = mean(.data[[pcy]], na.rm = TRUE), .groups = "drop")
        avg$hover <- make_text_diel_2d(avg, pcy, colvar)
        p <- plot_ly(avg,
                     x = ~Time_label, y = ~mean_val,
                     type = "scatter", mode = "lines+markers",
                     line = list(shape = "spline"),
                     marker = list(size = 4),
                     color = avg[[colvar]], colors = pal,
                     text = ~hover,
                     hovertemplate = "%{text}<extra></extra>") %>%
          layout(xaxis = list(title = "Time of day"),
                 yaxis = list(title = ylab))
        
      } else if (pt == "Diel Line 3D") {
        scores <- add_time_bins(scores, plot_tr, bin_mins = bin_mins)
        avg <- scores %>%
          group_by(Time_bin, Time_label, !!sym(colvar)) %>%
          summarise(mean_y = mean(.data[[pcy]], na.rm = TRUE),
                    mean_z = mean(.data[[pcz]], na.rm = TRUE),
                    .groups = "drop") %>%
          arrange(Time_bin)
        avg$hover <- make_text_diel_3d(avg, pcy, pcz, colvar)
        p <- plot_ly(avg,
                     x = ~Time_label, y = ~mean_y, z = ~mean_z,
                     type = "scatter3d", mode = "lines+markers",
                     marker = list(size = 2),
                     color = avg[[colvar]], colors = pal,
                     text = ~hover,
                     hovertemplate = "%{text}<extra></extra>") %>%
          layout(scene = list(xaxis = list(title = "Time of day"),
                              yaxis = list(title = ylab),
                              zaxis = list(title = zlab)))
        
      } else if (pt == "Boxplot") {
        pc_sel <- if (!is.null(input$pca_y)) input$pca_y else "PC1"
        ylab   <- paste0(pc_sel, " (",
                         var_exp[as.numeric(sub("PC", "", pc_sel))], "%)")
        scores$hover <- paste0(colvar, ": ", scores[[colvar]],
                               "<br>", pc_sel, ": ",
                               round(scores[[pc_sel]], 3))
        p <- plot_ly(scores,
                     x = ~color_vec, y = scores[[pc_sel]],
                     type = "box", color = color_vec, colors = pal,
                     text = ~hover,
                     hovertemplate = "%{text}<extra></extra>") %>%
          layout(yaxis = list(title = ylab),
                 xaxis = list(title = colvar))
      }
    }
    
    session$sendCustomMessage("compute_done", list(is_corr = FALSE))
    
    theme <- plotly_theme()
    p %>%
      layout(
        paper_bgcolor = theme$paper_bgcolor,
        plot_bgcolor  = theme$plot_bgcolor,
        font          = theme$font,
        xaxis         = theme$xaxis,
        yaxis         = theme$yaxis,
        scene         = theme$scene,
        legend        = theme$legend,
        margin        = list(l = 50, r = 20, t = 20, b = 50, pad = 0)
      ) %>%
      event_register("plotly_click")
  })
  
  output$main_plot <- renderPlotly({
    p <- plot_results()
    if (is.null(p)) {
      return(plot_ly() %>%
               layout(
                 xaxis = list(visible = FALSE),
                 yaxis = list(visible = FALSE),
                 paper_bgcolor = "rgba(0,0,0,0)",
                 plot_bgcolor  = "rgba(0,0,0,0)"
               ) %>%
               event_register("plotly_click"))
    }
    
    # Inject theme fonts into axis titles that were set as plain strings
    # plotly stores layout in p$x$layoutAttrs — we patch it here
    theme <- plotly_theme()
    tf    <- list(color = theme$font$color, size = 11)
    
    fix_axis <- function(ax_cfg, theme_ax) {
      if (is.null(ax_cfg)) return(theme_ax)
      # Preserve title text, override everything else with theme
      title_text <- if (is.list(ax_cfg$title)) ax_cfg$title$text
      else if (is.character(ax_cfg$title)) ax_cfg$title
      else NULL
      merged <- theme_ax
      if (!is.null(title_text))
        merged$title <- list(text = title_text, font = tf)
      merged
    }
    
    # Walk layoutAttrs and patch xaxis/yaxis/scene
    if (!is.null(p$x$layoutAttrs)) {
      p$x$layoutAttrs <- lapply(p$x$layoutAttrs, function(la) {
        if (!is.null(la$xaxis))
          la$xaxis <- fix_axis(la$xaxis, theme$xaxis)
        if (!is.null(la$yaxis))
          la$yaxis <- fix_axis(la$yaxis, theme$yaxis)
        if (!is.null(la$scene)) {
          sc <- la$scene
          if (!is.null(sc$xaxis)) sc$xaxis <- fix_axis(sc$xaxis, theme$scene$xaxis)
          if (!is.null(sc$yaxis)) sc$yaxis <- fix_axis(sc$yaxis, theme$scene$yaxis)
          if (!is.null(sc$zaxis)) sc$zaxis <- fix_axis(sc$zaxis, theme$scene$zaxis)
          la$scene <- sc
        }
        la
      })
    }
    
    # Apply zero margin for 3D plots only — 2D plots keep standard margins
    is_3d <- !is.null(input$plot_type) &&
      input$plot_type %in% c("Scatter 3D", "Diel Line 3D")
    if (is_3d) {
      p <- p %>% layout(margin = list(l = 0, r = 0, t = 0, b = 0, pad = 0))
    }
    
    p$x$source <- "main"
    p
  })
  
  # ── Correlation plot ──────────────────────────────────────────────────────────
  output$corr_plot <- renderPlot({
    req(bottom_trigger() > 0)
    req(cache_applied())
    req(isolate(input$plot_type) == "Index Correlation")
    
    inds <- isolate(input$selected_indices)
    if (is.null(inds) || length(inds) < 2) {
      plot.new()
      text(0.5, 0.5, "Select at least 2 indices.",
           cex = 1.4, col = "#aaa", adj = 0.5)
      session$sendCustomMessage("compute_done", list(is_corr = TRUE))
      return()
    }
    
    data <- isolate(analysis_data())
    if (nrow(data) > 5000) {
      set.seed(42)
      data <- data[sample(nrow(data), 5000), ]
      showNotification("Correlation plot: random sample of 5,000 rows.",
                       type = "message", duration = 4)
    }
    
    plot_data_corr <- data[, inds, drop = FALSE]
    plot_data_corr <- plot_data_corr[complete.cases(plot_data_corr), ]
    
    if (nrow(plot_data_corr) == 0) {
      plot.new()
      text(0.5, 0.5, "No complete cases available.",
           cex = 1.4, col = "#aaa", adj = 0.5)
      session$sendCustomMessage("compute_done", list(is_corr = TRUE))
      return()
    }
    
    p <- GGally::ggpairs(
      plot_data_corr,
      upper = list(continuous = GGally::wrap("cor",
                                             method = "pearson",
                                             size   = 5,
                                             color  = "#111")),
      lower = list(continuous = GGally::wrap("points",
                                             alpha = 0.2,
                                             size  = 0.6,
                                             color = "#111")),
      diag  = list(continuous = GGally::wrap("densityDiag",
                                             fill      = "#f0f0ec",
                                             color     = "#111",
                                             linewidth = 0.8))
    ) +
      theme_bw(base_size = 11) +
      theme(
        panel.grid.minor = element_blank(),
        panel.border     = element_rect(colour = "#e0e0dc",
                                        fill = NA, linewidth = 0.5),
        strip.text       = element_text(size = 10, colour = "#333"),
        axis.text        = element_text(size = 8,  colour = "#555")
      )
    
    corr_plot_obj(p)
    session$sendCustomMessage("compute_done", list(is_corr = TRUE))
    p
  }, bg = "transparent")
  outputOptions(output, "corr_plot", suspendWhenHidden = FALSE)
  
  # ── PCA axis reset ────────────────────────────────────────────────────────────
  observeEvent(input$plot_type, {
    if (input$plot_type == "Scatter 3D") {
      updateSelectInput(session, "pca_x", selected = "PC1")
      updateSelectInput(session, "pca_y", selected = "PC2")
      updateSelectInput(session, "pca_z", selected = "PC3")
    } else if (input$plot_type == "Scatter 2D") {
      updateSelectInput(session, "pca_x", selected = "PC1")
      updateSelectInput(session, "pca_y", selected = "PC2")
    } else {
      updateSelectInput(session, "pca_y", selected = "PC1")
      if (input$plot_type == "Diel Line 3D")
        updateSelectInput(session, "pca_z", selected = "PC2")
    }
  })
  
  # ── PCA summary ───────────────────────────────────────────────────────────────
  output$pca_summary <- renderPrint({
    req(bottom_trigger() > 0)
    inds <- isolate(input$selected_indices)
    if (!is.null(inds) && length(inds) > 3) {
      res <- isolate(full_pca_data())
      if (is.null(res)) return(cat("Computing..."))
      cat("PCA Summary:\n")
      print(summary(res$pca)$importance)
      cat("\nLoadings:\n")
      print(round(res$pca$rotation, 3))
    } else {
      cat("Select >3 indices to run PCA.")
    }
  })
  outputOptions(output, "pca_summary", suspendWhenHidden = FALSE)
  
  # ── Summary statistics ────────────────────────────────────────────────────────
  output$summary_stats <- renderUI({
    req(bottom_trigger() > 0)
    req(cache_applied())
    
    df_analysed <- isolate(analysis_data())
    df_plotted  <- isolate(plot_data())
    df_total    <- isolate(cache_df())
    choices     <- isolate(cache_filter_choices())
    date_col    <- isolate(cache_date_col())
    
    if (is.null(df_plotted))  df_plotted  <- df_analysed[0, ]
    if (is.null(df_analysed)) df_analysed <- df_total[0, ]
    
    n_plotted  <- nrow(df_plotted)
    n_analysed <- nrow(df_analysed)
    n_total    <- if (!is.null(df_total)) nrow(df_total) else NA
    
    fmt_date <- function(df) {
      if (is.null(df) || nrow(df) == 0 || !date_col %in% colnames(df))
        return("—")
      dates <- as.integer(df[[date_col]])
      dates <- dates[!is.na(dates)]
      if (length(dates) == 0) return("—")
      paste0(
        format(as.Date(as.character(min(dates)), "%Y%m%d"), "%d %b %Y"),
        " - ",
        format(as.Date(as.character(max(dates)), "%Y%m%d"), "%d %b %Y")
      )
    }
    
    meta_rows <- lapply(names(choices), function(col) {
      n_plot <- length(unique(df_plotted[[col]]))
      n_anal <- length(unique(df_analysed[[col]]))
      n_tot  <- length(choices[[col]])
      tags$tr(
        tags$td(style = "color:#aaa; font-size:10px; padding:2px 6px 2px 0;", col),
        tags$td(style = "font-size:10px; padding:2px 0;",
                paste0(n_plot, " / ", n_anal, " / ", n_tot))
      )
    })
    
    inds <- isolate(input$selected_indices)
    index_rows <- if (!is.null(inds) && length(inds) > 0 && n_plotted > 0) {
      lapply(inds, function(idx) {
        if (!idx %in% colnames(df_plotted)) return(NULL)
        vals <- as.numeric(df_plotted[[idx]])
        tags$tr(
          tags$td(style = "color:#aaa; font-size:10px; padding:2px 6px 2px 0;", idx),
          tags$td(style = "font-size:10px; padding:2px 0;",
                  paste0(round(mean(vals, na.rm = TRUE), 3),
                         " ± ", round(sd(vals, na.rm = TRUE), 3)))
        )
      })
    } else NULL
    
    tagList(
      div(style = "display:flex; gap:6px; margin-bottom:8px;",
          div(style = "flex:1; background:#f0f0ec; border-radius:6px;
                     padding:5px 6px; text-align:center;",
              div(style = "font-size:15px; font-weight:500; color:#4DBBD5;",
                  format(n_plotted, big.mark = ",")),
              div(style = "font-size:8px; color:#aaa; margin-top:1px;", "plotted")
          ),
          div(style = "flex:1; background:#f0f0ec; border-radius:6px;
                     padding:5px 6px; text-align:center;",
              div(style = "font-size:15px; font-weight:500; color:#333;",
                  format(n_analysed, big.mark = ",")),
              div(style = "font-size:8px; color:#aaa; margin-top:1px;", "analysed")
          ),
          div(style = "flex:1; background:#f0f0ec; border-radius:6px;
                     padding:5px 6px; text-align:center;",
              div(style = "font-size:15px; font-weight:500; color:#999;",
                  format(n_total, big.mark = ",")),
              div(style = "font-size:8px; color:#aaa; margin-top:1px;", "total")
          )
      ),
      div(style = "background:#f0f0ec; border-radius:6px;
                   padding:6px 8px; margin-bottom:8px;",
          div(style = "display:flex; justify-content:space-between; margin-bottom:2px;",
              span(style = "font-size:9px; color:#4DBBD5;", "Plotted"),
              span(style = "font-size:9px; color:#333;", fmt_date(df_plotted))
          ),
          div(style = "display:flex; justify-content:space-between;",
              span(style = "font-size:9px; color:#aaa;", "Analysed"),
              span(style = "font-size:9px; color:#555;", fmt_date(df_analysed))
          )
      ),
      if (length(meta_rows) > 0) tagList(
        div(style = "font-size:10px; color:#aaa; margin-bottom:4px;",
            "Metadata (plotted / analysed / total)"),
        tags$table(style = "width:100%; border-collapse:collapse;",
                   do.call(tagList, meta_rows))
      ),
      if (!is.null(index_rows)) tagList(
        div(style = "font-size:10px; color:#aaa; margin-top:8px; margin-bottom:4px;",
            "Index mean ± SD (plotted)"),
        tags$table(style = "width:100%; border-collapse:collapse;",
                   do.call(tagList, Filter(Negate(is.null), index_rows)))
      )
    )
  })
  outputOptions(output, "summary_stats", suspendWhenHidden = FALSE)
  
  # ── PCA export ────────────────────────────────────────────────────────────────
  output$download_pca <- downloadHandler(
    filename = function() paste0("PCA_export_", Sys.Date(), ".csv"),
    content = function(file) {
      res  <- full_pca_data()
      inds <- input$selected_indices
      if (is.null(res) || length(inds) <= 3) {
        showNotification("PCA export requires >3 indices.", type = "error")
        return(NULL)
      }
      scores    <- res$scores
      pc_cols   <- grep("^PC", colnames(scores), value = TRUE)
      meta_cols <- cache_meta_cols()
      keep_cols <- intersect(c(meta_cols, cache_filename_col()),
                             colnames(scores))
      write.csv(
        cbind(scores[, keep_cols, drop = FALSE],
              scores[, pc_cols,   drop = FALSE]),
        file, row.names = FALSE
      )
    }
  )
  
  # ── Audio click ───────────────────────────────────────────────────────────────
  observe({
    click <- event_data("plotly_click", source = "main")
    if (is.null(click)) return()
    
    click_sig <- paste(click$key, click$x, click$y, click$curveNumber, sep = "|")
    if (!is.null(last_click_key()) && last_click_key() == click_sig) return()
    last_click_key(click_sig)
    
    data_clicked <- NULL
    inds         <- input$selected_indices
    n_inds       <- length(inds)
    plot_tr      <- if (!is.null(input$plot_time_range)) input$plot_time_range
    else c(0, 1440)
    bin_mins     <- if (!is.null(input$diel_bin_mins)) input$diel_bin_mins else 30
    
    if (!is.null(click$key)) {
      composite_key <- click$key
      if (is.null(composite_key) || is.na(composite_key) ||
          composite_key == "NA") return()
      df <- plot_data()
      if (is.null(df)) return()
      row_idx <- which(df$.row_key == composite_key)
      if (length(row_idx) == 0) return()
      row <- df[row_idx[1], ]
      url <- resolve_audio_path(row)
      if (is.null(url)) return()
      current_audio(url)
      session$sendCustomMessage("update_now_playing",
                                list(info = build_now_playing(row, url)))
      updateAudio(session, url)
      
    } else {
      colvar <- input$color_by
      
      if (n_inds == 1) {
        group_data   <- plot_data() %>% filter(.data[[colvar]] == click$x)
        index_name   <- inds[1]
        data_clicked <- group_data[
          which.min(abs(group_data[[index_name]] - as.numeric(click$y))), ]
        
      } else if (n_inds > 3 &&
                 input$plot_type %in% c("Diel Line 2D", "Diel Line 3D")) {
        scores <- plot_data()
        req(scores)
        pcy <- if (!is.null(input$pca_y)) input$pca_y else "PC1"
        pcz <- if (!is.null(input$pca_z)) input$pca_z else "PC2"
        
        scores       <- add_time_bins(scores, plot_tr, bin_mins = bin_mins)
        clicked_time <- as.character(click$x)
        candidates   <- scores %>% filter(Time_label == clicked_time)
        if (nrow(candidates) == 0) return()
        
        if (input$plot_type == "Diel Line 2D") {
          avg_at_time <- candidates %>%
            group_by(!!sym(colvar)) %>%
            summarise(mean_val = mean(.data[[pcy]], na.rm = TRUE), .groups = "drop")
          clicked_group <- avg_at_time[[colvar]][
            which.min(abs(avg_at_time$mean_val - as.numeric(click$y)))]
        } else {
          avg_at_time <- candidates %>%
            group_by(!!sym(colvar)) %>%
            summarise(mean_y = mean(.data[[pcy]], na.rm = TRUE),
                      mean_z = mean(.data[[pcz]], na.rm = TRUE),
                      .groups = "drop")
          dists <- (avg_at_time$mean_y - as.numeric(click$y))^2 +
            (avg_at_time$mean_z - as.numeric(click$z))^2
          clicked_group <- avg_at_time[[colvar]][which.min(dists)]
        }
        
        group_candidates <- candidates %>% filter(.data[[colvar]] == clicked_group)
        
        if (nrow(group_candidates) > 0) {
          group_candidates <- if (input$plot_type == "Diel Line 2D") {
            group_candidates %>%
              mutate(.dist = abs(.data[[pcy]] - as.numeric(click$y)))
          } else {
            group_candidates %>%
              mutate(.dist = (.data[[pcy]] - as.numeric(click$y))^2 +
                       (.data[[pcz]] - as.numeric(click$z))^2)
          }
          data_clicked <- group_candidates[which.min(group_candidates$.dist), ]
        }
      }
      
      if (!is.null(data_clicked) && nrow(data_clicked) > 0) {
        url <- resolve_audio_path(data_clicked)
        if (!is.null(url)) {
          current_audio(url)
          session$sendCustomMessage("update_now_playing",
                                    list(info = build_now_playing(data_clicked, url)))
          updateAudio(session, url)
        }
      }
    }
  })
  
  # ── Open file ─────────────────────────────────────────────────────────────────
  observeEvent(input$open_file, {
    url  <- current_audio()
    if (is.null(url)) return()
    root <- cache_audio_root()
    path <- if (nchar(root) > 0)
      file.path(root, sub("^audio/", "", url)) else url
    if (Sys.info()[["sysname"]] == "Darwin")
      system2("open", c("-R", shQuote(path)))
    else if (.Platform$OS.type == "windows")
      system2("explorer",
              paste0('/select,"', normalizePath(path, winslash = "\\"), '"'))
    else
      system2("xdg-open", dirname(path))
  })
  
  updateAudio <- function(session, src) {
    session$sendCustomMessage("update_audio", list(src = src))
  }
}