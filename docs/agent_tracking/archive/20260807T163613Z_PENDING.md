# Pending

- **Updated (UTC):** 2026-08-07T16:21:03Z
- **Carried forward after session snapshot:** `20260807T161836Z`

## First Priority

**Close the remaining Stage 0 provenance, spatial-validity, identifier, and version-freeze gaps before beginning Stage 1.**

Completion evidence:

- the ICES raw acquisition is recreated through a restartable, symlink-verified, atomic download with endpoint/version/license/access metadata, registered SHA-256, machine-readable manifest, and human-readable log;
- hydrographic subregions use scientifically reviewed, cited definitions rather than an uncited completion-oriented rectangle, and pass GEOS plus s2 validity/partition tests;
- the GSHHG source has a frozen version and provenance or is removed if it is not actually used;
- UTC parsing, timestamp precision, date-only treatment, and depth representation/unknown-state conventions are explicit;
- ID functions exist for every required entity and match configured prefixes and dictionary recipes, with collision detection/resolution and full timestamp-safe sample identity;
- station assignment tests cover default buffer distance, outside-domain states, coastline behavior, overlap/tie-breaking, missing coordinates, and complete domain partitioning;
- protocol decisions have an identifiable accountable reviewer and evidence of approval;
- one non-interactive entry point can rebuild and validate all Stage 0 outputs from registered inputs;
- all checks pass, including fail-on-error tests and relevant diff/schema/provenance checks; and
- accepted artifacts and the milestone tracking snapshot are committed under a concrete Git revision.

## Ordered Next Actions

1. Correct `scripts/00_downloads/00_download_spatial.R` to meet the external raw-store contract and regenerate a checksummed, manifested, versioned ICES acquisition without overwriting the existing raw artifact.
2. Replace or scientifically justify the 8.5°E/57°N proxy split, document authoritative source/version/license, repair geometry, and add s2 partition/validity assertions.
3. Reconcile GSHHG, UTC, depth, buffer, boundary, and tie-breaking rules with actual code and traceable decisions.
4. Add year/subregion generators, use the configured `STN-` prefix, make sample identity timestamp-safe, and implement/test collision handling and canonicalization.
5. Expand the test suite to cover every Stage 0 contract and make the pipeline entry regenerate spatial outputs before validation.
6. Remove relevant staged-diff failures, rerun from a restored clean project environment, update tracking from the outputs, and commit the frozen Stage 0 milestone.
7. Only after the gate passes, resume Stage 1 source-specific systematic searches.

## Blockers and Missing Inputs

- A scientifically accountable reviewer must approve the core/external-transfer partition and coastal-buffer rule; the repository label alone is not evidence of review.
- An authoritative hydrographic subregion definition or defensible prespecified derivation must be selected and cited.
- GSHHG version/source/use and full time/depth conventions remain unresolved.
- Exact API capabilities, authentication requirements, and rate limits still need official verification for Stage 1 providers.
- The exact CMEMS product and dataset ID must be frozen before PhyC acquisition.
- Restricted/contact-only datasets remain unavailable until providers grant access and terms are recorded.

## Known Warnings and Scientific Risks

- The current spatial acquisition lacks mandatory provenance and could silently reuse a partial or changed raw response.
- The external-transfer split is agent-authored rather than demonstrated to be an ICES hydrographic subdivision.
- Default s2 operations fail on the generated subregion geometry.
- Missing ID functions and prefix/recipe mismatches can assign unstable or colliding identities to repeated raw records.
- The current passing tests do not detect the above gate failures.
- Staging is not a versioned protocol freeze; no Stage 0 commit exists yet.
- Prevent duplicate provider/aggregator records from being counted as independent evidence in Stage 1.
- Keep credentials out of scripts, manifests, logs, and Git history.

## Deferred or Out of Scope

- No further Stage 1 search execution, record screening, or coverage summaries until Stage 0 passes.
- No manual raw-file placement or unrecorded browser download.
- No CMEMS extraction before the in-situ manifest and product selection are frozen.
- No manuscript result, performance metric, or biological conclusion until calculated by the R pipeline.
- No taxonomic identification claim from total PhyC.
