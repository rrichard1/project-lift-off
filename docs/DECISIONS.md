# Decisions log

Newest first. Each entry: what was decided, why, and who decided.

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
