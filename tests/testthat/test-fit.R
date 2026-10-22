fit_for <- function(event, mark, reach) {
  t <- fixture_tables()
  fit_table(t, event, mark, divisions = "D1", enroll_year = 2027, reach_threshold_m = reach)
}

read_of <- function(fit, program_id) {
  as.character(fit$fit_read[fit$program_id == program_id])
}

test_that("fit reads follow SPEC §7 rule order", {
  f <- fit_for("HJ", 2.03, reach = 0.15)
  expect_equal(read_of(f, "GA_college_m_Alpha"), "well_above")   # gap 0.17
  expect_equal(read_of(f, "AL_college_m_Beta"), "top_three")     # one better jumper
  expect_equal(read_of(f, "FL_college_m_Gamma"), "none_listed")  # nobody listed

  f <- fit_for("HJ", 2.03, reach = 0.30)
  expect_equal(read_of(f, "GA_college_m_Alpha"), "top_three")    # 2 better -> #3

  f <- fit_for("HJ", 2.25, reach = 0.15)
  expect_equal(read_of(f, "GA_college_m_Alpha"), "would_lead")
})

test_that("missing data never reads as leading the group", {
  for (mark in c(1.50, 2.03, 2.50)) {
    f <- fit_for("HJ", mark, reach = 0.15)
    gamma <- dplyr::filter(f, program_id == "FL_college_m_Gamma")
    expect_equal(as.character(gamma$fit_read), "none_listed")
    expect_true(is.na(gamma$rank_now))
  }
})

test_that("below the list floor, ranks are lower bounds", {
  f <- fit_for("HJ", 1.90, reach = 1)
  alpha <- dplyr::filter(f, program_id == "GA_college_m_Alpha")
  beta <- dplyr::filter(f, program_id == "AL_college_m_Beta")
  expect_false(alpha$rank_complete)
  expect_equal(alpha$rank_now, 5L)
  expect_equal(as.character(alpha$fit_read), "depth")      # >= 4 even as a lower bound
  expect_equal(as.character(beta$fit_read), "cant_tell")   # #2 or lower: unknown

  f <- fit_for("LJ", 6.81, reach = 1)
  expect_true(all(as.character(f$fit_read) %in% c("cant_tell", "none_listed", "depth")))
})

test_that("ties count as level, not ahead", {
  f <- fit_for("HJ", 2.05, reach = 1)
  beta <- dplyr::filter(f, program_id == "AL_college_m_Beta")
  expect_equal(beta$ahead_now, 0L)
  expect_equal(beta$level_now, 1L)
  expect_equal(as.character(beta$fit_read), "would_lead")
})

test_that("arrival counts drop athletes who graduate before fall 2027", {
  f <- fit_for("HJ", 2.03, reach = 1)
  alpha <- dplyr::filter(f, program_id == "GA_college_m_Alpha")
  expect_equal(alpha$ahead_now, 2L)          # SR 2.20, FR 2.10
  expect_equal(alpha$ahead_at_arrival, 1L)   # only the freshman remains
  expect_true(in_school_at_arrival(2L, 2026L, 2027L))
  expect_false(in_school_at_arrival(3L, 2026L, 2027L))
})

test_that("national standing reports rank and completeness", {
  t <- fixture_tables()
  s <- national_standing(t, "HJ", 2.03, divisions = "D1")
  expect_equal(s$rank, 4L)
  expect_equal(s$list_size, 5L)
  expect_true(s$complete)

  s <- national_standing(t, "LJ", 6.81, divisions = "D1")
  expect_false(s$complete)
})

test_that("evidence slots the athlete into the program's list", {
  t <- fixture_tables()
  ev <- program_evidence(t, "GA_college_m_Alpha", "2026_outdoor_D1_HJ", 2.03)
  expect_equal(nrow(ev), 5)
  expect_equal(which(ev$is_athlete), 3L)
})
