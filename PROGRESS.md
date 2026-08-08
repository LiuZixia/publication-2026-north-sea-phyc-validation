# Progress

## Current State

- **Updated (UTC):** 2026-08-08T19:52:37Z
- **Current stage:** Stage 2 ranked acquisition in progress; rank-1 DS06 canonical acquisition, inventory, exact spatial screen, and cross-package duplicate audit completed.
- **Session objective:** Commit the validated Stage 1/EMODnet checkpoint, close the direct WFS uncertainty, and begin ranked canonical-provider acquisition — achieved through the DS06 acquisition milestone.
- **Branch/starting commit:** `main` at `9ea8a4b` (`stage2: freeze screening contract and resolve WFS candidates`).
- **First concrete next action:** Commit this DS06 milestone, then execute the rank-2 DS26 canonical acquisition route without inspecting CMEMS PhyC.
- **Last completed milestone:** Rank-1 DS06 canonical acquisition and initial record-level screening validated at 2026-08-08T19:48:09Z.
- **Archive snapshot:** `docs/agent_tracking/archive/20260808T194809Z_PROGRESS.md` and `..._PENDING.md` preserve the pre-DS06 handoff; `20260808T190853Z_*` preserves the prior contract/WFS milestone.

## Completed Work

- The prior Stage 2 contract and EMODnet WFS closure is committed as `9ea8a4b`. Stage 1 remains frozen at 30/34 register entries resolved or diagnosed, 19 ranked candidates, and 16/16 benchmark recall.
- `scripts/00_downloads/05_acquire_ds06_smhi_shark.R` acquired all 219 versioned phytoplankton packages from the canonical SMHI SHARK API because package titles cannot reliably establish record geography. The finalized run is `data/raw/stage2/ds06_smhi_shark/DS06_SMHI_SHARK_20260808T191500Z`; it contains 27,700,519 bytes and every ZIP passed CRC validation.
- The tracked acquisition manifest has 219 immutable file rows with provider version, URL, retrieval time, licence, size, checksum, and validation state. The raw manifest checksum is `e7c8aeec0f286616dd9080ae7d7be7fb5728f36185209bdd298a3787b2506535`.
- `scripts/02_inventory_screen_ds06_smhi_shark.R` successfully parses both the older 102-column SHARK schema with provider `row_number` and the current 96-column schema using immutable source-line position. It explicitly converts Latin-1 provider text to UTF-8 without altering raw ZIPs.
- All 909,693 source rows reconcile: 7,948 core-domain, 478,860 external-transfer, and 422,885 outside-domain. The source inventory contains 209,656 carbon, 186,334 biovolume, 513,703 abundance/count, and 494,671 method-metadata rows. These are source-row counts, not sample totals or independent observations.
- The variable inventory contains 21,390 source-column rows across 219 packages. Large row-level base screening and identity tables are ignored intermediate artifacts but are pinned by tracked SHA-256 registries.
- The duplicate audit found 8,102 provider sample IDs and only four shared across packages. Re-reading those eight sample-package memberships and comparing SHA-256 fingerprints across 51 sample, taxon, size-class, measurement, method, and reported-value fields found zero exact cross-package record duplicates. Similar measurements were preserved.
- DS06 is provisionally Tier A because canonical SHARK supplies taxon-level carbon concentration directly. Its Stage 2 decision remains `pending`: the exact CMEMS product temporal contract and Stage 5 compatible sample-level total-community/method-epoch checks are not complete.
- No CMEMS file or PhyC value was acquired or inspected. No event catalogue, recurrence label, split, or analysis-ready observation manifest exists.

## File-Change Ledger

