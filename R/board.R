# Target board: a human-curated shortlist of programs, the evidence behind
# each one, and where outreach stands. See docs/SPEC.md section 5.
#
# Three kinds of input feed the board:
#   * data-raw/manual/target_board.csv   which programs, in which group (human-edited)
#   * data-raw/source/tfrrs_results/     championship finals, used as evidence for
#                                        divisions whose lists are not loaded yet
#   * inst/private/                      coach contacts and the outreach log; local
#                                        files, never committed (D-009)
#
# Board groups are Roland's own sort of the shortlist. They are not fit reads
# and are never computed. Every number shown beside a group comes from the
# lists or the championship results, with its source.

# ---------------------------------------------------------------------------
# Vocabularies
# ---------------------------------------------------------------------------

#' Board groups, in display order
#' @noRd
board_groups <- function() {
  c("established_group", "smaller_group", "power_conference", "division_ii")
}

#' Columns of data-raw/manual/target_board.csv
#' @noRd
board_columns <- function() {
  c("program_id", "division", "board_group", "board_note", "added_on", "added_by", "source")
}

#' Columns of a championship results export in data-raw/source/tfrrs_results/
#' @noRd
results_export_columns <- function() {
  c(
    "division", "season", "season_year", "meet_name", "meet_date", "round",
    "event_code", "place", "athlete", "class_code", "eligibility_year", "team",
    "mark_m", "result_status", "wind", "source_url", "retrieved_on"
  )
}

#' Result statuses in a championship export
#' @noRd
result_statuses <- function() {
  c(
    mark = "Cleared a height or recorded a legal mark",
    no_height = "High jump: did not clear a height",
    no_mark = "Horizontal jumps: no legal mark"
  )
}

# ---------------------------------------------------------------------------
# Championship results
# ---------------------------------------------------------------------------

#' Standardise a championship results export
#'
#' Input: one row per athlete per event per round, as exported from a TFRRS
#' results page (see `results_export_columns()`).
#'
#' @param raw Data frame read from `data-raw/source/tfrrs_results/*.csv`.
#' @return One row per meet x event x round x athlete. Team names are not yet
#'   matched to programs.
#' @noRd
standardize_results <- function(raw) {
  missing <- setdiff(results_export_columns(), names(raw))
  if (length(missing) > 0) {
    cli::cli_abort("Results export is missing columns: {.val {missing}}")
  }

  out <- raw |>
    dplyr::mutate(
      division = division_code(.data$division),
      season_type = tolower(stringr::str_squish(.data$season)),
      season = as.integer(.data$season_year),
      event_code = toupper(stringr::str_squish(.data$event_code)),
      result_status = stringr::str_squish(.data$result_status),
      wind_mps = as.numeric(.data$wind)
    ) |>
    dplyr::transmute(
      # One championship per division and season type, so this is unique.
      meet_id = paste(.data$season, .data$season_type, .data$division, "champs", sep = "_"),
      meet_name = stringr::str_squish(.data$meet_name),
      meet_date = as.Date(dplyr::na_if(.data$meet_date, "")),
      season = .data$season,
      season_type = .data$season_type,
      division = .data$division,
      event_code = .data$event_code,
      round = tolower(stringr::str_squish(.data$round)),
      place = as.integer(.data$place),
      athlete_name = stringr::str_squish(.data$athlete),
      class_code = stringr::str_squish(.data$class_code),
      class_group = class_group(.data$class_code),
      eligibility_year = as.integer(.data$eligibility_year),
      list_team_name = stringr::str_squish(.data$team),
      mark_m = as.numeric(.data$mark_m),
      result_status = .data$result_status,
      wind_mps = .data$wind_mps,
      wind_status = dplyr::if_else(
        .data$result_status == "mark",
        wind_status(.data$event_code, .data$wind_mps),
        NA_character_
      ),
      source_url = .data$source_url,
      retrieved_on = .data$retrieved_on
    )

  bad_division <- unique(raw$division[is.na(out$division)])
  if (length(bad_division) > 0) {
    cli::cli_abort("Unrecognised division label{?s} in results: {.val {bad_division}}")
  }
  bad_status <- setdiff(unique(out$result_status), names(result_statuses()))
  if (length(bad_status) > 0) {
    cli::cli_abort("Unknown result status{?es}: {.val {bad_status}}")
  }
  mark_mismatch <- (out$result_status == "mark") != !is.na(out$mark_m)
  if (any(mark_mismatch)) {
    cli::cli_abort("{sum(mark_mismatch)} result row{?s} have a mark that disagrees with result_status.")
  }
  out
}

