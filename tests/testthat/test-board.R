# Target board: shortlist, championship evidence, private outreach files.
# See docs/SPEC.md section 5 and DECISIONS D-007 to D-009.

test_that("championship results standardise and match programs", {
  cm <- build_championship_marks(fixture_raw_results(), fixture_registry(), fixture_crosswalk())
  expect_equal(unique(cm$program_id), "TX_college_m_Delta")
  expect_equal(unique(cm$division), "D2")
  expect_equal(unique(cm$meet_id), "2026_outdoor_D2_champs")
  nh <- dplyr::filter(cm, result_status == "no_height")
  expect_true(is.na(nh$mark_m))
  expect_true(is.na(nh$wind_status))
  expect_equal(unique(cm$wind_status[cm$result_status == "mark"]), "not_applicable")
})

test_that("results with a mark that disagrees with their status stop the build", {
  bad <- fixture_raw_results()
  bad$mark_m[3] <- "1.95"
  expect_error(standardize_results(bad), "disagrees")

  bad <- fixture_raw_results()
  bad$result_status[1] <- "scratched"
  expect_error(standardize_results(bad), "Unknown result status")
})

test_that("unmatched championship team names stop the build", {
  bad <- fixture_raw_results()
  bad$team[1] <- "Nowhere State"
  expect_error(build_championship_marks(bad, fixture_registry(), fixture_crosswalk()), "did not match")
})

test_that("board rows resolve from the lists, else the registry", {
  d <- fixture_board_data()
  b <- d$board
  expect_equal(nrow(b), 3)
  expect_equal(b$board_group, c("established_group", "smaller_group", "division_ii"))

  delta <- dplyr::filter(b, program_id == "TX_college_m_Delta")
  expect_false(delta$on_lists)
  expect_equal(delta$school_name, "Delta")
  expect_equal(delta$state, "TX")

  beta <- dplyr::filter(b, program_id == "AL_college_m_Beta")
  expect_true(beta$on_lists)
  expect_equal(beta$school_name, "Beta University")
})

test_that("bad board rows stop the build", {
  t <- fixture_tables()
  build <- function(m) build_board(m, t$programs, fixture_registry())

  m <- fixture_board_manual()
  m$program_id[1] <- "ZZ_college_m_Nowhere"
  expect_error(build(m), "not found")

  m <- fixture_board_manual()
  m$program_id[2] <- m$program_id[1]
  expect_error(build(m), "twice")

  m <- fixture_board_manual()
  m$board_group[1] <- "dream_school"
  expect_error(build(m), "Unknown board group")

  m <- fixture_board_manual()
  m$division[1] <- "D2"
  expect_error(build(m), "disagrees with the lists")
})

test_that("board fit rows carry list metrics, or championship evidence with no list", {
  d <- fixture_board_data()
  bf <- board_fit_table(d, "HJ", 2.03, enroll_year = 2027, reach_threshold_m = 0.15)

  beta <- dplyr::filter(bf, program_id == "AL_college_m_Beta")
  expect_true(beta$has_list)
  expect_equal(as.character(beta$fit_read), "top_three")
  expect_equal(beta$rank_now, 2L)

  delta <- dplyr::filter(bf, program_id == "TX_college_m_Delta")
  expect_false(delta$has_list)
  expect_true(is.na(delta$fit_read))
  expect_true(is.na(delta$rank_now))       # no list: never rank #1
  expect_equal(delta$champs_finalists, 3L)
  expect_equal(delta$champs_best_m, 2.15)
  expect_equal(delta$champs_best_place, 1L)
})

test_that("championship evidence slots the athlete in and keeps no-heights last", {
  d <- fixture_board_data()
  ev <- championship_evidence(d, "TX_college_m_Delta", "HJ", 2.03, athlete_label = "You")
  expect_equal(ev$athlete_name, c("D, One", "You", "D, Two", "D, Three"))

  st <- championship_standing(d, "HJ", 2.03)
  expect_equal(st$place_equiv, 2L)
  expect_equal(st$field, 3L)
})

