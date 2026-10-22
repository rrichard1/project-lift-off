# Language rules (CLAUDE.md rule 3). Do not weaken these patterns to make a
# string pass; reword the string.

banned_patterns <- c(
  "scholarship",
  "\\boffers?\\b",
  "\\bopenings?\\b",
  "roster spot",
  "\\bneeds?\\b",
  "\\blikel(y|ihood)\\b",
  "guarantee",
  "opportunit",
  "will recruit",
  "coach(es)? (want|plan|intend)"
)

string_literals <- function(path) {
  lines <- readLines(path, warn = FALSE)
  lines <- lines[!grepl("^\\s*#", lines)]
  unlist(regmatches(lines, gregexpr("\"([^\"\\\\]|\\\\.)*\"", lines)))
}

ui_files <- function() {
  root <- testthat::test_path("..", "..")
  c(
    list.files(file.path(root, "R"), pattern = "^(copy|mod_.*|ui_.*|app_ui|app_server)\\.R$", full.names = TRUE),
    list.files(file.path(root, "inst", "app", "www"), full.names = TRUE)
  )
}

test_that("user-facing strings avoid banned language", {
  files <- ui_files()
  skip_if(length(files) == 0, "source files not available (installed package)")

  hits <- purrr::map(files, \(f) {
    strings <- string_literals(f)
    bad <- strings[grepl(paste(banned_patterns, collapse = "|"), strings, ignore.case = TRUE)]
    if (length(bad) > 0) paste0(basename(f), ": ", bad)
  }) |> unlist()

  expect_equal(hits, NULL, label = paste(hits, collapse = "\n"))
})

test_that("rank text states completeness and ties", {
  expect_equal(copy_rank_main(c(2L, NA)), c("#2", "—"))
  expect_equal(
    copy_rank_sub(listed_count = c(4L, 4L, 2L, 0L), rank_complete = c(TRUE, TRUE, FALSE, TRUE), level_now = c(0L, 1L, 0L, NA)),
    c("of 5", "of 5 · tied", "or lower", "")
  )
  expect_match(copy_fit_sentence("Alpha", "HJ", "would_lead", 1L, 2L, TRUE, 0, 1.90, level_now = 1L), "tied for #1")
})

test_that("generated sentences avoid banned language", {
  s <- c(
    copy_fit_sentence("Alpha", "HJ", "top_three", 2L, 3L, TRUE, 0.05, 1.90),
    copy_fit_sentence("Alpha", "LJ", "cant_tell", 2L, 1L, FALSE, -0.10, 6.95),
    copy_fit_sentence("Alpha", "HJ", "none_listed", NA, 0L, TRUE, NA, 1.90),
    unname(copy_fit_read_help)
  )
  expect_false(any(grepl(paste(banned_patterns, collapse = "|"), s, ignore.case = TRUE)))
})
