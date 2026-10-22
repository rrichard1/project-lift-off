# Mark conversion and formatting.
# All marks are stored in metres. Feet-inches are display-only and rounded to
# the nearest quarter inch, matching TFRRS (2.05 m -> 6' 8.75").

METRES_PER_INCH <- 0.0254

#' Round metres to the nearest quarter inch
#'
#' @param m Numeric vector of marks in metres.
#' @return Numeric vector of inches, rounded to the nearest 0.25.
#' @noRd
m_to_quarter_inches <- function(m) {
  round(m / METRES_PER_INCH * 4) / 4
}

#' Format inches as a compact string ("8", "8.5", "8.75")
#' @noRd
format_inches_value <- function(x) {
  out <- formatC(x, format = "f", digits = 2)
  out <- sub("0+$", "", out)
  sub("\\.$", "", out)
}

#' Format a mark in metres as feet and inches
#'
#' @param m Numeric vector of marks in metres.
#' @return Character vector like `6' 8"`; `NA` where `m` is `NA`.
#' @export
#' @examples
#' format_ft_in(c(2.03, 2.05, 6.81))
format_ft_in <- function(m) {
  inches <- m_to_quarter_inches(m)
  feet <- floor(inches / 12)
  rem <- inches - feet * 12
  out <- paste0(feet, "' ", format_inches_value(rem), "\"")
  out[is.na(m)] <- NA_character_
  out
}

#' Format a mark as metres with feet-inches
#'
#' @param m Numeric vector of marks in metres.
#' @return Character vector like `2.03 m (6' 8")`.
#' @export
format_mark <- function(m) {
  out <- paste0(formatC(m, format = "f", digits = 2), " m (", format_ft_in(m), ")")
  out[is.na(m)] <- NA_character_
  out
}

#' Format a difference between two marks
#'
#' @param gap_m Numeric vector, program best minus athlete mark, in metres.
#' @return Character vector like `+0.14 m (5.5 in)` or `-0.03 m (1.25 in)`.
#' @export
format_gap <- function(gap_m) {
  sign <- ifelse(gap_m > 0, "+", ifelse(gap_m < 0, "\u2212", "\u00b1"))
  inches <- m_to_quarter_inches(abs(gap_m))
  out <- paste0(
    sign,
    formatC(abs(gap_m), format = "f", digits = 2),
    " m (",
    format_inches_value(inches),
    " in)"
  )
  out[is.na(gap_m)] <- NA_character_
  out
}

#' Compare marks at list precision
#'
#' TFRRS lists report jumps to the centimetre. Comparing rounded values keeps
#' floating-point noise from turning a tie into a loss.
#'
#' @param a,b Numeric marks in metres.
#' @return Integer vector: 1 if `a` is better, 0 if tied, -1 if worse.
#' @noRd
compare_marks <- function(a, b) {
  a_cm <- round(a * 100)
  b_cm <- round(b * 100)
  as.integer(sign(a_cm - b_cm))
}
