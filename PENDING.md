# Pending

- **Updated (UTC):** 2026-08-07T16:44:49Z
- **Carried forward after session snapshot:** `20260807T164128Z`

## First Priority

**Correct and fully validate the Stage 0 spatial pipeline before any Stage 1 transition.**

Completion evidence:

- raw ICES geometries are explicitly transformed from their declared EPSG:3857 source CRS to the frozen EPSG:4326 output CRS;
- domain and subregion outputs have plausible longitude/latitude bounds, pass GEOS and s2 validity, contain exactly one unique feature per declared `subregion_id`, and form the intended non-overlapping domain partition;
- `assign_station()` runs in the locked environment without skips or missing packages and is tested at inside, outside, boundary, overlap/tie-break, missing-coordinate, and default-buffer cases;
- spatial manifests include source/license, API/layer version, query, UTC execution time, HTTP/result status, response size, transfer-limit/completeness state, software version, filenames, and SHA-256 checksums;
- raw file extensions or metadata accurately identify ESRI JSON versus GeoJSON;
- one non-interactive Stage 0 entry point regenerates spatial outputs from registered inputs and then runs fail-on-error provenance, schema, CRS, geometry, identifier, and assignment checks;
- protocol decisions name an accountable scientific reviewer with traceable approval; and
- corrected outputs, tests, trackers, and a genuine Stage 0 milestone snapshot are committed and reproducible from a clean restored environment.

## Ordered Next Actions

1. Fix CRS handling in `scripts/00_downloads/00_download_spatial.R`: preserve the source CRS, union Area 27.3.a subdivisions as intended, transform all outputs with `st_transform(4326)`, and assert unique IDs plus plausible bounds.
2. Repair and validate geometries under both GEOS and s2; assert that subregions are non-overlapping and partition the Greater North Sea domain according to the reviewed design.
3. Add `lwgeom` to the environment if planar geodetic operations remain necessary, or keep s2 enabled and implement metre-safe assignment without it; eliminate skipped gate tests.
4. Complete spatial acquisition manifest/log fields and response-completeness checks, using truthful raw file extensions.
5. Make the Stage 0 entry point regenerate or validate registered spatial derivations before running the expanded test suite.
6. Obtain and record identifiable scientific approval for the domain roles and 5.5 km buffer.
7. Run from a clean restored environment, reconcile tracking, commit the corrected milestone, and only then begin Stage 1.

## Blockers and Missing Inputs

- An accountable scientific reviewer must approve the core/external-transfer role and coastal-buffer rule.
- The intended treatment of overlapping ICES Area 27.3.a parent/subdivision features must be explicitly decided before union/deduplication.
- Exact API capabilities, authentication requirements, and rate limits still need official verification for Stage 1 providers.
- The exact CMEMS product and dataset ID must be frozen before PhyC acquisition.
- Restricted/contact-only datasets remain unavailable until providers grant access and terms are recorded.

## Known Warnings and Scientific Risks

- Current subregions are metre coordinates mislabeled as longitude/latitude; any station assignment from them is scientifically invalid.
- The passing-test count hides a skipped spatial test and therefore cannot support the Stage 0 gate.
- Duplicate external-transfer features can create ambiguous joins or duplicated matches.
- The committed station assignment is not executable in the locked environment.
- The latest commit is local and one revision ahead of `origin/main`; publication/review availability has not been verified remotely.
- Prevent duplicate provider/aggregator records from being counted as independent evidence in Stage 1.
- Keep credentials out of scripts, manifests, logs, and Git history.

## Deferred or Out of Scope

- No Stage 1 search execution, record screening, or coverage summaries until Stage 0 passes.
- No manual raw-file placement or unrecorded browser download.
- No CMEMS extraction before the in-situ manifest and product selection are frozen.
- No manuscript result, performance metric, or biological conclusion until calculated by the R pipeline.
- No taxonomic identification claim from total PhyC.
