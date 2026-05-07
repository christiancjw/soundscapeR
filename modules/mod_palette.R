# modules/mod_palette.R

PALETTE_PRESETS <- list(
  NPG = c(
    "#4DBBD5", "#E64B35", "#00A087", "#3C5488",
    "#F39B7F", "#8491B4", "#91D1C2", "#DC0000",
    "#7E6148", "#B09C85"
  ),
  OkabeIto = c(
    "#E69F00", "#56B4E9", "#009E73", "#F0E442",
    "#0072B2", "#D55E00", "#CC79A7", "#000000"
  ),
  Dark2 = c(
    "#1B9E77", "#D95F02", "#7570B3", "#E7298A",
    "#66A61E", "#E6AB02", "#A6761D", "#666666"
  ),
  Viridis = c(
    "#440154", "#414487", "#2A788E", "#22A884",
    "#7AD151", "#FDE725", "#BD3786", "#31688E"
  ),
  Tableau10 = c(
    "#4E79A7", "#F28E2B", "#E15759", "#76B7B2",
    "#59A14F", "#EDC948", "#B07AA1", "#FF9DA7",
    "#9C755F", "#BAB0AC"
  )
)

sid <- function(...) gsub("[^a-zA-Z0-9]", "_", paste0(...))

paletteUI <- function(id) {
  ns <- NS(id)
  uiOutput(ns("palette_card"))
}

