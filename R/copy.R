# Every user-facing string lives here.
#
# Language rules (CLAUDE.md rule 3): describe where a mark would have ranked
# on real lists. Never imply scholarships, offers, openings, roster spots,
# need, likelihood or coach intent. tests/testthat/test-copy.R scans this
# file and the UI code for banned terms.

copy_brand_sub <- "Program fit for a Class of 2027 jumper"

copy_nav_note <- "2026 outdoor lists \u00b7 HJ and LJ"

copy_event_names <- c(HJ = "High jump", LJ = "Long jump", TJ = "Triple jump")

copy_division_names <- c(D1 = "Division I", D2 = "Division II")

#' Short labels for fit reads
#' @noRd
copy_fit_read_label <- c(
  would_lead = "Would lead",
  top_three = "Top three",
  depth = "Depth",
  well_above = "Above your level",
  cant_tell = "Can't tell yet",
  verified_active = "Verified active",
  none_listed = "Verify program",
  verified_no_marks = "No marks (verified)",
  verified_no_event = "No group (verified)"
)

#' One-sentence explanations for fit reads
#' @noRd
copy_fit_read_help <- c(
  would_lead = "Your mark is at or above every jumper this program had on the 2026 list.",
  top_three = "Your mark would have been one of the program's top three on the 2026 list.",
  depth = "At least three of the program's listed jumpers were better than your mark.",
  well_above = "The program's best jumper was well above your mark. Your mark would have trailed its top level.",
  cant_tell = "Your mark is below the national list's cutoff, so jumpers between your mark and the cutoff are not visible.",
  verified_active = "Nobody from this program made the list, but a source confirms a current event group.",
  none_listed = "Nobody from this program cleared the list's cutoff in this event. Treat it as a data gap to check.",
  verified_no_marks = "A person checked the program's TFRRS page: no marks in this event this season.",
  verified_no_event = "A person confirmed the program has no current group in this event."
)

#' Coverage-state labels
#' @noRd
copy_coverage_label <- c(
  listed = "On the list",
  verified_active = "Verified active",
  none_listed = "Not on the list",
  verified_no_marks = "Verified: no marks",
  verified_no_event = "Verified: no event group"
)

#' Rank on the program's list: main figure ("#2") and qualifier ("of 5")
#'
#' @param rank_now Integer rank (lower bound when not complete).
#' @param listed_count Athletes from the program on the list.
#' @param rank_complete Logical.
#' @param level_now Teammates tied with the athlete's mark.
#' @noRd
copy_rank_main <- function(rank_now) {
  ifelse(is.na(rank_now), "\u2014", paste0("#", rank_now))
}

#' @rdname copy_rank_main
#' @noRd
copy_rank_sub <- function(listed_count, rank_complete, level_now = 0L) {
  tied <- !is.na(level_now) & level_now > 0
  dplyr::case_when(
    listed_count == 0 ~ "",
    !rank_complete ~ "or lower",
    tied ~ paste0("of ", listed_count + 1L, " \u00b7 tied"),
    .default = paste0("of ", listed_count + 1L)
  )
}

#' Plain-English summary of one program's fit for the evidence panel
#' @noRd
copy_fit_sentence <- function(school_name, event_code, fit_read, rank_now, listed_count, rank_complete, gap_to_top_m, floor_mark_m, level_now = 0L) {
  event <- tolower(copy_event_names[[event_code]])
  read <- as.character(fit_read)

  if (read %in% c("none_listed", "verified_no_marks", "verified_no_event", "verified_active")) {
    return(paste0(school_name, " had no ", event, " jumpers on the 2026 list (cutoff ", format_mark(floor_mark_m), "). ", copy_fit_read_help[[read]]))
  }

  tied <- !is.na(level_now) && level_now > 0
  position <- if (rank_complete && tied) {
    paste0("would have tied for #", rank_now, " among the program's ", listed_count + 1L, " jumpers including you")
  } else if (rank_complete) {
    paste0("would have ranked #", rank_now, " among the program's ", listed_count + 1L, " jumpers including you")
  } else {
    paste0("would have ranked #", rank_now, " or lower; the list stops at ", format_mark(floor_mark_m), ", below which the program's jumpers are not visible")
  }

  gap <- if (gap_to_top_m > 0) {
    paste0("The program's best was ", format_gap(gap_to_top_m), " above your mark.")
  } else if (gap_to_top_m < 0) {
    paste0("Your mark was ", sub("^\u2212", "", format_gap(gap_to_top_m)), " above the program's best.")
  } else {
    "Your mark matched the program's best."
  }

  paste0("On the 2026 ", event, " list, your mark ", position, ". ", gap)
}