test_that("board strips use list marks where loaded and finals otherwise", {
  d <- fixture_board_data()
  bm <- board_marks(d, "HJ", enroll_year = 2027)
  expect_setequal(unique(bm$evidence[bm$program_id == "TX_college_m_Delta"]), "championship")
  expect_setequal(unique(bm$evidence[bm$program_id == "GA_college_m_Alpha"]), "list")
  expect_false(any(is.na(bm$mark_m)))   # no-heights are not plotted
})

test_that("missing private files load as empty tables with their schema", {
  p <- load_private_data(dir = tempfile("nothing-here"))
  expect_false(any(p$found))
  expect_equal(names(p$coach_contacts), private_schemas()$coach_contacts)
  expect_equal(nrow(p$outreach_log), 0)
  expect_length(p$problems, 0)
})

test_that("templates match the private schemas", {
  for (name in names(private_schemas())) {
    path <- app_sys("templates", paste0(name, ".csv"))
    expect_true(nzchar(path), label = name)
    expect_equal(names(readr::read_csv(path, col_types = readr::cols(), progress = FALSE)), private_schemas()[[name]])
  }
})

test_that("bad private rows are reported, not fatal", {
  log <- tibble::tribble(
    ~program_id, ~contact_date, ~direction, ~channel, ~coach_name, ~summary, ~next_step, ~next_step_date,
    "AL_college_m_Beta", "2026-11-16", "sent", "email", "Coach B", "Intro email", "Follow up", "2026-11-30",
    "AL_college_m_Beta", "Nov 20", "replied", "pigeon", "Coach B", "", "", "",
    "ZZ_college_m_Nowhere", "2026-11-18", "sent", "email", "", "", "", ""
  )
  p <- load_private_data(dir = fixture_private_dir(log = log), known_ids = fixture_board_manual()$program_id)
  expect_true(p$found[["outreach_log"]])
  expect_false(p$found[["coach_contacts"]])
  expect_true(any(grepl("row 2: direction", p$problems)))
  expect_true(any(grepl("row 2: channel", p$problems)))
  expect_true(any(grepl("row 2: contact_date", p$problems)))
  expect_true(any(grepl("row 3: program_id", p$problems)))
  expect_s3_class(p$outreach_log$contact_date, "Date")
})

test_that("outreach state comes from the latest logged contact", {
  board <- fixture_board_data()$board
  contacts <- tibble::tibble(program_id = c("AL_college_m_Beta", "GA_college_m_Alpha"), coach_name = c("Coach B", "Coach A"))
  log <- tibble::tibble(
    program_id = c("AL_college_m_Beta", "AL_college_m_Beta"),
    contact_date = as.Date(c("2026-11-16", "2026-11-20")),
    direction = c("sent", "received"),
    channel = c("email", "email"),
    next_step = c(NA, "Send indoor schedule"),
    next_step_date = as.Date(c(NA, "2026-12-01"))
  )
  o <- board_outreach(board, contacts, log)
  state <- stats::setNames(o$contact_state, o$program_id)
  expect_equal(state[["AL_college_m_Beta"]], "received")
  expect_equal(state[["GA_college_m_Alpha"]], "coach_on_file")
  expect_equal(state[["TX_college_m_Delta"]], "no_coach")
  expect_equal(o$replies[o$program_id == "AL_college_m_Beta"], 1L)
  expect_equal(o$next_step_date[o$program_id == "AL_college_m_Beta"], as.Date("2026-12-01"))
})

test_that("board copy avoids banned language", {
  s <- c(
    unname(copy_board_group_label), unname(copy_board_group_help), unname(copy_contact_label),
    copy_champs_sentence("Delta", "HJ", 3, 2.15, 1L, "2026 Test Championships"),
    copy_champs_sentence("Delta", "HJ", 1, NA, NA, "2026 Test Championships"),
    copy_champs_standing(2L, 3L, "2026 Test Championships", 2.00),
    copy_champs_standing(4L, 3L, "2026 Test Championships", 2.00)
  )
  expect_false(any(has_banned_language(s)))
  expect_equal(ordinal(c(1, 2, 3, 11, 12, 13, 21, 22)), c("1st", "2nd", "3rd", "11th", "12th", "13th", "21st", "22nd"))
})
