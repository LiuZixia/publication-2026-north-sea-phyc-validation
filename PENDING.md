# Pending

- **Updated (UTC):** 2026-08-08T19:08:53Z
- **Current stage:** Stage 2 contract and EMODnet WFS record-level closure complete. Ranked provider acquisition is next; CMEMS acquisition and PhyC inspection remain prohibited.

## First Priority

**Commit the validated Stage 2 contract/WFS checkpoint, then acquire rank-1 `REGISTER:DS06` from canonical SMHI/SHARK provider routes.**

Completion evidence: immutable provider files and acquisition manifests cover the national and regional SHARK phytoplankton packages exposed by WFS 2453/6698 and the ranked Kattegat/Skagerrak products; variables, licences, record keys, coordinates, dates, units, methods, and duplicate links are inventoried under the frozen contract.

## Ordered Next Actions

1. Commit this checkpoint before any DS06 raw provider acquisition.
2. Acquire the highest-resolution canonical SMHI/SHARK packages for DS06, including the national and regional packages routed from WFS 2453/6698; treat WFS, GBIF, OBIS, and PLET versions only as aggregator/provenance copies.
3. Screen DS06 files and records under the frozen contract, including biovolume/carbon availability, method epochs, cadence, spatial support, and exact duplicate linkage.
4. Continue in rank order with DS26, DS02, DS04, DS05, and DS07.
5. Acquire only DS08's open abundance children; contact-required carbon and biovolume children remain unavailable.
6. Resolve every `licence_state` before an item can enter the later eligible manifest; link PLET-to-Cefas SmartBuoy copies at record level.

## Needs User Action, Non-Blocking

1. Send the seven drafts in `docs/access_requests/DRAFT_EMAILS.md`, filling sender details and recording `sent_utc`; current availability decisions already apply and no analysis waits for replies.
2. Appoint an independent scientific reviewer once preliminary results exist; review is mandatory before the Stage 7 manifest freeze.

## Warnings and Scientific Risks

- The confirmatory analysis rests on uncertain abundance-to-carbon conversion; DS22 taxon coverage and lower/central/upper conversion propagation remain load-bearing.
- WFS 2453 and 6698 are large but are one SMHI provider family, not independent networks. Their open CC0 aggregator copies do not replace canonical SHARK acquisition and deduplication.
- WFS 5951 is only an exploratory targeted `Diatoma`/*Phaeocystis* series from 1995–1996. It cannot supply total-community truth or meet the ≥10-year recurrence criterion.
- Offshore evidence still rests on Tier D/E CPR; German coastal high-tier coverage still depends on DS04.
- The generic WFS layer timed out for an unbounded count and rejects simultaneous `bbox` plus `cql_filter`; the completed, pinned route uses official `eurobis-obisenv_full` `viewParams` links from MarineInfo.
- Large raw WFS exports are immutable geometry/provenance evidence, not canonical analysis inputs.
- No dataset is eligible merely because it is ranked, open, or has in-domain records.

## Deferred or Out of Scope

- Do not inspect CMEMS PhyC until the eligible observation manifest, observation-only outcomes, recurrence labels, and validation splits are frozen.
- Do not treat missing or inadequately observed windows as negatives.
- Do not begin event construction, modelling, performance analysis, or redistribution of provider files during Stage 2.
- Do not treat total PhyC as a taxon, lifeform, or *Phaeocystis* measurement.
