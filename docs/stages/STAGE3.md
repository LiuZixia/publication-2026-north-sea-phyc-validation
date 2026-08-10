# Stage 3 — Coverage Audit and Scientific-Use Gate

## Purpose and boundary

Stage 3 determines what the independently acquired observation evidence can support before bloom outcomes are constructed or CMEMS PhyC is inspected. It covers the complete 19-item Stage 2 handoff: 16 completed work items and the three explicit unavailable dispositions (DS08, DS23, and DS28). It does not infer ecological negatives from unavailable access, harmonize biomass, define recurrence, select a CMEMS product, or acquire any CMEMS value.

The authoritative scientific requirements remain in `docs/STAGED_WORK_PLAN.md` and the observation protocol. This file documents how those requirements are executed.

## Inputs and source adapters

`config/stage3_source_adapters.csv` assigns an explicit adapter, monitoring-network identity, duplicate family, observation kind, and Stage 3 scope to every ranked work item. `scripts/03_stage3/00_build_input_manifest.R` joins those declarations to the authoritative Stage 2 status and checksum pins and writes a 19-row input manifest. No dataset is selected by searching filenames.

Fourteen datasets have observation-bearing payloads that can support a Stage 3 coverage description: DS02, DS03, DS04, DS05, DS06, DS07, DS09, DS10, DS11, DS12, DS16, DS24, DS26, and DS27. DS15 is a derived occurrence-density product, DS22 is a conversion authority, and DS08/DS23/DS28 are unavailable. These five remain visible in the manifest and gate rather than becoming zero-row observations.

`R/05_stage3_contract.R` contains source-specific parsers for screened-record tables, PLET archives, EurOBIS, PANGAEA, the large ICES COMP4 archive, and FerryBox summaries. The standard sample-support table preserves defensible datetime precision, coordinates, depth, subregion, method epoch, and identity limitations. Coordinate and transect identifiers are labelled as proxies and never reported as true stations.

## Outputs and interpretation

The coverage scripts generate temporal cadence by network-year and station/proxy-year, time-of-day and explicit tidal-phase availability, seasonal effort, spatial support, vertical support, method and biological-variable availability, method-epoch state, a network-year-variable matrix, figures, coverage gaps, and the dataset-region-year/method-epoch/window/tier role gate. Figures show points and effort only; spatial interpolation is prohibited.

Gate roles have exactly four values: `eligible`, `secondary`, `exploratory`, and `unusable`. They are assigned separately to each observed subregion, year/method epoch, analysis window, and reference tier; a well-sampled year therefore cannot make an entire multi-year span eligible. `Eligible` means that Stage 3 coverage and the source's prospective role permit the combination to proceed to Stage 4/5 checks. It is not a final reference label: biomass compatibility, target-season adequacy, recurrence, outcome construction, and held-out splitting remain later-stage work. DS03 is retained for duplicate auditing but cannot be an independent eligible network because it represents the RWS/MTWL lineage already represented by DS02.

The CMEMS-overlap table deliberately records product identity and overlap as unknown until a product is prospectively frozen. This is not evidence of no overlap or no usable data. Stage 4 evaluates feasibility from the eligible observation combinations without inspecting PhyC.

## Rebuild and validation

Run the ordinary cached offline replay from the repository root:

```sh
Rscript scripts/03_stage3/00_run_stage3.R
```

Force every source adapter to rebuild from immutable Stage 2 evidence:

```sh
STAGE3_REBUILD=1 Rscript scripts/03_stage3/00_run_stage3.R
```

During adapter development, one or more named caches can be rebuilt without bypassing any source validation, for example `STAGE3_REBUILD_IDS=DS24 Rscript scripts/03_stage3/01_build_coverage.R`. Publication validation still requires the full command above at least once.

The runner performs no downloads. It rebuilds the manifest, sample-support and coverage products, method/biology audit, gate, and figures; proves a same-input deterministic replay; runs `tests/test_stage3_coverage.R`; writes the calculated gate state; checksums every authoritative output and adapter cache; refreshes traceability inventories and generated project status; and records R/session information in a dated validation log.

The calculated gate is `metadata/stage3/gate/stage3_gate_status.csv`. The checksummed output registry is `metadata/stage3/inventory/stage3_output_registry.csv`. Exact counts and role totals must be read from generated outputs, not copied from this description.
