#' Program Fit page UI
#'
#' @param id Module id.
#' @param athlete Athlete profile from [read_athlete_profile()].
#' @param events Event codes to offer (from golem-config).
#' @noRd
mod_program_fit_ui <- function(id, athlete, events = c("HJ", "LJ")) {
  ns <- shiny::NS(id)
  first_event <- events[[1]]

  bslib::layout_sidebar(
    fillable = FALSE,
    class = "lo-layout",
    sidebar = bslib::sidebar(
      width = 290,
      open = "desktop",
      class = "lo-sidebar",
      htmltools::h2(class = "lo-sidebar__title", copy_page$athlete_heading),
      shiny::radioButtons(
        ns("event"),
        copy_page$event_label,
        choices = stats::setNames(events, copy_event_names[events]),
        selected = first_event
      ),
      shiny::numericInput(
        ns("mark"),
        copy_page$mark_label,
        value = athlete$marks[[first_event]]$best_m,
        min = 0, max = 10, step = 0.01
      ),
      shiny::uiOutput(ns("mark_echo")),
      shiny::checkboxGroupInput(
        ns("divisions"),
        copy_page$division_label,
        choices = stats::setNames(c("D1", "D2"), copy_division_names[c("D1", "D2")]),
        selected = c("D1", "D2")
      ),
      shiny::selectizeInput(
        ns("states"),
        copy_page$state_label,
        choices = NULL,
        multiple = TRUE,
        options = list(placeholder = copy_page$state_placeholder)
      ),
      shiny::radioButtons(
        ns("show"),
        copy_page$read_label,
        choices = copy_page$show_choices,
        selected = "all"
      ),
      htmltools::p(class = "lo-note", copy_page$profile_note)
    ),
    htmltools::div(
      class = "lo-head",
      htmltools::h1(class = "lo-head__title", copy_page$title),
      htmltools::p(class = "lo-head__dek", copy_page$subtitle)
    ),
    shiny::uiOutput(ns("notice")),
    shiny::uiOutput(ns("kpis")),
    shiny::uiOutput(ns("strip")),
    bslib::layout_columns(
      col_widths = bslib::breakpoints(sm = c(12, 12), lg = c(7, 5)),
      class = "lo-main",
      bslib::card(
        class = "lo-card",
        bslib::card_header(class = "lo-card__head", copy_page$table_heading),
        reactable::reactableOutput(ns("table"))
      ),
      bslib::card(
        class = "lo-card lo-evidence",
        bslib::card_header(class = "lo-card__head", copy_page$evidence_heading),
        shiny::uiOutput(ns("evidence"))
      )
    ),
    htmltools::p(class = "lo-footer", copy_footer)
  )
}

