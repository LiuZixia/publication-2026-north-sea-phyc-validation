# Project Progress

**Last update (UTC):** 2026-08-11T11:43:51Z
**Current project stage:** Stage 5 in progress; canonical-source harmonization pass validated and biomass construction gate remains closed.
**Session objective:** Put DS04 and DS22 source repairs in their responsible Stage 2 scripts, remove downstream workaround code, and rebuild Stages 3–5.
**Starting branch/commit:** `main` at `24bbe7c`; `origin/main` at `06bfc81`.
**Relevant starting dirty files:** uncommitted Stage 5 implementation plus generated inventory/tracking changes carried from the prior session.
**First concrete next action:** investigate and register the missing PLET abundance units and provider method epochs required to construct compatible total-biomass samples.

## Completed Work This Session

- Archived unchanged tracker snapshots at session start (`20260811T103551Z_*`) and at the completed ownership/rebuild milestone (`20260811T113020Z_*`).
- Replaced the malfunctioning DS04 Stage 2 acquisition with an idempotent `BSH_Phyto_Zoo_abundance` request and explicit abundance-schema validation. The new immutable run is `data/raw/stage2/ds04_plet_bsh/DS04_PLET_BSH_ABUNDANCE_20260811T103949Z`; payload SHA256 is `3ad6c98b215e944bccb083163f1610aebc306dbba6104131d22301428e4d7fd9`.
- Replaced the schematic-only DS22 acquisition with a direct, versioned provider PEG_BVOL archive intake. The new immutable run is `data/raw/stage2/ds22_peg_bvol/DS22_PEG_BVOL_20260811T104017Z`; archive SHA256 is `e5cb8b2f4c416e186c4a56f350fb855b866204892c3946e7fafca42d2f6e4492` and it contains `PEG_BVOL2026.xlsx`.
- Removed the Stage 5 DS04 reacquisition/config/pin and the DS22 Stage 1 bypass. Stage 5 now resolves all seven sources only through canonical Stage 2 active pins.
- Rebuilt Stage 2 DS04/DS22 screening, Stage 3 coverage, Stage 4 feasibility, and the complete current Stage 5 harmonization pass.
- Stage 3 passed with 19 retained work items, 14 parsed observation datasets, 826087 support units, and 330 eligible dataset-region-period-role rows. Stage 4 conditionally authorizes observation-only Stage 5 work and explicitly blocks Stage 6 and CMEMS.
- Stage 5 verified seven inputs and generated six provisional canonical datasets with 2369523 records and 31947 samples. It validated 2234773 taxonomy rows and found 247261 unique conversion-authority candidates, but authorized zero abundance conversions and zero total-biomass samples. This is an incomplete harmonization result, not evidence that usable datasets or bloom observations do not exist.

## File-Change Ledger