copy_page <- list(
  title = "Program Fit",
  subtitle = "Where your marks would have ranked on each program's 2026 outdoor list, and how complete that picture is.",
  athlete_heading = "Your marks",
  event_label = "Event",
  mark_label = "Your best (metres)",
  division_label = "Divisions",
  state_label = "States",
  state_placeholder = "All states",
  read_label = "Show",
  table_heading = "Programs",
  evidence_heading = "Evidence",
  evidence_empty = "Select a program to see the jumpers behind its fit read.",
  arrival_note = "\u201cIn school fall 2027\u201d comes from each jumper's 2026 class year. It cannot see the 2026 and 2027 recruiting classes, transfers or redshirts, so it is context, not a forecast.",
  d2_not_loaded = "Division II lists are not loaded yet. Programs shown are Division I only.",
  profile_note = "Starting marks come from the athlete profile and are not yet confirmed. Changes here are not saved.",
  mark_invalid = "Enter a mark in metres, for example 2.03.",
  division_none = "Choose at least one division.",
  table_empty = "No programs match these filters.",
  search_placeholder = "Find a program",
  show_choices = c("All programs" = "all", "Programs on the list" = "listed", "Programs to verify" = "verify"),
  you = "You",
  yes = "Yes",
  no = "No",
  verification_heading = "Verification:",
  tfrrs_link = "Open the TFRRS team page \u2197",
  cutoff_prefix = "List cutoff ",
  cutoff_suffix = ". Jumpers below it are not visible."
)

copy_kpi <- list(
  national = "National standing",
  national_complete = function(rank, size, division, tied) {
    paste0("of ", size, " on the ", division, " list", if (tied > 0) paste0(" \u00b7 tied with ", tied) else "")
  },
  national_below = function(floor, division) paste0("Your mark is below the ", division, " list cutoff of ", floor, ", so national rank is not visible."),
  below_value = "Below cutoff",
  top = "Would lead or top three",
  top_note = function(total) paste0("of ", total, " programs, against their 2026 lists"),
  verify = "Programs to verify",
  verify_note = "had nobody on the list in this event",
  as_of = "Data through",
  as_of_note = function(parsed) paste0("TFRRS lists parsed ", parsed)
)

copy_table <- list(
  program = "Program",
  state = "State",
  division = "Div.",
  fit_read = "Fit read",
  rank = "Your rank",
  top_mark = "Program best",
  gap = "Best vs. you",
  listed = "Listed"
)

copy_evidence_cols <- list(
  athlete = "Jumper",
  class = "Class",
  mark = "Mark",
  meet = "Meet",
  arrival = "In school fall 2027"
)

copy_footer <- paste(
  "Source: TFRRS 2026 NCAA outdoor performance lists (top-500 per event).",
  "Lists show season bests only, so a program's jumpers below the list cutoff are not visible.",
  "Fit reads describe where a mark would have ranked. They say nothing about how a program evaluates athletes."
)

# ---- Target Board ---------------------------------------------------------

#' Board group labels and one-line descriptions
#'
#' Groups are the athlete's own sort of the shortlist, set by hand in
#' data-raw/manual/target_board.csv. They are not fit reads.
#' @noRd
copy_board_group_label <- c(
  established_group = "Established jumps group",
  smaller_group = "Smaller jumps group",
  power_conference = "Power conference",
  division_ii = "Division II"
)

#' @rdname copy_board_group_label
#' @noRd
copy_board_group_help <- c(
  established_group = "Programs carrying several listed high jumpers, with your mark inside the group's range.",
  smaller_group = "Programs with fewer listed high jumpers, where your mark sits near the top of the group.",
  power_conference = "Power-conference programs that also carry jumpers close to your mark.",
  division_ii = "Programs with finalists at the 2026 Division II outdoor championships. Division II lists are not loaded yet."
)

#' Outreach state labels
#' @noRd
copy_contact_label <- c(
  no_coach = "No coach on file",
  coach_on_file = "Coach on file",
  sent = "Sent",
  received = "Reply"
)