#' Build the championship marks table
#'
#' Grain: one row per meet_id x event_code x round x athlete. Team names are
#' matched to TFRRS programs with the same rules as the lists
#' ([match_list_teams()]), so unmatched names stop the build.
#'
#' @param raw_results Data frame: one or more results exports, row-bound.
#' @param registry TFRRS team registry.
#' @param crosswalk Name crosswalk.
#' @noRd
build_championship_marks <- function(raw_results, registry, crosswalk) {
  results <- standardize_results(raw_results)
  matches <- match_list_teams(results$list_team_name, registry, crosswalk)

  results |>
    dplyr::left_join(
      matches |> dplyr::select("list_team_name", "program_id"),
      by = "list_team_name",
      relationship = "many-to-one"
    ) |>
    dplyr::select(
      "meet_id", "meet_name", "meet_date", "season", "season_type", "division",
      "event_code", "round", "place", "program_id", "list_team_name",
      "athlete_name", "class_code", "class_group", "eligibility_year",
      "mark_m", "result_status", "wind_mps", "wind_status", "source_url", "retrieved_on"
    ) |>
    dplyr::arrange(.data$meet_id, .data$event_code, .data$round, .data$place, .data$athlete_name)
}

# ---------------------------------------------------------------------------
# The board
# ---------------------------------------------------------------------------

#' Build the board table
#'
#' Grain: one row per board program. School name, state and team URL come
#' from `programs` when the program is on a loaded list, otherwise from the
#' TFRRS team registry.
#'
#' @param board_manual `data-raw/manual/target_board.csv`.
#' @param programs Built `programs` table.
#' @param registry TFRRS team registry.
#' @noRd
build_board <- function(board_manual, programs, registry) {
  missing <- setdiff(board_columns(), names(board_manual))
  if (length(missing) > 0) {
    cli::cli_abort("target_board.csv is missing columns: {.val {missing}}")
  }

  board <- board_manual |>
    dplyr::mutate(dplyr::across(dplyr::everything(), \(x) stringr::str_squish(as.character(x))))

  dup <- unique(board$program_id[duplicated(board$program_id)])
  if (length(dup) > 0) cli::cli_abort("Programs listed twice on the board: {.val {dup}}")

  bad_group <- setdiff(unique(board$board_group), board_groups())
  if (length(bad_group) > 0) cli::cli_abort("Unknown board group{?s}: {.val {bad_group}}")

  bad_div <- setdiff(unique(board$division), c("D1", "D2"))
  if (length(bad_div) > 0) cli::cli_abort("Board division must be D1 or D2, not {.val {bad_div}}")

  reg <- registry |>
    dplyr::transmute(
      program_id = program_id_from_url(.data$tfrrs_team_url),
      reg_school_name = .data$school_name,
      reg_state = .data$state_abbrev,
      reg_url = .data$tfrrs_team_url
    ) |>
    dplyr::distinct(.data$program_id, .keep_all = TRUE)

  out <- board |>
    dplyr::left_join(
      programs |> dplyr::select("program_id", "school_name", "state", "tfrrs_team_url", list_division = "division"),
      by = "program_id",
      relationship = "one-to-one"
    ) |>
    dplyr::left_join(reg, by = "program_id", relationship = "many-to-one")

  unknown <- out$program_id[is.na(out$school_name) & is.na(out$reg_school_name)]
  if (length(unknown) > 0) {
    cli::cli_abort(c(
      "Board programs not found in the lists or the team registry: {.val {unknown}}",
      "i" = "Use the TFRRS team slug from the team page URL, e.g. {.val GA_college_m_Kennesaw_State}."
    ))
  }

  clash <- out$program_id[!is.na(out$list_division) & out$list_division != out$division]
  if (length(clash) > 0) {
    cli::cli_abort("Board division disagrees with the lists for: {.val {clash}}")
  }

  out |>
    dplyr::mutate(
      on_lists = !is.na(.data$school_name),
      school_name = dplyr::coalesce(.data$school_name, .data$reg_school_name),
      state = dplyr::coalesce(.data$state, .data$reg_state),
      tfrrs_team_url = dplyr::coalesce(.data$tfrrs_team_url, .data$reg_url),
      group_order = match(.data$board_group, board_groups())
    ) |>
    dplyr::select(
      "program_id", "school_name", "state", "division", "tfrrs_team_url",
      "board_group", "group_order", "board_note", "on_lists",
      "added_on", "added_by", "source"
    ) |>
    dplyr::arrange(.data$group_order, .data$school_name)
}

