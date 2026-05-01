# modules/mod_project.R
# Handles project selection, creation, and config read/write.
# Returns: active_config() — a reactive list of the loaded config.

library(jsonlite)

PROJECTS_ROOT <- file.path(getwd(), "SoundscapeR_projects")

projectUI <- function(id) {
  ns <- NS(id)
  tagList(
    div(
      style = "font-size: 11px; font-weight: 500; color: #888; 
               letter-spacing: 0.04em; margin-bottom: 6px;",
      "SoundscapeR Projects"
    ),
    
    # Project selector
    selectInput(
      ns("selected_project"),
      label    = NULL,
      choices  = get_project_list(),
      selected = NULL,
      width    = "100%"
    ),
    
    # Open project button
    actionButton(
      ns("open_project"),
      "Open project",
      width = "100%",
      class = "btn-sm btn-primary",
      style = "margin-bottom: 6px;"
    ),
    
    hr(style = "margin: 8px 0;"),
    
    # New project creation
    div(
      style = "font-size: 11px; font-weight: 500; color: #888;
               letter-spacing: 0.04em; margin-bottom: 4px;",
      "Create new project"
    ),
    textInput(
      ns("new_project_name"),
      label       = NULL,
      placeholder = "Enter project name…",
      width       = "100%"
    ),
    
    # Create button — only appears when text is entered
    conditionalPanel(
      condition = paste0(
        "input['", ns("new_project_name"), "'] != ''"
      ),
      actionButton(
        ns("create_project"),
        "Create project",
        width = "100%",
        class = "btn-sm",
        style = "margin-bottom: 6px;"
      )
    ),
    
    # Status message
    uiOutput(ns("project_status"))
  )
}


projectServer <- function(id) {
  moduleServer(id, function(input, output, session) {
    
    # Reactive config — this is what the rest of the app reads
    active_config <- reactiveVal(NULL)
    
    # ── Helpers ────────────────────────────────────────────────────────────
    
    refresh_project_list <- function() {
      updateSelectInput(
        session,
        "selected_project",
        choices = get_project_list()
      )
    }
    
    show_status <- function(msg, type = "info") {
      colour <- switch(type,
                       success = "#2a9d5c",
                       error   = "#c0392b",
                       "#555"
      )
      output$project_status <- renderUI({
        div(msg, style = paste0(
          "font-size: 11px; color: ", colour, "; margin-top: 4px;"
        ))
      })
    }
    
    # ── Create project ──────────────────────────────────────────────────────
    observeEvent(input$create_project, {
      req(input$new_project_name)
      
      name     <- trimws(input$new_project_name)
      proj_dir <- file.path(PROJECTS_ROOT, name)
      
      if (dir.exists(proj_dir)) {
        show_status("A project with that name already exists.", "error")
        return()
      }
      
      # Create folder structure
      dir.create(proj_dir, recursive = TRUE)
      dir.create(file.path(proj_dir, "raw_data"))
      dir.create(file.path(proj_dir, "figures"))
      dir.create(file.path(proj_dir, "outputs"))
      
      # Write blank config
      config <- list(
        project_name     = name,
        csv_path         = "",
        index_columns    = list(),
        metadata_columns = list(),
        filename_column  = "",
        audio_root       = "",
        audio_path_mode  = "folder_structure",
        folder_structure = "{Site}/{Device}/{Date}",
        palettes         = list()
      )
      write_config(proj_dir, config)
      
      # Update UI
      refresh_project_list()
      updateSelectInput(session, "selected_project", selected = name)
      updateTextInput(session, "new_project_name", value = "")
      show_status(paste0("'", name, "' created. Add your CSV to raw_data/ then open."), "success")
    })
    
    # ── Open project ────────────────────────────────────────────────────────
    observeEvent(input$open_project, {
      req(input$selected_project)
      
      proj_dir    <- file.path(PROJECTS_ROOT, input$selected_project)
      config_path <- file.path(proj_dir, "config.json")
      
      if (!file.exists(config_path)) {
        show_status("No config found. Is this a valid project folder?", "error")
        return()
      }
      
      config <- read_config(proj_dir)
      
      # Find CSV in raw_data/ if not already set
      if (config$csv_path == "") {
        csvs <- list.files(
          file.path(proj_dir, "raw_data"),
          pattern    = "\\.csv$",
          full.names = TRUE
        )
        if (length(csvs) == 1) {
          config$csv_path <- csvs[1]
        } else if (length(csvs) > 1) {
          show_status("Multiple CSVs in raw_data/ — specify one in config.", "error")
          return()
        } else {
          show_status("No CSV found in raw_data/. Add one and try again.", "error")
          return()
        }
      }
      
      active_config(config)
      show_status(paste0("'", config$project_name, "' loaded."), "success")
    })
    
    # ── Return the reactive config ──────────────────────────────────────────
    return(active_config)
  })
}


# ── Standalone helpers (used by both modules) ───────────────────────────────

get_project_list <- function() {
  if (!dir.exists(PROJECTS_ROOT)) {
    dir.create(PROJECTS_ROOT, recursive = TRUE)
    return(character(0))
  }
  dirs <- list.dirs(PROJECTS_ROOT, full.names = FALSE, recursive = FALSE)
  dirs[dirs != ""]
}

read_config <- function(proj_dir) {
  path <- file.path(proj_dir, "config.json")
  jsonlite::read_json(path, simplifyVector = TRUE)
}

write_config <- function(proj_dir, config) {
  path <- file.path(proj_dir, "config.json")
  jsonlite::write_json(config, path, pretty = TRUE, auto_unbox = TRUE)
}