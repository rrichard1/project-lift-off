# Read the built app tables from inst/extdata/.
# Column types are explicit so a schema drift fails loudly at load time.

#' Load the app tables
#'
#' @param dir Folder holding the built CSVs. Defaults to the installed
#'   package's `extdata`.
#' @return Named list: `programs`, `event_lists`, `athlete_marks`,
#'   `program_events`, `build_info`.
#' @export
load_app_data <- function(dir = app_sys("extdata")) {
  if (!nzchar(dir) || !dir.exists(dir)) {
    cli::cli_abort("App data folder not found. Run {.code source(\"data-raw/build_data.R\")} first.")
  }

  read <- function(file, col_types) {
    readr::read_csv(file.path(dir, file), col_types = col_types, progress = FALSE)
  }

  list(
    programs = read("programs.csv", readr::cols(.default = readr::col_character())),
    event_lists = read("event_lists.csv", readr::cols(
      season = readr::col_integer(),
      list_size = readr::col_integer(),
      program_count = readr::col_integer(),
      floor_mark_m = readr::col_double(),
      top_mark_m = readr::col_double(),
      latest_meet_date = readr::col_date(),
      .default = readr::col_character()
    )),
    athlete_marks = read("athlete_marks.csv", readr::cols(
      season = readr::col_integer(),
      eligibility_year = readr::col_integer(),
      mark_m = readr::col_double(),
      wind_mps = readr::col_double(),
      meet_date = readr::col_date(),
      list_place = readr::col_integer(),
      .default = readr::col_character()
    )),
    program_events = read("program_events.csv", readr::cols(
      season = readr::col_integer(),
      listed_count = readr::col_integer(),
      top_mark_m = readr::col_double(),
      fr = readr::col_integer(),
      so = readr::col_integer(),
      jr = readr::col_integer(),
      sr = readr::col_integer(),
      .default = readr::col_character()
    )),
    build_info = yaml::read_yaml(file.path(dir, "build_info.yml"))
  )
}
