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

test_that("the committed board meets its contracts", {
  d <- load_app_data()
  expect_silent(validate_board_tables(d))
  expect_setequal(unique(d$board$board_group), board_groups())
  # Division I board programs are all on a loaded list today.
  expect_true(all(d$board$on_lists[d$board$division == "D1"]))
  # Every championship program on the board has results behind it.
  d2 <- d$board$program_id[d$board$division == "D2"]
  expect_true(all(d2 %in% d$championship_marks$program_id))
})

test_that("board notes follow the language rules", {
  d <- load_app_data()
  bad <- d$board$board_note[has_banned_language(d$board$board_note)]
  expect_equal(bad, character(), label = paste(bad, collapse = "\n"))
})

test_that("private outreach files are never committed", {
  path <- testthat::test_path("..", "..", ".gitignore")
  skip_if_not(file.exists(path), "source files not available (installed package)")
  expect_true("inst/private/" %in% readLines(path, warn = FALSE))
})
