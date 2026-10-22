# Lift Off — Product Spec (v1)

_Last updated: 2026-10-22. Owner: Roland Richard._

## 1. The job

Lift Off helps one Class of 2027 jumper answer a single question:

> **"At which college programs would my marks put me, and how sure are we?"**

It is an **athlete program-fit tool**. It is not a coach-side recruiting model, it does not predict offers, and it does not score programs on a blended index.

| In scope (v1) | Out of scope (v1) |
|---|---|
| High jump (HJ) and long jump (LJ) | Triple jump in the app (kept in raw data only) |
| NCAA D1 and D2 men's outdoor track | NAIA, JUCO, D3 |
| Athletic fit from current performance lists | Academic fit, cost, location scoring (Phase 3) |
| Coverage and verification status for every program-event | Live scraping inside the app |

## 2. Principles (non-negotiable)

1. **Missing is not zero, and zero is not opportunity.** A program with no listed jumpers is a coverage question, never an opening. Every program-event row carries an explicit coverage state.
2. **Describe, don't predict.** The app says where a mark _would have ranked_ on real lists. It never says what a coach will do.
3. **No blended score.** Each signal stands on its own and is shown as a plain number with its source.
4. **Every number is traceable.** Any figure in the app can be expanded to the rows that produced it, with the source list and date.
5. **Completeness is computed, not assumed.** If the athlete's mark is below a list's floor, counts become lower bounds and the app says so.
6. **Language rules.** Never imply scholarships, offers, roster openings, coach intent or likelihood. All user-facing text lives in `R/copy.R` and is tested for banned terms.
7. **Humans verify.** `verified_*` states come only from the manual verification ledger, written by a person who checked a source.

## 3. Why v0 is being replaced

These are the root causes found in the v0 data and code. Each one maps to a rule above.

| v0 problem | Evidence | v1 response |
|---|---|---|
| National top-500 lists were treated as rosters | "Depth" for a school = how many of its athletes cracked the national top 500. 203 of 629 school-events had exactly one listed athlete. | Lists are used only for what they can support: rank of a mark against listed athletes, complete above the list floor. |
| The athlete's LJ mark is below the entire LJ list | LJ list floor is 6.95 m; the athlete's PR is 6.81 m. Every LJ comparison was silently against better jumpers only. | Completeness flag per event; LJ counts shown as "at least N". |
| One-athlete "rosters" produced "High Need / Strong Fit" | A school with one listed senior got senior share = 100%. | No class-share scores. Class info shown as counts with caveats. |
| Projection ignored the two-year gap | The athlete enrolls fall 2027; 2026 data can't see the 2026 and 2027 recruiting classes. Prototyping "projected slot at arrival" put 125 of 210 HJ programs at #1. | Arrival projection is shown as context only, never used to label fit. |
| Division and conference unknown | Team registry: division known for 6 of 1,552 teams, conference for 6. | Division comes from which list a team appears on; conference mapping is a Phase 2 pipeline task. |
| Validations passed on broken data | `team_urls_extractable` = PASS with 0% URLs; `event_anchors_match_config` = PASS with 0 of 9 anchors. | Tests fail on bad data. A data-contract test suite gates every build. |
| Audit reported real data as missing | Missing-HJ audit listed Florida as absent from all events; Florida has 2 LJ and 2 TJ athletes on the lists. | Coverage is computed in one place from the same tables the app reads. |
| One program counted as two | Lists print both "Middle Tennessee" and "Mid. Tenn. State"; v0's 258 "schools" are 257 programs. | Every list name resolves to one TFRRS team slug. |
| Name mapping hardcoded in code | `normalize_school_name()` held recodes; `school_name_crosswalk.csv` was inert. | The crosswalk file drives matching. Unmatched names fail the build. |
| Legacy tiers predicted offers | Workbook fields: `offer_likely`, `scholarship_attention`. | Dropped. Workbook kept as reference in `data-raw/source/legacy/`. |
| Wind-aided LJ marks mixed in | 167 of 500 LJ list marks had wind > 2.0 m/s. | Every LJ mark carries `wind_status`. |

## 4. Athlete inputs

Stored in `inst/athlete/athlete_profile.yml` and editable in the app.

