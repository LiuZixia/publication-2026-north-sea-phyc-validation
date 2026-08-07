# Progress

## Current State

- **Updated (UTC):** 2026-08-07T16:21:03Z
- **Current stage:** Stage 0 (Governance and protocol freeze) remains in progress; the gate has not passed.
- **Session objective:** Re-audit the rectified Stage 0 implementation, staged files, generated spatial data, tests, and environment against the repository's full gate and provenance rules.
- **Starting branch:** `main`
- **Starting commit:** `2b2eeb88f5b08fd6b66c5b80cd5ec9f1d300fd6b`
- **Relevant starting dirty state:** Stage 0 implementation files staged but uncommitted; live trackers modified both in the index and worktree; ignored raw spatial/search files and run logs.
- **First concrete action:** Compare every claimed Stage 0 completion item with code, artifacts, Git history, tests, raw provenance, and spatial/identifier diagnostics.
- **Last completed milestone:** The Stage 0 setup script and its current 22-test suite ran successfully at 2026-08-07T15:29:44Z, but the Stage 0 gate is not complete. The unchanged claimed-pass state is archived as `20260807T161836Z_PROGRESS.md` and `20260807T161836Z_PENDING.md`.

## Completed Work and Audit Findings

- The versioned protocol documents define the primary row unit, hierarchy, evidence tiers, outcome, candidate lifeforms, recurrence criteria, baselines, metrics, and decision rules.
- The implementation is materially improved: the ICES Greater North Sea feature is downloaded and converted to a domain GeoJSON; two role-labelled subregions are generated; stable-ID and station-assignment functions exist; `renv.lock` records 44 packages; project-activated `renv::status()` is consistent; and the current test suite reports 22 passes.
- `scripts/00_setup.R` has failure-on-test behavior and produced a successful timestamped run log with full `sessionInfo()` at `outputs/logs/run_20260807T152944Z.log`.
- Stage 0 still does **not** pass. The staged artifacts have no commit/version identifier, and the live tracker differs from its staged version. `git add .` does not constitute a frozen version.
- The spatial raw acquisition violates the mandatory download contract. `scripts/00_downloads/00_download_spatial.R` does not call `verify_raw_data_target()` before writing, writes the response directly rather than atomically, explicitly omits checksum registration, and creates no manifest or human-readable acquisition log. The 78,168,688-byte raw ICES file has no registered version, license, access time, response metadata, or checksum manifest.
- The ICES domain feature is authoritative input, but the hydrographic split is not an ICES subregion definition: the script introduces an uncited rectangular cutoff (`longitude > 8.5°E` and `latitude > 57°N`) described only as a “common proxy.” The register's claim of alignment with established ICES definitions therefore overstates the evidence.
- The generated subregion geometry fails a default `sf`/s2 union-area audit with a degenerate duplicate-vertex error. Geometries cannot be frozen until generation repairs and validates them under the engine used by the pipeline.
- `GSHHG_high_res` is named but no version, URL, license, checksum, acquisition artifact, or use in spatial generation exists. UTC and depth conventions also remain names rather than explicit parsing/precision/unknown-state rules.
- The identifier layer is incomplete: `generate_year_id()` and `generate_subregion_id()` are absent; `generate_station_id()` emits `STATION-*` while configuration and the dictionary require `STN-*`; and no collision detection/resolution exists despite the tracker claiming collision handling.
- The data dictionary and code disagree for samples: the dictionary exposes `utc_timestamp`, while the hash recipe and generator use date only, allowing same-station/same-depth samples on one day to collide. Canonical case, Unicode, timestamp/time-zone, provider-version, and collision rules are not fully specified or tested.
- The current tests pass but are not comprehensive enough for the gate: they do not test year/subregion IDs, all configured prefixes, collisions, the prescribed 5.5 km default buffer, overlap/centroid tie-breaking, s2 validity, raw provenance, or full domain partitioning.
- The change register attributes scientific approval to `Core Team / Protocol Review`, but the repository contains no identifiable reviewer or approval evidence. Scientifically material spatial and buffering decisions must not be treated as reviewed solely because that label was entered.
- `scripts/00_setup.R` validates environment/helpers/tests but does not regenerate the spatial configuration or orchestrate later stages; a reproducible pipeline entry point remains incomplete.

## File-Change Ledger

