#' The application server-side
#'
#' @param input,output,session Internal parameters for `{shiny}`.
#' @noRd
app_server <- function(input, output, session) {
  settings <- list(
    reach_threshold_m = get_golem_config("reach_threshold_m")
  )

  mod_program_fit_server(
    "fit",
    app_data = app_data_cached(),
    athlete = read_athlete_profile(),
    settings = settings
  )
}

# App tables are read once per R process and shared across sessions.
.liftoff_cache <- new.env(parent = emptyenv())

#' @noRd
app_data_cached <- function() {
  if (is.null(.liftoff_cache$app_data)) {
    .liftoff_cache$app_data <- load_app_data()
  }
  .liftoff_cache$app_data
}
