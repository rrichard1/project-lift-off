# Athlete-relative metrics and the fit read. See docs/SPEC.md section 6-7.
#
# Everything here compares one athlete mark against real list entries. No
# scores are blended and nothing predicts coach behaviour.

#' Fit-read codes in display order
#' @noRd
fit_read_codes <- function() {
  c(
    "would_lead", "top_three", "depth", "well_above", "cant_tell",
    "verified_active", "none_listed", "verified_no_marks", "verified_no_event"
  )
}

#' Assign the fit read (SPEC section 7, rules applied in order)
#'
#' @param coverage_state Coverage state for the program x event row.
#' @param gap_to_top_m Program best minus athlete mark, metres.
#' @param rank_now Where the athlete's mark would have ranked on the
#'   program's listed group (a lower bound when `rank_complete` is FALSE).
#' @param rank_complete TRUE when the athlete's mark is at or above the list
#'   floor, so every better teammate is on the list.
#' @param reach_threshold_m Gap at or above which the program is "well above
#'   current level".
#' @return Character vector of fit-read codes.
#' @noRd
fit_read_code <- function(coverage_state, gap_to_top_m, rank_now, rank_complete, reach_threshold_m) {
  dplyr::case_when(
    coverage_state != "listed" ~ coverage_state,
    round(gap_to_top_m, 2) >= reach_threshold_m ~ "well_above",
    rank_complete & rank_now == 1 ~ "would_lead",
    rank_now >= 4 ~ "depth",
    rank_complete & rank_now <= 3 ~ "top_three",
    .default = "cant_tell"
  )
}

#' Which lists apply to a request
#'
#' Outdoor lists for the event and divisions; the latest season per division
#' unless `season` is given.
#' @noRd
select_lists <- function(event_lists, event_code, divisions, season = NULL) {
  out <- event_lists |>
    dplyr::filter(
      .data$event_code == .env$event_code,
      .data$division %in% divisions,
      .data$season_type == "outdoor"
    )
  if (is.null(season)) {
    out <- out |>
      dplyr::group_by(.data$division) |>
      dplyr::filter(.data$season == max(.data$season)) |>
      dplyr::ungroup()
  } else {
    out <- dplyr::filter(out, .data$season == .env$season)
  }
  out
}

#' Is an athlete still in school in the enrollment year?
#'
#' A listed athlete in class year `e` in spring `season` is in class year
#' `e + (enroll_year + 1 - season)` during the athlete's first college
#' season (spring of `enroll_year + 1`). Still in school if that is <= 4.
#' Redshirts and fifth years are not visible in list data.
#' @noRd
in_school_at_arrival <- function(eligibility_year, season, enroll_year) {
  (eligibility_year + (enroll_year + 1 - season)) <= 4
}

#' Fit table: one row per program for one event
#'
#' Grain: one row per program x list (one list per division for the event).
#'
#' @param app_data Output of [load_app_data()].
#' @param event_code `"HJ"` or `"LJ"`.
#' @param athlete_mark_m The athlete's mark in metres.
#' @param divisions Divisions to include.
#' @param enroll_year Fall the athlete enrolls.
#' @param reach_threshold_m Threshold for "well above current level".
#' @param season Season to use; latest per division when `NULL`.
#' @return A tibble with program details, metrics, completeness flags and
#'   `fit_read`.
#' @export
fit_table <- function(
  app_data,
  event_code,
  athlete_mark_m,
  divisions = c("D1", "D2"),
  enroll_year = 2027,
  reach_threshold_m,
  season = NULL
) {
  lists <- select_lists(app_data$event_lists, event_code, divisions, season) |>
    dplyr::mutate(rank_complete = compare_marks(athlete_mark_m, .data$floor_mark_m) >= 0)

  relative <- app_data$athlete_marks |>
    dplyr::filter(.data$list_id %in% lists$list_id) |>
    dplyr::mutate(
      vs_athlete = compare_marks(.data$mark_m, athlete_mark_m),
      stays = in_school_at_arrival(.data$eligibility_year, .data$season, enroll_year)
    ) |>
    dplyr::group_by(.data$list_id, .data$program_id) |>
    dplyr::summarise(
      ahead_now = sum(.data$vs_athlete == 1L),
      level_now = sum(.data$vs_athlete == 0L),
      ahead_at_arrival = sum(.data$vs_athlete == 1L & .data$stays, na.rm = TRUE),
      .groups = "drop"
    )

  app_data$program_events |>
    dplyr::filter(.data$list_id %in% lists$list_id) |>
    dplyr::left_join(relative, by = c("list_id", "program_id"), relationship = "one-to-one") |>
    dplyr::left_join(
      lists |> dplyr::select("list_id", "rank_complete", "floor_mark_m"),
      by = "list_id",
      relationship = "many-to-one"
    ) |>
    dplyr::left_join(
      app_data$programs |> dplyr::select("program_id", "school_name", "conference", "state", "tfrrs_team_url"),
      by = "program_id",
      relationship = "many-to-one"
    ) |>
    dplyr::mutate(
      is_listed = .data$coverage_state == "listed",
      ahead_now = dplyr::if_else(.data$is_listed, .data$ahead_now, NA_integer_),
      level_now = dplyr::if_else(.data$is_listed, .data$level_now, NA_integer_),
      ahead_at_arrival = dplyr::if_else(.data$is_listed, .data$ahead_at_arrival, NA_integer_),
      rank_now = .data$ahead_now + 1L,
      gap_to_top_m = round(.data$top_mark_m - athlete_mark_m, 2),
      fit_read = fit_read_code(
        .data$coverage_state, .data$gap_to_top_m, .data$rank_now,
        .data$rank_complete, reach_threshold_m
      ),
      fit_read = factor(.data$fit_read, levels = fit_read_codes())
    ) |>
    dplyr::select(-"is_listed") |>
    # Within each fit read, programs closest to the athlete's level first.
    dplyr::arrange(.data$fit_read, abs(.data$gap_to_top_m), .data$school_name)
}

