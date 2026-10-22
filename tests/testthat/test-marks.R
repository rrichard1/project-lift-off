test_that("feet-inches match TFRRS quarter-inch rounding", {
  expect_equal(format_ft_in(2.05), "6' 8.75\"")
  expect_equal(format_ft_in(2.03), "6' 8\"")
  expect_equal(format_ft_in(6.81), "22' 4\"")
  expect_equal(format_ft_in(2.31), "7' 7\"")
  expect_equal(format_ft_in(NA_real_), NA_character_)
})

test_that("format_mark shows metres and feet-inches", {
  expect_equal(format_mark(2.03), "2.03 m (6' 8\")")
})

test_that("format_gap signs and converts", {
  expect_equal(format_gap(0.14), "+0.14 m (5.5 in)")
  expect_equal(format_gap(-0.03), "−0.03 m (1.25 in)")
  expect_equal(format_gap(0), "±0.00 m (0 in)")
})

test_that("compare_marks treats centimetre ties as ties", {
  expect_equal(compare_marks(2.03, 2.0300000001), 0L)
  expect_equal(compare_marks(2.04, 2.03), 1L)
  expect_equal(compare_marks(c(2.02, 2.03), 2.03), c(-1L, 0L))
})
