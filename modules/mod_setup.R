# modules/mod_setup.R

setupUI <- function(id) {
  ns <- NS(id)
  tagList(
    uiOutput(ns("setup_title")),
    uiOutput(ns("setup_body"))
  )
}

setupServer <- function(id, active_config) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    
    raw_df        <- reactiveVal(NULL)
    missing_files <- reactiveVal(NULL)
    output_data   <- reactiveVal(NULL)
    
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
            
            fluidRow(
              column(6,
                     div(style = "font-size: 11px; color: #888; margin-bottom: 3px;",
                         "Date column"),
                     selectInput(ns("date_col"), label = NULL,
                                 choices = NULL, multiple = FALSE, width = "100%")
              ),
              column(6,
                     div(style = "font-size: 11px; color: #888; margin-bottom: 3px;",
                         "Time column"),
                     selectInput(ns("time_col"), label = NULL,
                                 choices = NULL, multiple = FALSE, width = "100%")
              )
            ),
            
            div(style = "height: 8px;"),
            
            fluidRow(
              column(4,
                     div(style = "font-size: 11px; color: #888; margin-bottom: 3px;",
                         "Index columns"),
                     selectInput(ns("index_cols"), label = NULL,
                                 choices = NULL, multiple = TRUE, width = "100%")
              ),
              column(4,
                     div(style = "font-size: 11px; color: #888; margin-bottom: 3px;",
                         "Metadata columns"),
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
                  div(style = "font-size: 11px; color: #888; margin-bottom: 3px;",
                      "Folder pattern — use {ColumnName} tokens"),
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
              column(3,
                     actionButton(ns("link_files"), "Test links",
                                  class = "btn-sm", width = "100%")
              ),
              column(3,
                     actionButton(ns("save_config"), "Save config",
                                  class = "btn-sm", width = "100%")
              ),
              column(3,
                     actionButton(ns("apply"), "Apply",
                                  class = "btn-primary btn-sm", width = "100%")
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
      
      showNotification("Loading project…", id = "loading_msg", duration = NULL)
      
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
      if (!is.null(cfg$audio_root) && cfg$audio_root != "")
        updateTextInput(session, "audio_root", value = cfg$audio_root)
      if (!is.null(cfg$folder_structure) && cfg$folder_structure != "")
        updateTextInput(session, "folder_structure",
                        value = cfg$folder_structure)
    })
    
    # ── Helper: package output ─────────────────────────────────────────────────
    package_output <- function(df, cfg, index_cols, meta_cols,
                               fn_col, date_col, time_col, audio_root,
                               audio_mode, folder_pattern, path_col) {
      if (date_col %in% colnames(df))
        df[[date_col]] <- as.integer(df[[date_col]])
      if (time_col %in% colnames(df))
        df[[time_col]] <- as.numeric(df[[time_col]])
      
      list(
        df             = df,
        config         = cfg,
        index_cols     = index_cols,
        meta_cols      = meta_cols,
        filename_col   = fn_col,
        date_col       = date_col,
        time_col       = time_col,
        audio_root     = audio_root,
        audio_mode     = audio_mode,
        folder_pattern = folder_pattern,
        path_col       = path_col
      )
    }
    
    # ── Manual Apply ───────────────────────────────────────────────────────────
    observeEvent(input$apply, {
      df  <- raw_df()
      cfg <- active_config()
      req(df, cfg)
      
      showNotification("Applying…", id = "apply_msg", duration = NULL)
      removeNotification("apply_msg")
      showNotification("Ready.", type = "message", duration = 2)
      
      output_data(package_output(
        df             = df,
        cfg            = cfg,
        index_cols     = input$index_cols,
        meta_cols      = input$meta_cols,
        fn_col         = input$filename_col,
        date_col       = input$date_col,
        time_col       = input$time_col,
        audio_root     = trimws(input$audio_root),
        audio_mode     = input$audio_path_mode,
        folder_pattern = input$folder_structure,
        path_col       = input$path_col
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
      
      showNotification("Loading previous settings…",
                       id = "auto_apply_msg", duration = NULL)
      removeNotification("auto_apply_msg")
      
      output_data(package_output(
        df             = raw_df(),
        cfg            = cfg,
        index_cols     = unlist(cfg$index_columns),
        meta_cols      = unlist(cfg$metadata_columns),
        fn_col         = cfg$filename_column,
        date_col       = cfg$date_column %||% "Date",
        time_col       = cfg$time_column %||% "Time",
        audio_root     = trimws(cfg$audio_root %||% ""),
        audio_mode     = cfg$audio_path_mode %||% "folder_structure",
        folder_pattern = cfg$folder_structure %||% "{Site}/{Device}/{Date}",
        path_col       = cfg$filename_column
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
                              gregexpr("(?<=\\{)[^}]+(?=\\})", pattern, perl = TRUE))[[1]]
        missing_cols <- tokens[!tokens %in% colnames(df)]
        if (length(missing_cols) > 0) {
          showNotification(
            paste("Pattern uses columns not in CSV:",
                  paste(missing_cols, collapse = ", ")),
            type = "error")
          return()
        }
        
        # Sample 200 rows and build paths only for those
        n_check    <- min(200, nrow(df))
        sample_idx <- sample(seq_len(nrow(df)), n_check)
        sample_df  <- df[sample_idx, ]
        
        paths <- mapply(function(i) {
          p <- pattern
          for (tok in tokens)
            p <- gsub(paste0("\\{", tok, "\\}"),
                      as.character(sample_df[[tok]][i]), p)
          file.path(audio_root, p,
                    paste0(trimws(as.character(
                      sample_df[[input$filename_col]][i])), ".wav"))
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
        type = if (n_missing == 0) "message" else "warning",
        duration = 5
      )
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
    observeEvent(input$save_config, {
      cfg      <- active_config()
      req(cfg)
      proj_dir <- file.path(PROJECTS_ROOT, cfg$project_name)
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
        palettes         = cfg$palettes
      ))
      showNotification("Config saved.", type = "message", duration = 3)
    })
    
    return(output_data)
  })
}
 