# Progress

## Current State

- **Updated (UTC):** 2026-08-08T16:12:29Z
- **Current stage:** Stage 1 complete and accepted. All five principal-investigator decisions of 2026-08-08 are implemented and frozen.
- **Session objective:** Decide the Stage 1 checkpoint-commit scope and whether to close the remaining EMODnet Biology route assumption before Stage 2.
- **Branch/commit:** `main` at `753c8d5`, with all remediation uncommitted in the working tree.
- **First concrete next action:** Stage the validated Stage 1 files and tracking archives and create the checkpoint commit.
- **Last completed milestone:** Full Stage 1 deterministic rebuild and all Stage 0/1 tests passed at 2026-08-08T16:12:09Z.
- **Archive snapshot:** `docs/agent_tracking/archive/20260808T161229Z_PROGRESS.md` and `..._PENDING.md`.

Live counts, checksums, and gate states are **generated**, not narrated here: see `outputs/stage_status.md` (`Rscript scripts/99_stage_status.R`). This file records decisions and rationale only.

## Completed Work

### Stage 1 defects repaired

Eight defects were found and fixed. The automated suite passed before every one of them, so the tests were extended in step.

1. **Biological screen too narrow.** Matched only `phytoplank`; DS02 (RWS) and DS04 (BSH) were excluded as outside biological scope while recall reported them found. Recall now asserts retention as well as presence.
2. **PLET parser required a DOI.** Seven archived catalogue datasets marked "No DOI" produced no registry row, including DS17 `OSPAR_LLUR-SH_2010-2020`. Restricted holdings are the least likely to carry a DOI and the most important for gap filling, so the filter biased discovery in the one direction no count would reveal.
3. **PLET names are provider codes.** DS17 was then screened out on its name while DS18 survived only because that provider appended `_phyto`. PLET is now a scope-guaranteed catalogue.
4. **Title identity depended on capitalisation.** `[^a-z0-9]` was applied before `tolower`, deleting every capital.
5. **Collection DOIs merged distinct observatories.** PLET publishes eight Marine Scotland series under `10.17031/1637`; Loch Ewe, Scalloway, Scapa, and Stonehaven became one family.
6. **The GBIF geographic screen was inert.** An inclusion term in a disjunction any phytoplankton dataset satisfied. Replaced by a recorded `geographic_screen_state`; geography is never enforced at dataset level.
7. **Non-ASCII rows were silently unmatchable** under the C locale, so a benchmark could have gone unrecalled with nothing failing.
8. **The benchmark set only contained datasets the modules were built around.** Extended from 9 to 16 (DS03, DS09, DS12, DS17, DS18, DS23, DS26 added); the extension immediately exposed defects 2 and 3.

### Stage 1 deliverables added

- `metadata/stage1_ds_crosswalk.csv` — every DS01–DS34 register entry resolved against archived evidence, with availability computed from archived licence and access evidence rather than from the register's claim. 30 of 34 resolved; the four that did not (DS20, DS21, DS31, DS33) are all recorded as unavailable or excluded-by-decision. No discovery failure remains.
- `metadata/stage1_acquisition_shortlist.csv` — 19 named datasets ranked for Stage 2, replacing "1 advanced to acquisition against 8,060 pending" with an ordered work order.
- `metadata/stage1_unavailable_candidates.csv` — the five datasets the study proceeds without, with the consequence already applied.
- `metadata/provider_access_requests.csv` — seven requests, each with its availability treatment, the consequence applied now, and the trigger that would re-admit it.
- `config/screening_rules.json` and `config/ds_register_crosswalk.json` — screening and ranking rules as versioned configuration rather than code.

### Checkpoint and EMODnet decision audit

- `scratch.R` is a six-line diagnostic against an abandoned Figshare run and is not a pipeline input; exclude it from the commit and remove it after confirming no retained logic depends on it.
- The timestamped files under `docs/agent_tracking/archive/` are required immutable handoff snapshots; commit them intact, including snapshots that preserve superseded or failed states.
- The stale validation note was reconciled to the generated 30/34 resolved and 19-dataset shortlist state.
- `scripts/99_stage_status.R` now treats blank/`NA` `sent_utc` values as unsent and distinguishes diagnosed no-route/excluded-by-decision entries from undiagnosed search failures. A regression test verifies 0 sent, 7 awaiting send, four diagnosed absences, and zero undiagnosed failures.
- The official EMODnet documentation exposes a live Biology occurrence WFS at `geo.vliz.be/geoserver/Dataportal/wfs`, distinct from the searched ERDDAP catalogue route. Run an append-only direct-route comparison after the checkpoint commit and before Stage 2 acquisition.
- The checkpoint validation detected a stale registry encoding that stored non-ASCII text as literal `<U+....>` tokens. Regeneration now writes proper UTF-8 and is byte-stable across repeated rebuilds; the accepted registry SHA-256 is `a765fde77776b6d57d0004f307207c47221d8c22f2607e717e9cdddc1f97f2a9`.

