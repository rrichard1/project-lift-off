# Small synthetic inputs for pipeline and fit tests.

fixture_raw_lists <- function() {
  tibble::tribble(
    ~division, ~season, ~list_year, ~event_code, ~place, ~athlete, ~class_code, ~eligibility_year, ~team, ~mark_m, ~wind, ~meet, ~meet_date, ~source_url, ~parsed_at,
    "NCAA DI", "Outdoor", "2026", "HJ", "1", "A, One", "SR-4", "4", "Alpha", "2.20", NA, "Meet", "2026-05-01", "https://example.test/list", "2026-05-22T00:00:00Z",
    "NCAA DI", "Outdoor", "2026", "HJ", "2", "A, Two", "FR-1", "1", "Alpha", "2.10", NA, "Meet", "2026-05-01", "https://example.test/list", "2026-05-22T00:00:00Z",
    "NCAA DI", "Outdoor", "2026", "HJ", "3", "B, One", "SO-2", "2", "Beta U.", "2.05", NA, "Meet", "2026-05-01", "https://example.test/list", "2026-05-22T00:00:00Z",
    "NCAA DI", "Outdoor", "2026", "HJ", "4", "A, Three", "JR-3", "3", "Alpha", "2.00", NA, "Meet", "2026-05-01", "https://example.test/list", "2026-05-22T00:00:00Z",
    "NCAA DI", "Outdoor", "2026", "HJ", "5", "A, Three", "JR-3", "3", "Alpha", "1.98", NA, "Meet", "2026-04-01", "https://example.test/list", "2026-05-22T00:00:00Z",
    "NCAA DI", "Outdoor", "2026", "HJ", "6", "A, Four", "SO-2", "2", "Alpha", "1.95", NA, "Meet", "2026-05-01", "https://example.test/list", "2026-05-22T00:00:00Z",
    "NCAA DI", "Outdoor", "2026", "LJ", "1", "C, One", "SO-2", "2", "Gamma", "7.50", "2.4", "Meet", "2026-05-01", "https://example.test/list", "2026-05-22T00:00:00Z",
    "NCAA DI", "Outdoor", "2026", "LJ", "2", "A, Five", "FR-1", "1", "Alpha", "7.00", "1.0", "Meet", "2026-05-01", "https://example.test/list", "2026-05-22T00:00:00Z",
    "NCAA DI", "Outdoor", "2026", "LJ", "3", "C, Two", "FR-1", "1", "Gamma", "6.95", NA, "Meet", "2026-05-01", "https://example.test/list", "2026-05-22T00:00:00Z"
  )
}

fixture_registry <- function() {
  tibble::tribble(
    ~school_name, ~state_abbrev, ~tfrrs_team_url,
    "Alpha", "GA", "https://www.tfrrs.org/teams/tf/GA_college_m_Alpha.html",
    "Beta University", "AL", "https://www.tfrrs.org/teams/tf/AL_college_m_Beta.html",
    "Gamma", "FL", "https://www.tfrrs.org/teams/tf/FL_college_m_Gamma.html",
    "Delta", "TX", "https://www.tfrrs.org/teams/tf/TX_college_m_Delta.html"
  )
}

fixture_crosswalk <- function() {
  tibble::tibble(list_team_name = "Beta U.", registry_school_name = "Beta University", notes = "test")
}

fixture_ledger <- function(rows = NULL) {
  base <- tibble::tibble(
    program_id = character(), event_code = character(), season = character(),
    status = character(), checked_on = character(), checked_by = character(),
    source_url = character(), notes = character()
  )
  if (is.null(rows)) base else dplyr::bind_rows(base, rows)
}

fixture_tables <- function(ledger = fixture_ledger()) {
  build_app_tables(fixture_raw_lists(), fixture_registry(), fixture_crosswalk(), ledger)
}
