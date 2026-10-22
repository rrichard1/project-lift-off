# Pure functions that turn source files into the app's tables.
# data-raw/build_data.R reads the files and calls build_app_tables().
# Grain of every output table is stated where it is built and in SPEC section 5.

# ---------------------------------------------------------------------------
# Small vocabularies
# ---------------------------------------------------------------------------

#' Map a TFRRS division label to D1 / D2
#' @noRd
division_code <- function(x) {
  x <- stringr::str_squish(toupper(x))
  dplyr::case_when(
    x %in% c("NCAA DI", "NCAA D1", "DI", "D1") ~ "D1",
    x %in% c("NCAA DII", "NCAA D2", "DII", "D2") ~ "D2",
    .default = NA_character_
  )
}

#' Classify wind legality for a mark
#'
#' High jump has no wind reading. For horizontal jumps, a missing reading is
#' `unknown`, never assumed legal.
#' @noRd
wind_status <- function(event_code, wind_mps, legal_limit = 2.0) {
  dplyr::case_when(
    event_code == "HJ" ~ "not_applicable",
    is.na(wind_mps) ~ "unknown",
    wind_mps > legal_limit ~ "aided",
    .default = "legal"
  )
}

#' Class group from a TFRRS class code ("SO-2" -> "so")
#' @noRd
class_group <- function(class_code) {
  out <- tolower(substr(stringr::str_squish(class_code), 1, 2))
  dplyr::if_else(out %in% c("fr", "so", "jr", "sr"), out, NA_character_)
}

#' Normalise a school name into a join key
#'
#' Used only to match list names to the registry. Never used as a key in
#' app tables; that is `program_id`.
#' @noRd
name_key <- function(x) {
  x |>
    tolower() |>
    stringr::str_replace_all("[^a-z0-9&]+", " ") |>
    stringr::str_squish()
}

#' Extract the TFRRS team slug from a team URL
#'
#' `https://www.tfrrs.org/teams/tf/GA_college_m_Georgia.html` ->
#' `GA_college_m_Georgia`.
#' @noRd
program_id_from_url <- function(url) {
  stringr::str_match(url, "/teams/tf/([^/]+?)\\.html")[, 2]
}

# ---------------------------------------------------------------------------
# Standardise performance-list exports
# ---------------------------------------------------------------------------

list_export_columns <- function() {
  c(
    "division", "season", "list_year", "event_code", "place", "athlete",
    "class_code", "eligibility_year", "team", "mark_m", "wind", "meet",
    "meet_date", "source_url", "parsed_at"
  )
}

#' Standardise a TFRRS performance-list export
#'
#' Input: one row per list entry, in the schema written by the v0 list parser
#' (see `list_export_columns()`).
#'
#' @param raw Data frame read from `data-raw/source/tfrrs_lists/*.csv`.
#' @return One row per list entry with standard column names. Team names are
#'   not yet matched to programs.
#' @noRd
standardize_list_marks <- function(raw) {
  missing <- setdiff(list_export_columns(), names(raw))
  if (length(missing) > 0) {
    cli::cli_abort("List export is missing columns: {.val {missing}}")
  }

  out <- raw |>
    dplyr::mutate(
      season_type = tolower(stringr::str_squish(.data$season)),
      season_year = as.integer(.data$list_year),
      division = division_code(.data$division),
      event_code = toupper(stringr::str_squish(.data$event_code)),
      class_code = stringr::str_squish(.data$class_code),
      class_group = class_group(.data$class_code),
      eligibility_year = as.integer(.data$eligibility_year),
      mark_m = as.numeric(.data$mark_m),
      wind_mps = as.numeric(.data$wind)
    ) |>
    dplyr::transmute(
      list_id = paste(.data$season_year, .data$season_type, .data$division, .data$event_code, sep = "_"),
      event_code = .data$event_code,
      season = .data$season_year,
      season_type = .data$season_type,
      division = .data$division,
      list_team_name = stringr::str_squish(.data$team),
      athlete_name = stringr::str_squish(.data$athlete),
      class_code = .data$class_code,
      class_group = .data$class_group,
      eligibility_year = .data$eligibility_year,
      mark_m = .data$mark_m,
      wind_mps = .data$wind_mps,
      wind_status = wind_status(.data$event_code, .data$wind_mps),
      meet_name = stringr::str_squish(.data$meet),
      meet_date = as.Date(.data$meet_date),
      list_place = as.integer(.data$place),
      source_url = .data$source_url,
      parsed_at = as.character(.data$parsed_at)
    )

  bad_division <- unique(raw$division[is.na(out$division)])
  if (length(bad_division) > 0) {
    cli::cli_abort("Unrecognised division label{?s}: {.val {bad_division}}")
  }
  if (anyNA(out$mark_m)) {
    cli::cli_abort("{sum(is.na(out$mark_m))} list row{?s} have no numeric mark.")
  }
  out
}