### Principal-investigator decisions of 2026-08-08, now frozen

1. **Access policy — no deadlines** (`config/access_and_licence_policy.json`). A dataset obtainable only by contacting a provider is unavailable at the current stage; its consequence applies immediately, not at a deadline. Requests are still sent (`docs/access_requests/DRAFT_EMAILS.md`) and a reply re-admits the dataset as a dated addition. Rationale: access latency is unbounded, so waiting would make the analysable scope a function of correspondence timing rather than a design decision.
2. **Tiered licence rule.** Open licences are used normally; openly reachable records with no stated licence are usable for exploratory Stage 2–4 work, never redistributed, and must have licence resolved before the Stage 7 freeze; contact-required records are not used. Recorded caveat: the working assumption that EU-funded data are CC-BY is not universally true and is applied nowhere in the pipeline — every classification is read from archived provider evidence. Assumption and evidence agree here, because the records with unknown licences are also the ones that cannot be downloaded.
3. **Protocol-change register fully approved**, including correction of eight rows whose approval reference read "System auto-approval policy" while attributed to the principal investigator.
4. **Reviewer recorded as Dr. Zixia Liu**, self-review, independent second review deferred until results exist and required before the Stage 7 freeze. Recorded in the new `config/scientific_review.json` rather than in the frozen search configuration, whose checksum is pinned into all ten archived run summaries — editing it would have invalidated every executed search. Stage 1 action 2 is explicitly **not** marked satisfied, because designer and reviewer are the same party.
5. **Basin-wide framing retained.** The paper is not narrowed. The offshore arm becomes a required component pursued through the open OBIS CPR route at Tier D/E, and a subregion is declared an observation-adequacy limit only after every open route has been tried.

### The decisive finding these decisions produced

Applying decision 1 to the archived licence evidence reclassified DS08. All 28 of its carbon and all 24 of its biovolume children state "Licensing unknown: contact principal investigator to gain access"; only its abundance children are CC-BY. Under the frozen policy those carbon and biovolume datasets are unavailable, so:

- **DS08 falls from a Tier A carbon reference to a Tier C abundance sentinel.** The Tier A base reduces to DS06 alone, in the external-transfer region.
- **No available source measures lifeform dominance as a carbon share.** It must be derived from abundance through DS22 `PEG_BVOL` at every source, making the conversion-uncertainty propagation added earlier this session load-bearing rather than precautionary.
- **DS12 CPR is *not* blocked.** Its phytoplankton records are reachable through the open OBIS/EurOBIS route, so the offshore arm survives at Tier D/E — better than the register's contact-only classification implied.
- **DS17, DS18, DS19, DS20, DS21 are unavailable** and recorded in `metadata/stage1_unavailable_candidates.csv` with the consequence already applied.

Two further defects surfaced while implementing this: `paste0(character(0), "")` returns a length-one string, so two register entries with zero evidence were being reported as openly available; and DS20's resolution pattern matched an ICES report rather than data. Both are fixed and covered by tests.

### Earlier plan and workflow changes (now approved)

- **Access requests are parallel and non-blocking** (Stage 1 action 14), with consequences applied immediately at Stage 4 action 8 rather than at a deadline.
- **Stage 2 acquires in shortlist rank order** rather than registry order.
- **Stage 4 action 9 declares the Tier A base explicitly** before PhyC inspection.
- **Stage 5 action 10 carries lower/central/upper conversion series** through outcome construction to the Stage 10 metrics; every headline metric is reported three times and the PhyC increment is accepted only where it holds across all three.
- **Stage 6.3 registers a threshold-percentile sensitivity and a seasonal phenology check**, because a fixed 90th percentile fixes bloom prevalence by construction.
- **Stage 9 action 10 and Stage 10 register a positive control** (CMEMS chlorophyll against in-situ chlorophyll) **and a negative control** (date-permuted PhyC). Without them a null result cannot be distinguished from a broken matchup, and a null is a legitimate outcome of this study.
- **Status is generated, not narrated** (`scripts/99_stage_status.R`), and **requirements map to tests** (`tests/requirements_map.csv`, enforced by a test that fails on any unmapped Stage 1 action).

## Scientific Findings Recorded Before PhyC Inspection

1. **The confirmatory analysis rests on Tier C conversion.** Only DS06 retains a usable direct-carbon route, and it is external-transfer by the Stage 0 assignment.
2. **Lifeform dominance must be derived, not measured.** No available source expresses it as a carbon share.
3. **Offshore coverage rests on one Tier D/E source**, DS12 CPR via OBIS. DS19 and DS20 yielded no usable route.
4. **The transition region depends on a single provider**: DS06 and DS26 are both SMHI, so two independent networks cannot be claimed there.
5. **The German coastal sector retains one of three sources** (DS04), in the sector where *Phaeocystis* blooms recur.

