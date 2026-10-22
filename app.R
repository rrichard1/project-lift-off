# Launch the app on Posit Connect or with shiny::runApp().
# Do not remove this file; Connect deploys from it.

pkgload::load_all(export_all = FALSE, helpers = FALSE, attach_testthat = FALSE)
options("golem.app.prod" = TRUE)
liftoff::run_app()
