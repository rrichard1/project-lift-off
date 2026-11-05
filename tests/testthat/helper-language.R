# Language rules (CLAUDE.md rule 3), shared by test-copy.R and the board
# data contracts. Do not weaken these patterns to make a string pass; reword
# the string.

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

has_banned_language <- function(x) {
  grepl(paste(banned_patterns, collapse = "|"), x, ignore.case = TRUE)
}