These are recorded in `README.md` under "Observation-Adequacy Limits Known Before PhyC Inspection" and in `DATASET_SYSTEMATIC_SEARCH.md` §13.2.

## File-Change Ledger

| Path | Change | Purpose | Status |
|---|---|---|---|
| `R/01_registry_identity.R` | added | Dependency-free identity and screening-rule loaders, unit tested | complete |
| `config/screening_rules.json` | added | Screening and identity rules, versioned apart from the checksum-pinned search config | complete |
| `config/ds_register_crosswalk.json` | added | DS01–DS34 resolution patterns, declared attributes, and ranking weights | complete |
| `scripts/01_compile_candidate_registry.R` | edited | PLET parser fix, screening from config, UTF-8 marking, benchmark retention guard | complete |
| `scripts/01_build_ds_crosswalk.R` | added | Resolve the register and generate the ranked shortlist | complete |
| `scripts/99_stage_status.R` | added/edited | Generate status from artifacts and correctly classify request and diagnosis states | regression test passed |
| `scripts/01_validate_stage1.R` | edited | Validate the whole artefact chain for determinism, not the registry alone | complete |
| `tests/test_stage1_search.R` | edited | Nine new tests covering the repaired defects and the new deliverables | complete |
| `tests/requirements_map.csv` | added | Requirement-to-test traceability, enforced by test | complete |
| `metadata/*` | regenerated/added | Registry, recall, flow, crosswalk, shortlist, access register | validated |
| `docs/STAGED_WORK_PLAN.md` | edited | Stage 1 actions 13–14, Stage 2 ordering, Stage 4 actions 8–9, Stage 5 action 10, Stage 6.3 checks, Stage 9 action 10, Stage 10 controls | complete |
| `docs/DATASET_SYSTEMATIC_SEARCH.md` | edited | §13.1 audit and remediation; §13.2 crosswalk, shortlist, and feasibility findings | complete |
| `README.md` | edited | Observation-adequacy limits known before PhyC inspection | complete |
| `config/access_and_licence_policy.json` | added | Frozen availability, licence, and redistribution rules | complete |
| `config/scientific_review.json` | added | Reviewer identity and honest independence statement; supersedes the frozen placeholder | complete |
| `docs/access_requests/DRAFT_EMAILS.md` | added | Seven ready-to-send request drafts | awaiting send |
| `metadata/stage1_unavailable_candidates.csv` | added | Datasets the study proceeds without, with reasons | complete |
| `config/protocol_change_register.csv` | edited | 28 rows, all approved; six new rows for the 2026-08-08 decisions | complete |
| `docs/agent_tracking/archive/20260807T195118Z_*` through `20260808T154957Z_*` | added | Preserve required immutable session and milestone handoff snapshots | ready to commit |
| `scratch.R` | removed from working tree | Discard obsolete diagnostic against an abandoned Figshare run; not a pipeline input | excluded from commit |

## Validation Record

- `Rscript scripts/01_compile_candidate_registry.R`: passed, no warnings; 16 of 16 benchmarks recalled and retained.
- `Rscript scripts/01_build_ds_crosswalk.R`: latest generated state reports 30 of 34 register entries resolved and 19 datasets shortlisted; the older 31/34 and 22-dataset validation note is stale and must be corrected before commit.
- `Rscript -e 'testthat::test_dir("tests", reporter="summary")'`: all Stage 0 and Stage 1 tests passed, no failures, warnings, or skips.
- `Rscript scripts/01_validate_stage1.R`: passed; registry, recall, crosswalk, and shortlist all reproduce byte-for-byte; log `outputs/logs/stage1_validation_20260808T145322Z.log`.
- `Rscript scripts/99_stage_status.R`: regenerated `outputs/stage_status.md`.
- `Rscript -e 'testthat::test_file("tests/test_stage1_search.R", reporter="summary", stop_on_failure=TRUE)'`: passed after adding generated-status regression coverage.
- `Rscript scripts/01_validate_stage1.R`: passed after the UTF-8 artifact refresh; full log `outputs/logs/stage1_validation_20260808T161209Z.log`.

## Data, Search, and Model State

- Counts, checksums, and screen states: see `outputs/stage_status.md`. Prose totals are deliberately not repeated here.
- The single `advanced_to_acquisition` row remains DS22 `PEG_BVOL_2025`, the conversion authority. No observation dataset has advanced, which is correct for a discovery stage; the shortlist, not that count, is the Stage 2 handoff.
- No observation manifest, event catalogue, recurrence labels, validation split, or CMEMS data exist. No CMEMS PhyC value has been acquired or inspected.
