function(input, output, session) {
  
  current_audio <- reactiveVal(NULL)
  
  selected_data <- reactive(datasets[[input$selected_dataframe]])
  
  # ── Render HH:MM label for the time range slider ──────────────────────────
  output$time_range_label <- renderUI({
    req(input$time_range)
    lo <- minutes_to_label(input$time_range[1])
    hi <- minutes_to_label(input$time_range[2])
    div(paste0(lo, " – ", hi),
        style = "font-size: 11px; color: #555; text-align: center; margin-top: -8px; margin-bottom: 4px;")
  })
  
  # ── Core time filter using slider ─────────────────────────────────────────
  # Returns a filtered dataframe based on the slider range
  apply_time_filter <- function(df, range_mins) {
    t_start <- minutes_to_hhmmss(range_mins[1])
    t_end   <- minutes_to_hhmmss(range_mins[2])
    if (t_start <= t_end) {
      subset(df, Time >= t_start & Time <= t_end)
    } else {
      # Wraps midnight (e.g. 22:00 – 04:00)
      subset(df, Time >= t_start | Time <= t_end)
    }
  }
  
  # Single Index Data (filtered by time slider + period + season)
  filtered_data <- reactive({
    df <- selected_data()
    df <- apply_time_filter(df, input$time_range)
    if (!is.null(input$selected_period)) {
      pr <- recording_periods[[input$selected_period]]
      df <- df %>% filter(Date >= pr[1] & Date <= pr[2])
    }
    # Assign season column always, then filter if not "All"
    df <- df %>% mutate(Season = assign_season(Date))
    if (!is.null(input$selected_season) && input$selected_season != "All") {
      df <- df %>% filter(Season == input$selected_season)
    }
    df
  })
  
  # PCA Data (full, no time/season filter — those are applied at plotting stage)
  full_pca_data <- reactive({
    df <- datasets[[input$selected_dataframe]]
    inds <- input$selected_indices
    if (!is.null(input$selected_sites) && length(input$selected_sites) > 0) {
      df <- df %>% filter(Site %in% input$selected_sites)
    }
    if (length(inds) <= 3) return(NULL)
    # Assign Season column here so it's available throughout
    df <- df %>% mutate(Season = assign_season(Date))
    pca <- prcomp(df %>% select(all_of(inds)), center = TRUE, scale. = TRUE)
    scores <- as.data.frame(pca$x)
    scores <- bind_cols(df, scores[, !(names(scores) %in% names(df)), drop = FALSE])
    list(scores = scores, pca = pca)
  })
  
  # Subset for plotting: apply time slider + period + season filter on top of full PCA scores
  plotting_data <- reactive({
    full_scores <- full_pca_data()$scores
    pca_obj     <- full_pca_data()$pca
    inds        <- input$selected_indices
    
    df <- apply_time_filter(full_scores, input$time_range)
    
    if (!is.null(input$selected_period)) {
      pr <- recording_periods[[input$selected_period]]
      df <- df %>% filter(Date >= pr[1] & Date <= pr[2])
    }
    
    # Season already assigned in full_pca_data; just filter if not "All"
    if (!is.null(input$selected_season) && input$selected_season != "All") {
      df <- df %>% filter(Season == input$selected_season)
    }
    
    df_proj <- as.data.frame(predict(pca_obj, newdata = df[inds]))
    df_proj  <- bind_cols(df, df_proj[, !(names(df_proj) %in% names(df)), drop = FALSE])
    df_proj
  })
  
  
  # --------------------------
  # Plotting
  # --------------------------  
  
  plot_results <- eventReactive(input$compute, {
    
    inds   <- input$selected_indices
    n_inds <- length(inds)
    colvar <- input$color_by
    
    if (n_inds <= 3) {
      data <- filtered_data()
    } else {
      data <- plotting_data()
      if (is.null(data)) return(NULL)
    }
    
    # Colour vector
    if (colvar == "Site") {
      color_vec <- factor(data$Site, levels = site_order)
      pal <- site_colors
    } else if (colvar == "Month") {
      data <- data %>%
        mutate(Month = factor(month.name[as.numeric(substr(as.character(Date), 5, 6))], levels = month_levels))
      color_vec <- data$Month
      pal <- month_colors
    } else if (colvar == "QBR_Class") {
      color_vec <- factor(data$QBR_Class, levels = qbr_order)
      pal <- qbr_colors
    } else if (colvar == "Strahler_Class") {
      color_vec <- factor(data$Strahler_Class, levels = strahler_order)
      pal <- strahler_colors
    } else if (colvar == "Season") {
      color_vec <- factor(data$Season, levels = c("Monsoon", "Dry"))
      pal <- season_colors
    } else {
      color_vec <- "black"
      pal <- NULL
    }
    
    data$Time_fmt <- sprintf("%06d", as.numeric(data$Time))
    
    if (n_inds == 1) {
      p <- plot_ly(data, x = ~color_vec, y = data[[inds[1]]],
                   type = "box", color = color_vec, colors = pal)
      
    } else if (n_inds == 2) {
      p <- plot_ly(data, x = data[[inds[1]]], y = data[[inds[2]]],
                   type = "scatter", mode = "markers", marker = list(size = 2),
                   color = color_vec, colors = pal,
                   text = ~paste("Site:", Site, "<br>Date:", Date, "<br>Device:", Device, "<br>Time:", Time_fmt),
                   key = ~paste0("http://localhost:8000/", Site, "/", Device, "/", Date, "/", FileName, ".wav")) %>%
        layout(xaxis = list(title = inds[1]), yaxis = list(title = inds[2]))
      
    } else if (n_inds == 3) {
      p <- plot_ly(data, x = data[[inds[1]]], y = data[[inds[2]]], z = data[[inds[3]]],
                   type = "scatter3d", mode = "markers", marker = list(size = 2),
                   color = color_vec, colors = pal,
                   text = ~paste("Site:", Site, "<br>Date:", Date, "<br>Device:", Device, "<br>Time:", Time_fmt),
                   key = ~paste0("http://localhost:8000/", Site, "/", Device, "/", Date, "/", FileName, ".wav")) %>%
        layout(scene = list(xaxis = list(title = inds[1]), yaxis = list(title = inds[2]), zaxis = list(title = inds[3])))
      
    } else if (n_inds > 3) {
      scores  <- data   # data already has Month column added above if colvar == "Month"
      pca_obj <- full_pca_data()$pca
      var_exp <- round(100 * (pca_obj$sdev^2 / sum(pca_obj$sdev^2)), 1)
      
      pcx <- if (!is.null(input$pca_x) && nchar(input$pca_x) > 0) input$pca_x else "PC1"
      pcy <- if (!is.null(input$pca_y) && nchar(input$pca_y) > 0) input$pca_y else "PC2"
      pcz <- if (!is.null(input$pca_z) && nchar(input$pca_z) > 0) input$pca_z else "PC3"
      
      # Validate that required PC columns actually exist in scores
      available_pcs <- grep("^PC", colnames(data), value = TRUE)
      if (input$plot_type == "Diel Line 3D" || input$plot_type == "Scatter 3D") {
        if (!all(c(pcy, pcz) %in% available_pcs)) return(NULL)
      }
      if (input$plot_type %in% c("Diel Line 2D", "Scatter 2D")) {
        if (!pcy %in% available_pcs) return(NULL)
      }
      
      xlab <- paste0(pcx, " (", var_exp[as.numeric(sub("PC", "", pcx))], "%)")
      ylab <- paste0(pcy, " (", var_exp[as.numeric(sub("PC", "", pcy))], "%)")
      zlab <- paste0(pcz, " (", var_exp[as.numeric(sub("PC", "", pcz))], "%)")
      
      if (input$plot_type == "Scatter 3D") {
        p <- plot_ly(scores, x = scores[[pcx]], y = scores[[pcy]], z = scores[[pcz]],
                     type = "scatter3d", mode = "markers", marker = list(size = 2),
                     color = color_vec, colors = pal,
                     text = ~paste("Site:", Site, "<br>Date:", Date, "<br>Device:", Device, "<br>Time:", Time_fmt),
                     key = ~paste0("http://localhost:8000/", Site, "/", Device, "/", Date, "/", FileName, ".wav")) %>%
          layout(scene = list(xaxis = list(title = xlab), yaxis = list(title = ylab), zaxis = list(title = zlab)))
        
      } else if (input$plot_type == "Scatter 2D") {
        p <- plot_ly(scores, x = scores[[pcx]], y = scores[[pcy]],
                     type = "scatter", mode = "markers", marker = list(size = 2),
                     color = color_vec, colors = pal,
                     text = ~paste("Site:", Site, "<br>Date:", Date, "<br>Device:", Device, "<br>Time:", Time_fmt),
                     key = ~paste0("http://localhost:8000/", Site, "/", Device, "/", Date, "/", FileName, ".wav")) %>%
          layout(xaxis = list(title = xlab), yaxis = list(title = ylab))
        
      } else if (input$plot_type == "Diel Line 2D") {
        
        scores <- scores %>%
          mutate(
            Time_fmt   = sprintf("%06d", as.numeric(Time)),
            Time_posix = as.POSIXct(Time_fmt, format = "%H%M%S", tz = "UTC"),
            Minutes    = hour(Time_posix) * 60 + minute(Time_posix),
            Time_bin   = floor(Minutes / 30) * 30,
            Time_label = sprintf("%02d:%02d", Time_bin %/% 60, Time_bin %% 60)
          )
        
        avg_scores <- scores %>%
          group_by(Time_label, Time_bin, !!sym(colvar)) %>%
          summarise(mean_val = mean(.data[[pcy]], na.rm = TRUE), .groups = "drop")
        
        p <- plot_ly(avg_scores, x = ~Time_label, y = ~mean_val,
                     type = "scatter", mode = "lines+markers",
                     line = list(shape = "spline"), marker = list(size = 4),
                     color = avg_scores[[colvar]], colors = pal) %>%
          layout(xaxis = list(title = "Time of Day"), yaxis = list(title = ylab))
        
      } else if (input$plot_type == "Diel Line 3D") {
        
        scores <- scores %>%
          mutate(
            Time_fmt   = sprintf("%06d", as.numeric(Time)),
            Time_posix = as.POSIXct(Time_fmt, format = "%H%M%S", tz = "UTC"),
            Minutes    = hour(Time_posix) * 60 + minute(Time_posix),
            Time_bin   = floor(Minutes / 30) * 30,
            Time_label = sprintf("%02d:%02d", Time_bin %/% 60, Time_bin %% 60)
          )
        
        avg_scores <- scores %>%
          group_by(Time_bin, Time_label, !!sym(colvar)) %>%
          summarise(
            mean_y = mean(.data[[pcy]], na.rm = TRUE),
            mean_z = mean(.data[[pcz]], na.rm = TRUE),
            .groups = "drop"
          ) %>%
          arrange(Time_bin)
        
        p <- plot_ly(avg_scores, x = ~Time_label, y = ~mean_y, z = ~mean_z,
                     type = "scatter3d", mode = "lines+markers", marker = list(size = 2),
                     color = avg_scores[[colvar]], colors = pal) %>%
          layout(scene = list(
            xaxis = list(title = "Time of Day"),
            yaxis = list(title = ylab),
            zaxis = list(title = zlab)
          ))
        
      } else if (input$plot_type == "Boxplot") {
        pc_sel <- if (!is.null(input$pca_y)) input$pca_y else "PC1"
        ylab   <- paste0(pc_sel, " (", var_exp[as.numeric(sub("PC", "", pc_sel))], "%)")
        p <- plot_ly(scores, x = ~color_vec, y = scores[[pc_sel]],
                     type = "box", color = color_vec, colors = pal,
                     text = ~paste("Site:", Site, "<br>Date:", Date, "<br>Device:", Device, "<br>Time:", Time_fmt)) %>%
          layout(yaxis = list(title = ylab), xaxis = list(title = input$color_by))
      }
    }
    
    p <- p %>%
      layout(
        legend = list(
          x = 1, y = 1, xanchor = "right", yanchor = "top",
          bgcolor = 'rgba(255,255,255,0.85)', borderwidth = 0,
          font = list(size = 10), traceorder = "normal", itemsizing = "constant"
        )
      )
    
    event_register(p, "plotly_click")
  })
  
  
  # Reset PCA axis selectors when plot type changes
  observeEvent(input$plot_type, {
    if (input$plot_type == "Scatter 3D") {
      updateSelectInput(session, "pca_x", selected = "PC1")
      updateSelectInput(session, "pca_y", selected = "PC2")
      updateSelectInput(session, "pca_z", selected = "PC3")
    } else if (input$plot_type == "Scatter 2D") {
      updateSelectInput(session, "pca_x", selected = "PC1")
      updateSelectInput(session, "pca_y", selected = "PC2")
    } else if (input$plot_type == "Diel Line 2D") {
      updateSelectInput(session, "pca_y", selected = "PC1")
    } else if (input$plot_type == "Diel Line 3D") {
      updateSelectInput(session, "pca_y", selected = "PC1")
      updateSelectInput(session, "pca_z", selected = "PC2")
    }
  })
  
  observeEvent(input$run_pca,  { shinyjs::show("pca_results_panel") })
  observeEvent(input$toggle_controls,     { shinyjs::toggle(id = "controls_panel",     anim = TRUE) })
  observeEvent(input$toggle_pca_controls, { shinyjs::toggle(id = "pca_controls_panel", anim = TRUE) })
  
  observeEvent(input$open_file, {
    url <- current_audio()
    if (is.null(url)) return()
    rel_path  <- sub("^http://localhost:8000/", "", url)
    base_dir  <- "/Volumes/SSD Type II/Acoustics/CCMP Riparian Audio"
    file_path <- file.path(base_dir, rel_path)
    if (.Platform$OS.type == "windows") {
      system2("explorer", paste0('/select,"', normalizePath(file_path, winslash = "\\"), '"'))
    } else if (Sys.info()[["sysname"]] == "Darwin") {
      system2("open", c("-R", shQuote(file_path)))
    } else {
      system2("xdg-open", dirname(file_path))
    }
  })
  
  output$main_plot <- renderPlotly(plot_results())
  
  output$pca_summary <- renderPrint({
    inds <- input$selected_indices
    if (length(inds) > 3) {
      df_for_pca <- full_pca_data()$scores
      pca <- prcomp(df_for_pca %>% select(all_of(inds)), center = TRUE, scale. = TRUE)
      cat("PCA Summary:\n")
      print(summary(pca)$importance)
      cat("\nPCA Loadings (all PCs):\n")
      print(round(pca$rotation, 3))
    } else {
      cat("PCA Summary available only when >3 indices selected.")
    }
  })
  
  output$download_pca <- downloadHandler(
    filename = function() paste0("PCA_export_", Sys.Date(), ".csv"),
    content = function(file) {
      data <- full_pca_data()$scores
      inds <- input$selected_indices
      if (length(inds) <= 3) {
        showNotification("PCA export only available when >3 indices selected", type = "error")
        return(NULL)
      }
      pca    <- prcomp(data %>% select(all_of(inds)), center = TRUE, scale. = TRUE)
      scores <- as.data.frame(pca$x)
      pca_export <- cbind(
        data %>% select(file_id, Site, Device, Date, Time,
                        Strahler, QBR_Score, QBR_Class,
                        Strahler_Class, Deployment_Season,
                        Branch, Year, Month, FileName),
        scores
      )
      write.csv(pca_export, file, row.names = FALSE)
    }
  )
  
  
  # ── Click → Audio Functionality ───────────────────────────────────────────
  observe({
    click <- event_data("plotly_click")
    if (!is.null(click)) {
      
      data_clicked <- NULL
      url <- NULL
      
      # --- Scatter / 3D / PCA scatter plots (have key) ---
      if (!is.null(click$key)) {
        url <- click$key
        current_audio(url)
        
        parts    <- strsplit(url, "/")[[1]]
        site     <- parts[4]; device <- parts[5]; date <- parts[6]
        time_str <- substr(gsub(".wav", "", basename(parts[7])), 10, 15)
        info_html <- paste0("<div><strong>Site:</strong> ", site,
                            " | <strong>Device:</strong> ", device, "</div>",
                            "<div><strong>Date:</strong> ", date,
                            " | <strong>Time:</strong> ", time_str, "</div>")
        session$sendCustomMessage("update_now_playing", list(info = info_html))
        updateAudio(session, url)
        
      } else {
        n_inds <- length(input$selected_indices)
        
        if (n_inds <= 3) {
          # ── Boxplot: single-index ──────────────────────────────────────
          index_name  <- input$selected_indices[1]
          site_clicked <- click$x
          y_clicked    <- click$y
          site_data    <- filtered_data() %>% filter(Site == site_clicked)
          closest_row  <- site_data[which.min(abs(site_data[[index_name]] - y_clicked)), ]
          data_clicked <- closest_row
          
        } else {
          # ── Diel Line plots ───────────────────────────────────────────
          scores <- plotting_data()
          
          if (!is.null(scores) && input$plot_type %in% c("Diel Line 2D", "Diel Line 3D")) {
            
            pcy <- if (!is.null(input$pca_y)) input$pca_y else "PC1"
            pcz <- if (!is.null(input$pca_z)) input$pca_z else "PC2"
            
            # ── Step 1: Compute time bins on the raw (individual) scores ──
            scores <- scores %>%
              mutate(
                Time_fmt   = sprintf("%06d", as.numeric(Time)),
                Time_posix = as.POSIXct(Time_fmt, format = "%H%M%S", tz = "UTC"),
                Minutes    = hour(Time_posix) * 60 + minute(Time_posix),
                Time_bin   = floor(Minutes / 30) * 30,
                Time_label = sprintf("%02d:%02d", Time_bin %/% 60, Time_bin %% 60)
              )
            
            # ── Step 2: Identify which colour group was clicked ────────────
            colvar       <- input$color_by
            curve_number <- click$curveNumber  # 0-indexed
            
            # When plot_ly receives color as a plain vector with a named colors palette,
            # it assigns curveNumber by sorting the unique group names alphabetically.
            # So we sort the unique values present in avg_scores to match plotly's trace order.
            avg_scores_for_order <- scores %>%
              group_by(Time_label, Time_bin, !!sym(colvar)) %>%
              summarise(.groups = "drop") %>%
              arrange(Time_bin)
            
            
            # Sort alphabetically — this matches plotly's internal trace ordering
            # when color is passed as a plain vector with a named palette.
            # Exception: Season is always assigned before scoring so values are present.
            rendered_groups <- unique(as.character(avg_scores_for_order[[colvar]]))
            
            clicked_group <- if (!is.null(curve_number) && curve_number + 1 <= length(rendered_groups)) {
              rendered_groups[curve_number + 1]
            } else {
              NULL
            }
            
            # ── Step 3: Identify the clicked 30-min bin from click$x ──────
            # For 2D diel: click$x is Time_label string e.g. "06:30"
            # For 3D diel: click$x is also Time_label on the x-axis
            clicked_time_label <- as.character(click$x)
            
            # ── Step 4: Filter candidates ─────────────────────────────────
            # First filter by time bin
            candidates <- scores %>%
              filter(Time_label == clicked_time_label)
            
            # Then filter by colour group — fall back to full time-bin pool if group yields 0 rows
            if (!is.null(clicked_group) && colvar %in% colnames(candidates)) {
              group_candidates <- candidates %>% filter(.data[[colvar]] == clicked_group)
              if (nrow(group_candidates) > 0) candidates <- group_candidates
              # else: keep all rows in that time bin as fallback
            }
            
            # ── Step 5: Find closest individual point by PC values ────────
            if (nrow(candidates) > 0) {
              if (input$plot_type == "Diel Line 2D") {
                y_clicked  <- as.numeric(click$y)
                candidates <- candidates %>%
                  mutate(.dist = abs(.data[[pcy]] - y_clicked))
                
              } else {
                # 3D diel: click$y and click$z hold the PC axis values
                # Note: plotly scatter3d click returns x/y/z matching the axes as set
                y_clicked <- as.numeric(click$y)
                z_clicked <- as.numeric(click$z)
                
                if (!is.null(y_clicked) && !is.null(z_clicked) &&
                    !is.na(y_clicked)   && !is.na(z_clicked)) {
                  candidates <- candidates %>%
                    mutate(.dist = (.data[[pcy]] - y_clicked)^2 + (.data[[pcz]] - z_clicked)^2)
                } else {
                  # z not available — fall back to y-only distance
                  candidates <- candidates %>%
                    mutate(.dist = abs(.data[[pcy]] - y_clicked))
                }
              }
              data_clicked <- candidates[which.min(candidates$.dist), ]
            }
          }
        }
        
        # ── Construct URL and send to audio player ─────────────────────
        if (!is.null(data_clicked) && nrow(data_clicked) > 0) {
          url <- paste0("http://localhost:8000/",
                        data_clicked$Site, "/",
                        data_clicked$Device, "/",
                        data_clicked$Date, "/",
                        data_clicked$Date, "_",
                        sprintf("%06d", as.numeric(data_clicked$Time)), ".wav")
          current_audio(url)
          
          info_html <- paste0("<div><strong>Site:</strong> ", data_clicked$Site,
                              " | <strong>Device:</strong> ", data_clicked$Device, "</div>",
                              "<div><strong>Date:</strong> ", data_clicked$Date,
                              " | <strong>Time:</strong> ", sprintf("%06d", as.numeric(data_clicked$Time)), "</div>")
          session$sendCustomMessage("update_now_playing", list(info = info_html))
          updateAudio(session, url)
        }
      }
    }
  })
  
  
  # Wavesurfer Integration
  shinyjs::runjs("
       $(document).ready(function() {
  var wavesurfer = WaveSurfer.create({
    container: '#waveform',
    waveColor: 'violet',
    progressColor: 'purple',
    cursorColor: 'black',
    height: 100,
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

  var spectrogramPlugin = wavesurfer.getActivePlugins()[0];
  var isPlaying = false;
      
      $('#play_pause').click(function() {
        isPlaying ? wavesurfer.pause() : wavesurfer.play(); 
        isPlaying = !isPlaying; 
      });
      
      Shiny.addCustomMessageHandler('update_audio', function(msg) {
        wavesurfer.load(msg.src);
        wavesurfer.on('ready', function() { wavesurfer.play(); isPlaying = true; });
      });
      
      Shiny.addCustomMessageHandler('update_now_playing', function(msg) {
        $('#now_playing_text').html('Currently Playing: ' + msg.info);
        $('#buttons_container').removeClass('hidden');
      });
    });
  ")
  
  updateAudio <- function(session, src) session$sendCustomMessage("update_audio", list(src = src))
}
