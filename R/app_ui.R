#' The application User-Interface
#'
#' @param request Internal parameter for `{shiny}`.
#' @noRd
app_ui <- function(request) {
  athlete <- read_athlete_profile()
  events <- unlist(get_golem_config("events"))

  bslib::page_navbar(
    title = htmltools::span(
      class = "lo-brand",
      htmltools::span(class = "lo-brand__mark", "Lift Off"),
      htmltools::span(class = "lo-brand__sub", copy_brand_sub)
    ),
    window_title = "Lift Off",
    theme = liftoff_theme(),
    fillable = FALSE,
    header = golem_add_external_resources(),
    bslib::nav_panel(copy_page$title, mod_program_fit_ui("fit", athlete, events)),
    bslib::nav_spacer(),
    bslib::nav_item(htmltools::span(class = "lo-nav-note", copy_nav_note))
  )
}

#' Add external resources to the app
#'
#' Resources in `inst/app/www` are bundled automatically.
#' @noRd
golem_add_external_resources <- function() {
  golem::add_resource_path("www", app_sys("app/www"))

  htmltools::tags$head(
    htmltools::tags$link(rel = "preconnect", href = "https://fonts.googleapis.com"),
    htmltools::tags$link(rel = "preconnect", href = "https://fonts.gstatic.com", crossorigin = NA),
    htmltools::tags$link(
      rel = "stylesheet",
      href = "https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap"
    ),
    golem::bundle_resources(path = app_sys("app/www"), app_title = "Lift Off")
  )
}
