# Small presentational helpers shared by modules. Text comes from copy.R.

#' Format a date as "May 17, 2026"
#' @noRd
fmt_date <- function(x) {
  x <- as.Date(x)
  out <- paste0(format(x, "%B"), " ", as.integer(format(x, "%d")), ", ", format(x, "%Y"))
  out[is.na(x)] <- NA_character_
  out
}

#' Fit-read badge
#' @noRd
fit_badge <- function(code) {
  code <- as.character(code)
  htmltools::span(
    class = paste0("lo-badge lo-badge--", code),
    title = unname(copy_fit_read_help[code]),
    unname(copy_fit_read_label[code])
  )
}

#' Summary card
#' @noRd
kpi_card <- function(label, value, note = NULL, modifier = NULL) {
  htmltools::div(
    class = paste(c("lo-kpi", if (!is.null(modifier)) paste0("lo-kpi--", modifier)), collapse = " "),
    htmltools::div(class = "lo-kpi__label", label),
    htmltools::div(class = "lo-kpi__value", value),
    if (!is.null(note)) htmltools::div(class = "lo-kpi__note", note)
  )
}

#' Two-line mark: metres over feet-inches
#' @noRd
mark_cell <- function(m, wind_status = NA_character_, wind_mps = NA_real_) {
  if (is.na(m)) return(htmltools::span(class = "lo-muted", "\u2014"))
  htmltools::div(
    class = "lo-mark",
    htmltools::span(class = "lo-mark__m", formatC(m, format = "f", digits = 2), " m"),
    htmltools::span(class = "lo-mark__ftin", format_ft_in(m)),
    if (!is.na(wind_status) && wind_status == "aided") {
      htmltools::span(class = "lo-wind", title = "Wind-aided mark", paste0("w +", formatC(wind_mps, format = "f", digits = 1)))
    }
  )
}

# ---- Vectorised HTML for table cells -------------------------------------
# Building strings once per render is far faster than one tag object per cell.

esc <- function(x) htmltools::htmlEscape(x)

#' @noRd
html_program <- function(name, state, division) {
  paste0(
    '<div class="lo-prog__name">', esc(name), "</div>",
    '<div class="lo-prog__meta">', esc(state), " \u00b7 ", esc(division), "</div>"
  )
}

#' @noRd
html_fit_badge <- function(code) {
  code <- as.character(code)
  paste0(
    '<span class="lo-badge lo-badge--', code, '" title="', esc(unname(copy_fit_read_help[code])), '">',
    esc(unname(copy_fit_read_label[code])), "</span>"
  )
}

#' @noRd
html_rank <- function(main, sub) {
  paste0(
    '<div class="lo-rank"><span class="lo-rank__main">', esc(main), "</span>",
    '<span class="lo-rank__sub">', esc(sub), "</span></div>"
  )
}

#' @noRd
html_mark <- function(m) {
  ifelse(
    is.na(m),
    '<span class="lo-muted">\u2014</span>',
    paste0(
      '<div class="lo-mark"><span class="lo-mark__m">', formatC(m, format = "f", digits = 2), " m</span>",
      '<span class="lo-mark__ftin">', esc(format_ft_in(m)), "</span></div>"
    )
  )
}

#' @noRd
html_gap <- function(gap_m) {
  sign <- ifelse(gap_m > 0, "+", ifelse(gap_m < 0, "\u2212", ""))
  ifelse(
    is.na(gap_m),
    '<span class="lo-muted">\u2014</span>',
    paste0('<span class="lo-num">', sign, formatC(abs(gap_m), format = "f", digits = 2), "</span>")
  )
}

#' Horizontal strip showing how programs split across fit reads
#'
#' @param counts Named integer vector of program counts by fit-read code.
#' @noRd
fit_strip <- function(counts) {
  counts <- counts[counts > 0]
  total <- sum(counts)
  if (total == 0) return(NULL)

  segments <- purrr::imap(counts, \(n, code) {
    htmltools::div(
      class = paste0("lo-strip__seg lo-seg--", code),
      style = paste0("flex-grow:", n, ";"),
      title = paste0(copy_fit_read_label[[code]], ": ", n)
    )
  })

  legend <- purrr::imap(counts, \(n, code) {
    htmltools::div(
      class = "lo-strip__key",
      htmltools::span(class = paste0("lo-strip__dot lo-seg--", code)),
      htmltools::span(class = "lo-strip__name", copy_fit_read_label[[code]]),
      htmltools::span(class = "lo-strip__n", n)
    )
  })

  htmltools::div(
    class = "lo-strip",
    htmltools::div(class = "lo-strip__bar", unname(segments)),
    htmltools::div(class = "lo-strip__legend", unname(legend))
  )
}
