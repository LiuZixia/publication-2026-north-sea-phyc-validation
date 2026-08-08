# 02A — North Sea PhyC Bloom-Proxy Validation

## Paper Identity

**Exact title:** **Can CMEMS North-West Shelf Phytoplankton Carbon Detect Recurrent North Sea Phytoplankton Blooms? A Multi-Network, Lifeform-Stratified Validation**

**One-sentence thesis:** CMEMS total phytoplankton carbon is accepted as a North Sea bloom proxy only if it adds calibrated, event-level discrimination of independently observed total-biomass blooms and that value is reproducible across years, regions, monitoring networks, and the dominant recurrent bloom lifeforms.

**Paper type:** Multi-network product validation and proxy-suitability study.

## The One Question

> Does daily CMEMS North-West Shelf total PhyC distinguish independently observed recurrent phytoplankton biomass blooms from adequately observed non-bloom conditions across the dominant North Sea bloom lifeforms?

This is one generic-proxy question. Lifeform stratification tests transportability and failure modes; it does not turn PhyC into a taxonomic classifier.

## Why 02A Is Broader Than *Phaeocystis*

PhyC represents modelled total phytoplankton carbon, not *Phaeocystis* and not any other taxon. A *Phaeocystis*-only validation could confuse a generic biomass response with species-specific skill. Therefore, 02A first tests whether PhyC detects total bloom biomass across independently observed North Sea bloom regimes.

The downstream 02B–02E programme remains focused on *Phaeocystis*. Those modules may use PhyC only if the *Phaeocystis*/haptophyte stratum of 02A passes its prespecified validation rule. A generic 02A pass is not sufficient.

## Primary Hypothesis and Outcome

**H1:** Adding a prespecified PhyC representation improves held-out-event calibration and discrimination of an independently observed total-phytoplankton biomass bloom over seasonality, persistence, and non-PhyC baselines.

**Primary outcome:** `total_biomass_bloom_present` for an adequately observed `subregion_id × analysis_window`.

The primary reference is microscopy- or imaging-derived total phytoplankton carbon. Valid lower-tier substitutes are total biovolume or taxon-resolved counts with defensible size-to-biovolume and biovolume-to-carbon conversion. Chlorophyll, the CPR Phytoplankton Colour Index, and derived presence/absence maps are comparators or supporting evidence, not the primary truth where direct carbon or biovolume is available.

## Confirmatory Lifeform Strata

The initial candidate strata are:

1. diatom-dominant blooms;
2. *Phaeocystis*/haptophyte-dominant blooms;
3. dinoflagellate-dominant blooms.

Coccolithophore-dominant and pico/nanophytoplankton-dominant blooms enter confirmatory analysis only if the independent-data audit demonstrates adequate annual recurrence, biomass-resolved observation, and event counts. Otherwise, they remain a documented evidence gap or exploratory stratum.

Lifeform dominance must be calculated from carbon or biovolume share. Counts from differently sized taxa must never be summed to infer cross-lifeform dominance.

## Recurrence Eligibility

A lifeform becomes confirmatory only when the reference data, inspected without PhyC, show all of the following:

- at least ten adequately sampled years in one defined subregion, or at least five years in each of two independent networks;
- at least ten independently observed bloom events across the pooled networks;
- a bloom in at least 80% of adequately sampled years in one prespecified high-confidence subregion/series, or at least 70% in each of two independent networks;
- representation in at least two monitoring networks or a separately justified high-frequency sentinel series;
- enough positive and negative analysis windows for event- or year-level validation.

These rules operationalize an annually recurrent bloom regime while allowing for documented observation gaps. Lifeforms blooming in 60–79% of adequately sampled years are reported as frequently recurring but remain secondary unless the two-network rule is met. No lifeform is assumed to bloom everywhere every year.

## Unit of Inference

- row: `subregion_id × analysis_window`;
- cluster: `event_id` nested within `year` and `monitoring_network`;
- independent validation unit: complete event or year;
- external-transfer unit: held-out monitoring network or North Sea hydrographic region;
- positive: window meeting the frozen independent total-biomass bloom rule;
- negative: adequately sampled window below that rule;
- unknown: inadequate sampling, unresolved biomass conversion, or indeterminate taxonomic coverage.

Daily, 3-day, 7-day, and sampling-cadence-matched windows may be compared inside training data. One primary window is then frozen for evaluation. Sparse monthly monitoring cannot validate daily timing.