| Path | Change and purpose | Validation state |
|---|---|---|
| `PROGRESS.md`, `PENDING.md` | Refreshed canonical handoff for the DS06 milestone | reconciled |
| `docs/agent_tracking/archive/20260808T194809Z_PROGRESS.md`, `..._PENDING.md` | Immutable pre-milestone live-file snapshots | complete |
| `config/stage2_ds06_smhi_shark_acquisition.json` | Freeze rank, catalogue checksum, routes, licence, raw run ID, and selection rule | executed |
| `scripts/00_downloads/05_acquire_ds06_smhi_shark.R` | Restartable canonical SHARK acquisition with raw-target checks, CRC tests, atomic finalization, and tracked pins | executed and idempotent |
| `scripts/02_inventory_screen_ds06_smhi_shark.R` | Verify raw checksums, inventory schemas, generate stable record IDs, and exact-screen every record | executed and idempotent |
| `scripts/02_resolve_ds06_smhi_shark_duplicates.R` | Audit cross-package sample identity and strict scientific fingerprints; emit separate resolved screen | executed and idempotent |
| `scripts/02_summarize_ds06_smhi_shark_screening.R` | Generate contract-level pending Tier A disposition | executed and idempotent |
| `scripts/02_validate_stage2_contract.R` | Extend milestone validation to idempotently verify the DS06 acquisition and screen | passed |
| `metadata/stage2_ds06_smhi_shark_active_run.csv` | Pin one completed canonical raw run | complete |
| `metadata/stage2_ds06_smhi_shark_acquisition_manifest.csv` | Track all 219 raw package files | complete |
| `metadata/stage2_ds06_smhi_shark_variable_inventory.csv` | Inventory every source column per package | complete |
| `metadata/stage2_ds06_smhi_shark_package_summary.csv` | Reconcile dates, spatial states, measurements, methods, and source rows | complete |
| `metadata/stage2_ds06_smhi_shark_output_registry.csv` | Pin base inventory and large ignored intermediates | complete |
| `metadata/stage2_ds06_smhi_shark_sample_overlap.csv` | Preserve all eight cross-package sample memberships | complete |
| `metadata/stage2_ds06_smhi_shark_duplicate_resolution_summary.csv` | Record sample/fingerprint/duplicate totals and rule | complete |
| `metadata/stage2_ds06_smhi_shark_duplicate_resolution_registry.csv` | Pin duplicate map and resolved screen | complete |
| `metadata/stage2_ds06_smhi_shark_screening_summary.csv` | Contract-compliant provisional Tier A, pending decision | complete |
| `data/raw/stage2/ds06_smhi_shark/DS06_SMHI_SHARK_20260808T191500Z/` | Immutable 219-package run plus raw manifest, summary, and log; each file enumerated in tracked manifest | complete, ignored raw store |
| `data/interim/stage2_ds06_smhi_shark_*.csv` | Base/resolved record screening, duplicate identity, and empty exact-duplicate map | complete, ignored and checksum-pinned |
| `docs/DATASET_SYSTEMATIC_SEARCH.md` | Add §13.5 evidence-backed DS06 acquisition and conservative disposition | complete |
| `tests/test_stage2_contract.R` | Add rank, provenance, inventory, spatial, duplicate, and pending-tier regression checks | focused suite passed |
| `tests/requirements_map.csv` | Map Stage 2 DS06 requirements to executable tests | validated |

## Validation Record

- `Rscript scripts/00_downloads/05_acquire_ds06_smhi_shark.R`: complete; 219 packages and 27,700,519 bytes, then idempotent verification without re-download.
- `Rscript scripts/02_inventory_screen_ds06_smhi_shark.R`: complete; 909,693 rows, 7,948 core, 478,860 external-transfer, 422,885 outside; rerun verified existing outputs.
- `Rscript scripts/02_resolve_ds06_smhi_shark_duplicates.R`: complete; four shared samples, 51-field fingerprint, zero exact duplicate fingerprints and redundant rows; rerun verified checksums.
- `Rscript scripts/02_summarize_ds06_smhi_shark_screening.R`: passed; provisional Tier A primary-reference role remains pending.
- `Rscript -e 'testthat::test_file("tests/test_stage2_contract.R", reporter="summary", stop_on_failure=TRUE)'`: passed after correcting two test expectations exposed by the real provider versions and empty-map CSV typing.
- `Rscript scripts/02_validate_stage2_contract.R`: passed; idempotent DS06 verification and focused tests recorded in `outputs/logs/stage2_contract_validation_20260808T195120Z.log`.
- `Rscript -e 'testthat::test_dir("tests", reporter="summary", stop_on_failure=TRUE)'`: all Stage 0–2 tests passed.

## Conservative Scientific State

- DS06 materially confirms a usable direct-carbon route, but it is overwhelmingly an external-transfer holding and does not repair the core/offshore Tier A–C gap.
- The 7,948 core rows come from three packages; source-row presence does not yet establish enough compatible sample totals, recurrence years, positive/negative windows, or independent networks.
- Carbon and biovolume values remain taxon-level source measurements. They cannot be summed until Stage 5 verifies sampled volume, size domain, technical replicates, methods, quality flags, and autotrophic-community completeness.
- Shared SHARK sample IDs did not yield scientifically identical rows across packages under the strict 51-field rule. This prevents false deletion but does not license pooling package series before method and sample harmonization.
- Exact CMEMS-era overlap is deliberately unresolved until the exact product metadata contract is frozen; zero in the pending summary means not assessed, not no overlap.
