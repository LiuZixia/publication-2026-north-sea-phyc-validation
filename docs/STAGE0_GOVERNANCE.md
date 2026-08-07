# Stage 0 Governance and Reproduction Record

## Frozen scientific scope

Stage 0 governs one paper: validation of CMEMS North-West Shelf total phytoplankton carbon as a concurrent proxy for independently observed total-biomass blooms. No PhyC values or performance results are used to construct the domain, subregions, identifiers, outcomes, recurrence rules, or later validation splits.

The primary row unit is `subregion_id × analysis_window`. Samples are nested through stations or subregion-windows into events, years, and monitoring networks. Complete events or years are the independent validation units; networks and hydrographic regions are external-transfer units. The evidence hierarchy, lifeform restrictions, recurrence rules, baselines, metrics, and generic versus *Phaeocystis*-handoff decisions remain frozen in the README and outcome protocol.

## Frozen spatial definition

- Domain: the ICES `Greater North Sea` ecoregion.
- Core region: the Greater North Sea excluding ICES Area `27.3.a` and its subdivisions.
- External-transfer region: ICES Area `27.3.a` intersected with the Greater North Sea.
- Stored CRS: EPSG:4326.
- Separate coastline or land mask: none. The ICES marine polygon boundary is authoritative for Stage 0.
- UTC representation: `%Y-%m-%dT%H:%M:%SZ`.
- Depth convention: positive down, metres.

Station assignment uses geodesic distances under `sf`/s2. A point at zero distance from one polygon is assigned to it. Shared boundaries enter every polygon within `0.000001` m of zero distance. A point outside all polygons is assigned only when its minimum polygon distance is no more than 5,500 m. Multiple candidates are resolved by minimum polygon distance, then minimum distance to polygon centroid, then lexicographic `subregion_id`. Missing coordinates remain unknown; non-finite or out-of-range WGS84 coordinates cause an error.

The machine-readable source of truth is `config/protocol_config.json`. The provider endpoints, feature selectors, licence, and licence-policy URL are frozen in `config/spatial_sources.csv`.

## Raw acquisition and provenance

`scripts/00_downloads/00_download_spatial.R` is the only program that creates these raw spatial inputs. A normal invocation validates checksums and reuses the latest complete registered acquisition. `--refresh` explicitly requests a new append-only provider run. Each accepted run archives:

- the official ICES data-policy page;
- MapServer and layer metadata, including service item ID, API version, and maximum record count;
- an independent feature-count response per layer;
- every feature page with its exact query URL, HTTP status, content type, size, and SHA-256 checksum; and
- a machine-readable manifest plus human-readable acquisition log.

Returned feature totals must equal the independent count response. Provider errors, missing pages, transfer-limit flags, size changes, or checksum changes fail validation. The frozen immutable run used by Stage 0 is recorded in `config/spatial_raw_run.txt`.

## Deterministic derivation and gate

Run from the repository root:

```sh
Rscript scripts/00_downloads/00_download_spatial.R
Rscript scripts/00_derive_spatial.R
Rscript scripts/00_setup.R
```

The first command is idempotent when the registered raw run is unchanged. The second regenerates both GeoJSON files and `metadata/stage0_spatial_provenance.csv` from the pinned raw run. The third checks the locked R environment, reruns derivation, executes the fail-on-warning Stage 0 tests, and records `sessionInfo()` in a timestamped log.

The tests cover configuration, change control, identifiers, dictionary coverage, CRS, geometry validity, unique subregions, the non-overlapping full-domain partition, core/external/outside/missing assignments, invalid coordinates, the exact 5.5 km threshold, shared boundaries, centroid and lexical tie-breaks, raw response counts, pagination, checksums, the archived licence source, and derived-output provenance.

## Scientific approval

Material protocol decisions require an identifiable accountable scientific reviewer and a traceable approval reference in `config/protocol_change_register.csv`. An agent must never create or infer that approval.

Zixia Liu explicitly approved all five Stage 0 decisions on 7 August 2026. The approval reference recorded in the change register is the named statement received in the Codex conversation at 19:17 UTC. This approval covers the domain and external-transfer partition, use of the ICES marine boundary without a separate GSHHG mask, the exact 5,500 m station-assignment rule, and the identifier amendments; it does not authorize any later outcome or model-performance change.