## Dataset Search and Evidence Hierarchy

The systematic dataset search, completed-search log, inclusion criteria, and candidate register are in [docs/DATASET_SYSTEMATIC_SEARCH.md](docs/DATASET_SYSTEMATIC_SEARCH.md).

The intended acquisition order is:

1. public harmonized lifeform, abundance, and biomass datasets in the Plankton Lifeform Extraction Tool;
2. raw national monitoring data from RWS, BSH, NOVANA/Aarhus University, SMHI SHARK, Cefas, VLIZ, and relevant Scottish networks;
3. ICES DOME community data and EMODnet Biology/EurOBIS records for coverage completion and provenance;
4. high-frequency sentinel series from Helgoland Roads and Sylt Roads;
5. CPR taxon abundance and Phytoplankton Colour Index for basin-scale coarse validation;
6. contact-only or restricted datasets where they close a material spatial or lifeform gap.

No dataset is pooled until its sampling gear, preservation, size selectivity, taxonomic resolution, units, cadence, quality flags, and licensing are recorded.

## Observation-Adequacy Limits Known Before PhyC Inspection

The executed Stage 1 search (`DATASET_SYSTEMATIC_SEARCH.md` §13) establishes three limits on what this paper can claim. They are recorded here, before any PhyC value is inspected, so that none of them can later appear as a post-hoc exclusion.

1. **Reference tier.** Only DS06, in the external-transfer region, has a usable direct-carbon route. DS08's carbon and biovolume datasets state an unknown licence requiring author contact and are therefore unavailable under the frozen access policy; only its CC-BY abundance series can be used. The confirmatory analysis consequently rests on Tier C abundance-to-carbon conversion through the pinned DS22 `PEG_BVOL` file, and whether the incremental value of PhyC survives that conversion uncertainty is a prespecified result of this study rather than a caveat.
2. **Lifeform stratification.** No available source measures lifeform dominance as a carbon share directly; DS08 was the only one, through the datasets now unavailable. Dominance must therefore be derived from abundance via `PEG_BVOL` at every source, with the conversion uncertainty carried into the `phaeocystis_handoff_pass` decision that authorizes PhyC use in 02B, 02C, and 02E.
3. **Spatial.** Every high-tier candidate lies at a coastal margin or in the Skagerrak/Kattegat transition. Offshore central and northern North Sea coverage rests entirely on the CPR records (DS12) reachable through OBIS/EurOBIS, at Tier D/E; DS19 and DS20 yielded no usable route.

**The basin-wide framing above is retained.** The paper is not narrowed to coastal and transition waters. Instead, every subregion is pursued through every open route — including the Tier D/E offshore CPR arm, which is a required component rather than an optional one — and a subregion is declared an observation-adequacy limit only after that has been done, always before PhyC is inspected. Datasets the study proceeds without are listed in `metadata/stage1_unavailable_candidates.csv`; access is a documented reason for a limit, never a reason a result was excluded.

## Fixed Inputs

- frozen North Sea domain and hydrographic subregions;
- CMEMS North-West Shelf total PhyC product and version;
- dataset registry, raw-file checksums, licenses, and acquisition dates;
- taxonomic crosswalk based on reported names and WoRMS identifiers where available;
- monitoring-method and size-selectivity metadata;
- observation-only recurrence and event catalogue;
- event/year/network split registry;
- assimilation and product-dependence metadata.

## Analysis Plan

### Stage 1 — Dataset qualification

1. Execute and archive all portal queries and responses.
2. Deduplicate datasets exposed through more than one aggregator.
3. Audit temporal overlap with CMEMS, spatial coverage, cadence, taxonomic detail, and biomass convertibility.
4. Assign each dataset an evidence tier and analysis role.
5. Freeze the eligible dataset manifest before examining PhyC performance.

### Stage 2 — Independent reference construction

1. Preserve original taxa, units, life stages, colony fields, and analytical methods.
2. Convert biovolume to carbon only with a cited taxon- or shape-appropriate method.
3. Create total-carbon or total-biovolume series without mixing incompatible sampling size fractions.
4. identify dominant lifeforms from carbon or biovolume share only.
5. derive subregion- and season-aware bloom events from the independent observations.
6. label inadequately observed windows as unknown, not non-bloom.

### Stage 3 — PhyC matchup and validation

