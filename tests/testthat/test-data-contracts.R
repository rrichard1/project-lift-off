# Contracts on the committed tables in inst/extdata/ (SPEC §5).
# These run against real data, so a bad rebuild fails here before it ships.

test_that("built tables load and meet their contracts", {
  d <- load_app_data()
  expect_silent(validate_app_tables(d))
})

test_that("program ids are TFRRS slugs and the Florida trap holds", {
  d <- load_app_data()
  expect_true(all(grepl("^[A-Z]{2}_college_m_", d$programs$program_id)))

  names_for <- function(id) {
    unlist(strsplit(d$programs$list_team_name[d$programs$program_id == id], "; ", fixed = TRUE))
  }
  expect_equal(names_for("FL_college_m_Florida"), "Florida")
  expect_false("Florida" %in% names_for("FL_college_m_Florida_AM"))
})

test_that("absence is explicit: every program has a row for every list in its division", {
  d <- load_app_data()
  per_program <- dplyr::count(d$program_events, program_id)
  expect_true(all(per_program$n == nrow(dplyr::filter(d$event_lists, division == "D1"))))
  expect_true(all(is.na(d$program_events$top_mark_m[d$program_events$listed_count == 0])))
})

test_that("verified states come only from the ledger", {
  d <- load_app_data()
  verified <- dplyr::filter(d$program_events, startsWith(coverage_state, "verified"))
  expect_true(all(!is.na(verified$ledger_status)))
})

test_that("horizontal-jump marks carry a wind status", {
  d <- load_app_data()
  lj <- dplyr::filter(d$athlete_marks, event_code == "LJ")
  expect_true(all(lj$wind_status %in% c("legal", "aided", "unknown")))
  hj <- dplyr::filter(d$athlete_marks, event_code == "HJ")
  expect_true(all(hj$wind_status == "not_applicable"))
})

test_that("build info matches the tables", {
  d <- load_app_data()
  expect_equal(d$build_info$row_counts$programs, nrow(d$programs))
  expect_equal(d$build_info$row_counts$athlete_marks, nrow(d$athlete_marks))
})
