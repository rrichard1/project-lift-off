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

# ---- Target Board ---------------------------------------------------------

#' @noRd
html_board_group <- function(code) {
  paste0(
    '<span class="lo-group lo-group--', code, '" title="', esc(unname(copy_board_group_help[code])), '">',
    esc(unname(copy_board_group_label[code])), "</span>"
  )
}

#' Fit-read badge, or a neutral label when the program has no loaded list
#' @noRd
html_board_fit <- function(code, has_list) {
  out <- rep(
    paste0('<span class="lo-badge lo-badge--no_list" title="', esc(copy_board$no_list_help), '">', esc(copy_board$no_list), "</span>"),
    length(has_list)
  )
  show <- has_list & !is.na(code)
  out[show] <- html_fit_badge(code[show])
  out
}

#' @noRd
html_contact <- function(state, text) {
  paste0('<span class="lo-contact lo-contact--', state, '">', esc(text), "</span>")
}

#' Scale for a board strip: the event's visible marks plus the athlete's
#' @noRd
strip_scale <- function(marks, athlete_mark_m) {
  all <- c(marks, athlete_mark_m)
  lo <- min(all, na.rm = TRUE)
  hi <- max(all, na.rm = TRUE)
  pad <- max((hi - lo) * 0.04, 0.02)
  c(lo = lo - pad, hi = hi + pad)
}

#' Bar-height strip: one dot per jumper, a line at the athlete's mark
#'
#' Filled dots are jumpers still in school in the athlete's first season,
#' hollow dots are not (context only, D-006).
#'
#' @param program_ids Board rows, in table order.
#' @param marks `board_marks()` output.
#' @param athlete_mark_m Athlete's mark.
#' @param scale Named `lo`, `hi` from [strip_scale()].
#' @return Character vector of HTML, one per program.
#' @noRd
html_mark_strip <- function(program_ids, marks, athlete_mark_m, scale) {
  pct <- function(m) formatC((m - scale[["lo"]]) / (scale[["hi"]] - scale[["lo"]]) * 100, format = "f", digits = 2)
  you <- paste0('<i class="lo-strip2__you" style="left:', pct(athlete_mark_m), '%"></i>')

  by_program <- split(marks, marks$program_id)
  vapply(program_ids, \(id) {
    m <- by_program[[id]]
    if (is.null(m) || nrow(m) == 0) {
      return(paste0('<div class="lo-strip2 lo-strip2--empty">', you, "</div>"))
    }
    # Stack tied marks a few pixels apart so each jumper stays visible.
    m <- m[order(-m$mark_m), ]
    tie_rank <- stats::ave(m$mark_m, m$mark_m, FUN = seq_along) - 1
    offset <- ifelse(tie_rank == 0, 0, ifelse(tie_rank %% 2 == 1, -1, 1) * ceiling(tie_rank / 2) * 7)
    dots <- paste0(
      '<i class="lo-strip2__dot', ifelse(m$in_school %in% FALSE, " lo-strip2__dot--out", ""), '" ',
      'style="left:', pct(m$mark_m), "%;top:calc(50% + ", offset, 'px)" ',
      'title="', formatC(m$mark_m, format = "f", digits = 2), " m · ", esc(m$class_code), '"></i>',
      collapse = ""
    )
    paste0('<div class="lo-strip2"><i class="lo-strip2__base"></i>', you, dots, "</div>")
  }, character(1), USE.NAMES = FALSE)
}

#' Legend for the board strip
#' @noRd
strip_legend <- function() {
  htmltools::div(
    class = "lo-strip2-legend",
    htmltools::span(htmltools::tags$i(class = "lo-strip2__dot lo-strip2__dot--key"), copy_board$strip_in),
    htmltools::span(htmltools::tags$i(class = "lo-strip2__dot lo-strip2__dot--out lo-strip2__dot--key"), copy_board$strip_out),
    htmltools::span(htmltools::tags$i(class = "lo-strip2__you lo-strip2__you--key"), copy_board$strip_you)
  )
}