1. Audit model coverage, depth treatment, coastal masks, assimilation regime, and product versions.
2. Construct point-neighbourhood and hydrographic-subregion matchups.
3. Compare a small registered set of surface, upper-layer, local, and subregional PhyC representations.
4. derive anomalies, changes, persistence, and spatial extent using training folds only.
5. fit baselines before adding PhyC.
6. evaluate held-out events and years.
7. run network-held-out and region-held-out transfer tests.
8. quantify performance heterogeneity across lifeform, water type, season, observation method, and assimilation era.

## Required Baselines

1. seasonal prevalence or day-of-year climatology;
2. previous adequately observed bloom state;
3. seasonality plus physical and nutrient covariates;
4. CMEMS chlorophyll-only;
5. baseline plus total PhyC.

Satellite chlorophyll and CMEMS fields affected by ocean-colour assimilation cannot provide independent truth. They are explicitly dependency-sensitive comparators.

## Primary Evaluation

- Brier score, calibration slope, and calibration intercept;
- PR-AUC and ROC-AUC, with PR-AUC emphasized for rare events;
- sensitivity at a training-selected fixed false-alarm rate;
- incremental performance over the primary baseline;
- between-event, between-year, and between-network performance distributions;
- lifeform-specific sensitivity and false-negative rate;
- performance loss under network-held-out and region-held-out transfer.

Daily-row confidence intervals are prohibited. Uncertainty is clustered or resampled at event/year/network level.

## Owned Figures

1. systematic-search flow diagram and dataset coverage map;
2. sampling cadence, temporal overlap, and method matrix;
3. independent annual recurrence and biomass share of candidate lifeforms;
4. observed total biomass versus matched PhyC by network and region;
5. baseline-versus-PhyC held-out performance;
6. lifeform-stratified sensitivity and calibration;
7. network- and region-transfer performance;
8. false-positive high-PhyC non-blooms and lifeform-specific missed blooms.

## Inputs Received and Outputs Handed Off

**Receives:** CMEMS product specification, frozen North Sea subregions, and the shared split rules.

**Hands to 02B/02C:** only the PhyC representation, preprocessing, domain restrictions, and uncertainty that pass within the *Phaeocystis*/haptophyte stratum. Generic or diatom-only success is not transferable to the *Phaeocystis* papers.

**Hands to 02E:** out-of-fold *Phaeocystis*-relevant occurrence probabilities and uncertainty if that stratum passes; otherwise, no PhyC occurrence layer.

**Retains within 02A:** the broader total-bloom and lifeform-stratified validation results.

## Explicitly Out of Scope

- identifying the taxonomic group from PhyC alone;
- onset hazard or forecast lead time;
- post-onset peak timing or magnitude;
- satellite algorithm validation;
- DOC or chlorophyll lag estimation;
- source-field fusion;
- marine organic aerosol emission.

## Decision Rules

- `generic_pass`: PhyC adds reproducible, calibrated total-bloom discrimination across held-out events and more than one network, without material collapse in the prespecified confirmatory lifeforms;
- `conditional_pass`: value is restricted to named lifeforms, regions, seasons, products, or observing methods;
- `fail`: PhyC has no meaningful incremental value, is poorly calibrated, or apparent skill is not reproducible outside the development network;
- `phaeocystis_handoff_pass`: the *Phaeocystis*/haptophyte stratum independently meets its minimum event count, calibration, discrimination, and transfer rules.

Only `phaeocystis_handoff_pass` authorizes PhyC use in 02B, 02C, or the *Phaeocystis* layer of 02E.

## Definition of Done

- reproducible systematic-search archive and screening log;
- frozen candidate and included-dataset registers;
- documented taxonomic and lifeform crosswalk;
- independent total-biomass and recurrence audit;
- complete baseline comparison with event/year-level validation;
- network- and region-transfer assessment;
- lifeform-stratified results and explicit failure modes;
- generic and *Phaeocystis*-specific decisions reported separately;
- publication-ready manuscript centred only on concurrent bloom-proxy validity.

See [docs/CONTEXT.md](docs/CONTEXT.md), [docs/DATASET_SYSTEMATIC_SEARCH.md](docs/DATASET_SYSTEMATIC_SEARCH.md), [docs/OUTCOME_AND_LIFEFORM_PROTOCOL.md](docs/OUTCOME_AND_LIFEFORM_PROTOCOL.md), the [Stage 0 governance record](docs/STAGE0_GOVERNANCE.md), and the [staged work plan](docs/STAGED_WORK_PLAN.md).