| Path | Change | Purpose | Execution status |
|---|---|---|---|
| `.Rprofile` | staged addition | Activate `renv` | present; uncommitted |
| `R/00_core_setup.R` | staged addition | Raw-target, checksum, and download helpers | loaded; trailing-whitespace check fails |
| `R/00_identifiers.R` | staged addition | Stable-ID generators | executes; two required generators missing and station prefix mismatched |
| `R/00_spatial_assignment.R` | staged addition | Station-to-subregion assignment | narrow tests pass; full boundary contract untested |
| `config/data_dictionary.csv` | staged addition | Entity schema and hash inputs | inspected; sample-time and collision gaps remain |
| `config/protocol_change_register.csv` | staged addition | Protocol decisions | required columns present; review attribution unverified |
| `config/protocol_config.json` | staged addition | Spatial and provenance conventions | parses; source/version and operational rules incomplete |
| `config/spatial/greater_north_sea.geojson` | staged addition | ICES-derived domain | matches source feature by generation route; 8.3 MB, uncommitted |
| `config/spatial/hydrographic_subregions.geojson` | staged addition | Core/external-transfer partition | s2 audit fails; split is an uncited rectangular proxy |
| `renv.lock` | staged addition | Dependency snapshot | 44 packages; project-activated status consistent |
| `renv/.gitignore` | staged addition | Ignore local environment library | present |
| `renv/activate.R` | staged addition | Activate `renv` | generated; staged diff has trailing whitespace |
| `renv/settings.json` | staged addition | `renv` settings | present |
| `scripts/00_downloads/00_download_spatial.R` | staged addition | Download and derive spatial files | executed previously; raw provenance/storage contract fails |
| `scripts/00_downloads/01_search_emodnet_erddap.R` | staged addition | Preliminary EMODnet search | prior response exists; Stage 1-incomplete |
| `scripts/00_setup.R` | staged addition | Environment validation and Stage 0 tests | successful run logged; not a full pipeline entry point |
| `tests/test_stage0_identifiers.R` | staged addition | Identifier and spatial tests | 22 passes; gate coverage incomplete |
| `docs/agent_tracking/archive/20260807T144242Z_PROGRESS.md` | staged addition | Preserve earlier state | unchanged |
| `docs/agent_tracking/archive/20260807T144242Z_PENDING.md` | staged addition | Preserve earlier state | unchanged |
| `docs/agent_tracking/archive/20260807T144825Z_PROGRESS.md` | staged addition | Preserve earlier state | unchanged |
| `docs/agent_tracking/archive/20260807T144825Z_PENDING.md` | staged addition | Preserve earlier state | unchanged |
| `docs/agent_tracking/archive/20260807T151725Z_PROGRESS.md` | staged addition | Preserve earlier state | unchanged |
| `docs/agent_tracking/archive/20260807T151725Z_PENDING.md` | staged addition | Preserve earlier state | unchanged |
| `docs/agent_tracking/archive/20260807T161836Z_PROGRESS.md` | untracked addition | Preserve unchanged pre-audit pass claim | snapshot created before live refresh |
| `docs/agent_tracking/archive/20260807T161836Z_PENDING.md` | untracked addition | Preserve unchanged pre-audit pending state | snapshot created before live refresh |
| `PROGRESS.md` | staged and worktree modification | Correct Stage 0 status and record audit | reconciled with actual evidence |
| `PENDING.md` | staged and worktree modification | Restore Stage 0 work as first priority | reconciled with actual evidence |
| `data/raw/spatial/ices_ecoregions_raw.geojson` | ignored external raw artifact | ICES REST response | 78,168,688 bytes; unregistered checksum `6069a38a6419267dfa44a5baf8bd06e0dc4e7fd0393ac05b5305f78ca6e3a5b7` |
| `data/raw/search_runs/SEARCH-EMODNET-20260807T144229Z/` | ignored external raw artifact | Preliminary API response and manifest | prior checksum verified; no new API run |
| `outputs/logs/run_20260807T151352Z.log` | ignored generated artifact | Earlier setup log | inspected previously |
| `outputs/logs/run_20260807T152759Z.log` | ignored generated artifact | Initial rectification setup run | records ten test failures before fixes |
| `outputs/logs/run_20260807T152944Z.log` | ignored generated artifact | Successful rectification setup run | records 22 passes and `sessionInfo()` |

## Validation Record

- `Rscript -e 'testthat::test_dir("tests", stop_on_failure = TRUE)'` passed 22 expectations in 5.5 seconds.
- Project-activated `Rscript -e 'renv::status()'` reported no issues; `Rscript --vanilla -e 'renv::status()'` correctly reported packages not installed outside the project library and is not the restoration-status criterion.
- `renv.lock` contains 44 packages and all six direct packages used by Stage 0 (`httr2`, `jsonlite`, `digest`, `sf`, `testthat`, `rprojroot`).
- `sf` read one domain feature, two subregions, and 17 raw ICES features; basic GEOS validity passed, but the default s2 union/intersection audit failed on a degenerate duplicate vertex.
- Identifier execution confirmed the station prefix is `STATION-` and that year/subregion generators are missing.
- SHA-256 was calculated diagnostically for the raw ICES response and generated GeoJSON files, but no acquisition manifest registers those values.
- `git status` showed implementation files staged but no new commit beyond `2b2eeb8`; the live trackers had both staged and unstaged changes.
- `git diff --cached --check` failed on trailing whitespace in staged R and generated `renv/activate.R`; the unstaged tracker diff itself was otherwise syntactically inspectable.
- No API or data download was performed during this audit, and no scientific result was created.

## Archive History

- `20260807T124500Z_PROGRESS.md` and `20260807T124500Z_PENDING.md` — initial tracking milestone.
- `20260807T143428Z_PROGRESS.md` and `20260807T143428Z_PENDING.md` — terminal session start.
- `20260807T144242Z_PROGRESS.md` and `20260807T144242Z_PENDING.md` — pre-implementation state.
- `20260807T144825Z_PROGRESS.md` and `20260807T144825Z_PENDING.md` — pre-first-audit state.
- `20260807T151725Z_PROGRESS.md` and `20260807T151725Z_PENDING.md` — earlier claimed-pass state.
- `20260807T161836Z_PROGRESS.md` and `20260807T161836Z_PENDING.md` — unchanged rectified claimed-pass state before this audit.
