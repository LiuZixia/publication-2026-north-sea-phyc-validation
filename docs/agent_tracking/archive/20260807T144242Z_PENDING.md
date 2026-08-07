# Pending

- **Updated (UTC):** 2026-08-07T14:35:56Z
- **Carried forward after session snapshot:** `20260807T143428Z`

## First Priority

Implement Stage 0 governance and the first reproducible systematic-search acquisition script under `scripts/00_downloads/`.

Completion evidence:

- frozen machine-readable domain/subregion and provenance configuration;
- a scripted API request with archived raw response, query log, checksum, and restart-safe behavior;
- tests or assertions for storage-target verification, pagination, and response integrity;
- updated `PROGRESS.md` with commands and artifacts; and
- a milestone snapshot of both tracking files when the stage gate is passed.

## Ordered Next Actions

1. Choose and document the Stage 0 configuration formats, identifier rules, checksum algorithm, and R dependency strategy.
2. Create reusable R helpers that verify the `data/raw` symlink target, available storage, atomic downloads, checksums, logging, retries, and secret-safe failures.
3. Implement one source-specific systematic-search script as the tested pattern for the remaining services.
4. Generate the candidate registry and systematic-search flow counts from archived API evidence.
5. Add the remaining in-situ source acquisition scripts and provider-specific screening tests.
6. Advance through temporal/spatial coverage auditing only after the search and acquisition gates pass.

## Blockers and Missing Inputs

- Exact API capabilities, authentication requirements, and rate limits still need to be verified from official documentation for each provider.
- The exact CMEMS product and dataset ID must be frozen from official metadata before any PhyC values are acquired.
- Restricted/contact-only datasets remain unavailable until providers grant access and terms are recorded.

## Known Risks and Required Follow-Up

- Prevent duplicate national records exposed through multiple aggregators from being counted as independent evidence.
- Do not let catalogue descriptions substitute for record-level acquisition and method screening.
- Confirm that every download is created by a version-controlled script and physically stored through the verified HDD symlink.
- Keep credentials out of scripts, manifests, logs, and Git history.
- Freeze observation eligibility and grouped validation design before extracting or inspecting PhyC values.

## Deferred or Out of Scope

- No manual raw-file placement or unrecorded browser download.
- No CMEMS extraction before the in-situ manifest and product selection are frozen.
- No manuscript result, performance metric, or biological conclusion until calculated by the R pipeline.
- No taxonomic identification claim from total PhyC.
