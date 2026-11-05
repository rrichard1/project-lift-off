# Create the private outreach files from their templates.
#
# Run once per computer, from the project root:
#   source("dev/init_private_data.R")
#
# Creates inst/private/coach_contacts.csv and inst/private/outreach_log.csv
# with the right headers. inst/private/ is gitignored (DECISIONS D-009), so
# coach details and outreach notes never reach the public repo. Existing
# files are left alone.
#
# coach_contacts.csv  one row per program x coach
#   program_id       TFRRS team slug, as in data-raw/manual/target_board.csv
#   coach_name, coach_title, events_coached, email, phone, staff_page_url
#   checked_on       date you copied the details (YYYY-MM-DD)
#   source_url       page you copied them from
#   notes
#
# outreach_log.csv    one row per contact, append-only, newest last
#   program_id, contact_date (YYYY-MM-DD)
#   direction        sent | received
#   channel          email | call | text | social | questionnaire | visit | camp | meet | other
#   coach_name, summary, next_step, next_step_date (YYYY-MM-DD or blank)
#
# To keep the files somewhere else (a synced folder, say), set
# LIFTOFF_PRIVATE_DIR in .Renviron to that folder instead.

dest <- "inst/private"
dir.create(dest, showWarnings = FALSE, recursive = TRUE)

for (name in c("coach_contacts", "outreach_log")) {
  target <- file.path(dest, paste0(name, ".csv"))
  if (file.exists(target)) {
    cli::cli_alert_info("{.path {target}} already exists; left as is.")
  } else {
    file.copy(file.path("inst/templates", paste0(name, ".csv")), target)
    cli::cli_alert_success("Created {.path {target}}.")
  }
}
