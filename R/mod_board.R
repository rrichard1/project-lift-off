#' Target Board page UI
#'
#' The athlete's shortlist: each program's board group, fit read and rank
#' from the lists (or championship finals for Division II), a bar-height
#' strip of its jumpers, and where outreach stands.
#'
#' @param id Module id.
#' @param events Event codes to offer (from golem-config).
#' @noRd
mod_board_ui <- function(id, events = c("HJ", "LJ")) {
  ns <- shiny::NS(id)

  htmltools::div(
    class = "lo-board",
    htmltools::div(
      class = "lo-head",
      htmltools::h1(class = "lo-head__title", copy_board$title),
      htmltools::p(class = "lo-head__dek", copy_board$subtitle)
    ),
    htmltools::div(
      class = "lo-board__controls",
      shiny::radioButtons(
        ns("event"),
        copy_board$event_label,
        choices = stats::setNames(events, copy_event_names[events]),
        selected = events[[1]],
        inline = TRUE
      ),
      shiny::uiOutput(ns("mark_note"))
    ),
    shiny::uiOutput(ns("notice")),
    shiny::uiOutput(ns("kpis")),
    bslib::layout_columns(
      col_widths = bslib::breakpoints(sm = c(12, 12), lg = c(7, 5)),
      class = "lo-main",
      bslib::card(
        class = "lo-card",
        bslib::card_header(class = "lo-card__head", copy_board$table_heading),
        strip_legend(),
        reactable::reactableOutput(ns("table")),
        htmltools::p(class = "lo-note lo-board__strip-note", copy_board$strip_note)
      ),
      bslib::card(
        class = "lo-card lo-evidence",
        bslib::card_header(class = "lo-card__head", copy_board$evidence_heading),
        shiny::uiOutput(ns("evidence"))
      )
    ),
    htmltools::p(class = "lo-footer", copy_board$footer)
  )
}