#' Build the board tables
#'
#' @return Named list: `board`, `championship_marks`.
#' @noRd
build_board_tables <- function(board_manual, raw_results, programs, registry, crosswalk) {
  tables <- list(
    board = build_board(board_manual, programs, registry),
    championship_marks = build_championship_marks(raw_results, registry, crosswalk)
  )
  validate_board_tables(tables)
  tables
}

#' Check the board data contracts (SPEC section 5)
#' @noRd
validate_board_tables <- function(tables) {
  problems <- character()
  add <- function(ok, msg) if (!isTRUE(ok)) problems <<- c(problems, msg)

  b <- tables$board
  c <- tables$championship_marks

  add(!anyNA(b$program_id) && !anyDuplicated(b$program_id), "board: program_id missing or duplicated")
  add(all(grepl("^[A-Z]{2}_college_m_", b$program_id)), "board: program_id is not a TFRRS men's team slug")
  add(all(b$board_group %in% board_groups()), "board: invalid board_group")
  add(all(b$division %in% c("D1", "D2")), "board: division outside D1/D2")
  add(!anyNA(b$school_name), "board: school_name missing")

  add(!anyNA(c$program_id), "championship_marks: program_id missing")
  add(all(c$result_status %in% names(result_statuses())), "championship_marks: invalid result_status")
  add(all((c$result_status == "mark") == !is.na(c$mark_m)), "championship_marks: mark disagrees with result_status")
  add(
    !anyDuplicated(c[c("meet_id", "event_code", "round", "athlete_name", "program_id")]),
    "championship_marks: athlete listed twice in one round"
  )

  if (length(problems) > 0) {
    cli::cli_abort(c("Board contract violations:", stats::setNames(problems, rep("x", length(problems)))))
  }
  invisible(TRUE)
}

# ---------------------------------------------------------------------------
# Metrics for the Board page
# ---------------------------------------------------------------------------

