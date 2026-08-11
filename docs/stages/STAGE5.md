# Stage 5 — In-Situ Harmonization and Biomass Construction

## Current state

Stage 5 is in progress; it has not passed its gate. The current work establishes immutable source provenance, provisional canonical observations, cached taxonomy resolution, a versioned lifeform authority crosswalk, and sample-level compatibility scaffolding. It does not construct bloom outcomes and it does not access CMEMS PhyC.

The machine-readable verdict is `metadata/stage5/gate/stage5_gate_status.csv`. The generated narrative is `outputs/reports/stage5_harmonization.md`.

## Authoritative inputs

Stage 5 consumes the canonical Stage 2 active pins. DS04 supplies the validated `BSH_Phyto_Zoo_abundance` observation payload, and DS22 supplies the provider `PEG_BVOL` archive containing `PEG_BVOL2026.xlsx`. Source repairs belong to the Stage 2 acquisition scripts; Stage 5 does not reacquire or bypass those inputs. Earlier malformed raw runs remain immutable historical evidence but are not active inputs.

## Data contracts

The six provisional canonical partitions under `data/interim/stage5/canonical/` have one row per provider taxon-measurement record. Their sizes, row counts, checksums, and provisional state are registered in `metadata/stage5/harmonization/canonical_partition_manifest.csv`. Reported values, units, names, identifiers, timestamps, coordinates, depths, and provider record links are preserved. Harmonized method and accepted-taxonomy fields remain incomplete and the tables must not be treated as Stage 5-ready biomass.

The sample audit under `data/interim/stage5/sample_method_completeness.csv` has one row per provider-defined sample. Its tracked manifest records its checksum and row count. Unknown method epochs, size domains, converted fractions, biomass risk, completeness, and biomass estimates remain explicit unknowns. The three lower/central/upper carbon fields are missing by design until a sourced conversion-uncertainty rule is registered.

WoRMS requests are scripted, batched, cached unmodified, and checksum registered. Exact name matches and validated provider AphiaIDs are distinct from fuzzy candidates and unresolved terms. The PEG_BVOL crosswalk classifies authority rows using its reported class, genus, and trophic fields; it does not infer *Phaeocystis* colony or solitary forms and has not yet been applied to observation-level biomass.

## Why biomass is not yet constructed

The current blockers are machine-readable in `metadata/stage5/harmonization/harmonization_issues.csv`:

- PLET abundance exports do not report their measurement unit;
- provider method fields have not yet been joined into sample-level method epochs;
- taxonomy and PEG size/stage ambiguity remains for part of the data;
- no sourced rule yet propagates conversion uncertainty into parallel lower, central, and upper reference series.

Provider carbon and biovolume from DS06 are preserved, but total phytoplankton carbon still requires autotrophic scope, compatible sampling support, and sample completeness. A provider carbon field is not automatically a complete total-biomass sample.

## Execution

The complete current pass is:

```bash
Rscript scripts/05_stage5/00_run_stage5.R
```

The runner performs the idempotent WoRMS acquisition, rebuilds the audits and provisional tables from canonical Stage 2 inputs, validates their manifests, runs the Stage 5 tests, writes the blocked gate, renders the report, refreshes the output registry and repository inventories, and records `sessionInfo()` in a timestamped log.

## Gate interpretation

`harmonization_in_progress_biomass_construction_blocked` means the generated artifacts are valid for continuing Stage 5 work only. It authorizes neither Stage 6 outcome/event construction nor CMEMS acquisition. Zero authorized samples means “not yet demonstrated sufficiently compatible and complete,” not “no useful observations exist” and not “no bloom occurred.”
