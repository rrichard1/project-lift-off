test_that("vocabularies map correctly", {
  expect_equal(division_code(c("NCAA DI", "NCAA DII", "NAIA")), c("D1", "D2", NA))
  expect_equal(
    wind_status(c("HJ", "LJ", "LJ", "LJ"), c(NA, NA, 2.1, 2.0)),
    c("not_applicable", "unknown", "aided", "legal")
  )
  expect_equal(class_group(c("FR-1", "SR-4", "FR", "GR")), c("fr", "sr", "fr", NA))
  expect_equal(
    program_id_from_url("https://www.tfrrs.org/teams/tf/FL_college_m_Florida.html"),
    "FL_college_m_Florida"
  )
})

test_that("crosswalk resolves list names; unmatched names stop the build", {
  m <- match_list_teams(c("Alpha", "Beta U."), fixture_registry(), fixture_crosswalk())
  expect_equal(m$program_id, c("GA_college_m_Alpha", "AL_college_m_Beta"))

  expect_error(
    match_list_teams(c("Alpha", "Nowhere State"), fixture_registry(), fixture_crosswalk()),
    "did not match"
  )
})

test_that("the Florida trap: Florida never resolves to Florida A&M", {
  reg <- tibble::tribble(
    ~school_name, ~state_abbrev, ~tfrrs_team_url,
    "Florida", "FL", "https://www.tfrrs.org/teams/tf/FL_college_m_Florida.html",
    "Florida A&M", "FL", "https://www.tfrrs.org/teams/tf/FL_college_m_Florida_AM.html"
  )
  m <- match_list_teams(c("Florida", "Florida A&M"), reg, fixture_crosswalk()[0, ])
  expect_equal(m$program_id[m$list_team_name == "Florida"], "FL_college_m_Florida")
  expect_equal(m$program_id[m$list_team_name == "Florida A&M"], "FL_college_m_Florida_AM")
})

test_that("athlete marks keep one best entry per athlete per list", {
  t <- fixture_tables()
  three <- dplyr::filter(t$athlete_marks, athlete_name == "A, Three")
  expect_equal(nrow(three), 1)
  expect_equal(three$mark_m, 2.00)
})

test_that("program_events is a full cross with explicit coverage", {
  t <- fixture_tables()
  # 3 programs on lists (Delta never appears) x 2 lists
  expect_equal(nrow(t$programs), 3)
  expect_equal(nrow(t$program_events), 6)

  beta_lj <- dplyr::filter(t$program_events, program_id == "AL_college_m_Beta", event_code == "LJ")
  expect_equal(beta_lj$listed_count, 0L)
  expect_equal(beta_lj$coverage_state, "none_listed")
  expect_true(is.na(beta_lj$top_mark_m))
  expect_true(is.na(beta_lj$fr))
})

test_that("ledger entries set verified states and contradictions stop the build", {
  ok <- fixture_ledger(tibble::tibble(
    program_id = "AL_college_m_Beta", event_code = "LJ", season = "2026",
    status = "no_marks_on_tfrrs", checked_on = "2026-10-01", checked_by = "test",
    source_url = "x", notes = ""
  ))
  t <- fixture_tables(ok)
  beta_lj <- dplyr::filter(t$program_events, program_id == "AL_college_m_Beta", event_code == "LJ")
  expect_equal(beta_lj$coverage_state, "verified_no_marks")

  conflict <- dplyr::mutate(ok, program_id = "GA_college_m_Alpha")
  expect_error(fixture_tables(conflict), "contradicts")

  bad_status <- dplyr::mutate(ok, status = "probably_fine")
  expect_error(fixture_tables(bad_status), "Unknown ledger status")

  unknown_program <- dplyr::mutate(ok, program_id = "XX_college_m_Nope")
  expect_error(fixture_tables(unknown_program), "unknown program_id")
})

test_that("lists record their floor", {
  t <- fixture_tables()
  lj <- dplyr::filter(t$event_lists, event_code == "LJ")
  expect_equal(lj$floor_mark_m, 6.95)
  expect_equal(lj$list_size, 3L)
})
