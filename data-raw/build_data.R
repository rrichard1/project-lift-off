# Rebuild the app tables in inst/extdata/ from source files.
#
# Run from the project root:
#   source("data-raw/build_data.R")
#
# Inputs
#   data-raw/source/tfrrs_lists/*.csv     TFRRS performance-list exports
#                                          (one file per list or per batch)
#   data-raw/source/tfrrs_team_registry.csv
#   data-raw/manual/school_name_crosswalk.csv   human-edited
#   data-raw/manual/verification_ledger.csv     human-edited, append-only
#
# Outputs (inst/extdata/)
#   programs.csv         one row per program
#   event_lists.csv      one row per event x season x division list
#   athlete_marks.csv    one row per athlete x list (season best)
#   program_events.csv   one row per program x list, with coverage_state
#   build_info.yml       what was built, from what, and when
#   build_report.md      counts and coverage for review

pkgload::load_all(export_all = TRUE, helpers = FALSE, quiet = TRUE)

src <- "data-raw/source"
man <- "data-raw/manual"
out <- "inst/extdata"
dir.create(out, showWarnings = FALSE, recursive = TRUE)

list_files <- list.files(file.path(src, "tfrrs_lists"), pattern = "\\.csv$", full.names = TRUE)
if (length(list_files) == 0) cli::cli_abort("No list exports in {.path {file.path(src, 'tfrrs_lists')}}.")

raw_lists <- list_files |>
  purrr::map(\(f) readr::read_csv(f, col_types = readr::cols(.default = readr::col_character()), progress = FALSE)) |>
  purrr::list_rbind()

registry <- readr::read_csv(file.path(src, "tfrrs_team_registry.csv"), col_types = readr::cols(.default = readr::col_character()), progress = FALSE)
crosswalk <- readr::read_csv(file.path(man, "school_name_crosswalk.csv"), col_types = readr::cols(.default = readr::col_character()), progress = FALSE)
ledger <- readr::read_csv(file.path(man, "verification_ledger.csv"), col_types = readr::cols(.default = readr::col_character()), progress = FALSE)

tables <- build_app_tables(raw_lists, registry, crosswalk, ledger)

purrr::iwalk(tables, \(tbl, name) readr::write_csv(tbl, file.path(out, paste0(name, ".csv")), na = ""))

# --- Build info --------------------------------------------------------------
lists <- tables$event_lists
build_info <- list(
  built_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
  source_files = basename(list_files),
  lists = purrr::pmap(lists, \(list_id, list_size, floor_mark_m, latest_meet_date, parsed_at, source_url, ...) list(
    list_id = list_id,
    size = list_size,
    floor_m = floor_mark_m,
    latest_meet_date = as.character(latest_meet_date),
    parsed_at = parsed_at,
    source_url = source_url
  )),
  row_counts = purrr::map(tables, nrow)
)
yaml::write_yaml(build_info, file.path(out, "build_info.yml"))

# --- Build report ------------------------------------------------------------
pe <- tables$program_events
coverage <- pe |>
  dplyr::count(.data$list_id, .data$coverage_state) |>
  tidyr::pivot_wider(names_from = "coverage_state", values_from = "n", values_fill = 0)

wind <- tables$athlete_marks |>
  dplyr::count(.data$event_code, .data$wind_status) |>
  tidyr::pivot_wider(names_from = "wind_status", values_from = "n", values_fill = 0)

md_table <- function(df) {
  df <- dplyr::mutate(df, dplyr::across(dplyr::everything(), as.character))
  c(
    paste0("| ", paste(names(df), collapse = " | "), " |"),
    paste0("|", paste(rep("---", ncol(df)), collapse = "|"), "|"),
    apply(df, 1, \(r) paste0("| ", paste(r, collapse = " | "), " |"))
  )
}

report <- c(
  "# Build report",
  "",
  paste0("Built ", build_info$built_at, " from ", paste(build_info$source_files, collapse = ", "), "."),
  "",
  "## Lists",
  md_table(lists |> dplyr::select("list_id", "list_size", "program_count", "floor_mark_m", "top_mark_m", "latest_meet_date")),
  "",
  "## Coverage by list (program x event rows)",
  md_table(coverage),
  "",
  "## Wind status of marks",
  md_table(wind),
  "",
  "## Programs",
  paste0(nrow(tables$programs), " programs; ", sum(is.na(tables$programs$conference)), " without a conference mapping (Phase 2)."),
  ""
)
writeLines(report, file.path(out, "build_report.md"))

cli::cli_alert_success("Built {nrow(tables$programs)} programs, {nrow(lists)} lists, {nrow(tables$athlete_marks)} marks, {nrow(pe)} program x list rows.")
