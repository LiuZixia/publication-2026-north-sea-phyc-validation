# Pending

- **Updated (UTC):** 2026-08-08T16:12:29Z
- **Current stage:** Stage 1 complete and accepted. Stage 2 ready to begin. Do not begin CMEMS acquisition or PhyC inspection.

## Current Audit

All five principal-investigator decisions of 2026-08-08 are implemented and frozen. The protocol-change register carries no pending rows. Everything automatable passes and reproduces byte-for-byte.

## Needs You — but nothing is blocked on it

1. **Send the seven request drafts** in [`docs/access_requests/DRAFT_EMAILS.md`](docs/access_requests/DRAFT_EMAILS.md). Fill in name, affiliation, and email, confirm each provider's current address, and record the date in `sent_utc` in `metadata/provider_access_requests.csv`. Nothing waits on a reply: under the frozen access policy each dataset is already treated as unavailable and its consequence is already applied. A reply re-admits the dataset as a dated addition to the change register.
2. **Review the pre-existing uncommitted changes** to `docs/DATASET_SYSTEMATIC_SEARCH.md`, `docs/STAGED_WORK_PLAN.md`, and the rewrite of `scripts/00_downloads/01_search_emodnet_erddap.R`, which predate this session. Then commit.
3. **Identify an independent second scientific reviewer once preliminary results exist.** Recorded as deferred in `config/scientific_review.json` with a hard requirement to complete before the Stage 7 manifest freeze. The exclusions most needing a second reader are the 18,503 rows excluded on one reason code and the access-driven scope reductions.

## First Priority

**Create a clean, validated Stage 1 checkpoint commit before any further network acquisition.**

Completion evidence: all required Stage 1 files and tracking archives are committed and `scratch.R` is excluded. The complete Stage 1 validation has passed immediately before staging, with log `outputs/logs/stage1_validation_20260808T161209Z.log`.

## Ordered Next Actions

1. Commit the validated Stage 1 checkpoint: include all required timestamped tracking archives and exclude the removed `scratch.R` diagnostic.
2. Before Stage 2, append a direct EMODnet Biology occurrence-WFS search run using the official `Dataportal:eurobis` route; compare its dataset identifiers/holdings with archived OBIS/EurOBIS evidence and rerun the crosswalk and ranking.
3. Commit the EMODnet closure result separately, whether it demonstrates no new holdings or changes the shortlist.
4. Freeze the Stage 2 record-level screening contract, then acquire in shortlist rank order beginning DS06, DS26, DS02, DS04, DS05, and DS07.
5. For DS08, acquire the 128 open-licence abundance children only; the 289 contact-required carbon and biovolume children are out of scope.
6. Record a `licence_state` per acquired file, so shortlist entries flagged `resolve_licence_before_stage7_manifest_freeze` cannot reach the confirmatory manifest unresolved.
7. Link the PLET-to-Cefas SmartBuoy relationship at record level; it is one-to-many across time and intentionally unlinked at Stage 1.

## Blockers, Warnings, and Scientific Risks

- **The confirmatory analysis now rests on Tier C conversion.** DS08's carbon and biovolume children are contact-required and therefore unavailable; only DS06 retains a usable direct-carbon route, and it sits in the external-transfer region. Every carbon estimate flows through the pinned DS22 `PEG_BVOL` file, so its North Sea taxon coverage audit is now load-bearing rather than routine.
- **No available source measures lifeform dominance as a carbon share.** It must be derived from abundance via `PEG_BVOL` everywhere, with lower/central/upper uncertainty carried through to the Stage 10 metrics. Whether the PhyC increment survives that spread is a prespecified result.
- **Offshore coverage rests on one Tier D/E source.** DS12 CPR through its open OBIS route is the only offshore evidence; DS19 and DS20 yielded no usable route. CPR silk retention makes it semi-quantitative for most phytoplankton, so offshore conclusions will be weaker than coastal ones by construction, not by chance.
- **The transition region depends on a single provider.** DS06 and DS26 are both SMHI holdings, so "two independent networks" cannot be claimed there.
- **The German coastal sector lost two of three sources.** DS17 and DS18 are contact-required, leaving DS04. This is the sector where *Phaeocystis* blooms recur.
- The 8,060 `pending` catalogue rows are neither eligible nor independent datasets. The shortlist, not that number, is the Stage 2 handoff.
- GBIF lacks a spatial dataset filter; 341 rows positively indicate out-of-domain water and 5,492 carry no domain evidence. Record-level geographic screening is mandatory at Stage 2.
- DS20's crosswalk pattern previously matched an ICES report rather than data; it now resolves to nothing. Stage 2 must treat any resolution as provisional until a record schema is inspected.
- Nine EMODnet ERDDAP queries returned HTTP 404, that server's zero-results response, undocumented in the frozen strategy. EMODnet Biology's databox route was never queried directly; OBIS/EurOBIS very likely covers the same holdings, but that is assumed rather than demonstrated.
- Abandoned preflight raw runs are immutable, excluded by the active-run registry, and must not be reused silently.

## Deferred or Out of Scope

- Do not inspect CMEMS PhyC until the eligible in-situ manifest, observation-only outcomes, recurrence labels, and validation splits are frozen.
- Do not interpret search yield, known-item recall, or shortlist rank as biological eligibility, data usability, independence, or feasibility. Rank is a work order.
- Do not redistribute any acquired provider file.
- Do not begin event construction, modelling, or performance analysis during Stage 2.
- Do not treat a passing suite as proof that untested requirements are satisfied. It passed while two benchmarks were excluded, seven catalogue datasets were invisible, four observatories were merged into one family, the geographic screen was inert, and two datasets with zero evidence were reported as openly available. `tests/requirements_map.csv` now makes the covered set explicit.