#' Target Board page server
#'
#' @param id Module id.
#' @param app_data Output of [load_app_data()].
#' @param athlete Athlete profile.
#' @param settings List with `reach_threshold_m` (named by event).
#' @param private Output of [load_private_data()].
#' @noRd
mod_board_server <- function(id, app_data, athlete, settings, private) {
  shiny::moduleServer(id, function(input, output, session) {
    outreach <- board_outreach(app_data$board, private$coach_contacts, private$outreach_log)

    mark <- shiny::reactive({
      shiny::req(input$event)
      athlete$marks[[input$event]]$best_m
    })

    output$mark_note <- shiny::renderUI({
      htmltools::p(
        class = "lo-note lo-board__mark",
        htmltools::strong(format_mark(mark())), " · ", copy_board$marks_note
      )
    })

    # --- Data --------------------------------------------------------------
    # Grain: one row per board program for the selected event.
    rows <- shiny::reactive({
      board_fit_table(
        app_data,
        event_code = input$event,
        athlete_mark_m = mark(),
        enroll_year = athlete$enroll_year,
        reach_threshold_m = settings$reach_threshold_m[[input$event]]
      ) |>
        dplyr::left_join(outreach, by = "program_id", relationship = "one-to-one")
    })

    strip_marks <- shiny::reactive(board_marks(app_data, input$event, athlete$enroll_year))

    champs_meta <- app_data$championship_marks |>
      dplyr::distinct(.data$meet_id, .data$meet_name, .data$season) |>
      dplyr::mutate(meet_label = paste(.data$season, .data$meet_name))

    meet_label <- function(meet_id) {
      out <- champs_meta$meet_label[match(meet_id, champs_meta$meet_id)]
      if (length(out) == 0 || is.na(out)) champs_meta$meet_label[1] else out
    }

    # --- Notices -----------------------------------------------------------
    output$notice <- shiny::renderUI({
      notes <- list()
      if (!any(private$found)) {
        notes <- c(notes, list(htmltools::div(class = "lo-notice", copy_board$private_missing)))
      }
      if (length(private$problems) > 0) {
        notes <- c(notes, list(htmltools::div(
          class = "lo-notice",
          copy_board$private_problems,
          htmltools::tags$ul(purrr::map(private$problems, htmltools::tags$li))
        )))
      }
      if (length(notes) == 0) return(NULL)
      htmltools::tagList(notes)
    })

    # --- Summary cards -----------------------------------------------------
    output$kpis <- shiny::renderUI({
      r <- rows()
      upcoming <- r |>
        dplyr::filter(!is.na(.data$next_step_date), .data$next_step_date >= Sys.Date()) |>
        dplyr::arrange(.data$next_step_date) |>
        dplyr::slice_head(n = 1)

      htmltools::div(
        class = "lo-kpis",
        kpi_card(copy_board$kpi_programs, nrow(r), copy_board$kpi_programs_note(sum(r$division == "D1"), sum(r$division == "D2"))),
        kpi_card(copy_board$kpi_coaches, sum(r$coaches_on_file > 0), copy_board$kpi_coaches_note(nrow(r))),
        kpi_card(copy_board$kpi_contacted, sum(r$contacts_logged > 0), copy_board$kpi_contacted_note(sum(r$replies > 0))),
        kpi_card(
          copy_board$kpi_next,
          if (nrow(upcoming) == 0) copy_board$kpi_next_none else fmt_date(upcoming$next_step_date),
          copy_board$kpi_next_note(if (nrow(upcoming) == 0) NA_character_ else upcoming$school_name)
        )
      )
    })

    # --- Board table -------------------------------------------------------
    output$table <- reactable::renderReactable({
      df <- rows()
      shiny::validate(shiny::need(nrow(df) > 0, copy_page$table_empty))

      scale <- strip_scale(strip_marks()$mark_m, mark())
      best_m <- dplyr::if_else(df$has_list, df$top_mark_m, df$champs_best_m)

      display <- df |>
        dplyr::transmute(
          group_order = .data$group_order,
          program = .data$school_name,
          fit_order = dplyr::coalesce(as.integer(.data$fit_read), 99L),
          rank_sort = dplyr::coalesce(.data$rank_now, 999L),
          best_m = best_m,
          strip = .data$program_id,
          contact = .data$contact_state
        )
      html <- list(
        group = html_board_group(df$board_group),
        program = html_program(df$school_name, df$state, df$division),
        fit = html_board_fit(df$fit_read, df$has_list),
        rank = ifelse(
          df$has_list,
          html_rank(copy_rank_main(df$rank_now), copy_rank_sub(df$listed_count, df$rank_complete, df$level_now)),
          '<span class="lo-muted">—</span>'
        ),
        best = html_mark(best_m),
        strip = html_mark_strip(df$program_id, strip_marks(), mark(), scale),
        contact = html_contact(df$contact_state, copy_contact_status(df$contact_state, df$last_contact_date, df$last_channel))
      )

      reactable::reactable(
        display,
        selection = "single",
        onClick = "select",
        defaultSelected = 1L,
        highlight = TRUE,
        compact = TRUE,
        searchable = TRUE,
        pagination = FALSE,
        defaultSorted = "group_order",
        theme = liftoff_reactable_theme(),
        language = reactable::reactableLang(
          searchPlaceholder = copy_page$search_placeholder,
          noData = copy_page$table_empty
        ),
        columns = list(
          .selection = reactable::colDef(show = FALSE),
          group_order = reactable::colDef(name = copy_board$group, minWidth = 120, html = TRUE, cell = function(value, index) html$group[index]),
          program = reactable::colDef(name = copy_board$program, minWidth = 150, html = TRUE, cell = function(value, index) html$program[index]),
          fit_order = reactable::colDef(name = copy_board$fit_read, minWidth = 120, html = TRUE, cell = function(value, index) html$fit[index]),
          rank_sort = reactable::colDef(name = copy_board$rank, minWidth = 70, align = "right", html = TRUE, cell = function(value, index) html$rank[index]),
          best_m = reactable::colDef(name = copy_board$top_mark, minWidth = 80, align = "right", html = TRUE, cell = function(value, index) html$best[index]),
          strip = reactable::colDef(name = copy_board$strip, minWidth = 160, sortable = FALSE, html = TRUE, cell = function(value, index) html$strip[index]),
          contact = reactable::colDef(name = copy_board$outreach, minWidth = 120, html = TRUE, cell = function(value, index) html$contact[index])
        )
      )
    })

    selected_row <- shiny::reactive({
      idx <- reactable::getReactableState("table", "selected")
      df <- rows()
      if (is.null(idx) || length(idx) == 0 || idx > nrow(df)) return(NULL)
      df[idx, ]
    })

    # --- Evidence panel ----------------------------------------------------
    output$evidence <- shiny::renderUI({
      row <- selected_row()
      if (is.null(row)) return(htmltools::p(class = "lo-empty", copy_board$evidence_empty))

      head <- htmltools::div(
        class = "lo-ev__head",
        htmltools::div(
          htmltools::h3(class = "lo-ev__name", row$school_name),
          htmltools::div(class = "lo-prog__meta", paste(row$state, "·", copy_division_names[[row$division]], "·", copy_event_names[[row$event_code]])),
          htmltools::HTML(html_board_group(row$board_group))
        ),
        if (row$has_list) fit_badge(row$fit_read) else htmltools::HTML(html_board_fit(NA, FALSE))
      )

      evidence <- if (row$has_list) {
        ev <- program_evidence(app_data, row$program_id, row$list_id, mark(), athlete$enroll_year, athlete_label = copy_page$you)
        htmltools::tagList(
          htmltools::p(
            class = "lo-ev__sentence",
            copy_fit_sentence(row$school_name, row$event_code, row$fit_read, row$rank_now, row$listed_count, row$rank_complete, row$gap_to_top_m, row$floor_mark_m, row$level_now)
          ),
          evidence_table(ev, floor_mark_m = row$floor_mark_m),
          htmltools::p(class = "lo-note", copy_page$arrival_note)
        )
      } else {
        label <- meet_label(row$champs_meet_id)
        standing <- championship_standing(app_data, row$event_code, mark())
        ev <- championship_evidence(app_data, row$program_id, row$event_code, mark(), athlete_label = copy_page$you)
        htmltools::tagList(
          htmltools::p(
            class = "lo-ev__sentence",
            copy_champs_sentence(row$school_name, row$event_code, row$champs_finalists, row$champs_best_m, row$champs_best_place, label),
            if (nrow(standing) > 0) paste0(" ", copy_champs_standing(standing$place_equiv[1], standing$field[1], label, standing$last_mark_m[1]))
          ),
          champs_table(ev, copy_board$champs_heading(label, row$event_code)),
          htmltools::p(class = "lo-note", copy_board$champs_note)
        )
      }

      htmltools::tagList(
        head,
        evidence,
        if (!is.na(row$verification_note)) {
          htmltools::div(class = "lo-ev__verify", htmltools::strong(copy_page$verification_heading), " ", row$verification_note)
        },
        board_section(copy_board$note_heading, htmltools::p(class = "lo-board__text", row$board_note)),
        board_section(copy_board$coaches_heading, coach_list(private$coach_contacts, row$program_id)),
        board_section(copy_board$log_heading, outreach_list(private$outreach_log, row$program_id)),
        htmltools::a(class = "lo-link", href = row$tfrrs_team_url, target = "_blank", rel = "noopener", copy_page$tfrrs_link)
      )
    })
  })
}