# ---------------------------------------------------------------------------
# Match list team names to TFRRS programs
# ---------------------------------------------------------------------------

#' Match performance-list team names to the TFRRS team registry
#'
#' Matching order: crosswalk override, then normalised name. Any name that
#' does not resolve to exactly one registry team stops the build.
#'
#' @param list_team_names Character vector of names as printed on lists.
#' @param registry TFRRS team registry (`school_name`, `state_abbrev`,
#'   `tfrrs_team_url`).
#' @param crosswalk `list_team_name`, `registry_school_name`.
#' @return One row per list team name with `program_id`, `school_name`,
#'   `state` and `tfrrs_team_url`.
#' @noRd
match_list_teams <- function(list_team_names, registry, crosswalk) {
  reg <- registry |>
    dplyr::transmute(
      join_key = name_key(.data$school_name),
      program_id = program_id_from_url(.data$tfrrs_team_url),
      school_name = .data$school_name,
      state = .data$state_abbrev,
      tfrrs_team_url = .data$tfrrs_team_url
    )

  dup_keys <- unique(reg$join_key[duplicated(reg$join_key)])
  if (length(dup_keys) > 0) {
    cli::cli_abort("Registry names collide after normalising: {.val {dup_keys}}")
  }
  if (anyNA(reg$program_id)) {
    cli::cli_abort("{sum(is.na(reg$program_id))} registry URL{?s} have no team slug.")
  }

  out <- tibble::tibble(list_team_name = sort(unique(list_team_names))) |>
    dplyr::left_join(
      crosswalk |> dplyr::select("list_team_name", "registry_school_name"),
      by = "list_team_name"
    ) |>
    dplyr::mutate(
      join_key = name_key(dplyr::coalesce(.data$registry_school_name, .data$list_team_name))
    ) |>
    dplyr::left_join(reg, by = "join_key", relationship = "many-to-one") |>
    dplyr::select("list_team_name", "program_id", "school_name", "state", "tfrrs_team_url")

  unmatched <- out$list_team_name[is.na(out$program_id)]
  if (length(unmatched) > 0) {
    cli::cli_abort(c(
      "{length(unmatched)} list team name{?s} did not match the registry: {.val {unmatched}}",
      "i" = "Map each one in {.file data-raw/manual/school_name_crosswalk.csv}."
    ))
  }
  out
}

# ---------------------------------------------------------------------------
# Build app tables
# ---------------------------------------------------------------------------

#' Keep each athlete's best entry per list
#'
#' Grain after: one row per list_id x program_id x athlete_name.
#' @noRd
dedupe_athlete_marks <- function(marks) {
  marks |>
    dplyr::arrange(.data$list_id, .data$program_id, .data$athlete_name, dplyr::desc(.data$mark_m), .data$list_place) |>
    dplyr::distinct(.data$list_id, .data$program_id, .data$athlete_name, .keep_all = TRUE)
}

#' Summarise each list
#'
#' Grain: one row per list_id (event x season x season_type x division).
#' `floor_mark_m` is the lowest mark on the list; marks at or above it are
#' complete, marks below it are not.
#' @noRd
build_event_lists <- function(athlete_marks) {
  athlete_marks |>
    dplyr::group_by(.data$list_id, .data$event_code, .data$season, .data$season_type, .data$division) |>
    dplyr::summarise(
      list_size = dplyr::n(),
      program_count = dplyr::n_distinct(.data$program_id),
      floor_mark_m = min(.data$mark_m),
      top_mark_m = max(.data$mark_m),
      latest_meet_date = max(.data$meet_date, na.rm = TRUE),
      source_url = dplyr::first(.data$source_url),
      parsed_at = dplyr::first(.data$parsed_at),
      .groups = "drop"
    )
}