#' Short outreach status for the board table
#'
#' @param state `contact_state` from `board_outreach()`.
#' @param last_date Date of the last logged contact.
#' @param channel Channel of the last logged contact.
#' @noRd
copy_contact_status <- function(state, last_date, channel) {
  when <- ifelse(is.na(last_date), "", paste0(" ", format(as.Date(last_date), "%b "), as.integer(format(as.Date(last_date), "%d"))))
  how <- ifelse(is.na(channel) | channel == "", "", paste0(" · ", channel))
  dplyr::case_when(
    state %in% c("sent", "received") ~ paste0(unname(copy_contact_label[state]), when, how),
    .default = unname(copy_contact_label[state])
  )
}

#' Sentence for a program evidenced by championship results only
#' @noRd
copy_champs_sentence <- function(school_name, event_code, finalists, best_m, best_place, meet_name) {
  event <- tolower(copy_event_names[[event_code]])
  if (is.na(finalists) || finalists == 0) {
    return(paste0(school_name, " had no finalists in the ", event, " at the ", meet_name, "."))
  }
  who <- if (finalists == 1) "one finalist" else paste0(finalists, " finalists")
  best <- if (is.na(best_m)) {
    " None recorded a mark in the final."
  } else {
    paste0(" The best finished ", ordinal(best_place), " at ", format_mark(best_m), ".")
  }
  paste0(school_name, " had ", who, " in the ", event, " at the ", meet_name, ".", best)
}

#' Where the athlete's mark would have placed in a championship final
#' @noRd
copy_champs_standing <- function(place_equiv, field, meet_name, last_mark_m) {
  if (place_equiv > field) {
    paste0("Your mark is below every finalist at the ", meet_name, ". The last finalist recorded ", format_mark(last_mark_m), ".")
  } else {
    paste0("Your mark would have placed ", ordinal(place_equiv), " of ", field, " finalists at the ", meet_name, ".")
  }
}

#' Ordinal number ("1st", "12th", "22nd")
#' @noRd
ordinal <- function(n) {
  suffix <- ifelse(n %% 100 %in% 11:13, "th", c("th", "st", "nd", "rd", rep("th", 6))[n %% 10 + 1])
  paste0(n, suffix)
}

copy_board <- list(
  title = "Target Board",
  subtitle = "The programs on your shortlist, the evidence behind each one, and where your outreach stands.",
  event_label = "Event",
  marks_note = "Marks come from the athlete profile. Try other marks on the Program Fit page.",
  table_heading = "Programs on the board",
  evidence_heading = "Program",
  evidence_empty = "Select a program to see its jumpers, notes and coaches.",
  group = "Group",
  program = "Program",
  fit_read = "Fit read",
  rank = "Your rank",
  top_mark = "Program best",
  strip = "Jumpers vs. you",
  outreach = "Outreach",
  no_list = "No list loaded",
  no_list_help = "Division II lists are not loaded yet. Evidence comes from championship results.",
  strip_in = "In school fall 2027",
  strip_out = "Gone by fall 2027",
  strip_you = "Your mark",
  strip_note = "Dots are each listed jumper's 2026 season best, or the final mark for Division II programs. Hollow dots were juniors or seniors in 2026. Class years cannot see redshirts, transfers or the next two recruiting classes.",
  champs_heading = function(meet_name, event_code) paste0(meet_name, " · ", copy_event_names[[event_code]], " final"),
  champs_note = "Championship results show a program's finalists at one meet, not its full event group.",
  place = "Place",
  no_height = "NH",
  no_mark = "NM",
  note_heading = "Board note",
  coaches_heading = "Coaches",
  coaches_empty = "No coach on file yet.",
  coach_staff_link = "Staff page ↗",
  log_heading = "Outreach log",
  log_empty = "No contact logged yet.",
  next_step = "Next step",
  sent = "Sent",
  received = "Received",
  private_missing = "Coach contacts and the outreach log are not set up on this computer. Run dev/init_private_data.R to create them in inst/private/, which stays out of git.",
  private_problems = "Some rows in your contact files could not be read:",
  kpi_programs = "Programs on the board",
  kpi_programs_note = function(d1, d2) paste0(d1, " Division I · ", d2, " Division II"),
  kpi_coaches = "Coaches on file",
  kpi_coaches_note = function(total) paste0("programs out of ", total),
  kpi_contacted = "Programs contacted",
  kpi_contacted_note = function(replies) paste0(replies, " with a reply"),
  kpi_next = "Next follow-up",
  kpi_next_none = "—",
  kpi_next_note = function(school) if (is.na(school)) "nothing scheduled" else school,
  footer = "Board groups and notes are set by hand in data-raw/manual/target_board.csv. Fit reads and ranks come from the 2026 TFRRS lists; Division II evidence comes from the 2026 championship finals."
)