#' Program Fit page server
#'
#' @param id Module id.
#' @param app_data Output of [load_app_data()].
#' @param athlete Athlete profile.
#' @param settings List with `reach_threshold_m` (named by event).
#' @noRd
mod_program_fit_server <- function(id, app_data, athlete, settings) {
  shiny::moduleServer(id, function(input, output, session) {
    # --- Inputs ----------------------------------------------------------------
    states <- sort(unique(stats::na.omit(app_data$programs$state)))
    shiny::updateSelectizeInput(session, "states", choices = states, server = TRUE)

    # The mark for each event lives in marks_store, keyed by event, so that
    # switching events never scores one event's list against the other
    # event's mark while the input box catches up.
    marks_store <- do.call(shiny::reactiveValues, purrr::map(athlete$marks, "best_m"))

    shiny::observeEvent(input$event, {
      shiny::updateNumericInput(session, "mark", value = marks_store[[input$event]])
    }, ignoreInit = TRUE)

    typed <- shiny::debounce(shiny::reactive(list(event = input$event, mark = input$mark)), 300)
    last_event <- shiny::reactiveVal(NULL)

    shiny::observeEvent(typed(), {
      t <- typed()
      switched <- !identical(t$event, last_event())
      last_event(t$event)
      # A value that arrives with an event switch is the old event's number.
      if (!switched && is.numeric(t$mark) && !is.na(t$mark)) {
        marks_store[[t$event]] <- t$mark
      }
    })

    mark <- shiny::reactive({
      m <- marks_store[[input$event]]
      shiny::validate(shiny::need(is.numeric(m) && !is.na(m) && m > 0 && m < 10, copy_page$mark_invalid))
      round(m, 2)
    })

    output$mark_echo <- shiny::renderUI({
      htmltools::p(class = "lo-mark-echo", format_ft_in(mark()))
    })

    divisions <- shiny::reactive({
      shiny::validate(shiny::need(length(input$divisions) > 0, copy_page$division_none))
      input$divisions
    })

    # --- Data --------------------------------------------------------------------
    fit_base <- shiny::reactive({
      out <- fit_table(
        app_data,
        event_code = input$event,
        athlete_mark_m = mark(),
        divisions = divisions(),
        enroll_year = athlete$enroll_year,
        reach_threshold_m = settings$reach_threshold_m[[input$event]]
      )
      if (length(input$states) > 0) out <- dplyr::filter(out, .data$state %in% input$states)
      out
    })

    fit_shown <- shiny::reactive({
      switch(input$show,
        listed = dplyr::filter(fit_base(), .data$coverage_state == "listed"),
        verify = dplyr::filter(fit_base(), .data$coverage_state != "listed"),
        fit_base()
      )
    })

    standing <- shiny::reactive({
      national_standing(app_data, input$event, mark(), divisions())
    })

    # --- Notice ----------------------------------------------------------------
    output$notice <- shiny::renderUI({
      loaded <- unique(app_data$event_lists$division)
      missing <- setdiff(divisions(), loaded)
      if (length(missing) == 0) return(NULL)
      htmltools::div(class = "lo-notice", copy_page$d2_not_loaded)
    })

    # --- Summary cards ---------------------------------------------------------
    output$kpis <- shiny::renderUI({
      s <- standing()
      fit <- fit_base()
      first <- s[1, ]
      division_name <- copy_division_names[[first$division]]

      standing_card <- if (nrow(s) == 0) {
        kpi_card(copy_kpi$national, "\u2014")
      } else if (isTRUE(first$complete)) {
        kpi_card(copy_kpi$national, paste0("#", first$rank), copy_kpi$national_complete(first$rank, first$list_size, division_name, first$tied))
      } else {
        kpi_card(copy_kpi$national, copy_kpi$below_value, copy_kpi$national_below(format_mark(first$floor_mark_m), division_name), modifier = "caution")
      }

      top_n <- sum(fit$fit_read %in% c("would_lead", "top_three"))
      verify_n <- sum(fit$coverage_state == "none_listed")
      latest <- max(app_data$event_lists$latest_meet_date)
      parsed <- fmt_date(substr(app_data$event_lists$parsed_at[[1]], 1, 10))

      htmltools::div(
        class = "lo-kpis",
        standing_card,
        kpi_card(copy_kpi$top, top_n, copy_kpi$top_note(nrow(fit))),
        kpi_card(copy_kpi$verify, verify_n, copy_kpi$verify_note, modifier = if (verify_n > 0) "caution"),
        kpi_card(copy_kpi$as_of, fmt_date(latest), copy_kpi$as_of_note(parsed))
      )
    })

    output$strip <- shiny::renderUI({
      counts <- table(fit_base()$fit_read)
      fit_strip(stats::setNames(as.integer(counts), names(counts)))
    })

    # --- Program table ---------------------------------------------------------
    output$table <- reactable::renderReactable({
      df <- fit_shown()
      shiny::validate(shiny::need(nrow(df) > 0, copy_page$table_empty))

      # Sortable raw values in the columns; display HTML built once, vectorised.
      display <- df |>
        dplyr::transmute(
          program = .data$school_name,
          fit_order = as.integer(.data$fit_read),
          rank_sort = dplyr::coalesce(.data$rank_now, 999L),
          top_mark_m = .data$top_mark_m,
          gap_to_top_m = .data$gap_to_top_m
        )
      html <- list(
        program = html_program(df$school_name, df$state, df$division),
        fit = html_fit_badge(df$fit_read),
        rank = html_rank(copy_rank_main(df$rank_now), copy_rank_sub(df$listed_count, df$rank_complete, df$level_now)),
        mark = html_mark(df$top_mark_m),
        gap = html_gap(df$gap_to_top_m)
      )

      reactable::reactable(
        display,
        selection = "single",
        onClick = "select",
        defaultSelected = 1L,
        highlight = TRUE,
        compact = TRUE,
        searchable = TRUE,
        defaultPageSize = 12,
        paginationType = "simple",
        theme = liftoff_reactable_theme(),
        language = reactable::reactableLang(
          searchPlaceholder = copy_page$search_placeholder,
          noData = copy_page$table_empty
        ),
        columns = list(
          .selection = reactable::colDef(show = FALSE),
          program = reactable::colDef(
            name = copy_table$program,
            minWidth = 170,
            html = TRUE,
            cell = function(value, index) html$program[index]
          ),
          fit_order = reactable::colDef(
            name = copy_table$fit_read,
            minWidth = 135,
            html = TRUE,
            cell = function(value, index) html$fit[index]
          ),
          rank_sort = reactable::colDef(
            name = copy_table$rank,
            minWidth = 80,
            align = "right",
            html = TRUE,
            cell = function(value, index) html$rank[index]
          ),
          top_mark_m = reactable::colDef(
            name = copy_table$top_mark,
            minWidth = 90,
            align = "right",
            html = TRUE,
            cell = function(value, index) html$mark[index]
          ),
          gap_to_top_m = reactable::colDef(
            name = copy_table$gap,
            minWidth = 85,
            align = "right",
            html = TRUE,
            cell = function(value, index) html$gap[index]
          )
        )
      )
    })

    selected_row <- shiny::reactive({
      idx <- reactable::getReactableState("table", "selected")
      df <- fit_shown()
      if (is.null(idx) || length(idx) == 0 || idx > nrow(df)) return(NULL)
      df[idx, ]
    })

    # --- Evidence panel --------------------------------------------------------
    output$evidence <- shiny::renderUI({
      row <- selected_row()
      if (is.null(row)) return(htmltools::p(class = "lo-empty", copy_page$evidence_empty))

      ev <- program_evidence(app_data, row$program_id, row$list_id, mark(), athlete$enroll_year, athlete_label = copy_page$you)

      htmltools::tagList(
        htmltools::div(
          class = "lo-ev__head",
          htmltools::div(
            htmltools::h3(class = "lo-ev__name", row$school_name),
            htmltools::div(class = "lo-prog__meta", paste(row$state, "\u00b7", copy_division_names[[row$division]], "\u00b7", copy_event_names[[row$event_code]]))
          ),
          fit_badge(row$fit_read)
        ),
        htmltools::p(
          class = "lo-ev__sentence",
          copy_fit_sentence(row$school_name, row$event_code, row$fit_read, row$rank_now, row$listed_count, row$rank_complete, row$gap_to_top_m, row$floor_mark_m, row$level_now)
        ),
        evidence_table(ev, floor_mark_m = row$floor_mark_m),
        if (!is.na(row$verification_note)) {
          htmltools::div(
            class = "lo-ev__verify",
            htmltools::strong(copy_page$verification_heading), " ",
            row$verification_note
          )
        },
        htmltools::p(class = "lo-note", copy_page$arrival_note),
        htmltools::a(class = "lo-link", href = row$tfrrs_team_url, target = "_blank", rel = "noopener", copy_page$tfrrs_link)
      )
    })
  })
}