- Tracking: modified `PROGRESS.md`, `PENDING.md`; added archives `docs/agent_tracking/archive/20260810T194356Z_{PROGRESS,PENDING}.md`, `20260810T210114Z_{PROGRESS,PENDING}.md`, `20260811T103551Z_{PROGRESS,PENDING}.md`, and `20260811T113020Z_{PROGRESS,PENDING}.md`.
- Reusable/config/docs/tests: modified `R/04_stage_inventory.R`, `docs/stages/STAGE2.md`, `tests/requirements_map.csv`, `tests/test_stage2_contract.R`; added `R/07_stage5_contract.R`, `config/stage2_ds04_plet_bsh_acquisition.json`, `config/stage2_ds22_peg_bvol_acquisition.json`, `config/stage5_source_contract.csv`, `config/stage5_worms_acquisition.json`, `docs/stages/STAGE5.md`, and `tests/test_stage5_harmonization.R`.
- Stage 2 scripts: modified `scripts/00_downloads/stage2/11_acquire_ds04_plet_bsh.R`, `scripts/02_stage2/datasets/02_screen_ds04_bsh.R`, and `scripts/02_stage2/datasets/02_summarize_ds15_ds22_screening.R`; replaced deleted `scripts/00_downloads/stage2/22_acquire_ds22_figshare.R` with added `scripts/00_downloads/stage2/22_acquire_ds22_peg_bvol.R`.
- Stage 2 metadata: modified `metadata/stage2/acquisition/ds04_plet_bsh_active_run.csv`, `metadata/stage2/control/acquisition_status.csv`, `metadata/stage2/screening/ds04_plet_bsh_location_summary.csv`, and `metadata/stage2/screening/ds04_plet_bsh_screening_summary.csv`; replaced deleted `metadata/stage2/acquisition/ds22_figshare_active_run.csv` and `metadata/stage2/screening/ds22_ices_figshare_screening_summary.csv` with added `metadata/stage2/acquisition/ds22_peg_bvol_active_run.csv` and `metadata/stage2/screening/ds22_peg_bvol_screening_summary.csv`.
- Stage 3 rebuilt metadata: modified `metadata/stage3/gate/coverage_gaps.csv`, `metadata/stage3/input/input_manifest_checksums.csv`, `metadata/stage3/input/stage3_input_manifest.csv`, `metadata/stage3/method/method_biological_coverage.csv`, and `metadata/stage3/inventory/stage3_output_registry.csv`.
- Stage 4 rebuilt metadata: modified `metadata/stage4/feasibility/provisional_dataset_manifest.csv` and `metadata/stage4/inventory/stage4_output_registry.csv`.
- Stage 5 code: added `scripts/00_downloads/stage5/02_acquire_worms_taxonomy.R` and `scripts/05_stage5/00_audit_inputs.R`, `00_run_stage5.R`, `01_extract_conversion_authority.R`, `02_profile_taxon_conversion.R`, `03_build_provisional_canonical.R`, `04_build_taxonomy_crosswalk.R`, `05_build_conversion_readiness.R`, `06_build_lifeform_crosswalk.R`, `07_build_provisional_sample_audit.R`, `08_build_report.R`, `98_build_output_registry.R`, and `99_validate_stage5.R`.
- Stage 5 metadata: added `metadata/stage5/input/{input_artifact_manifest,source_readiness}.csv`; `metadata/stage5/conversion/{conversion_authority_provenance,conversion_authority_summary,conversion_field_registry}.csv`; `metadata/stage5/taxonomy/{worms_active_run,worms_query_log,worms_taxonomy_crosswalk,worms_taxonomy_summary}.csv`; `metadata/stage5/lifeform/{lifeform_crosswalk,lifeform_crosswalk_summary}.csv`; `metadata/stage5/harmonization/{canonical_observation_summary,canonical_partition_manifest,conversion_readiness_by_taxon,conversion_readiness_summary,harmonization_issues,sample_method_completeness_manifest,sample_method_completeness_summary,taxon_conversion_coverage,taxon_conversion_summary}.csv`; `metadata/stage5/gate/stage5_gate_status.csv`; and `metadata/stage5/inventory/{file_inventory,stage5_output_registry}.csv`.
- Cross-stage inventory/status: modified `metadata/stage1/inventory/file_inventory.csv`, `metadata/stage2/inventory/file_inventory.csv`, `metadata/stage3/inventory/file_inventory.csv`, `metadata/stage4/inventory/file_inventory.csv`, `metadata/stage_file_inventory_summary.csv`, `scripts/00_traceability/01_build_stage_file_inventory.R`, and `scripts/99_stage_status.R`.
- Ignored generated artifacts: created the two immutable raw Stage 2 runs above, the checksum-pinned Stage 5 WoRMS raw run, six `data/interim/stage5/canonical/*.csv` partitions, `data/interim/stage5/reference/peg_bvol_2026.csv`, `data/interim/stage5/sample_method_completeness.csv`, refreshed Stage 3/4 reports and figures, `outputs/reports/stage5_harmonization.md`, and timestamped validation logs.

## Validation Commands and Outcomes

- `Rscript scripts/00_downloads/stage2/11_acquire_ds04_plet_bsh.R`: passed; created and pinned a 78280543-byte abundance payload with the required schema.
- `Rscript scripts/00_downloads/stage2/22_acquire_ds22_peg_bvol.R`: passed; created and pinned the 1790602-byte provider archive and verified `PEG_BVOL2026.xlsx`.
- Stage 2 DS04/DS22 screening and acquisition-status refresh: passed; 16 work items complete, 3 unavailable, none unfinished.
- `Rscript scripts/02_stage2/control/99_validate_stage2.R`: passed its complete offline replay after the local test-helper correction; log `outputs/logs/stage2_contract_validation_20260811T114322Z.log`. It regenerated all five stage inventories with 3288 files and zero unresolved generated/raw artifacts.
- `Rscript scripts/03_stage3/00_run_stage3.R`: passed; log `outputs/logs/stage3_validation_20260811T110504Z.log`.
- `Rscript scripts/04_stage4/00_run_stage4.R`: passed; log `outputs/logs/stage4_validation_20260811T110643Z.log`.
- `Rscript scripts/05_stage5/00_run_stage5.R`: passed, including Stage 5 tests, manifest checks, report, registry, inventories, and status; log `outputs/logs/stage5_validation_20260811T112958Z.log`.
- Active-reference search found no remaining DS04 Stage 5 corrective acquisition or DS22 schematic/bypass references. `metadata/stage_file_inventory_unresolved.csv` contains zero unresolved rows.

## Conservative State

- Stage 5 is not complete: its state is `harmonization_in_progress_biomass_construction_blocked` with four unresolved scientific blockers.
- The PLET exports omit measurement units; provider sampling/analysis methods and method epochs are not joined; taxonomy/PEG ambiguity remains; and no sourced lower/central/upper conversion-uncertainty rule is registered.
- No Stage 6 outcome or event construction is authorized. No CMEMS PhyC value has been accessed.
- Superseded DS04 and DS22 raw runs were retained unchanged as historical provenance; only their active pins were replaced.

## Last Completed Milestone

- Canonical-source ownership refactor and full Stage 3–5 rebuild completed with Stage 5 conservatively blocked.
- Latest archive snapshot: `20260811T113020Z_PROGRESS.md` / `20260811T113020Z_PENDING.md`.
