# Progress

## Current State

- **Updated (UTC):** 2026-08-08T20:21:20Z
- **Current stage:** Stage 2 ranked acquisition in progress; rank-1 DS06 and rank-2 DS26 acquisition/screening milestones are complete, with final full-suite validation pending.
- **Session objective:** Acquire and record-screen the recurrent SMHI IFCB observation archive while keeping its annotated-image reference library in a method-evidence role — completed.
- **Branch/starting commit:** `main` at `796b7c2` (`stage2: acquire and screen canonical DS06 SHARK data`).
- **First concrete next action:** Run the extended Stage 2 validation and full Stage 0–2 suite, then commit the DS26 milestone before rank-3 DS02 acquisition.
- **Last completed milestone:** Rank-2 DS26 recurrent IFCB observations and full classifier reference library archived and screened at 2026-08-08T20:15:53Z.
- **Archive snapshot:** `docs/agent_tracking/archive/20260808T201553Z_PROGRESS.md` and `..._PENDING.md` preserve the DS26-start handoff; `20260808T194809Z_*` preserves the pre-DS06 milestone handoff.

## Completed Work

- Commits `9ea8a4b` and `796b7c2` preserve the Stage 2 contract/EMODnet closure and rank-1 DS06 acquisition. DS06 remains provisional Tier A and pending compatible total-community/method/CMEMS-metadata qualification.
- Rank-2 DS26 was resolved into two related resources rather than counted twice: the SMHI-published recurrent IFCB observation stream and the SciLifeLab annotated-image reference library used for classifier/method evidence.
- `scripts/00_downloads/06_acquire_ds26_smhi_ifcb.R` archived official Figshare article metadata, the publisher-managed SMHI EML, and the 18,334,266-byte Darwin Core archive. The three-artifact run is pinned at `data/raw/stage2/ds26_smhi_ifcb/DS26_SMHI_IFCB_20260808T195600Z`.
- The observation archive contains 17,731 event rows, 121,103 occurrence rows, and 1,111,062 extended measurement/fact rows. All provider event and occurrence keys reconcile.
- Exact geometry assigns 3,212 occurrence rows to the core, 57,844 to external transfer, 60,047 outside the domain, and zero to invalid coordinates. All datetimes parse; all record IDs are unique and stable.
- The stream reports carbon content, biovolume concentration, abundance, classifier identity, classifier F1 score, trophic type, unidentified-ROI totals, instrument flags, and sampling methods. Classifications are explicitly machine-predicted.
- Provider series comprise Tångesund in 2016, Baltic records in 2022–2024, and Skagerrak/Kattegat records in 2022–2024. Four calendar years cannot establish registered recurrence; incomplete imaging size coverage cannot be assumed to be total phytoplankton.
- DS26 is therefore provisional Tier B, `lifeform_only`, and `secondary`: a high-frequency lifeform/temporal-resolution benchmark, not recurrent total-biomass truth and not a network independent of DS06.
- `scripts/00_downloads/07_acquire_ds26_ifcb_reference_library.R` archived all four Figshare v6 files (8,104,707,049 bytes). Source sizes and MD5 values, SHA-256 checksums, and both ZIP CRCs passed. The CC-BY README documents 86,232 expert-annotated images, 146 classes, and 2016–2026 coverage.
- The image/MATLAB library is recorded solely as classifier, taxonomy, size-range, and method evidence. Its images never enter observation or network counts.
- No CMEMS file or PhyC value was acquired or inspected; no event outcome, recurrence label, split, or performance measure exists.

## File-Change Ledger

