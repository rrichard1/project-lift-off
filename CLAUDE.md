# CLAUDE.md — Lift Off

Read this before every session. The product spec is `docs/SPEC.md`; decisions are logged in `docs/DECISIONS.md`.

## What this is

An R/Shiny (golem) app that shows one Class of 2027 jumper where his high jump and long jump marks would sit on NCAA D1 and D2 programs' performance lists, and how complete that picture is. Athlete-facing, descriptive, no predictions.

## Hard rules

1. **Missing ≠ zero ≠ opportunity.** Never render absent data as an opening, a need, or rank #1. Every program × event row has a `coverage_state`; use it.
2. **No blended scores.** Do not combine signals into an index. Show plain numbers with their source.
3. **Language.** All user-facing text lives in `R/copy.R`. Never write "scholarship", "offer", "opening", "roster spot", "need", "likely", or anything implying coach intent. `tests/testthat/test-copy.R` enforces this; do not weaken it.
4. **Verification is human-only.** Only a person edits `data-raw/manual/verification_ledger.csv`. Never generate `verified_*` rows.
5. **Keys, not names.** Join on `program_id` (TFRRS team slug). School names are display-only. New name variants go in `data-raw/manual/school_name_crosswalk.csv`, never in code.
6. **The "Florida" trap.** "Florida" on TFRRS lists is the University of Florida, never Florida A&M (`Florida_AM`).
7. **Completeness.** When the athlete's mark is below a list's floor, counts are lower bounds. Use the `*_complete` flags from `fit_table()`; never drop them.
8. **Ask before** changing fit-read rules, thresholds in `inst/golem-config.yml`, or the data contracts in `docs/SPEC.md` §5. Log approved changes in `docs/DECISIONS.md`.
9. **Private stays private.** Coach contacts and the outreach log live in `inst/private/` (gitignored, D-009). Never commit them, never copy their contents into committed files, tests or docs. Fixtures use invented rows.
10. **Board groups are hand-made.** `board_group` in `data-raw/manual/target_board.csv` is the athlete's own sort; never compute, infer or combine it with a fit read (D-007). Championship finals are evidence only and never feed a fit read (D-008).

## Layout

```
R/                     package code
  marks.R              unit conversion and formatting (m ↔ ft-in)
  pipeline.R           pure functions that build the app tables
  coverage.R           coverage states
  fit.R                athlete-relative metrics and fit read
  board.R              target board, championship evidence, private outreach files
  copy.R               every user-facing string
  data_load.R          reads inst/extdata/
  mod_program_fit.R    Program Fit page
  mod_board.R          Target Board page
  app_ui.R, app_server.R, run_app.R, app_config.R, theme.R
data-raw/
  build_data.R         run this to rebuild inst/extdata/ from sources
  source/              raw inputs (TFRRS list exports, registry); never edit by hand
  source/tfrrs_results/ championship finals (D2 evidence until D2 lists load)
  source/legacy/       v0 workbook, reference only
  manual/              human-edited inputs (crosswalk, verification ledger, target board)
inst/
  extdata/             built tables (committed, small, diffable CSV)
  athlete/athlete_profile.yml
  templates/           headers for the private outreach files
  private/             coach contacts + outreach log (gitignored; dev/init_private_data.R)
  golem-config.yml     thresholds and settings
  app/www/             CSS
tests/testthat/        unit tests, data-contract tests, copy tests
docs/                  SPEC.md, DECISIONS.md
```

## Commands

```r
source("dev/init_private_data.R") # once per computer: create inst/private/ files
source("data-raw/build_data.R")   # rebuild inst/extdata/
devtools::test()                  # must pass before any commit
devtools::load_all(); run_app()   # run locally
```

## Code style

Tidyverse, native pipe `|>`, explicit `pkg::fn()` in package code. One grain per table, stated in a comment where the table is built. Complete files over snippets. Surgical edits; don't restructure working modules without asking.

## Workflow

Work on a branch (`cc/<topic>`), run `devtools::test()`, open a PR for Roland to review. Never commit straight to `main`.