paletteServer <- function(id, active_config, app_data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    
    reactive_palettes <- reactiveVal(list())
    saved_custom      <- reactiveVal(list())
    selected_col      <- reactiveVal(NULL)
    saved_order       <- reactiveVal(list())
    
    # ── Load from config ─────────────────────────────────────────────────────
    observeEvent(active_config(), {
      cfg <- active_config()
      req(cfg)
      saved <- cfg$palettes
      if (is.null(saved) || length(saved) == 0) {
        reactive_palettes(list())
        saved_custom(list())
        saved_order(list())
        return()
      }
      parsed  <- list()
      customs <- list()
      orders  <- list()
      for (col in names(saved)) {
        p <- saved[[col]]
        if (isTRUE(p$active) && length(p$colours) > 0)
          parsed[[col]] <- unlist(p$colours)
        if (length(p$custom_colours) > 0)
          customs[[col]] <- unlist(p$custom_colours)
        if (length(p$level_order) > 0)
          orders[[col]] <- unlist(p$level_order)
      }
      reactive_palettes(parsed)
      saved_custom(customs)
      saved_order(orders)
    })
    
    # ── Set first col on data load ───────────────────────────────────────────
    observeEvent(app_data(), {
      ad <- app_data()
      req(ad)
      fcols <- ad$meta_cols[!ad$meta_cols %in% c(ad$date_col, ad$time_col)]
      if (length(fcols) > 0) selected_col(fcols[1])
    })
    
    # ── Outer card ───────────────────────────────────────────────────────────
    output$palette_card <- renderUI({
      cfg <- active_config()
      if (is.null(cfg)) return(NULL)
      
      ad <- app_data()
      if (is.null(ad)) return(
        div(class = "setup-card",
            div(class = "setup-card-title", "Step 4 — Colour palettes"),
            div(style = "font-size:11px; color:#aaa;",
                "Click Apply in Step 3 to load palette options.")
        )
      )
      
      fcols <- ad$meta_cols[!ad$meta_cols %in% c(ad$date_col, ad$time_col)]
      if (length(fcols) == 0) return(
        div(class = "setup-card",
            div(class = "setup-card-title", "Step 4 — Colour palettes"),
            div(style = "font-size:11px; color:#aaa;", "No metadata columns.")
        )
      )
      
      pals <- reactive_palettes()
      
      div(class = "setup-card",
          div(class = "setup-card-title", "Step 4 — Colour palettes"),
          div(style = "font-size:11px; color:#888; margin-bottom:10px;",
              "Assign a custom palette per metadata column. ",
              "Columns without a custom palette use NPG by default."
          ),
          div(style = "display:flex; gap:4px; flex-wrap:wrap; margin-bottom:12px;",
              lapply(fcols, function(col) {
                is_active <- !is.null(pals[[col]])
                is_sel    <- identical(selected_col(), col)
                tags$button(
                  style = paste0(
                    "font-size:10px; padding:3px 10px; border-radius:4px; ",
                    "border:0.5px solid ",
                    if (is_sel) "#1a56db" else "#d0d0cc", "; ",
                    "background:", if (is_sel) "#e8f0fe" else "white", "; ",
                    "color:", if (is_sel) "#1a56db" else "#666", "; ",
                    "cursor:pointer; display:flex; align-items:center; gap:5px;"
                  ),
                  onclick = paste0(
                    "Shiny.setInputValue('", ns("selected_col"), "','",
                    col, "',{priority:'event'})"
                  ),
                  tags$span(style = paste0(
                    "width:7px; height:7px; border-radius:50%; flex-shrink:0; ",
                    "background:", if (is_active) "#00A087" else "#e0e0dc", ";"
                  )),
                  col
                )
              })
          ),
          uiOutput(ns("col_editor"))
      )
    })
    outputOptions(output, "palette_card", suspendWhenHidden = FALSE)
    
    observeEvent(input$selected_col, selected_col(input$selected_col))
    
    # ── Column editor ────────────────────────────────────────────────────────
    output$col_editor <- renderUI({
      ad  <- app_data()
      cfg <- active_config()
      req(ad, cfg)
      
      col <- selected_col()
      req(col, col %in% colnames(ad$df))
      
      all_levels <- sort(unique(as.character(ad$df[[col]])))
      orders     <- saved_order()
      pals       <- reactive_palettes()
      customs    <- saved_custom()
      is_active  <- !is.null(pals[[col]])
      
      # Apply saved level order — keep only existing levels, append new ones
      levels_vec <- if (!is.null(orders[[col]]) && length(orders[[col]]) > 0) {
        saved_lvs <- orders[[col]]
        c(saved_lvs[saved_lvs %in% all_levels],
          setdiff(all_levels, saved_lvs))
      } else {
        all_levels
      }
      
      current_cols <- if (is_active) pals[[col]] else
        setNames(rep_len(PALETTE_PRESETS$NPG, length(levels_vec)), levels_vec)
      
      ns_str       <- ns("")
      preset_names <- c(names(PALETTE_PRESETS), "Custom")
      list_id      <- paste0("pal_list_", sid(col))
      
      tagList(
        
        # Status badge
        div(style = "display:flex; align-items:center; gap:8px; margin-bottom:10px;",
            div(style = paste0(
              "font-size:10px; padding:2px 8px; border-radius:10px; ",
              "background:", if (is_active) "#e6f4ee" else "#f0f0ec", "; ",
              "color:", if (is_active) "#0F6E56" else "#888", "; ",
              "border:0.5px solid ",
              if (is_active) "#9FE1CB" else "#d0d0cc", ";"
            ), if (is_active) "Custom palette active" else "Using default NPG"),
            if (is_active) tags$button("Deactivate",
                                       style = "font-size:10px; padding:2px 8px; border-radius:4px;
                     border:0.5px solid #d0d0cc; background:white;
                     color:#c0392b; cursor:pointer;",
                                       onclick = paste0(
                                         "Shiny.setInputValue('", ns("deactivate_col"), "','",
                                         col, "',{priority:'event'})"
                                       )
            )
        ),
        
        # Preset buttons
        div(style = "margin-bottom:10px;",
            div(style = "font-size:11px; color:#888; margin-bottom:5px;",
                "1. Choose a preset to start from"),
            div(style = "display:flex; gap:5px; flex-wrap:wrap;",
                lapply(preset_names, function(pname) {
                  is_custom <- pname == "Custom"
                  
                  dot_cols <- if (!is_custom) {
                    pc <- PALETTE_PRESETS[[pname]]
                    pc[1:min(5, length(pc))]
                  } else {
                    cc <- customs[[col]]
                    if (!is.null(cc) && length(cc) > 0) cc[1:min(5, length(cc))]
                    else rep("#cccccc", 5)
                  }
                  dots <- lapply(dot_cols, function(hx)
                    div(style = paste0("width:10px; height:10px; ",
                                       "border-radius:2px; background:", hx, ";")))
                  
                  btn_onclick <- if (!is_custom) {
                    cols_json <- jsonlite::toJSON(
                      as.list(setNames(
                        rep_len(PALETTE_PRESETS[[pname]], length(levels_vec)),
                        levels_vec
                      )),
                      auto_unbox = TRUE
                    )
                    paste0(
                      "PAL.applyPreset(",
                      "'", ns("apply_preset"), "',",
                      "'", ns_str, "',",
                      "'", col, "',",
                      "'", pname, "',",
                      cols_json,
                      ")"
                    )
                  } else {
                    cust_json <- jsonlite::toJSON(
                      if (!is.null(customs[[col]]) && length(customs[[col]]) > 0)
                        as.list(customs[[col]])
                      else list(),
                      auto_unbox = TRUE
                    )
                    paste0(
                      "PAL.loadCustom(",
                      "'", ns("load_custom"), "',",
                      "'", ns_str, "',",
                      "'", col, "',",
                      cust_json,
                      ")"
                    )
                  }
                  
                  tags$button(
                    id    = paste0("pal_pbtn_", sid(col), "_", sid(pname)),
                    style = "display:flex; flex-direction:column; gap:3px;
                         padding:5px 8px; border-radius:5px; cursor:pointer;
                         align-items:center; border:0.5px solid #d0d0cc;
                         background:white;",
                    onclick = btn_onclick,
                    div(style = "display:flex; gap:2px;", dots),
                    span(style = "font-size:9px; color:#666;", pname)
                  )
                })
            )
        ),
        
        # Draggable level rows
        div(style = "margin-bottom:10px;",
            div(style = "display:flex; justify-content:space-between;
                       align-items:center; margin-bottom:5px;",
                span(style = "font-size:11px; color:#888;",
                     "2. Recolour and reorder levels"),
                span(style = "font-size:10px; color:#bbb; font-style:italic;",
                     "drag rows to reorder")
            ),
            div(
              id    = list_id,
              style = "background:#f7f7f5; border:0.5px solid #e0e0dc;
                     border-radius:6px; padding:6px 10px;
                     max-height:280px; overflow-y:auto;",
              lapply(levels_vec, function(lv) {
                el_id   <- paste0(ns_str, "col_", sid(col), "_lv_", sid(lv))
                cur_col <- if (!is.null(current_cols[[lv]]) &&
                               !is.na(current_cols[[lv]]))
                  current_cols[[lv]] else "#4DBBD5"
                
                div(
                  `data-level` = lv,
                  draggable    = "true",
                  style = "display:flex; align-items:center; gap:8px;
                         padding:5px 0; border-bottom:0.5px solid #e0e0dc;
                         cursor:grab; user-select:none; background:transparent;
                         transition: opacity 0.15s;",
                  ondragstart = paste0("PAL.dragStart(event,'", list_id, "')"),
                  ondragover  = "PAL.dragOver(event)",
                  ondrop      = paste0("PAL.drop(event,'", list_id, "')"),
                  ondragend   = "PAL.dragEnd(event)",
                  
                  # Drag handle (two vertical dots)
                  span(
                    style = "color:#ccc; font-size:13px; flex-shrink:0;
                           line-height:1; letter-spacing:-2px;",
                    HTML("&#8942;&#8942;")
                  ),
                  
                  # Colour picker
                  tags$input(
                    type    = "color",
                    id      = el_id,
                    value   = cur_col,
                    style   = "width:24px; height:24px; border:none; padding:0;
                             cursor:pointer; border-radius:3px; flex-shrink:0;
                             background:none;",
                    oninput = paste0(
                      "PAL.colourChanged('", ns_str, "','", col, "','", lv,
                      "',this.value)"
                    )
                  ),
                  
                  # Level name
                  span(style = "font-size:11px; color:#333; flex:1;", lv),
                  
                  # Hex display
                  span(
                    id    = paste0(el_id, "_hex"),
                    style = "font-size:10px; color:#aaa; font-family:monospace;",
                    cur_col
                  )
                )
              })
            )
        ),
        
        # Save
        div(style = "display:flex; gap:8px; align-items:center;",
            tags$button("3. Save palette",
                        style = "font-size:11px; padding:5px 16px; background:#1a56db;
                     color:white; border:none; border-radius:5px; cursor:pointer;",
                        onclick = paste0(
                          "PAL.save(",
                          "'", ns("save_palette"), "',",
                          "'", ns_str, "',",
                          "'", col, "',",
                          "'", list_id, "'",
                          ")"
                        )
            ),
            uiOutput(ns("save_status"))
        )
      )
    })
    outputOptions(output, "col_editor", suspendWhenHidden = FALSE)
    
    # ── Observers ────────────────────────────────────────────────────────────
    observeEvent(input$apply_preset,       {})
    observeEvent(input$load_custom,        {})
    observeEvent(input$switched_to_custom, {})
    
    observeEvent(input$deactivate_col, {
      col  <- input$deactivate_col
      pals <- reactive_palettes()
      pals[[col]] <- NULL
      reactive_palettes(pals)
      save_palettes_to_config(pals, saved_custom(), saved_order(),
                              active_config())
      output$save_status <- renderUI(
        div(style = "font-size:10px; color:#888;",
            paste0(col, " reset to default NPG."))
      )
    })
    
    observeEvent(input$save_palette, {
      req(input$save_palette)
      col         <- input$save_palette$col
      colours     <- unlist(input$save_palette$colours)
      level_order <- unlist(input$save_palette$level_order)
      is_custom   <- isTRUE(input$save_palette$is_custom)
      req(col, length(colours) > 0)
      
      pals        <- reactive_palettes()
      pals[[col]] <- colours
      reactive_palettes(pals)
      
      customs <- saved_custom()
      if (is_custom) {
        customs[[col]] <- colours
        saved_custom(customs)
      }
      
      orders        <- saved_order()
      orders[[col]] <- level_order
      saved_order(orders)
      
      save_palettes_to_config(pals, customs, orders, active_config())
      
      output$save_status <- renderUI(
        div(style = "font-size:10px; color:#00A087;",
            paste0("Saved — ", length(colours), " levels."))
      )
    })
    
    # ── Write to config ──────────────────────────────────────────────────────
    save_palettes_to_config <- function(pals, customs, orders, cfg) {
      req(cfg)
      proj_dir <- file.path(PROJECTS_ROOT, cfg$project_name)
      all_cols <- unique(c(names(pals), names(customs), names(orders)))
      pal_list <- setNames(lapply(all_cols, function(col) {
        list(
          active         = !is.null(pals[[col]]),
          colours        = if (!is.null(pals[[col]]))
            as.list(pals[[col]]) else list(),
          custom_colours = if (!is.null(customs[[col]]))
            as.list(customs[[col]]) else list(),
          level_order    = if (!is.null(orders[[col]]))
            as.list(orders[[col]]) else list()
        )
      }), all_cols)
      cfg_current          <- read_config(proj_dir)
      cfg_current$palettes <- pal_list
      write_config(proj_dir, cfg_current)
    }
    
    return(reactive_palettes)
  })
}