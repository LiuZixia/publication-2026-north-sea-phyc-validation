# Progress

## Current State

- **Updated (UTC):** 2026-08-07T16:44:49Z
- **Current stage:** Stage 0 (Governance and protocol freeze) remains in progress; the gate has not passed.
- **Session objective:** Audit committed revision `86933df` and the live artifacts against the complete Stage 0 requirements.
- **Starting branch:** `main`
- **Starting commit:** `86933df4690f7a50fe5c092b5e13e182359718b1`
- **Relevant starting dirty state:** modified `PENDING.md`; untracked `20260807T163613Z` tracking snapshots; local branch one commit ahead of `origin/main`.
- **First concrete action:** Validate the committed spatial CRS, geometry, station assignment, raw manifests, identifiers, environment, tests, and pipeline regeneration behavior.
- **Last completed milestone:** Revision `86933df` committed the Stage 0 implementation and resolved several earlier identifier/provenance gaps, but it did not pass the Stage 0 gate. The unchanged pre-audit live state is archived as `20260807T164128Z_PROGRESS.md` and `20260807T164128Z_PENDING.md`.

## Completed Work and Audit Findings

- Commit `86933df` provides a concrete version containing the R environment, ICES download/derivation script, machine-readable configuration, protocol-change register, data dictionary, spatial files, identifier functions, station-assignment function, setup runner, and tests.
- Identifier coverage improved: all twelve required generator functions exist, configured prefixes now match, sample identity uses a UTC timestamp, and source records accept a collision index.
- Raw spatial acquisitions now use the required external symlink, atomic-download helper, SHA-256 checksums, timestamped run directories, manifests, and human-readable logs. Two reproducible runs returned identical checksums.
- The project-activated `renv` environment is consistent and the lockfile records 44 packages.
- Stage 0 still does **not** pass because the committed spatial outputs have a fundamental CRS error. Both ICES REST responses declare Web Mercator (`wkid 102100`, latest `3857`). The domain correctly remains EPSG:3857, but the subregion geometry is relabelled—not transformed—as EPSG:4326 while retaining metre coordinates. Its bounding box is approximately `[-556597, 6106855, 1454850, 8859143]`, which is impossible longitude/latitude data and contradicts `config/protocol_config.json`.
- The committed subregion file contains three features rather than one row per two declared subregions: `skagerrak_kattegat` occurs twice. GEOS reports the three geometries valid only when treated planarly, while default s2 validation reports all three invalid.
- `assign_station()` disables s2 and requires geodetic distance support from `lwgeom`, which is neither installed nor locked. Direct station assignment terminates with `there is no package called 'lwgeom'`.
- The test suite reports 24 passes and one skip, not a complete pass. The spatial assignment portion is skipped when `lwgeom` is unavailable, so the assertions that would expose the unusable committed geometry do not run. The current tests also do not assert output CRS, plausible coordinate ranges, unique `subregion_id`, partition equality, default 5.5 km buffer behavior, or manifest completeness.
- The spatial script comment “Validate s2 topologies” is unsupported: its check uses `st_is_valid()` after processing but does not prove s2 validity, and the generated output fails an explicit s2 audit.
- The raw manifest records endpoint, nominal layer, access time, filename, and checksum, but it still omits license, HTTP status, response size/content validation, pagination/transfer-limit state, and software/session version. Files containing ESRI JSON are also named `.geojson`, obscuring their actual format.
- The committed setup runner does not execute `scripts/00_downloads/00_download_spatial.R`, so it cannot rebuild the Stage 0 spatial outputs from registered raw inputs. It validates whatever files already exist rather than serving as a complete Stage 0 pipeline entry point.
- The change register still attributes scientific approval to `Core Team / Protocol Review` without an identifiable reviewer or approval artifact. The live `PENDING.md` itself continues to list this approval as missing.
- The live tracking pair was internally inconsistent: `PROGRESS.md` described pre-commit defects, while `PENDING.md` both retained Stage 0 blockers and inserted a Stage 1 transition. This audit restores one conservative status.

## File-Change Ledger

| Path | Change | Purpose | Execution status |
|---|---|---|---|
| `PROGRESS.md` | modified | Reconcile the tracker with commit `86933df` and current audit evidence | refreshed; Stage 0 remains open |
| `PENDING.md` | modified | Remove contradictory Stage 1 transition and order remaining Stage 0 work | refreshed |
| `docs/agent_tracking/archive/20260807T163613Z_PROGRESS.md` | untracked, pre-existing | Preserve a prior state | present; not modified in this audit |
| `docs/agent_tracking/archive/20260807T163613Z_PENDING.md` | untracked, pre-existing | Preserve a prior state | present; not modified in this audit |
| `docs/agent_tracking/archive/20260807T164128Z_PROGRESS.md` | added | Preserve unchanged pre-audit live progress | snapshot created before refresh |
| `docs/agent_tracking/archive/20260807T164128Z_PENDING.md` | added | Preserve unchanged pre-audit live pending state | snapshot created before refresh |

## Validation Record

- `Rscript -e 'testthat::test_dir("tests", stop_on_failure=TRUE)'` reported 24 passes and one skip because `lwgeom` is not installed.
- Direct `assign_station(c(54,57.5,65), c(2,11,0))` failed with `there is no package called 'lwgeom'`.
- `Rscript -e 'renv::status()'` reported no dependency issues in the activated project environment.
- `sf` reported the domain CRS as EPSG:3857 and the subregions as WGS84 despite both sharing the same metre-valued bounding box.
- Default s2 validity was `FALSE` for all three subregion features; the file contains two rows with the same `skagerrak_kattegat` identifier.
- Raw ICES response headers independently confirmed `wkid 102100`/`latestWkid 3857`.
- Spatial runs `SPATIAL-ICES-20260807T162508Z` and `SPATIAL-ICES-20260807T162911Z` produced identical raw checksums, but their manifests omit required provenance fields noted above.
- All required identifier generator functions were found; station IDs use `STN-`, and differing collision indices produce differing record IDs.
- `git diff --check` passed for current unstaged changes. No download, API request, scientific transformation, or analysis result was produced during this audit.

## Archive History

- `20260807T124500Z_PROGRESS.md` and `20260807T124500Z_PENDING.md` — initial tracking milestone.
- `20260807T143428Z_PROGRESS.md` and `20260807T143428Z_PENDING.md` — terminal session start.
- `20260807T144242Z_PROGRESS.md` and `20260807T144242Z_PENDING.md` — pre-implementation state.
- `20260807T144825Z_PROGRESS.md` and `20260807T144825Z_PENDING.md` — pre-first-audit state.
- `20260807T151725Z_PROGRESS.md` and `20260807T151725Z_PENDING.md` — earlier claimed-pass state.
- `20260807T161836Z_PROGRESS.md` and `20260807T161836Z_PENDING.md` — pre-commit audit state.
- `20260807T164128Z_PROGRESS.md` and `20260807T164128Z_PENDING.md` — unchanged post-commit state before this audit.