#' Board fit table: one row per board program for one event
#'
#' Grain: one row per board program. List metrics come from [fit_table()]
#' and are `NA` for programs with no loaded list (D2 today). Championship
#' columns summarise the program's finalists in the event.
#'
#' @inheritParams fit_table
#' @noRd
board_fit_table <- function(app_data, event_code, athlete_mark_m, enroll_year = 2027, reach_threshold_m) {
  fit <- fit_table(
    app_data,
    event_code = event_code,
    athlete_mark_m = athlete_mark_m,
    divisions = c("D1", "D2"),
    enroll_year = enroll_year,
    reach_threshold_m = reach_threshold_m
  ) |>
    dplyr::select(
      "program_id", "list_id", "event_code", "listed_count", "top_mark_m",
      "coverage_state", "verification_note", "ahead_now", "level_now",
      "ahead_at_arrival", "rank_now", "rank_complete", "gap_to_top_m",
      "floor_mark_m", "fit_read"
    )

  champs <- app_data$championship_marks |>
    dplyr::filter(.data$event_code == .env$event_code) |>
    dplyr::group_by(.data$program_id) |>
    dplyr::summarise(
      champs_meet_id = dplyr::first(.data$meet_id),
      champs_finalists = dplyr::n(),
      champs_best_m = suppressWarnings(max(.data$mark_m, na.rm = TRUE)),
      champs_best_place = suppressWarnings(min(.data$place, na.rm = TRUE)),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      # min()/max() over all-NA groups return +/-Inf; those are "no mark".
      champs_best_m = dplyr::if_else(is.finite(.data$champs_best_m), .data$champs_best_m, NA_real_),
      champs_best_place = as.integer(dplyr::if_else(is.finite(.data$champs_best_place), .data$champs_best_place, NA_real_))
    )

  app_data$board |>
    dplyr::left_join(fit, by = "program_id", relationship = "one-to-one") |>
    dplyr::left_join(champs, by = "program_id", relationship = "one-to-one") |>
    dplyr::mutate(
      event_code = .env$event_code,
      has_list = !is.na(.data$list_id),
      champs_finalists = dplyr::coalesce(.data$champs_finalists, 0L)
    ) |>
    dplyr::arrange(.data$group_order, .data$fit_read, abs(.data$gap_to_top_m), .data$school_name)
}

#' Marks behind each board program's strip
#'
#' Grain: one row per board program x athlete for the event. List marks
#' where a list is loaded, otherwise championship final marks.
#' `in_school_at_arrival` is context only (D-006).
#' @noRd
board_marks <- function(app_data, event_code, enroll_year = 2027) {
  list_ids <- select_lists(app_data$event_lists, event_code, c("D1", "D2"))$list_id

  from_lists <- app_data$athlete_marks |>
    dplyr::filter(.data$list_id %in% list_ids, .data$program_id %in% app_data$board$program_id) |>
    dplyr::transmute(
      .data$program_id, .data$athlete_name, .data$class_code, .data$mark_m,
      in_school = in_school_at_arrival(.data$eligibility_year, .data$season, enroll_year),
      evidence = "list"
    )

  from_champs <- app_data$championship_marks |>
    dplyr::filter(
      .data$event_code == .env$event_code,
      .data$program_id %in% app_data$board$program_id,
      !.data$program_id %in% from_lists$program_id,
      .data$result_status == "mark"
    ) |>
    dplyr::transmute(
      .data$program_id, .data$athlete_name, .data$class_code, .data$mark_m,
      in_school = in_school_at_arrival(.data$eligibility_year, .data$season, enroll_year),
      evidence = "championship"
    )

  dplyr::bind_rows(from_lists, from_champs)
}

#' Championship evidence for one program
#'
#' The program's finalists in the event, with the athlete's mark slotted in
#' among them. Grain: one row per finalist, plus one row for the athlete.
#' @noRd
championship_evidence <- function(app_data, program_id, event_code, athlete_mark_m, athlete_label = "You") {
  finalists <- app_data$championship_marks |>
    dplyr::filter(.data$program_id == .env$program_id, .data$event_code == .env$event_code) |>
    dplyr::mutate(is_athlete = FALSE)

  you <- tibble::tibble(
    place = NA_integer_,
    athlete_name = athlete_label,
    class_code = "HS 2027",
    mark_m = athlete_mark_m,
    result_status = "mark",
    wind_mps = NA_real_,
    wind_status = NA_character_,
    is_athlete = TRUE
  )

  dplyr::bind_rows(finalists, you) |>
    dplyr::arrange(dplyr::desc(dplyr::coalesce(.data$mark_m, -Inf)), .data$is_athlete) |>
    dplyr::select("place", "athlete_name", "class_code", "mark_m", "result_status", "wind_mps", "wind_status", "is_athlete")
}

