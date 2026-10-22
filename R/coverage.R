# Coverage states for program x event rows.
#
# Every program x event x season x division row gets exactly one state, so
# absence is always explicit. See docs/SPEC.md section 5.

#' Statuses a person may record in data-raw/manual/verification_ledger.csv
#' @noRd
ledger_statuses <- function() {
  c(
    active_event_group = "Source shows current athletes in the event that the lists miss",
    no_marks_on_tfrrs = "TFRRS team page shows no marks in the event this season",
    no_event_group = "Roster or staff pages confirm no current event group"
  )
}

#' All coverage states, in display order
#' @noRd
coverage_states <- function() {
  c("listed", "verified_active", "none_listed", "verified_no_marks", "verified_no_event")
}

#' Assign a coverage state
#'
#' Rules:
#' * a ledger entry saying there is no event group always wins;
#' * otherwise, athletes on the list mean `listed`;
#' * with nobody listed, a ledger entry decides between `verified_active`
#'   and `verified_no_marks`; with no ledger entry the row is `none_listed`.
#'
#' Contradictions (a ledger says "no marks" but athletes are listed) are
#' caught by [check_ledger_conflicts()] at build time, not resolved here.
#'
#' @param listed_count Integer vector, athletes on the list for the program.
#' @param ledger_status Character vector from the ledger, `NA` if none.
#' @return Character vector of coverage states.
#' @noRd
coverage_state <- function(listed_count, ledger_status) {
  dplyr::case_when(
    ledger_status %in% "no_event_group" ~ "verified_no_event",
    listed_count > 0 ~ "listed",
    ledger_status %in% "active_event_group" ~ "verified_active",
    ledger_status %in% "no_marks_on_tfrrs" ~ "verified_no_marks",
    .default = "none_listed"
  )
}

#' Find ledger rows that contradict the lists
#'
#' @param program_events Table with `listed_count` and `ledger_status`.
#' @return Rows where a person recorded "no marks" or "no event group" but
#'   athletes from the program are on the list.
#' @noRd
check_ledger_conflicts <- function(program_events) {
  program_events |>
    dplyr::filter(
      .data$listed_count > 0,
      .data$ledger_status %in% c("no_marks_on_tfrrs", "no_event_group")
    )
}
