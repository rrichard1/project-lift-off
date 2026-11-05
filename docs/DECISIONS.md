# Decisions log

Newest first. Each entry: what was decided, why, and who decided.

## D-009 · 2026-11-05 · Coach contacts and outreach stay local
The repo is public. Coach names, emails and phones, and the athlete's outreach notes, live in `inst/private/` (gitignored, and excluded from package builds). Templates with the headers are committed in `inst/templates/`. The app reads the files at runtime and treats missing files as empty. _Roland._

## D-008 · 2026-11-05 · D2 championship finals as evidence until D2 lists load
The 2026 D2 outdoor HJ and LJ finals are a new source (`data-raw/source/tfrrs_results/`) and a new table, `championship_marks`. They are shown only as evidence on the Target Board, labelled as one meet's results, and never feed `program_events`, coverage or a fit read. When D2 lists load (Phase 1b), D2 board programs pick up list metrics automatically. _Roland._

## D-007 · 2026-11-05 · Target Board: a hand-made shortlist beside the computed signals
`data-raw/manual/target_board.csv` holds the programs the athlete is contacting and the group each sits in. Groups are a human sort of the shortlist, not a fit read: the board shows them next to the computed fit read and rank, never combined (rule 2). Group names were reworded from the outreach list so they pass the language rules. The first board (37 programs: 28 D1, 9 D2) came from the Nov 5 coach outreach list. _Roland asked for the board; Claude proposed the group names, for Roland to confirm._

## D-006 · 2026-10-22 · Arrival projection is context, not a fit signal
Counting jumpers "ahead of you and still in school in fall 2027" from 2026 data put 125 of 210 HJ programs at #1, because the 2026 and 2027 recruiting classes are invisible. It is shown in the evidence panel with that caveat and never drives the fit read. _Claude, from prototyping; for Roland to confirm._

## D-005 · 2026-10-22 · Legacy workbook tiers dropped
`offer_likely`, `scholarship_attention` and related conference-level estimates predict coach behavior, which the language rules forbid. The workbook is kept in `data-raw/source/legacy/` as research reference (staff, roster URLs, conference benchmarks) for Phase 2. _Claude; for Roland to confirm._

## D-004 · 2026-10-22 · Performance lists are not rosters
National top-N lists are used only to rank a mark against listed athletes. Depth, class share and "need" are not derived from them. _Claude, from data audit._

## D-003 · 2026-10-22 · `program_id` = TFRRS team slug
Stable, unique, and already in the team registry (1,552 teams, no duplicate keys). Display names are never join keys. _Claude._

## D-002 · 2026-10-22 · Scope: HJ + LJ, D1 + D2, athlete program-fit
Triple jump stays in raw data but is not surfaced. D2 is a parallel track, loaded as soon as lists are ingested. _Roland._

## D-001 · 2026-10-22 · Fresh rebuild
v0 had flaws across data trust, code structure, scoring and UI. Rebuilt as a golem package with a spec-first data model. v0 stays untouched in its own repo for reference. _Roland._