#' Where the athlete's mark would have placed in a championship final
#'
#' @return One row per meet x event: `place_equiv` is 1 + finalists with a
#'   better mark; `field` is the number of finalists.
#' @noRd
championship_standing <- function(app_data, event_code, athlete_mark_m) {
  app_data$championship_marks |>
    dplyr::filter(.data$event_code == .env$event_code) |>
    dplyr::group_by(.data$meet_id, .data$meet_name, .data$division, .data$season) |>
    dplyr::summarise(
      better = sum(compare_marks(.data$mark_m, athlete_mark_m) == 1L, na.rm = TRUE),
      field = dplyr::n(),
      last_mark_m = suppressWarnings(min(.data$mark_m, na.rm = TRUE)),
      .groups = "drop"
    ) |>
    dplyr::mutate(place_equiv = .data$better + 1L)
}

# ---------------------------------------------------------------------------
# Private data: coach contacts and the outreach log (D-009)
# ---------------------------------------------------------------------------

#' Column schemas for the private files
#'
#' Templates with these headers live in inst/templates/. The filled-in files
#' live in inst/private/ (gitignored) or in `LIFTOFF_PRIVATE_DIR`.
#' @noRd
private_schemas <- function() {
  list(
    # Grain: one row per program x coach.
    coach_contacts = c(
      "program_id", "coach_name", "coach_title", "events_coached", "email",
      "phone", "staff_page_url", "checked_on", "source_url", "notes"
    ),
    # Grain: one row per contact (append-only; newest last).
    outreach_log = c(
      "program_id", "contact_date", "direction", "channel", "coach_name",
      "summary", "next_step", "next_step_date"
    )
  )
}

#' Vocabularies for the outreach log
#' @noRd
outreach_directions <- function() c("sent", "received")

#' @rdname outreach_directions
#' @noRd
outreach_channels <- function() c("email", "call", "text", "social", "questionnaire", "visit", "camp", "meet", "other")

#' Folder holding the private files
#' @noRd
private_data_dir <- function() {
  env <- Sys.getenv("LIFTOFF_PRIVATE_DIR", "")
  if (nzchar(env)) env else app_sys("private")
}

