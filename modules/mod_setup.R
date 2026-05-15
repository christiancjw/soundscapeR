# modules/mod_setup.R
source("modules/mod_palette.R")

setupUI <- function(id) {
  ns <- NS(id)
  tagList(
    uiOutput(ns("setup_title")),
    uiOutput(ns("setup_body")),
    paletteUI(ns("palette"))
  )
}

setupServer <- function(id, active_config) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    
    raw_df              <- reactiveVal(NULL)
    missing_files       <- reactiveVal(NULL)
    output_data         <- reactiveVal(NULL)
    config_use_datetime <- reactiveVal(TRUE)   # persisted value from config
    confirmed_audio_root <- reactiveVal(NULL)  # set when test links passes
    
    # ── Title ─────────────────────────────────────────────────────────────────
    output$setup_title <- renderUI({
      cfg <- active_config()
      if (is.null(cfg)) return(
        div(style = "font-size: 13px; color: #aaa; padding: 1rem;",
            "Select and open a project to begin.")
      )
      div(style = "font-size: 14px; font-weight: 500; margin-bottom: 12px;",
          paste0("Setup — ", cfg$project_name))
    })
    
    # ── Main body ──────────────────────────────────────────────────────────────
    output$setup_body <- renderUI({
      cfg <- active_config()
      if (is.null(cfg)) return(NULL)
      
      tagList(
        
        div(class = "setup-card",
            div(class = "setup-card-title", "Step 1 — Map your columns"),
            
            # ── Date & time toggle ───────────────────────────────────────────
            div(style = "display:flex; align-items:center; gap:6px;
                         margin-bottom:10px;",
                if (config_use_datetime())
                  tags$input(type = "checkbox", id = ns("use_datetime"),
                             checked = "checked",
                             style   = "accent-color:#1a56db; cursor:pointer;
                                      width:13px; height:13px;")
                else
                  tags$input(type = "checkbox", id = ns("use_datetime"),
                             style   = "accent-color:#1a56db; cursor:pointer;
                                      width:13px; height:13px;"),
                tags$label(`for` = ns("use_datetime"),
                           style = "font-size:11px; color:#555;
                                  cursor:pointer; margin:0; user-select:none;",
                           "Use date & time data"),
                tags$span(class = "help-tip", `data-tip` = "Enable to use date and time columns for diel plots and temporal filtering. Disable if your data has no temporal information.", "?")
            ),
            
            conditionalPanel(
              condition = paste0("input['", ns("use_datetime"), "']"),
              
              # ── Date column + preview + format ──────────────────────────────
              fluidRow(
                column(6,
                       div(style = "font-size: 11px; color: #888; margin-bottom: 3px;",
                           "Date column"),
                       selectInput(ns("date_col"), label = NULL,
                                   choices = NULL, multiple = FALSE, width = "100%"),
                       uiOutput(ns("date_preview")),
                       div(style = "font-size: 11px; color: #888; margin-top: 6px; margin-bottom: 3px;
                               display:flex; align-items:center; gap:4px;",
                           "Date format", tags$span(class = "help-tip", `data-tip` = "Select the format your date column is stored in. Check the preview below to confirm.", "?")),
                       selectInput(ns("date_format"), label = NULL, width = "100%",
                                   choices = c(
                                     "YYYYMMDD (integer)"    = "YYYYMMDD",
                                     "YYYY-MM-DD"            = "YYYY-MM-DD",
                                     "DD/MM/YYYY"            = "DD/MM/YYYY",
                                     "MM/DD/YYYY"            = "MM/DD/YYYY",
                                     "YYYY/MM/DD"            = "YYYY/MM/DD",
                                     "DD-MM-YYYY"            = "DD-MM-YYYY",
                                     "Combined datetime col" = "datetime"
                                   ))
                ),
                
                # ── Time column + preview + format (hidden for datetime format) ──
                column(6,
                       conditionalPanel(
                         condition = paste0(
                           "input['", ns("date_format"), "'] !== 'datetime'"
                         ),
                         div(style = "font-size: 11px; color: #888; margin-bottom: 3px;",
                             "Time column"),
                         selectInput(ns("time_col"), label = NULL,
                                     choices = NULL, multiple = FALSE, width = "100%"),
                         uiOutput(ns("time_preview")),
                         div(style = "font-size: 11px; color: #888; margin-top: 6px; margin-bottom: 3px;
                                 display:flex; align-items:center; gap:4px;",
                             "Time format", tags$span(class = "help-tip", `data-tip` = "Select the format your time column is stored in.", "?")),
                         selectInput(ns("time_format"), label = NULL, width = "100%",
                                     choices = c(
                                       "HHMMSS (integer)"      = "HHMMSS",
                                       "HH:MM:SS"              = "HH:MM:SS",
                                       "HH:MM"                 = "HH:MM",
                                       "Minutes since midnight" = "minutes",
                                       "Seconds since midnight" = "seconds"
                                     ))
                       )
                )
              )
            ),
            
            div(style = "height: 8px;"),
            
            fluidRow(
              column(4,
                     div(style = "font-size: 11px; color: #888; margin-bottom: 3px;
                               display:flex; align-items:center; gap:4px;",
                         "Index columns", tags$span(class = "help-tip", `data-tip` = "Select numeric acoustic index columns. Selecting 4 or more enables PCA compound index analysis.", "?")),
                     selectInput(ns("index_cols"), label = NULL,
                                 choices = NULL, multiple = TRUE, width = "100%")
              ),
              column(4,
                     div(style = "font-size: 11px; color: #888; margin-bottom: 3px;
                               display:flex; align-items:center; gap:4px;",
                         "Metadata columns", tags$span(class = "help-tip", `data-tip` = "Categorical columns used for grouping, filtering, and colouring. Exclude date and time columns.", "?")),
                     div(style = "font-size: 10px; color: #aaa; margin-bottom: 3px;",
                         "exclude date & time columns"),
                     selectInput(ns("meta_cols"), label = NULL,
                                 choices = NULL, multiple = TRUE, width = "100%")
              ),
              column(4,
                     div(style = "font-size: 11px; color: #888; margin-bottom: 3px;",
                         "Filename column"),
                     selectInput(ns("filename_col"), label = NULL,
                                 choices = NULL, multiple = FALSE, width = "100%")
              )
            )
        ),
        
        div(class = "setup-card",
            div(class = "setup-card-title", "Step 2 — Audio file pathing"),
            fluidRow(
              column(6,
                     div(style = "font-size: 11px; color: #888; margin-bottom: 3px;",
                         "Path mode"),
                     selectInput(ns("audio_path_mode"), label = NULL,
                                 width = "100%",
                                 choices = c(
                                   "Folder structure" = "folder_structure",
                                   "Full paths in CSV" = "csv_paths"
                                 ))
              ),
              column(6,
                     div(style = "font-size: 11px; color: #888; margin-bottom: 3px;",
                         "Audio root folder"),
                     textInput(ns("audio_root"), label = NULL,
                               placeholder = "/path/to/audio/", width = "100%")
              )
            ),
            conditionalPanel(
              condition = paste0("input['", ns("audio_path_mode"),
                                 "'] == 'folder_structure'"),
              div(style = "margin-top: 8px;",
                  div(style = "font-size: 11px; color: #888; margin-bottom: 3px;
                               display:flex; align-items:center; gap:4px;",
                      "Folder pattern", tags$span(class = "help-tip", `data-tip` = "Use {ColumnName} tokens matching your CSV columns to describe your audio folder layout. e.g. {Site}/{Device}/{Date}", "?")),
                  textInput(ns("folder_structure"), label = NULL,
                            value = "{Site}/{Device}/{Date}", width = "100%"),
                  div(style = "font-size: 10px; color: #aaa; margin-top: 3px;",
                      "e.g. {Site}/{Device}/{Date}")
              )
            ),
            conditionalPanel(
              condition = paste0("input['", ns("audio_path_mode"),
                                 "'] == 'csv_paths'"),
              div(style = "margin-top: 8px;",
                  div(style = "font-size: 11px; color: #888; margin-bottom: 3px;",
                      "Column containing full file paths"),
                  selectInput(ns("path_col"), label = NULL,
                              choices = NULL, width = "100%")
              )
            )
        ),
        
        div(class = "setup-card",
            div(class = "setup-card-title", "Step 3 — Save and apply"),
            fluidRow(
              column(6,
                     div(style = "display:flex; align-items:center; gap:6px;",
                         actionButton(ns("link_files"), "Test links",
                                      class = "btn-sm btn-accent", width = "100%"),
                         tags$span(class = "help-tip", `data-tip` = "Samples up to 200 recordings to verify SoundscapeR can locate your audio files.", "?")
                     )
              ),
              column(6,
                     actionButton(ns("apply"), "Save & Apply",
                                  class = "btn-sm btn-accent", width = "100%")
              )
            ),
            uiOutput(ns("validation_summary")),
            div(style = "margin-top: 10px; max-height: 180px; overflow-y: auto;",
                tableOutput(ns("missing_files_table")))
        )
      )
    })
    
    # ── When project opens: load CSV + populate selectors ──────────────────────
    observeEvent(active_config(), {
      cfg <- active_config()
      req(cfg)
      
      showNotification("Loading project...", id = "loading_msg", duration = NULL)
      
      df <- tryCatch(
        data.table::fread(cfg$csv_path, data.table = FALSE),
        error = function(e) NULL
      )
      
      removeNotification("loading_msg")
      
      if (is.null(df)) {
        showNotification("Could not read CSV. Check config.", type = "error")
        return()
      }
      
      raw_df(df)
      cols <- colnames(df)
      
      updateSelectInput(session, "date_col",
                        choices  = cols,
                        selected = cfg$date_column %||% "Date")
      updateSelectInput(session, "time_col",
                        choices  = cols,
                        selected = cfg$time_column %||% "Time")
      updateSelectInput(session, "index_cols",
                        choices  = cols,
                        selected = cfg$index_columns)
      updateSelectInput(session, "meta_cols",
                        choices  = cols,
                        selected = cfg$metadata_columns)
      updateSelectInput(session, "filename_col",
                        choices  = cols,
                        selected = cfg$filename_column)
      updateSelectInput(session, "path_col",
                        choices  = cols,
                        selected = cfg$filename_column)
      
      if (!is.null(cfg$audio_path_mode) && cfg$audio_path_mode != "")
        updateSelectInput(session, "audio_path_mode",
                          selected = cfg$audio_path_mode)
      if (!is.null(cfg$date_format) && cfg$date_format != "")
        updateSelectInput(session, "date_format", selected = cfg$date_format)
      if (!is.null(cfg$time_format) && cfg$time_format != "")
        updateSelectInput(session, "time_format", selected = cfg$time_format)
      if (!is.null(cfg$audio_root) && cfg$audio_root != "")
        updateTextInput(session, "audio_root", value = cfg$audio_root)
      if (!is.null(cfg$folder_structure) && cfg$folder_structure != "")
        updateTextInput(session, "folder_structure",
                        value = cfg$folder_structure)
      
      # Store persisted use_datetime so renderUI can set checkbox correctly
      config_use_datetime(
        if (!is.null(cfg$use_datetime)) as.logical(cfg$use_datetime) else TRUE
      )
    })
    
    # ── Date / time parsers ───────────────────────────────────────────────────
    parse_date_col <- function(x, fmt) {
      tryCatch({
        switch(fmt,
               "YYYYMMDD"   = as.integer(x),
               "YYYY-MM-DD" = as.integer(format(as.Date(as.character(x), "%Y-%m-%d"), "%Y%m%d")),
               "DD/MM/YYYY" = as.integer(format(as.Date(as.character(x), "%d/%m/%Y"), "%Y%m%d")),
               "MM/DD/YYYY" = as.integer(format(as.Date(as.character(x), "%m/%d/%Y"), "%Y%m%d")),
               "YYYY/MM/DD" = as.integer(format(as.Date(as.character(x), "%Y/%m/%d"), "%Y%m%d")),
               "DD-MM-YYYY" = as.integer(format(as.Date(as.character(x), "%d-%m-%Y"), "%Y%m%d")),
               "datetime"   = {
                 parsed <- tryCatch(
                   as.POSIXct(as.character(x), tryFormats = c(
                     "%Y-%m-%d %H:%M:%S", "%Y-%m-%dT%H:%M:%S",
                     "%Y-%m-%d %H:%M",
                     "%d/%m/%Y %H:%M:%S", "%d/%m/%Y %H:%M",
                     "%m/%d/%Y %H:%M:%S", "%m/%d/%Y %H:%M",
                     "%Y/%m/%d %H:%M:%S", "%Y/%m/%d %H:%M",
                     "%Y-%m-%d", "%d/%m/%Y", "%m/%d/%Y", "%Y/%m/%d"
                   )),
                   error = function(e) as.POSIXct(NA)
                 )
                 as.integer(format(parsed, "%Y%m%d"))
               },
               as.integer(x)
        )
      }, error = function(e) {
        showNotification(paste("Date parse error:", e$message), type = "warning", duration = 5)
        suppressWarnings(as.integer(x))
      })
    }
    
    parse_time_col <- function(x, fmt, datetime_vals = NULL) {
      tryCatch({
        switch(fmt,
               "HHMMSS"   = as.numeric(x),
               "HH:MM:SS" = {
                 sapply(strsplit(as.character(x), ":"), function(p) {
                   h <- suppressWarnings(as.numeric(p[1]))
                   m <- suppressWarnings(as.numeric(p[2]))
                   s <- if (length(p) >= 3) suppressWarnings(as.numeric(p[3])) else 0
                   ifelse(is.na(h) | is.na(m), NA_real_,
                          h * 10000 + m * 100 + ifelse(is.na(s), 0, s))
                 })
               },
               "HH:MM" = {
                 sapply(strsplit(as.character(x), ":"), function(p) {
                   h <- suppressWarnings(as.numeric(p[1]))
                   m <- suppressWarnings(as.numeric(p[2]))
                   ifelse(is.na(h) | is.na(m), NA_real_, h * 10000 + m * 100)
                 })
               },
               "minutes" = {
                 m <- as.numeric(x)
                 floor(m / 60) * 10000 + floor(m %% 60) * 100
               },
               "seconds" = {
                 s <- as.numeric(x)
                 floor(s / 3600) * 10000 + floor((s %% 3600) / 60) * 100 + floor(s %% 60)
               },
               "in_date" = {
                 if (!is.null(datetime_vals)) {
                   parsed <- tryCatch(
                     as.POSIXct(as.character(datetime_vals), tryFormats = c(
                       "%Y-%m-%d %H:%M:%S", "%Y-%m-%dT%H:%M:%S",
                       "%Y-%m-%d %H:%M",
                       "%d/%m/%Y %H:%M:%S", "%d/%m/%Y %H:%M",
                       "%m/%d/%Y %H:%M:%S", "%m/%d/%Y %H:%M",
                       "%Y/%m/%d %H:%M:%S", "%Y/%m/%d %H:%M"
                     )),
                     error = function(e) as.POSIXct(NA)
                   )
                   as.numeric(format(parsed, "%H%M%S"))
                 } else as.numeric(x)
               },
               as.numeric(x)
        )
      }, error = function(e) {
        showNotification(paste("Time parse error:", e$message), type = "warning", duration = 5)
        suppressWarnings(as.numeric(x))
      })
    }
    
    # ── Helper: package output ─────────────────────────────────────────────────
    package_output <- function(df, cfg, index_cols, meta_cols,
                               fn_col, date_col, time_col, audio_root,
                               audio_mode, folder_pattern, path_col,
                               use_datetime, date_fmt = "YYYYMMDD",
                               time_fmt = "HHMMSS") {
      if (use_datetime) {
        if (date_col %in% colnames(df))
          df[[date_col]] <- parse_date_col(df[[date_col]], date_fmt)
        if (time_fmt == "in_date") {
          # Extract time from datetime column into synthetic column
          if (date_col %in% colnames(df)) {
            df[["__time__"]] <- parse_time_col(NULL, "in_date", df[[date_col]])
            time_col <- "__time__"
          }
        } else if (time_col %in% colnames(df)) {
          df[[time_col]] <- parse_time_col(df[[time_col]], time_fmt)
        }
      }
      
      list(
        df             = df,
        config         = cfg,
        index_cols     = index_cols,
        meta_cols      = meta_cols,
        filename_col   = fn_col,
        date_col       = if (use_datetime) date_col else "",
        time_col       = if (use_datetime) time_col else "",
        audio_root     = audio_root,
        audio_mode     = audio_mode,
        folder_pattern = folder_pattern,
        path_col       = path_col,
        use_datetime   = use_datetime,
        date_format    = date_fmt,
        time_format    = time_fmt
      )
    }
    
    # ── Date / time column previews ───────────────────────────────────────────
    preview_val <- function(col) {
      df <- raw_df()
      if (is.null(df) || !col %in% colnames(df)) return(NULL)
      vals <- df[[col]]
      # Use 3rd row, fallback to first non-NA
      v <- if (length(vals) >= 3) vals[3] else vals[which(!is.na(vals))[1]]
      if (is.null(v) || is.na(v)) return(NULL)
      as.character(v)
    }
    
    preview_ui <- function(val) {
      if (is.null(val)) return(NULL)
      div(style = "font-size: 10px; color: var(--text-faint,#aaa);
                   margin-top: 3px; font-family: monospace;
                   white-space: nowrap; overflow: hidden;
                   text-overflow: ellipsis;",
          paste0("e.g. “", val, "”"))
    }
    
    output$date_preview <- renderUI({
      col <- input$date_col
      if (is.null(col) || nchar(col) == 0) return(NULL)
      preview_ui(preview_val(col))
    })
    
    output$time_preview <- renderUI({
      col <- input$time_col
      if (is.null(col) || nchar(col) == 0) return(NULL)
      preview_ui(preview_val(col))
    })
    
    # ── Read use_datetime safely ───────────────────────────────────────────────
    get_use_datetime <- function() {
      val <- input$use_datetime
      if (is.null(val)) TRUE else as.logical(val)
    }
    
    # ── Manual Apply ───────────────────────────────────────────────────────────
    observeEvent(input$apply, {
      df  <- raw_df()
      cfg <- active_config()
      req(df, cfg)
      
      use_dt <- get_use_datetime()
      
      showNotification("Applying...", id = "apply_msg", duration = NULL)
      removeNotification("apply_msg")
      
      # Save config to disk on every apply
      proj_dir <- if (!is.null(cfg$proj_dir) && nchar(cfg$proj_dir) > 0)
        cfg$proj_dir
      else if (!is.null(cfg$csv_path) && nchar(cfg$csv_path) > 0)
        dirname(dirname(cfg$csv_path))
      else
        file.path(PROJECTS_ROOT, cfg$project_name)
      
      write_config(proj_dir, list(
        project_name     = cfg$project_name,
        csv_path         = cfg$csv_path,
        date_column      = input$date_col,
        time_column      = input$time_col,
        index_columns    = as.list(input$index_cols),
        metadata_columns = as.list(input$meta_cols),
        filename_column  = input$filename_col,
        audio_root       = input$audio_root,
        audio_path_mode  = input$audio_path_mode,
        folder_structure = input$folder_structure,
        use_datetime     = use_dt,
        date_format      = input$date_format %||% "YYYYMMDD",
        time_format      = input$time_format %||% "HHMMSS",
        palettes         = palette_config()
      ))
      
      showNotification("Saved & applied.", type = "message", duration = 2)
      
      output_data(package_output(
        df             = df,
        cfg            = cfg,
        index_cols     = input$index_cols,
        meta_cols      = input$meta_cols,
        fn_col         = input$filename_col,
        date_col       = input$date_col   %||% "Date",
        time_col       = input$time_col   %||% "Time",
        audio_root     = trimws(input$audio_root),
        audio_mode     = input$audio_path_mode,
        folder_pattern = input$folder_structure,
        path_col       = input$path_col,
        use_datetime   = use_dt,
        date_fmt       = input$date_format %||% "YYYYMMDD",
        time_fmt       = if (!is.null(input$date_format) &&
                             input$date_format == "datetime") "in_date"
        else input$time_format %||% "HHMMSS"
      ))
    })
    
    # ── Auto-apply if config already has cols saved ────────────────────────────
    observeEvent(raw_df(), {
      cfg <- active_config()
      req(cfg)
      
      has_cols <- length(cfg$index_columns) > 0 &&
        length(cfg$metadata_columns) > 0 &&
        nchar(cfg$filename_column) > 0
      if (!has_cols) return()
      
      use_dt <- if (!is.null(cfg$use_datetime)) cfg$use_datetime else TRUE
      
      showNotification("Loading previous settings...",
                       id = "auto_apply_msg", duration = NULL)
      removeNotification("auto_apply_msg")
      
      output_data(package_output(
        df             = raw_df(),
        cfg            = cfg,
        index_cols     = unlist(cfg$index_columns),
        meta_cols      = unlist(cfg$metadata_columns),
        fn_col         = cfg$filename_column,
        date_col       = cfg$date_column      %||% "Date",
        time_col       = cfg$time_column      %||% "Time",
        audio_root     = trimws(cfg$audio_root %||% ""),
        audio_mode     = cfg$audio_path_mode  %||% "folder_structure",
        folder_pattern = cfg$folder_structure %||% "{Site}/{Device}/{Date}",
        path_col       = cfg$filename_column,
        use_datetime   = use_dt,
        date_fmt       = cfg$date_format %||% "YYYYMMDD",
        time_fmt       = if (!is.null(cfg$date_format) &&
                             cfg$date_format == "datetime") "in_date"
        else cfg$time_format %||% "HHMMSS"
      ))
    })
    
    # ── Test link files ────────────────────────────────────────────────────────
    observeEvent(input$link_files, {
      df  <- raw_df()
      cfg <- active_config()
      req(df, cfg)
      
      audio_root <- trimws(input$audio_root)
      
      if (!dir.exists(audio_root)) {
        showNotification("Audio root folder not found.", type = "error")
        return()
      }
      
      mode <- input$audio_path_mode
      
      if (mode == "folder_structure") {
        pattern <- input$folder_structure
        tokens  <- regmatches(pattern,
                              gregexpr("(?<=\\{)[^}]+(?=\\})",
                                       pattern, perl = TRUE))[[1]]
        missing_cols <- tokens[!tokens %in% colnames(df)]
        if (length(missing_cols) > 0) {
          showNotification(
            paste("Pattern uses columns not in CSV:",
                  paste(missing_cols, collapse = ", ")),
            type = "error")
          return()
        }
        
        n_check    <- min(200, nrow(df))
        sample_idx <- sample(seq_len(nrow(df)), n_check)
        sample_df  <- df[sample_idx, ]
        
        audio_exts <- c(".wav", ".WAV", ".mp3", ".MP3",
                        ".flac", ".FLAC", ".ogg", ".OGG",
                        ".aif", ".aiff", ".AIFF")
        
        paths <- mapply(function(i) {
          p <- pattern
          for (tok in tokens)
            p <- gsub(paste0("\\{", tok, "\\}"),
                      as.character(sample_df[[tok]][i]), p)
          fn_raw  <- trimws(as.character(sample_df[[input$filename_col]][i]))
          fn_base <- tools::file_path_sans_ext(fn_raw)
          for (ext in audio_exts) {
            candidate <- file.path(audio_root, p, paste0(fn_base, ext))
            if (file.exists(candidate)) return(candidate)
          }
          file.path(audio_root, p, fn_raw)
        }, seq_len(n_check))
        
      } else {
        n_check    <- min(200, nrow(df))
        sample_idx <- sample(seq_len(nrow(df)), n_check)
        paths      <- df[[input$path_col]][sample_idx]
      }
      
      exists    <- file.exists(paths)
      missing_files(paths[!exists])
      
      n_linked  <- sum(exists)
      n_missing <- n_check - n_linked
      pct       <- round(100 * n_linked / n_check)
      
      showNotification(
        paste0(n_linked, "/", n_check, " sampled files found (", pct, "%)"),
        type     = if (n_missing == 0) "message" else "warning",
        duration = 5
      )
      session$sendCustomMessage("set_audio_linked",
                                list(status = if (n_missing == 0) "linked" else "unlinked"))
      if (n_missing == 0) confirmed_audio_root(audio_root)
    })
    
    # ── Validation summary ─────────────────────────────────────────────────────
    output$validation_summary <- renderUI({
      mf <- missing_files()
      if (is.null(mf)) return(NULL)
      n_missing <- length(mf)
      if (n_missing == 0) {
        div(style = "font-size: 11px; color: #2a9d5c; margin-top: 8px;",
            "All sampled files found.")
      } else {
        div(style = "font-size: 11px; color: #c0392b; margin-top: 8px;",
            paste0(n_missing, " missing in sample."))
      }
    })
    
    output$missing_files_table <- renderTable({
      mf <- missing_files()
      req(!is.null(mf) && length(mf) > 0)
      data.frame("Missing paths" = mf, check.names = FALSE)
    }, striped = TRUE, width = "100%", spacing = "xs")
    
    # ── Save config ────────────────────────────────────────────────────────────
    
    
    # ── Palette module ─────────────────────────────────────────────────────────
    palette_out       <- paletteServer("palette", active_config, output_data)
    reactive_palettes <- palette_out$palettes
    palette_config    <- palette_out$palette_config
    
    # Live reactive — updates immediately when checkbox changes, no Apply needed
    use_datetime_r <- reactive({
      val <- input$use_datetime
      if (is.null(val)) TRUE else as.logical(val)
    })
    
    return(list(
      app_data             = output_data,
      reactive_palettes    = reactive_palettes,
      use_datetime         = use_datetime_r,
      confirmed_audio_root = confirmed_audio_root
    ))
  })
}
