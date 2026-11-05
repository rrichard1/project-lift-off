# Lift Off

An R/Shiny app (golem) that shows a Class of 2027 jumper where his high jump and long jump marks would have ranked on NCAA programs' 2026 performance lists, and how complete that picture is.

It is descriptive. It does not score programs on a blended index and does not predict what coaches will do.

- **Spec:** [`docs/SPEC.md`](docs/SPEC.md): the question, data model, metrics, fit-read rules, roadmap.
- **Decisions:** [`docs/DECISIONS.md`](docs/DECISIONS.md).
- **Working rules for Claude Code:** [`CLAUDE.md`](CLAUDE.md).

## Run it

```r
# install.packages(c("golem", "bslib", "reactable", "config", "dplyr", "tidyr",
#                    "readr", "purrr", "stringr", "yaml", "cli", "devtools"))
devtools::load_all()
run_app()
```

## Rebuild the data

```r
source("data-raw/build_data.R")   # writes inst/extdata/ and build_report.md
devtools::test()                  # data contracts, fit rules, language rules
```

## Target Board and outreach

The **Target Board** page shows the shortlist in `data-raw/manual/target_board.csv` with each program's fit read, rank, a bar-height strip of its jumpers and your outreach status.

- Add or move a program: edit `target_board.csv` (use the TFRRS team slug from the team page URL), then rebuild.
- Coach contacts and the outreach log are private and never committed. Run `source("dev/init_private_data.R")` once to create `inst/private/coach_contacts.csv` and `inst/private/outreach_log.csv`, then fill them in. The column guide is at the top of that script.
- Division II programs show 2026 championship finals as evidence until D2 lists are loaded.

Add a new TFRRS list export (for example D2) by dropping a CSV in `data-raw/source/tfrrs_lists/` with the same columns as the existing file, then rebuild. Unmatched school names stop the build and tell you what to add to `data-raw/manual/school_name_crosswalk.csv`.

## Status

| Area | State |
|---|---|
| Program Fit page, HJ + LJ, D1 | Working on 2026 outdoor lists |
| Target Board, 37 programs (28 D1, 9 D2) | Working; coach contacts and outreach log are local stubs |
| D2 | Championship-final evidence on the board; lists still waiting on exports |
| Conference scoring marks, staff, map, academics | Phase 2–3 |