#' Load coach contacts and the outreach log
#'
#' Missing files are normal (a fresh clone, or Posit Connect without them):
#' each comes back as an empty table with its schema. Rows that break the
#' rules are reported in `problems`, never fatal, so the app still runs.
#'
#' @param dir Folder holding `coach_contacts.csv` and `outreach_log.csv`.
#' @param known_ids Program ids the files may refer to.
#' @return List: `coach_contacts`, `outreach_log`, `found` (named logical),
#'   `problems` (character).
#' @noRd
load_private_data <- function(dir = private_data_dir(), known_ids = NULL) {
  schemas <- private_schemas()
  problems <- character()

  empty <- function(cols) {
    tibble::as_tibble(stats::setNames(rep(list(character()), length(cols)), cols))
  }

  read_one <- function(name) {
    path <- if (nzchar(dir)) file.path(dir, paste0(name, ".csv")) else ""
    if (!nzchar(path) || !file.exists(path)) return(list(data = empty(schemas[[name]]), found = FALSE))

    df <- readr::read_csv(path, col_types = readr::cols(.default = readr::col_character()), progress = FALSE)
    missing <- setdiff(schemas[[name]], names(df))
    if (length(missing) > 0) {
      problems <<- c(problems, paste0(name, ".csv is missing columns: ", paste(missing, collapse = ", ")))
      for (m in missing) df[[m]] <- NA_character_
    }
    list(data = df[schemas[[name]]], found = TRUE)
  }

  contacts <- read_one("coach_contacts")
  log <- read_one("outreach_log")

  cc <- contacts$data
  ol <- log$data |>
    dplyr::mutate(
      contact_date_parsed = as.Date(.data$contact_date, optional = TRUE),
      next_step_date_parsed = as.Date(.data$next_step_date, optional = TRUE)
    )

  note <- function(df, ok, file, what) {
    bad <- which(!ok)
    if (length(bad) > 0) problems <<- c(problems, paste0(file, " row ", bad, ": ", what))
  }

  if (!is.null(known_ids)) {
    note(cc, cc$program_id %in% known_ids, "coach_contacts.csv", "program_id is not on the board or the lists")
    note(ol, ol$program_id %in% known_ids, "outreach_log.csv", "program_id is not on the board or the lists")
  }
  note(ol, ol$direction %in% outreach_directions(), "outreach_log.csv", paste0("direction must be one of ", paste(outreach_directions(), collapse = ", ")))
  note(ol, ol$channel %in% outreach_channels(), "outreach_log.csv", paste0("channel must be one of ", paste(outreach_channels(), collapse = ", ")))
  note(ol, !is.na(ol$contact_date_parsed), "outreach_log.csv", "contact_date must be YYYY-MM-DD")
  note(ol, is.na(ol$next_step_date) | ol$next_step_date == "" | !is.na(ol$next_step_date_parsed), "outreach_log.csv", "next_step_date must be YYYY-MM-DD or blank")

  ol <- ol |>
    dplyr::mutate(contact_date = .data$contact_date_parsed, next_step_date = .data$next_step_date_parsed) |>
    dplyr::select(-"contact_date_parsed", -"next_step_date_parsed")

  list(
    coach_contacts = cc,
    outreach_log = ol,
    found = c(coach_contacts = contacts$found, outreach_log = log$found),
    problems = problems
  )
}

#' Outreach state per board program
#'
#' Grain: one row per board program.
#' `contact_state`: `no_coach` (nothing on file), `coach_on_file` (a coach but
#' no logged contact), `sent` (last logged contact went out), `received`
#' (last logged contact came in).
#' @noRd
board_outreach <- function(board, coach_contacts, outreach_log) {
  coaches <- coach_contacts |>
    dplyr::filter(!is.na(.data$program_id)) |>
    dplyr::group_by(.data$program_id) |>
    dplyr::summarise(
      coaches_on_file = dplyr::n(),
      coach_names = paste(stats::na.omit(.data$coach_name), collapse = "; "),
      .groups = "drop"
    )

  last <- outreach_log |>
    dplyr::filter(!is.na(.data$program_id), !is.na(.data$contact_date)) |>
    dplyr::mutate(.row = dplyr::row_number()) |>
    dplyr::group_by(.data$program_id) |>
    dplyr::arrange(.data$contact_date, .data$.row, .by_group = TRUE) |>
    dplyr::summarise(
      contacts_logged = dplyr::n(),
      replies = sum(.data$direction %in% "received"),
      last_contact_date = dplyr::last(.data$contact_date),
      last_direction = dplyr::last(.data$direction),
      last_channel = dplyr::last(.data$channel),
      next_step = dplyr::last(.data$next_step),
      next_step_date = dplyr::last(.data$next_step_date),
      .groups = "drop"
    )

  board |>
    dplyr::select("program_id") |>
    dplyr::left_join(coaches, by = "program_id", relationship = "one-to-one") |>
    dplyr::left_join(last, by = "program_id", relationship = "one-to-one") |>
    dplyr::mutate(
      coaches_on_file = dplyr::coalesce(.data$coaches_on_file, 0L),
      contacts_logged = dplyr::coalesce(.data$contacts_logged, 0L),
      replies = dplyr::coalesce(.data$replies, 0L),
      contact_state = dplyr::case_when(
        .data$last_direction %in% "received" ~ "received",
        .data$last_direction %in% "sent" ~ "sent",
        .data$coaches_on_file > 0 ~ "coach_on_file",
        .default = "no_coach"
      )
    )
}
