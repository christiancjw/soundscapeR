source("modules/mod_project.R")
source("modules/mod_setup.R")

function(input, output, session) {
  
  current_audio <- reactiveVal(NULL)
  
  # ── Disable analysis tab on startup ──────────────────────────────────────────
  session$onFlushed(function() {
    session$sendCustomMessage("set_analysis_enabled", list(enabled = FALSE))
  }, once = TRUE)
  
  # ── Module wiring ─────────────────────────────────────────────────────────────
  active_config <- projectServer("project")
  app_data      <- setupServer("setup", active_config)
  
  # ── Flat cache ────────────────────────────────────────────────────────────────
  cache_df             <- reactiveVal(NULL)
  cache_index_cols     <- reactiveVal(character(0))
  cache_meta_cols      <- reactiveVal(character(0))
  cache_filter_choices <- reactiveVal(list())
  cache_audio_root     <- reactiveVal("")
  cache_date_col       <- reactiveVal("Date")
  cache_time_col       <- reactiveVal("Time")
  cache_date_range     <- reactiveVal(NULL)  # c(min_int, max_int)
  cache_applied        <- reactiveVal(FALSE)
  
  observeEvent(app_data(), {
    ad <- app_data()
    if (is.null(ad)) return()
    
    showNotification("Loading into analysis…", id = "cache_msg", duration = NULL)
    
    if (nchar(ad$audio_root) > 0 && dir.exists(ad$audio_root)) {
      addResourcePath("audio", ad$audio_root)
      cache_audio_root(ad$audio_root)
    } else if (nchar(ad$audio_root) > 0) {
      showNotification(
        "Audio root not accessible — analysis available, audio playback disabled.",
        type = "warning", duration = 6
      )
    }
    
    cache_df(ad$df)
    cache_index_cols(ad$index_cols)
    cache_meta_cols(ad$meta_cols)
    cache_date_col(ad$date_col)
    cache_time_col(ad$time_col)
    
    # Compute date range from data for the date pickers
    date_col <- ad$date_col
    if (date_col %in% colnames(ad$df)) {
      dates    <- as.integer(ad$df[[date_col]])
      dates    <- dates[!is.na(dates)]
      min_date <- as.Date(as.character(min(dates)), format = "%Y%m%d")
      max_date <- as.Date(as.character(max(dates)), format = "%Y%m%d")
      cache_date_range(c(min_date, max_date))
      
      updateDateInput(session, "date_from", value = min_date,
                      min = min_date, max = max_date)
      updateDateInput(session, "date_to",   value = max_date,
                      min = min_date, max = max_date)
    }
    
    # Build filter choices — skip date and time cols
    filter_cols <- ad$meta_cols[
      !ad$meta_cols %in% c(ad$date_col, ad$time_col)
    ]
    choices <- lapply(filter_cols, function(col) {
      vals <- sort(unique(as.character(ad$df[[col]])))
      if (length(vals) > 200) return(NULL)  # skip huge columns
      vals
    })
    names(choices) <- filter_cols
    choices <- Filter(Negate(is.null), choices)
    cache_filter_choices(choices)
    
    # Populate index selector
    updateCheckboxGroupInput(session, "selected_indices",
                             choices  = ad$index_cols,
                             selected = ad$index_cols)
    
    # Colour by
    updateSelectInput(session, "color_by",
                      choices  = ad$meta_cols,
                      selected = ad$meta_cols[1])
    
    cache_applied(TRUE)
    session$sendCustomMessage("set_analysis_enabled", list(enabled = TRUE))
    removeNotification("cache_msg")
    showNotification("Analysis ready.", type = "message", duration = 2)
  })
  
  # ── Analysis lock message ─────────────────────────────────────────────────────
  output$analysis_lock_msg <- renderUI({
    if (cache_applied()) return(NULL)
    div(style = "padding: 2rem; text-align: center; color: #aaa; font-size: 13px;",
        "Open a project and click Apply in Setup first.")
  })
  
  # ── Time range label ──────────────────────────────────────────────────────────
  output$time_range_label <- renderUI({
    req(input$time_range)
    lo <- minutes_to_label(input$time_range[1])
    hi <- minutes_to_label(input$time_range[2])
    div(paste0(lo, " – ", hi),
        style = "font-size: 11px; color: #555; text-align: center;
                 margin-top: -8px; margin-bottom: 4px;")
  })
  
  # ── Dynamic metadata filters ──────────────────────────────────────────────────
  output$dynamic_meta_filters <- renderUI({
    choices <- cache_filter_choices()
    if (length(choices) == 0) return(NULL)
    
    lapply(names(choices), function(col) {
      vals <- choices[[col]]
      tagList(
        div(style = "display: flex; justify-content: space-between;
                     align-items: center; margin-top: 8px; margin-bottom: 2px;",
            span(class = "s-label", style = "margin: 0;", col),
            div(
              tags$a(style = "font-size: 9px; color: #1a56db; cursor: pointer;
                            margin-right: 6px; text-decoration: none;",
                     onclick = paste0("Shiny.setInputValue('select_all_", col,
                                      "', Math.random())"),
                     "all"),
              tags$a(style = "font-size: 9px; color: #888; cursor: pointer;
                            text-decoration: none;",
                     onclick = paste0("Shiny.setInputValue('deselect_all_", col,
                                      "', Math.random())"),
                     "none")
            )
        ),
        div(class = "checkbox-filter-list",
            checkboxGroupInput(
              inputId  = paste0("meta_filter_", col),
              label    = NULL,
              choices  = vals,
              selected = vals,
              width    = "100%"
            )
        )
      )
    })
  })
  outputOptions(output, "dynamic_meta_filters", suspendWhenHidden = FALSE)
  outputOptions(output, "time_range_label",      suspendWhenHidden = FALSE)
  outputOptions(output, "analysis_lock_msg",     suspendWhenHidden = FALSE)
  
  # ── Select all / none observers for metadata filters ──────────────────────────
  observe({
    choices <- cache_filter_choices()
    lapply(names(choices), function(col) {
      # Select all
      observeEvent(input[[paste0("select_all_", col)]], {
        updateCheckboxGroupInput(session,
                                 paste0("meta_filter_", col),
                                 selected = choices[[col]])
      }, ignoreInit = TRUE)
      
      # Deselect all
      observeEvent(input[[paste0("deselect_all_", col)]], {
        updateCheckboxGroupInput(session,
                                 paste0("meta_filter_", col),
                                 selected = character(0))
      }, ignoreInit = TRUE)
    })
  })
  
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
    time_col <- cache_time_col()
    if (!time_col %in% colnames(df)) return(df)
    t_start <- minutes_to_hhmmss(range_mins[1])
    t_end   <- minutes_to_hhmmss(range_mins[2])
    if (t_start <= t_end) {
      subset(df, df[[time_col]] >= t_start & df[[time_col]] <= t_end)
    } else {
      subset(df, df[[time_col]] >= t_start | df[[time_col]] <= t_end)
    }
  }
  
  apply_date_filter <- function(df) {
    date_col <- cache_date_col()
    if (!date_col %in% colnames(df)) return(df)
    date_range <- cache_date_range()
    if (is.null(date_range)) return(df)
    from_int <- if (!is.null(input$date_from) && !is.na(input$date_from))
      as.integer(format(input$date_from, "%Y%m%d"))
    else
      as.integer(format(date_range[1], "%Y%m%d"))
    to_int <- if (!is.null(input$date_to) && !is.na(input$date_to))
      as.integer(format(input$date_to, "%Y%m%d"))
    else
      as.integer(format(date_range[2], "%Y%m%d"))
    df[df[[date_col]] >= from_int & df[[date_col]] <= to_int, ]
  }
  
  apply_meta_filters <- function(df) {
    choices <- cache_filter_choices()
    if (length(choices) == 0) return(df)
    for (col in names(choices)) {
      val <- input[[paste0("meta_filter_", col)]]
      # NULL or empty means nothing selected — return empty df
      if (is.null(val) || length(val) == 0) {
        return(df[0, ])
      }
      # If not all values selected, filter
      if (!setequal(val, choices[[col]])) {
        df <- df[df[[col]] %in% val, ]
      }
    }
    df
  }
  
  to_audio_url <- function(path) {
    root <- cache_audio_root()
    if (nchar(root) == 0) return(path)
    root_esc <- gsub("([.|()\\^{}+$*?]|\\[|\\])", "\\\\\\1", root)
    paste0("audio/", sub(paste0("^", root_esc, "/?"), "", path))
  }
  
  build_now_playing <- function(row, url) {
    meta_info <- paste(
      sapply(cache_meta_cols(), function(col) {
        if (col %in% colnames(row)) {
          paste0("<span style='color:#bbb; font-size:10px;'>", col,
                 "</span> ", row[[col]][1])
        } else NULL
      }),
      collapse = "<br>"
    )
    paste0("<strong style='font-size:12px;'>", basename(url),
           "</strong><br>", meta_info)
  }
  
  # ── Core data reactives ───────────────────────────────────────────────────────
  filtered_data <- reactive({
    df <- cache_df()
    req(df)
    df <- apply_date_filter(df)
    df <- apply_time_filter(df, input$time_range)
    df <- apply_meta_filters(df)
    if ("audio_path" %in% colnames(df))
      df$audio_url <- vapply(df$audio_path, to_audio_url, character(1))
    df
  })
  
  full_pca_data <- reactive({
    df <- cache_df()
    req(df)
    inds <- input$selected_indices
    if (is.null(inds) || length(inds) <= 3) return(NULL)
    df <- apply_date_filter(df)
    df <- apply_meta_filters(df)
    pca    <- prcomp(df %>% select(all_of(inds)), center = TRUE, scale. = TRUE)
    scores <- as.data.frame(pca$x)
    scores <- bind_cols(df,
                        scores[, !(names(scores) %in% names(df)), drop = FALSE])
    list(scores = scores, pca = pca)
  })
  
  plotting_data <- reactive({
    req(full_pca_data())
    full_scores <- full_pca_data()$scores
    pca_obj     <- full_pca_data()$pca
    inds        <- input$selected_indices
    df          <- apply_time_filter(full_scores, input$time_range)
    df_proj     <- as.data.frame(predict(pca_obj, newdata = df[inds]))
    df <- bind_cols(df,
                    df_proj[, !(names(df_proj) %in% names(df)), drop = FALSE])
    if ("audio_path" %in% colnames(df))
      df$audio_url <- vapply(df$audio_path, to_audio_url, character(1))
    df
  })
  
  # ── Palette helper ────────────────────────────────────────────────────────────
  get_palette <- function(df, colvar) {
    vals <- unique(as.character(df[[colvar]]))
    base_cols <- c(
      "#4DBBD5", "#E64B35", "#00A087", "#3C5488",
      "#F39B7F", "#8491B4", "#91D1C2", "#DC0000",
      "#7E6148", "#B09C85"
    )
    setNames(rep_len(base_cols, length(vals)), vals)
  }
  
  # ── Plot ──────────────────────────────────────────────────────────────────────
  plot_results <- eventReactive(input$compute, {
    req(cache_applied())
    inds   <- input$selected_indices
    n_inds <- length(inds)
    colvar <- input$color_by
    
    if (is.null(inds) || n_inds == 0) return(NULL)
    
    data <- if (n_inds <= 3) {
      filtered_data()
    } else {
      d <- plotting_data()
      if (is.null(d)) return(NULL)
      d
    }
    
    if (!is.null(colvar) && colvar %in% colnames(data)) {
      color_vec <- factor(data[[colvar]])
      pal       <- get_palette(data, colvar)
    } else {
      color_vec <- factor(rep("data", nrow(data)))
      pal       <- c("data" = "#4DBBD5")
    }
    
    time_col <- cache_time_col()
    data$Time_fmt <- if (time_col %in% colnames(data))
      sprintf("%06d", as.numeric(data[[time_col]])) else ""
    
    has_audio <- "audio_path" %in% colnames(data) &&
      !all(is.na(data$audio_path))
    if (has_audio && !"audio_url" %in% colnames(data))
      data$audio_url <- vapply(data$audio_path, to_audio_url, character(1))
    
    # ── Hover text builders ───────────────────────────────────────────────────
    date_col <- cache_date_col()
    time_col <- cache_time_col()
    
    make_text <- function(d) {
      paste0(colvar, ": ", d[[colvar]],
             "<br>Time: ", d$Time_fmt)
    }
    
    make_text_2d <- function(d) {
      paste0(colvar, ": ", d[[colvar]],
             "<br>", inds[1], ": ", round(d[[inds[1]]], 3),
             "<br>", inds[2], ": ", round(d[[inds[2]]], 3),
             if (date_col %in% colnames(d))
               paste0("<br>Date: ", d[[date_col]]),
             "<br>Time: ", d$Time_fmt)
    }
    
    make_text_3d <- function(d) {
      paste0(colvar, ": ", d[[colvar]],
             "<br>", inds[1], ": ", round(d[[inds[1]]], 3),
             "<br>", inds[2], ": ", round(d[[inds[2]]], 3),
             "<br>", inds[3], ": ", round(d[[inds[3]]], 3),
             if (date_col %in% colnames(d))
               paste0("<br>Date: ", d[[date_col]]),
             "<br>Time: ", d$Time_fmt)
    }
    
    make_text_pca_2d <- function(d, px, py) {
      paste0(colvar, ": ", d[[colvar]],
             "<br>", px, ": ", round(d[[px]], 3),
             "<br>", py, ": ", round(d[[py]], 3),
             if (date_col %in% colnames(d))
               paste0("<br>Date: ", d[[date_col]]),
             "<br>Time: ", d$Time_fmt)
    }
    
    make_text_pca_3d <- function(d, px, py, pz) {
      paste0(colvar, ": ", d[[colvar]],
             "<br>", px, ": ", round(d[[px]], 3),
             "<br>", py, ": ", round(d[[py]], 3),
             "<br>", pz, ": ", round(d[[pz]], 3),
             if (date_col %in% colnames(d))
               paste0("<br>Date: ", d[[date_col]]),
             "<br>Time: ", d$Time_fmt)
    }
    
    make_text_diel_2d <- function(d, py) {
      paste0("Time: ", d$Time_label,
             "<br>", py, ": ", round(d[[py]], 3),
             "<br>", colvar, ": ", d[[colvar]])
    }
    
    make_text_diel_3d <- function(d, py, pz) {
      paste0("Time: ", d$Time_label,
             "<br>", py, ": ", round(d[[py]], 3),
             "<br>", pz, ": ", round(d[[pz]], 3),
             "<br>", colvar, ": ", d[[colvar]])
    }
    
    if (n_inds == 1) {
      p <- plot_ly(data,
                   x = ~color_vec, y = data[[inds[1]]],
                   type = "box", color = color_vec, colors = pal,
                   hovertemplate = paste0(colvar, ": %{x}<br>",
                                          inds[1], ": %{y}<extra></extra>"))
      
    } else if (n_inds == 2) {
      data$hover <- make_text_2d(data)
      p <- plot_ly(data,
                   x = data[[inds[1]]], y = data[[inds[2]]],
                   type = "scatter", mode = "markers",
                   marker = list(size = 2),
                   color = color_vec, colors = pal,
                   text = ~hover,
                   hovertemplate = "%{text}<extra></extra>",
                   key = if (has_audio) ~audio_url else NULL) %>%
        layout(xaxis = list(title = inds[1]),
               yaxis = list(title = inds[2]))
      
    } else if (n_inds == 3) {
      data$hover <- make_text_3d(data)
      p <- plot_ly(data,
                   x = data[[inds[1]]], y = data[[inds[2]]],
                   z = data[[inds[3]]],
                   type = "scatter3d", mode = "markers",
                   marker = list(size = 2),
                   color = color_vec, colors = pal,
                   text = ~hover,
                   hovertemplate = "%{text}<extra></extra>",
                   key = if (has_audio) ~audio_url else NULL) %>%
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
      if (input$plot_type %in% c("Scatter 3D", "Diel Line 3D") &&
          !all(c(pcy, pcz) %in% available_pcs)) return(NULL)
      if (input$plot_type %in% c("Scatter 2D", "Diel Line 2D") &&
          !pcy %in% available_pcs) return(NULL)
      
      xlab <- paste0(pcx, " (", var_exp[as.numeric(sub("PC", "", pcx))], "%)")
      ylab <- paste0(pcy, " (", var_exp[as.numeric(sub("PC", "", pcy))], "%)")
      zlab <- paste0(pcz, " (", var_exp[as.numeric(sub("PC", "", pcz))], "%)")
      
      if (input$plot_type == "Scatter 3D") {
        scores$hover <- make_text_pca_3d(scores, pcx, pcy, pcz)
        p <- plot_ly(scores,
                     x = scores[[pcx]], y = scores[[pcy]], z = scores[[pcz]],
                     type = "scatter3d", mode = "markers",
                     marker = list(size = 2),
                     color = color_vec, colors = pal,
                     text = ~hover,
                     hovertemplate = "%{text}<extra></extra>",
                     key = if (has_audio) ~audio_url else NULL) %>%
          layout(scene = list(xaxis = list(title = xlab),
                              yaxis = list(title = ylab),
                              zaxis = list(title = zlab)))
        
      } else if (input$plot_type == "Scatter 2D") {
        scores$hover <- make_text_pca_2d(scores, pcx, pcy)
        p <- plot_ly(scores,
                     x = scores[[pcx]], y = scores[[pcy]],
                     type = "scatter", mode = "markers",
                     marker = list(size = 2),
                     color = color_vec, colors = pal,
                     text = ~hover,
                     hovertemplate = "%{text}<extra></extra>",
                     key = if (has_audio) ~audio_url else NULL) %>%
          layout(xaxis = list(title = xlab),
                 yaxis = list(title = ylab))
        
      } else if (input$plot_type == "Diel Line 2D") {
        time_col <- cache_time_col()
        scores <- scores %>%
          mutate(
            Time_posix = as.POSIXct(sprintf("%06d", as.numeric(.data[[time_col]])),
                                    format = "%H%M%S", tz = "UTC"),
            Time_bin   = floor((hour(Time_posix) * 60 +
                                  minute(Time_posix)) / 30) * 30,
            Time_label = sprintf("%02d:%02d",
                                 Time_bin %/% 60, Time_bin %% 60)
          )
        avg <- scores %>%
          group_by(Time_label, Time_bin, !!sym(colvar)) %>%
          summarise(mean_val = mean(.data[[pcy]], na.rm = TRUE),
                    .groups = "drop")
        avg$hover <- make_text_diel_2d(avg, pcy)
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
        
      } else if (input$plot_type == "Diel Line 3D") {
        time_col <- cache_time_col()
        scores <- scores %>%
          mutate(
            Time_posix = as.POSIXct(sprintf("%06d", as.numeric(.data[[time_col]])),
                                    format = "%H%M%S", tz = "UTC"),
            Time_bin   = floor((hour(Time_posix) * 60 +
                                  minute(Time_posix)) / 30) * 30,
            Time_label = sprintf("%02d:%02d",
                                 Time_bin %/% 60, Time_bin %% 60)
          )
        avg <- scores %>%
          group_by(Time_bin, Time_label, !!sym(colvar)) %>%
          summarise(mean_y = mean(.data[[pcy]], na.rm = TRUE),
                    mean_z = mean(.data[[pcz]], na.rm = TRUE),
                    .groups = "drop") %>%
          arrange(Time_bin)
        avg$hover <- make_text_diel_3d(avg, pcy, pcz)
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
        
      } else if (input$plot_type == "Boxplot") {
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
    
    p %>%
      layout(legend = list(
        x = 1, y = 1, xanchor = "right", yanchor = "top",
        bgcolor = "rgba(255,255,255,0.85)", borderwidth = 0,
        font = list(size = 10), traceorder = "normal",
        itemsizing = "constant"
      )) %>%
      event_register("plotly_click")
  })
  
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
  
  output$main_plot <- renderPlotly(plot_results())
  
  # ── PCA summary ───────────────────────────────────────────────────────────────
  output$pca_summary <- renderPrint({
    inds <- input$selected_indices
    if (!is.null(inds) && length(inds) > 3) {
      res <- full_pca_data()
      if (is.null(res)) return(cat("Computing…"))
      cat("PCA Summary:\n")
      print(summary(res$pca)$importance)
      cat("\nLoadings:\n")
      print(round(res$pca$rotation, 3))
    } else {
      cat("Select >3 indices to run PCA.")
    }
  })
  
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
      keep_cols <- intersect(c(meta_cols, "audio_path"), colnames(scores))
      write.csv(
        cbind(scores[, keep_cols, drop = FALSE],
              scores[, pc_cols,   drop = FALSE]),
        file, row.names = FALSE
      )
    }
  )
  
  # ── Audio click ───────────────────────────────────────────────────────────────
  observe({
    click <- event_data("plotly_click")
    if (is.null(click)) return()
    
    data_clicked <- NULL
    url          <- NULL
    
    if (!is.null(click$key)) {
      url <- click$key
      if (is.null(url) || is.na(url) || url == "NA") return()
      current_audio(url)
      
      df  <- filtered_data()
      row <- if ("audio_url" %in% colnames(df))
        df[!is.na(df$audio_url) & df$audio_url == url, ]
      else data.frame()
      
      info_html <- if (nrow(row) > 0) build_now_playing(row, url)
      else paste0("<strong>", basename(url), "</strong>")
      
      session$sendCustomMessage("update_now_playing", list(info = info_html))
      updateAudio(session, url)
      
    } else {
      n_inds <- length(input$selected_indices)
      colvar <- input$color_by
      time_col <- cache_time_col()
      
      if (n_inds == 1) {
        group_data   <- filtered_data() %>%
          filter(.data[[colvar]] == click$x)
        index_name   <- input$selected_indices[1]
        data_clicked <- group_data[
          which.min(abs(group_data[[index_name]] - as.numeric(click$y))), ]
        
      } else if (n_inds > 3 &&
                 input$plot_type %in% c("Diel Line 2D", "Diel Line 3D")) {
        scores <- plotting_data()
        req(scores)
        
        pcy <- if (!is.null(input$pca_y)) input$pca_y else "PC1"
        pcz <- if (!is.null(input$pca_z)) input$pca_z else "PC2"
        
        scores <- scores %>%
          mutate(
            Time_posix = as.POSIXct(
              sprintf("%06d", as.numeric(.data[[time_col]])),
              format = "%H%M%S", tz = "UTC"),
            Time_bin   = floor((hour(Time_posix) * 60 +
                                  minute(Time_posix)) / 30) * 30,
            Time_label = sprintf("%02d:%02d",
                                 Time_bin %/% 60, Time_bin %% 60)
          )
        
        candidates      <- scores %>%
          filter(Time_label == as.character(click$x))
        rendered_groups <- unique(as.character(candidates[[colvar]]))
        curve_number    <- click$curveNumber
        clicked_group   <- if (!is.null(curve_number) &&
                               curve_number + 1 <= length(rendered_groups))
          rendered_groups[curve_number + 1] else NULL
        
        if (!is.null(clicked_group)) {
          gc <- candidates %>% filter(.data[[colvar]] == clicked_group)
          if (nrow(gc) > 0) candidates <- gc
        }
        
        if (nrow(candidates) > 0) {
          candidates <- if (input$plot_type == "Diel Line 2D") {
            candidates %>%
              mutate(.dist = abs(.data[[pcy]] - as.numeric(click$y)))
          } else {
            candidates %>%
              mutate(.dist = (.data[[pcy]] - as.numeric(click$y))^2 +
                       (.data[[pcz]] - as.numeric(click$z))^2)
          }
          data_clicked <- candidates[which.min(candidates$.dist), ]
        }
      }
      
      if (!is.null(data_clicked) && nrow(data_clicked) > 0 &&
          "audio_path" %in% colnames(data_clicked)) {
        url <- to_audio_url(data_clicked$audio_path)
        if (!is.null(url) && !is.na(url) && url != "NA") {
          current_audio(url)
          info_html <- build_now_playing(data_clicked, url)
          session$sendCustomMessage("update_now_playing",
                                    list(info = info_html))
          updateAudio(session, url)
        }
      }
    }
  })
  
  # ── Open file in Finder/Explorer ──────────────────────────────────────────────
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