#' Evidence table with the athlete's row and the list cutoff marked
#' @noRd
evidence_table <- function(ev, floor_mark_m) {
  listed <- ev[!ev$is_athlete, ]
  you_idx <- which(ev$is_athlete)
  you_below_floor <- compare_marks(ev$mark_m[you_idx], floor_mark_m) < 0

  arrival_text <- function(x) ifelse(is.na(x), "\u2014", ifelse(x, copy_page$yes, copy_page$no))

  row_for <- function(i) {
    r <- ev[i, ]
    htmltools::tags$tr(
      class = if (r$is_athlete) "lo-ev__you",
      htmltools::tags$td(class = "lo-ev__ath", r$athlete_name),
      htmltools::tags$td(r$class_code),
      htmltools::tags$td(class = "lo-ev__mark", mark_cell(r$mark_m, r$wind_status, r$wind_mps)),
      htmltools::tags$td(class = "lo-ev__arr", if (r$is_athlete) "" else arrival_text(r$in_school_at_arrival))
    )
  }

  cutoff_row <- htmltools::tags$tr(
    class = "lo-ev__cutoff",
    htmltools::tags$td(colspan = 4, paste0(copy_page$cutoff_prefix, format_mark(floor_mark_m), copy_page$cutoff_suffix))
  )

  rows <- purrr::map(seq_len(nrow(ev)), row_for)
  rows <- if (you_below_floor) {
    append(rows, list(cutoff_row), after = you_idx - 1L)
  } else {
    c(rows, list(cutoff_row))
  }

  if (nrow(listed) == 0) {
    rows <- c(list(cutoff_row), list(row_for(you_idx)))
  }

  htmltools::tags$table(
    class = "lo-ev__table",
    htmltools::tags$thead(htmltools::tags$tr(
      htmltools::tags$th(copy_evidence_cols$athlete),
      htmltools::tags$th(copy_evidence_cols$class),
      htmltools::tags$th(class = "lo-ev__mark", copy_evidence_cols$mark),
      htmltools::tags$th(class = "lo-ev__arr", copy_evidence_cols$arrival)
    )),
    htmltools::tags$tbody(rows)
  )
}

#' reactable theme matching the bslib theme
#' @noRd
liftoff_reactable_theme <- function() {
  p <- liftoff_palette
  reactable::reactableTheme(
    color = p$ink,
    backgroundColor = "transparent",
    borderColor = p$rule,
    highlightColor = "#F1EFEA",
    cellPadding = "10px 12px",
    headerStyle = list(
      color = p$muted,
      fontSize = "0.72rem",
      fontWeight = 600,
      textTransform = "uppercase",
      letterSpacing = "0.04em",
      borderBottomWidth = "1px"
    ),
    rowSelectedStyle = list(
      backgroundColor = p$accent_soft,
      boxShadow = paste0("inset 3px 0 0 ", p$accent)
    ),
    searchInputStyle = list(
      width = "100%",
      borderColor = p$rule,
      borderRadius = "8px",
      fontSize = "0.9rem"
    )
  )
}