#' Titled block in the evidence panel
#' @noRd
board_section <- function(title, body) {
  htmltools::div(
    class = "lo-board__section",
    htmltools::h4(class = "lo-board__section-title", title),
    body
  )
}

#' Championship final table with the athlete's mark slotted in
#' @noRd
champs_table <- function(ev, caption) {
  status_text <- c(no_height = copy_board$no_height, no_mark = copy_board$no_mark)

  rows <- purrr::map(seq_len(nrow(ev)), \(i) {
    r <- ev[i, ]
    htmltools::tags$tr(
      class = if (r$is_athlete) "lo-ev__you",
      htmltools::tags$td(if (is.na(r$place)) "—" else r$place),
      htmltools::tags$td(class = "lo-ev__ath", r$athlete_name),
      htmltools::tags$td(r$class_code),
      htmltools::tags$td(
        class = "lo-ev__mark",
        if (r$result_status == "mark") mark_cell(r$mark_m, r$wind_status, r$wind_mps) else htmltools::span(class = "lo-muted", status_text[[r$result_status]])
      )
    )
  })

  htmltools::tags$table(
    class = "lo-ev__table",
    htmltools::tags$caption(class = "lo-ev__caption", caption),
    htmltools::tags$thead(htmltools::tags$tr(
      htmltools::tags$th(copy_board$place),
      htmltools::tags$th(copy_evidence_cols$athlete),
      htmltools::tags$th(copy_evidence_cols$class),
      htmltools::tags$th(class = "lo-ev__mark", copy_evidence_cols$mark)
    )),
    htmltools::tags$tbody(rows)
  )
}