| Path | Change and purpose | Validation state |
|---|---|---|
| `PROGRESS.md`, `PENDING.md` | Refresh canonical handoff for the DS26 milestone | reconciled |
| `docs/agent_tracking/archive/20260808T201553Z_PROGRESS.md`, `..._PENDING.md` | Immutable DS26-start snapshots | complete |
| `config/stage2_ds26_smhi_ifcb_acquisition.json` | Freeze rank-2 provider archive, EML, Figshare metadata, run, and selection rule | executed |
| `config/stage2_ds26_ifcb_reference_library.json` | Freeze four-file v6 method-reference acquisition from pinned official metadata | executed |
| `scripts/00_downloads/06_acquire_ds26_smhi_ifcb.R` | Archive and validate recurrent observations plus official role metadata | executed and idempotent logic present |
| `scripts/00_downloads/07_acquire_ds26_ifcb_reference_library.R` | Restartable full reference acquisition with size, MD5, SHA-256, CRC, and atomic finalization | executed |
| `scripts/02_inventory_screen_ds26_smhi_ifcb.R` | Inventory all Darwin Core fields, join events/measurements, and exact-screen occurrences | executed |
| `scripts/02_summarize_ds26_ifcb_reference_library.R` | Verify and summarize image/class/method evidence without promoting images to observations | executed |
| `scripts/02_validate_stage2_contract.R` | Extend idempotent milestone validation through rank-2 DS26 | passed |
| `metadata/stage2_ds26_smhi_ifcb_active_run.csv`, `..._acquisition_manifest.csv` | Pin three official observation/metadata artifacts | complete |
| `metadata/stage2_ds26_smhi_ifcb_figshare_file_inventory.csv` | Pin all four v6 library files, sizes, URLs, and MD5 values | complete |
| `metadata/stage2_ds26_smhi_ifcb_variable_inventory.csv`, `..._table_summary.csv` | Inventory 85 columns and reconcile three raw tables | complete |
| `metadata/stage2_ds26_smhi_ifcb_measurement_summary.csv`, `..._event_summary.csv` | Register 32 measurement type/unit groups and three provider series | complete |
| `metadata/stage2_ds26_smhi_ifcb_screening_summary.csv`, `..._output_registry.csv` | Record secondary Tier B disposition and pin outputs | complete |
| `metadata/stage2_ds26_ifcb_reference_active_run.csv`, `..._acquisition_manifest.csv` | Pin four complete 8.10 GB reference files | complete |
| `metadata/stage2_ds26_ifcb_reference_summary.csv` | Record 86,232 images, 146 classes, and method-only role | complete |
| `data/raw/stage2/ds26_smhi_ifcb/DS26_SMHI_IFCB_20260808T195600Z/` | Immutable recurrent archive/EML/article-metadata run | complete, ignored raw store |
| `data/raw/stage2/ds26_ifcb_reference/DS26_IFCB_REFERENCE_20260808T200000Z/` | Immutable four-file image/MATLAB reference run | complete, ignored raw store |
| `data/interim/stage2_ds26_smhi_ifcb_record_screening.csv` | Contract-level 121,103-row occurrence screen | complete, ignored and checksum-pinned |
| `docs/DATASET_SYSTEMATIC_SEARCH.md` | Add §13.6 generated DS26 evidence and conservative role | complete |
| `tests/test_stage2_contract.R`, `tests/requirements_map.csv` | Add acquisition, inventory, geometry, tier, and independent-network regression checks | focused suite passed |

## Validation Record

- `Rscript scripts/00_downloads/06_acquire_ds26_smhi_ifcb.R`: complete; three artifacts and 18,376,897 total bytes, with EML identity/licence/temporal checks and Darwin Core CRC/member validation.
- `Rscript scripts/00_downloads/07_acquire_ds26_ifcb_reference_library.R`: complete; four files and 8,104,707,049 bytes, all size/MD5/SHA-256 verified and both ZIPs CRC-tested.
- `Rscript scripts/02_inventory_screen_ds26_smhi_ifcb.R`: complete; 121,103 occurrences, 3,212 core, 57,844 external, 60,047 outside, zero invalid.
- `Rscript scripts/02_summarize_ds26_ifcb_reference_library.R`: complete; 86,232 images and 146 classes, method evidence only.
- `Rscript -e 'testthat::test_file("tests/test_stage2_contract.R", reporter="summary", stop_on_failure=TRUE)'`: passed with DS06 and DS26 assertions.
- `Rscript scripts/02_validate_stage2_contract.R`: passed; idempotent ranked acquisitions, checksum verification, frozen routing, and focused tests recorded in `outputs/logs/stage2_contract_validation_20260808T202040Z.log`.
- `Rscript -e 'testthat::test_dir("tests", reporter="summary", stop_on_failure=TRUE)'`: all Stage 0–2 tests passed.

## Conservative Scientific State

- DS26 supplies high-frequency machine-imaging evidence but only four calendar years. It cannot satisfy the ≥10-year recurrence criterion or the two-independent-network alternative.
- All DS26 carbon and biovolume values are linked to machine-classified imaging occurrences. Classifier uncertainty, imaged size range, unidentified ROIs, trophic assignment, and within-event aggregation remain mandatory later audits.
- The 3,212 core occurrences come from the Skagerrak/Kattegat provider series and do not create a core monitoring network independent of SMHI.
- The annotated library is excellent method evidence but is neither sampled field observations nor an additional network. Counting its 86,232 images as observations would be pseudoreplication.
- Exact CMEMS temporal overlap remains unknown pending the metadata-only product freeze. This does not change DS26's secondary recurrence disposition.