#' Build the program table
#'
#' Grain: one row per program_id. A program belongs to exactly one division.
#' @noRd
build_programs <- function(team_matches, athlete_marks) {
  divisions <- athlete_marks |>
    dplyr::distinct(.data$program_id, .data$division)

  multi <- divisions |>
    dplyr::count(.data$program_id) |>
    dplyr::filter(.data$n > 1)
  if (nrow(multi) > 0) {
    cli::cli_abort("Programs appear on lists for more than one division: {.val {multi$program_id}}")
  }

  team_matches |>
    dplyr::group_by(.data$program_id) |>
    dplyr::summarise(
      school_name = dplyr::first(.data$school_name),
      list_team_name = paste(sort(unique(.data$list_team_name)), collapse = "; "),
      state = dplyr::first(.data$state),
      tfrrs_team_url = dplyr::first(.data$tfrrs_team_url),
      .groups = "drop"
    ) |>
    dplyr::inner_join(divisions, by = "program_id", relationship = "one-to-one") |>
    dplyr::mutate(conference = NA_character_) |>
    dplyr::select(
      "program_id", "school_name", "list_team_name", "division",
      "conference", "state", "tfrrs_team_url"
    ) |>
    dplyr::arrange(.data$school_name)
}

#' Latest ledger entry per program x event x season
#'
#' The ledger is append-only; the last row for a key wins.
#' @noRd
latest_ledger <- function(ledger) {
  bad <- setdiff(unique(ledger$status), names(ledger_statuses()))
  if (length(bad) > 0) {
    cli::cli_abort("Unknown ledger status{?es}: {.val {bad}}")
  }
  ledger |>
    dplyr::mutate(.row = dplyr::row_number(), season = as.integer(.data$season)) |>
    dplyr::group_by(.data$program_id, .data$event_code, .data$season) |>
    dplyr::slice_max(.data$.row, n = 1) |>
    dplyr::ungroup() |>
    dplyr::select(
      "program_id", "event_code", "season",
      ledger_status = "status",
      verified_on = "checked_on",
      verification_note = "notes",
      verification_source = "source_url"
    )
}

#' Build the program x event table
#'
#' Grain: one row per program_id x list_id. Built as a full cross of
#' programs and the lists for their division, so a program with no listed
#' athletes in an event still has a row, with an explicit coverage state.
#' Class counts are `NA` when nobody is listed: they describe listed
#' athletes only.
#' @noRd
build_program_events <- function(programs, event_lists, athlete_marks, ledger) {
  unknown_ids <- setdiff(ledger$program_id, programs$program_id)
  if (length(unknown_ids) > 0) {
    cli::cli_abort("Verification ledger names unknown program_id{?s}: {.val {unknown_ids}}")
  }

  grid <- programs |>
    dplyr::select("program_id", "division") |>
    dplyr::inner_join(
      event_lists |> dplyr::select("list_id", "event_code", "season", "season_type", "division"),
      by = "division",
      relationship = "many-to-many"
    )

  counts <- athlete_marks |>
    dplyr::group_by(.data$list_id, .data$program_id) |>
    dplyr::summarise(
      listed_count = dplyr::n(),
      top_mark_m = max(.data$mark_m),
      fr = sum(.data$class_group %in% "fr"),
      so = sum(.data$class_group %in% "so"),
      jr = sum(.data$class_group %in% "jr"),
      sr = sum(.data$class_group %in% "sr"),
      .groups = "drop"
    )

  out <- grid |>
    dplyr::left_join(counts, by = c("list_id", "program_id"), relationship = "one-to-one") |>
    dplyr::mutate(listed_count = dplyr::coalesce(.data$listed_count, 0L)) |>
    dplyr::left_join(
      latest_ledger(ledger),
      by = c("program_id", "event_code", "season"),
      relationship = "many-to-one"
    ) |>
    dplyr::mutate(coverage_state = coverage_state(.data$listed_count, .data$ledger_status))

  conflicts <- check_ledger_conflicts(out)
  if (nrow(conflicts) > 0) {
    cli::cli_abort(c(
      "The verification ledger contradicts the lists for {nrow(conflicts)} row{?s}:",
      stats::setNames(paste(conflicts$program_id, conflicts$event_code, conflicts$season), rep("x", nrow(conflicts))),
      "i" = "Re-check the source and correct the ledger."
    ))
  }

  out |>
    dplyr::select(
      "program_id", "list_id", "event_code", "season", "season_type", "division",
      "listed_count", "top_mark_m", "fr", "so", "jr", "sr",
      "coverage_state", "ledger_status", "verified_on", "verification_note", "verification_source"
    ) |>
    dplyr::arrange(.data$program_id, .data$list_id)
}

