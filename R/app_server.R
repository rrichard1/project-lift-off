#' The application server-side
#'
#' @param input,output,session Internal parameters for `{shiny}`.
#' @noRd
app_server <- function(input, output, session) {
  settings <- list(
    reach_threshold_m = get_golem_config("reach_threshold_m")
  )

  app_data <- app_data_cached()
  athlete <- read_athlete_profile()

  mod_program_fit_server(
    "fit",
    app_data = app_data,
    athlete = athlete,
    settings = settings
  )

  # Coach contacts and the outreach log are read fresh for each session, so
  # edits to the local files show up on the next page load.
  private <- load_private_data(
    known_ids = union(app_data$board$program_id, app_data$programs$program_id)
  )

  mod_board_server(
    "board",
    app_data = app_data,
    athlete = athlete,
    settings = settings,
    private = private
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