#' National standing of a mark on each division's list
#'
#' @inheritParams fit_table
#' @return One row per division list: `rank` (1 + marks better), `tied`,
#'   `list_size`, `complete` (FALSE when the mark is below the floor).
#' @export
national_standing <- function(app_data, event_code, athlete_mark_m, divisions = c("D1", "D2"), season = NULL) {
  lists <- select_lists(app_data$event_lists, event_code, divisions, season)

  app_data$athlete_marks |>
    dplyr::filter(.data$list_id %in% lists$list_id) |>
    dplyr::mutate(vs_athlete = compare_marks(.data$mark_m, athlete_mark_m)) |>
    dplyr::group_by(.data$list_id) |>
    dplyr::summarise(
      better = sum(.data$vs_athlete == 1L),
      tied = sum(.data$vs_athlete == 0L),
      .groups = "drop"
    ) |>
    dplyr::right_join(lists, by = "list_id") |>
    dplyr::mutate(
      complete = compare_marks(athlete_mark_m, .data$floor_mark_m) >= 0,
      rank = .data$better + 1L
    ) |>
    dplyr::select(
      "list_id", "division", "season", "event_code", "rank", "tied", "complete",
      "list_size", "floor_mark_m", "top_mark_m", "latest_meet_date", "parsed_at", "source_url"
    )
}

#' Evidence rows behind one program's fit read
#'
#' The program's listed athletes for the list, with the athlete's mark
#' slotted in at its rank. Grain: one row per listed athlete, plus one row
#' for the athlete.
#'
#' @inheritParams fit_table
#' @param program_id TFRRS team slug.
#' @param list_id List identifier, e.g. `2026_outdoor_D1_HJ`.
#' @param athlete_label Name shown on the athlete's row.
#' @export
program_evidence <- function(app_data, program_id, list_id, athlete_mark_m, enroll_year = 2027, athlete_label = "You") {
  listed <- app_data$athlete_marks |>
    dplyr::filter(.data$program_id == .env$program_id, .data$list_id == .env$list_id) |>
    dplyr::mutate(
      is_athlete = FALSE,
      in_school_at_arrival = in_school_at_arrival(.data$eligibility_year, .data$season, enroll_year)
    )

  you <- tibble::tibble(
    athlete_name = athlete_label,
    class_code = "HS 2027",
    mark_m = athlete_mark_m,
    wind_mps = NA_real_,
    wind_status = NA_character_,
    meet_name = NA_character_,
    meet_date = as.Date(NA),
    is_athlete = TRUE,
    in_school_at_arrival = NA
  )

  dplyr::bind_rows(listed, you) |>
    dplyr::arrange(dplyr::desc(.data$mark_m), .data$is_athlete) |>
    dplyr::select(
      "athlete_name", "class_code", "mark_m", "wind_mps", "wind_status",
      "meet_name", "meet_date", "in_school_at_arrival", "is_athlete"
    )
}
