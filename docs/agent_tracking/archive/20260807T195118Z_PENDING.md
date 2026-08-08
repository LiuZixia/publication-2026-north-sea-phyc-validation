# Pending

- **Updated (UTC):** 2026-08-07T19:21:52Z
- **Carried forward after Stage 0 gate snapshot:** `20260807T192152Z`
- **Current stage:** Stage 0 passed; Stage 1 has not begun.

## First Priority

**Prepare and execute the Stage 1 reproducible systematic search without inspecting PhyC.**

Completion evidence:

- each in-scope source has a frozen query strategy and a version-controlled acquisition module under `scripts/00_downloads/`;
- exact endpoints, parameters, geographic and biological terms, API versions, UTC times, pages/cursors, retry states, HTTP statuses, response files, and software versions are registered;
- every raw response is immutable, checksummed, and linked to one append-only search run;
- pagination, server caps, provider totals, duplicate pages, and partial responses reconcile;
- a generated candidate registry preserves provider IDs, versions, URLs/DOIs, licences, access dates, screening states, exclusions, and duplicate-family links;
- known-item recall is tested against established North Sea monitoring datasets; and
- search-flow counts reproduce from the registry rather than narrative values.

## Ordered Next Actions

1. Audit and freeze provider-specific search strategies for PLET, ICES DOME, EMODnet Biology/EurOBIS/OBIS, SMHI SHARK, and relevant provider catalogues.
2. Repair or replace the existing preliminary EMODnet script so it follows the current immutable-download API, retrieves all pages, checks reported totals, and produces the common search manifest.
3. Implement one ordered R acquisition module per source family and test each against a small reproducible request before full execution.
4. Execute the complete searches, archive responses, calculate checksums, and generate the candidate registry and search-flow counts.
5. Reconcile the Stage 1 gate, create its milestone snapshot, and only then begin record-level acquisition/screening.

## Blockers and Missing Inputs

- Provider API capabilities, authentication requirements, rate limits, bulk-export alternatives, and request-only routes require official verification before each query is frozen.
- Restricted/contact-only datasets remain pending until records and terms are actually supplied.
- A second scientific reviewer should check ambiguous Stage 1 exclusions and query choices where possible.

## Known Warnings and Scientific Risks

- `scripts/00_downloads/01_search_emodnet_erddap.R` is preliminary and predates the current download-helper return schema; it is not an executable Stage 1 search gate and must be repaired before use.
- Narrative discovery counts in `docs/DATASET_SYSTEMATIC_SEARCH.md` are provisional evidence, not reproducibly executed search results.
- Aggregator and provider copies must not be counted as independent networks or observations.
- The local branch contains the completed Stage 0 milestone but remains ahead of `origin/main`; remote availability is not part of the local gate.

## Deferred or Out of Scope

- Do not perform record-level scientific screening until the Stage 1 search gate passes.
- Do not acquire or inspect CMEMS PhyC before the in-situ manifest and observation-only split registry are frozen.
- Do not infer taxonomic information from total PhyC.
- Do not claim biological or validation results before the complete held-out pipeline runs from registered inputs.