#' Build every app table from source data
#'
#' @param raw_lists Data frame: one or more TFRRS list exports, row-bound.
#' @param registry TFRRS team registry.
#' @param crosswalk Name crosswalk (`list_team_name`, `registry_school_name`).
#' @param ledger Verification ledger.
#' @return Named list: `programs`, `event_lists`, `athlete_marks`,
#'   `program_events`.
#' @noRd
build_app_tables <- function(raw_lists, registry, crosswalk, ledger) {
  marks <- standardize_list_marks(raw_lists)
  matches <- match_list_teams(marks$list_team_name, registry, crosswalk)

  # Grain: one row per list_id x program_id x athlete_name (season best).
  athlete_marks <- marks |>
    dplyr::left_join(
      matches |> dplyr::select("list_team_name", "program_id"),
      by = "list_team_name",
      relationship = "many-to-one"
    ) |>
    dedupe_athlete_marks() |>
    dplyr::select(
      "list_id", "program_id", "event_code", "season", "season_type", "division",
      "athlete_name", "class_code", "class_group", "eligibility_year",
      "mark_m", "wind_mps", "wind_status", "meet_name", "meet_date", "list_place"
    ) |>
    dplyr::arrange(.data$list_id, .data$list_place)

  event_lists <- build_event_lists(
    athlete_marks |>
      dplyr::left_join(
        marks |> dplyr::distinct(.data$list_id, .data$source_url, .data$parsed_at),
        by = "list_id",
        relationship = "many-to-one"
      )
  )

  programs <- build_programs(matches, athlete_marks)
  program_events <- build_program_events(programs, event_lists, athlete_marks, ledger)

  tables <- list(
    programs = programs,
    event_lists = event_lists,
    athlete_marks = athlete_marks,
    program_events = program_events
  )
  validate_app_tables(tables)
  tables
}

#' Check the data contracts in SPEC section 5
#'
#' Stops with a list of every violation. Used by the build script and by
#' `tests/testthat/test-data-contracts.R` on the committed tables.
#' @noRd
validate_app_tables <- function(tables) {
  problems <- character()
  add <- function(ok, msg) if (!isTRUE(ok)) problems <<- c(problems, msg)

  p <- tables$programs
  l <- tables$event_lists
  a <- tables$athlete_marks
  pe <- tables$program_events

  add(!anyNA(p$program_id) && !anyDuplicated(p$program_id), "programs: program_id missing or duplicated")
  add(all(p$division %in% c("D1", "D2")), "programs: division outside D1/D2")
  add(!anyDuplicated(l$list_id), "event_lists: list_id duplicated")
  add(all(a$program_id %in% p$program_id), "athlete_marks: program_id not in programs")
  add(all(a$list_id %in% l$list_id), "athlete_marks: list_id not in event_lists")
  add(!anyDuplicated(a[c("list_id", "program_id", "athlete_name")]), "athlete_marks: duplicate athlete within a list and program")
  add(all(a$wind_status %in% c("legal", "aided", "not_applicable", "unknown")), "athlete_marks: invalid wind_status")
  add(!anyDuplicated(pe[c("program_id", "list_id")]), "program_events: duplicate program x list")
  add(all(pe$coverage_state %in% coverage_states()), "program_events: invalid coverage_state")

  expected_rows <- sum(vapply(l$division, function(d) sum(p$division == d), integer(1)))
  add(nrow(pe) == expected_rows, "program_events: not a full cross of programs and their division's lists")

  listed <- pe$listed_count > 0
  add(all(is.na(pe$top_mark_m[!listed])), "program_events: top mark present where nobody is listed")
  add(all(!is.na(pe$top_mark_m[listed])), "program_events: top mark missing where athletes are listed")

  if (length(problems) > 0) {
    cli::cli_abort(c("Data contract violations:", stats::setNames(problems, rep("x", length(problems)))))
  }
  invisible(TRUE)
}
