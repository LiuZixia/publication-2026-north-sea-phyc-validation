# Pending

- **Updated (UTC):** 2026-08-08T20:21:20Z
- **Current stage:** Stage 2 ranked acquisition in progress. Ranks 1–2 are acquired and screened; rank 3 DS02 is next after validation/commit. CMEMS PhyC inspection remains prohibited.

## First Priority

**Validate and commit the DS26 milestone, then acquire rank-3 `REGISTER:DS02` from the canonical RWS route.**

Completion evidence for DS02: provider-version raw files and terms are archived and checksummed; overlapping RWS/PLET/EMODnet/ICES copies are linked; variables, coordinates, dates, methods, cadence, abundance/biovolume/carbon convertibility, exact domain state, and preliminary role are recorded without PhyC.

## Ordered Next Actions

1. Reconcile and commit the fully validated DS26 milestone.
2. Acquire and screen rank-3 DS02 RWS phytoplankton from its highest-resolution provider route. Do not substitute PLET or aggregator rows for canonical observations.
3. Continue in frozen rank order with DS04, DS05, and DS07; link DASSH as a DS07 aggregator copy.
4. Freeze exact CMEMS product identity and temporal metadata without downloading or inspecting values, then populate observation overlap potential.
5. Carry DS06 and DS26 into later method/sample qualification. DS26 remains secondary unless a prospective amendment and independent evidence change its role.
6. Acquire only DS08 open abundance children; contact-required carbon and biovolume remain unavailable unless terms change.
7. Resolve all licences and roles before Stage 2 closure while preserving excluded and pending records.

## Needs User Action, Non-Blocking

1. Send the seven drafts in `docs/access_requests/DRAFT_EMAILS.md`, filling sender details and recording `sent_utc`; current availability decisions already apply.
2. Appoint an independent scientific reviewer once preliminary results exist; review is mandatory before the Stage 7 manifest freeze.

## Warnings and Scientific Risks

- DS26's high row count is not long recurrence: it covers 2016 and 2022–2024 only.
- IFCB carbon/biovolume depends on machine classification and image-derived volume. Classifier F1, size selectivity, unidentified ROIs, trophic status, and aggregation compatibility must propagate into later uncertainty.
- DS06 and DS26 share the SMHI provider family. They cannot satisfy a two-independent-network recurrence rule in the transition region.
- DS26 has core-coordinate rows, but this does not make the provider series independent core total-biomass truth.
- The 8.10 GB annotated library is method evidence only; image counts must never inflate observation, event, or network counts.
- Core/offshore confirmatory evidence still depends on later ranked providers and Tier C conversion; offshore remains Tier D/E CPR.
- No dataset is eligible merely because it is open, high-frequency, in-domain, or reports carbon units.

## Deferred or Out of Scope

- Do not inspect CMEMS PhyC until the eligible observation manifest, observation-only outcomes, recurrence labels, and validation splits are frozen.
- Do not construct events, thresholds, recurrence, splits, or performance measures during Stage 2.
- Do not treat source rows, occurrence rows, images, or classifier training items as independent samples or networks.
- Do not treat missing or inadequately observed windows as negatives.
- Do not treat total PhyC as a taxon, lifeform, or *Phaeocystis* measurement.