| Field | v1 value | Status |
|---|---|---|
| HJ personal best | 2.03 m (6' 8") | Confirm |
| LJ personal best | 6.81 m (22' 4") | Confirm; note wind legality |
| Enrollment year | Fall 2027 | Confirmed |
| Home state, intended major, GPA | — | Phase 3 inputs |

## 5. Data model

All app-facing tables are built by `data-raw/build_data.R` into `inst/extdata/`. Grain is stated for every table.

### `programs` — one row per program (TFRRS men's track team)
| Column | Type | Notes |
|---|---|---|
| `program_id` | chr | **Key.** TFRRS team slug, e.g. `GA_college_m_Georgia`. Never a display name. |
| `school_name` | chr | Display name from the TFRRS team registry |
| `list_team_name` | chr | Name as printed on performance lists |
| `division` | chr | `D1` / `D2`, from the list the team appears on |
| `conference` | chr | `NA` = not yet mapped (Phase 2) |
| `state` | chr | From the TFRRS team URL |
| `tfrrs_team_url` | chr | |

### `event_lists` — one row per event × season × division list
`list_id`, `event_code`, `season`, `division`, `list_size`, `floor_mark_m`, `top_mark_m`, `source_url`, `parsed_at`. The floor drives completeness.

### `athlete_marks` — one row per athlete × event × season × division list
`program_id`, `event_code`, `season`, `division`, `athlete_name`, `class_code`, `eligibility_year`, `mark_m`, `wind_mps`, `wind_status` (`legal` / `aided` / `not_applicable` / `unknown`), `meet_name`, `meet_date`, `list_place`, `list_id`.

### `program_events` — one row per program × event × season × division
Built as a **full cross** of programs and loaded lists, so absence is a row, not a gap.

| Column | Notes |
|---|---|
| `listed_count` | Athletes from this program on the list |
| `top_mark_m` | `NA` when none listed |
| `fr`, `so`, `jr`, `sr` | Counts among listed athletes only |
| `coverage_state` | See below |
| `verification_note`, `verified_on` | From the ledger |

### Coverage states
| State | Meaning | App label |
|---|---|---|
| `listed` | ≥1 athlete on the list | — |
| `none_listed` | Program is on the lists for another event, but nobody cleared this event's floor | "Verify program" |
| `verified_active` | A person confirmed a current event group the lists miss | "Verified active" |
| `verified_no_marks` | A person checked the TFRRS team page: no marks this season | "No marks (verified)" |
| `verified_no_event` | A person confirmed no current event group | "No group (verified)" |

When a division has no lists loaded (D2 today), the app shows a notice instead of rows.

**Universe gap:** programs appear only if at least one of their jumpers made a 2026 list in some event (257 D1 programs). Programs with nobody on any list are invisible until an NCAA sponsorship list is added (Phase 2).

### Manual inputs (`data-raw/manual/`, human-edited only)
- `school_name_crosswalk.csv` — list name → registry name. Drives matching.
- `verification_ledger.csv` — append-only; last row per program × event × season wins. Columns `program_id`, `event_code`, `season`, `status` (`active_event_group` / `no_marks_on_tfrrs` / `no_event_group`), `checked_on`, `checked_by`, `source_url`, `notes`. A ledger row that contradicts the lists stops the build.

## 6. Metrics (per program × event, given the athlete's mark _m_)

| Metric | Definition | Complete when |
|---|---|---|
| `ahead_now` | Listed teammates with season best **> m** | m ≥ list floor (otherwise a lower bound) |
| `level_now` | Listed teammates with season best **= m** | same |
| `rank_now` | `ahead_now + 1` — "would have ranked #k on the 2026 list" | same |
| `gap_to_top_m` | `top_mark_m − m` (positive = program best is higher) | when `listed` |
| `national_rank` | Rank of _m_ on the full division list | m ≥ list floor |
| `ahead_at_arrival` | `ahead_now` restricted to athletes still in school in the enrollment year: `eligibility_year + (enroll_year + 1 − season) ≤ 4` | **Context only.** Excludes the 2026 and 2027 recruiting classes, transfers and progression. |

## 7. Fit read (one descriptive label, rules applied in order)

| # | Rule | Label |
|---|---|---|
| 1 | Coverage is not `listed` | Coverage label from §5 |
| 2 | `gap_to_top_m ≥ reach_threshold[event]` | Above your level |
| 3 | Complete and `rank_now = 1` | Would lead |
| 4 | `rank_now ≥ 4` (true even as a lower bound) | Depth |
| 5 | Complete and `rank_now ≤ 3` | Top three |
| 6 | Otherwise | Can't tell yet |

**What this produces today** (2026 D1 lists, athlete PRs): HJ 2.03 m ranks #204 of 513 nationally; 85 programs read "Would lead", 99 "Top three", 11 "Depth", 15 "Above your level", 46 "Verify program". LJ 6.81 m is below the 6.95 m list cutoff, so no program can read "Top three" or better: 10 "Depth", 144 "Above your level", 48 "Can't tell yet", 55 "Verify program".

`reach_threshold` lives in `inst/golem-config.yml`: HJ 0.15 m, LJ 0.45 m. **These are judgment calls for Roland to confirm.**

Labels describe a role, not a recommendation. Whether leading a weaker group or training as depth behind stronger jumpers is better is the athlete's call; the app shows both.

## 8. Pages

**v1 — Program Fit** (this build)
- Athlete strip: event toggle, PR input, division and state filters.
- Summary cards: national standing for the mark, counts by fit read, programs to verify, data as-of date.
- Program table: program, state, fit read, rank on 2026 list, program best, gap, coverage.
- Evidence panel: click a program to see its listed athletes for the event with the athlete's mark slotted in.

**Phase 2 — Programs**: conference mapping and conference-meet scoring marks ("would have placed 5th at SoCon"), jumps coach on staff, verification workflow.
**Phase 3 — Shortlist**: location (IPEDS coordinates, map), academic fit (IPEDS admissions), cost; a personal shortlist with notes.

## 9. Roadmap

| Phase | Deliverable | Data needed |
|---|---|---|
| 1 (now) | Program Fit page on 2026 D1 outdoor lists, HJ + LJ | In hand |
| 1b | Same for D2 | 2026 D2 outdoor HJ/LJ lists (port the v0 list parser into `data-raw/`) |
| 1c | Refresh with 2027 indoor lists (Jan–Mar 2027) | Shows current college freshmen the 2026 lists can't |
| 2 | Conference scoring marks, coach/staff, verification | TFRRS conference results; league pages in `tfrrs_conference_inventory.csv` |
| 3 | Map, academics, shortlist | IPEDS HD + ADM files |

## 10. Decisions waiting on Roland

1. Confirm PRs (and LJ wind legality).
2. Confirm or change the reach thresholds (HJ 0.15 m, LJ 0.45 m).
3. D2 source: rerun the v0 list parser on D2 lists, or pull TFRRS team pages for deeper rosters.
4. Repo name and hosting (Posit Connect vs. local only).
