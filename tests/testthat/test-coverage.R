test_that("coverage states follow the documented rules", {
  expect_equal(
    coverage_state(
      listed_count = c(3L, 0L, 0L, 0L, 0L, 2L),
      ledger_status = c(NA, NA, "active_event_group", "no_marks_on_tfrrs", "no_event_group", "active_event_group")
    ),
    c("listed", "none_listed", "verified_active", "verified_no_marks", "verified_no_event", "listed")
  )
})

test_that("every coverage state and fit read has copy", {
  expect_setequal(names(copy_coverage_label), coverage_states())
  expect_setequal(names(copy_fit_read_label), fit_read_codes())
  expect_setequal(names(copy_fit_read_help), fit_read_codes())
})