#' Coaches on file for one program
#' @noRd
coach_list <- function(coach_contacts, program_id) {
  cc <- coach_contacts[coach_contacts$program_id %in% program_id, ]
  if (nrow(cc) == 0) return(htmltools::p(class = "lo-empty", copy_board$coaches_empty))

  htmltools::tags$ul(
    class = "lo-board__list",
    purrr::map(seq_len(nrow(cc)), \(i) {
      r <- cc[i, ]
      present <- function(x) !is.na(x) && nzchar(x)
      htmltools::tags$li(
        htmltools::div(class = "lo-board__who", r$coach_name, if (present(r$coach_title)) htmltools::span(class = "lo-muted", paste0(" · ", r$coach_title))),
        if (present(r$events_coached)) htmltools::div(class = "lo-board__meta", r$events_coached),
        if (present(r$email)) htmltools::div(class = "lo-board__meta lo-board__select", r$email),
        if (present(r$phone)) htmltools::div(class = "lo-board__meta lo-board__select", r$phone),
        if (present(r$staff_page_url)) htmltools::a(class = "lo-link", href = r$staff_page_url, target = "_blank", rel = "noopener", copy_board$coach_staff_link),
        if (present(r$notes)) htmltools::div(class = "lo-board__meta", r$notes)
      )
    })
  )
}

#' Outreach log for one program, newest first
#' @noRd
outreach_list <- function(outreach_log, program_id) {
  ol <- outreach_log[outreach_log$program_id %in% program_id, ]
  if (nrow(ol) == 0) return(htmltools::p(class = "lo-empty", copy_board$log_empty))
  ol <- ol[order(ol$contact_date, decreasing = TRUE), ]

  htmltools::tags$ul(
    class = "lo-board__list",
    purrr::map(seq_len(nrow(ol)), \(i) {
      r <- ol[i, ]
      present <- function(x) !is.na(x) && nzchar(as.character(x))
      direction <- if (r$direction %in% "received") copy_board$received else copy_board$sent
      htmltools::tags$li(
        htmltools::div(
          class = "lo-board__who",
          paste0(fmt_date(r$contact_date), " · ", direction, if (present(r$channel)) paste0(" · ", r$channel)),
          if (present(r$coach_name)) htmltools::span(class = "lo-muted", paste0(" · ", r$coach_name))
        ),
        if (present(r$summary)) htmltools::div(class = "lo-board__meta", r$summary),
        if (present(r$next_step)) {
          htmltools::div(
            class = "lo-board__meta",
            htmltools::strong(paste0(copy_board$next_step, ": ")),
            r$next_step,
            if (present(r$next_step_date)) paste0(" (", fmt_date(r$next_step_date), ")")
          )
        }
      )
    })
  )
}
