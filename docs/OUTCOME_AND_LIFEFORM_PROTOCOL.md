# Outcome and Lifeform Protocol

## 1. Purpose

This protocol turns heterogeneous North Sea phytoplankton observations into one defensible concurrent bloom outcome and prespecified lifeform strata. It is frozen before PhyC feature selection or performance evaluation.

## 2. Core Principle

CMEMS PhyC is total carbon. The primary reference must therefore approximate total phytoplankton carbon or biovolume rather than the raw number of cells. A million small cells and a million large cells are not equivalent biomass.

## 3. Canonical Observation Table

Retain one row per reported taxon, life stage, size class, and sample. Minimum fields are:

- `dataset_id`, `sample_id`, `station_id`, `datetime_utc`;
- `latitude`, `longitude`, `sample_depth_m`;
- `sampling_gear`, `size_fraction_min_um`, `size_fraction_max_um`;
- `preservative`, `analytical_method`, `analyst_or_lab`;
- `reported_name`, `accepted_name`, `aphia_id`, `reported_rank`;
- `autotrophy_status` and uncertainty;
- `lifeform_primary`, `lifeform_secondary`;
- `colony_state` and *Phaeocystis* life-stage fields;
- `abundance_value`, `abundance_unit`;
- `biovolume_value`, `biovolume_unit`;
- `carbon_value`, `carbon_unit`;
- cell dimensions, shape model, and conversion reference where used;
- provider quality flags and harmonization flags.

Never overwrite the reported value or name. Harmonized fields are additional columns.

## 4. Lifeform Crosswalk

The confirmatory crosswalk contains:

- `diatom`;
- `phaeocystis_haptophyte`;
- `dinoflagellate_autotroph`;
- `coccolithophore`;
- `pico_nano_other`;
- `other_autotrophic_phytoplankton`;
- `unresolved_autotroph`;
- `heterotroph_or_mixotroph_uncertain`.

Autotrophic and heterotrophic dinoflagellates must not be pooled when trophic status is known. Ambiguous mixotrophs retain an uncertainty flag and are handled in sensitivity analysis.

## 5. Carbon and Biovolume Construction

Use the highest available reference tier for each sample:

1. provider-reported carbon;
2. provider-reported biovolume converted to carbon with a documented equation;
3. abundance multiplied by provider-reported or taxon-specific cell volume, then converted to carbon;
4. abundance multiplied by a literature cell-volume distribution, propagated as conversion uncertainty.

Do not convert when taxonomic identity, dimensions, colony structure, or sampling fraction makes the calculation indefensible. Such records can still support within-lifeform abundance analyses.

For *Phaeocystis*, preserve colonies, colonial cells, solitary cells, and total cells separately. Do not infer one from another without an explicit validated conversion.

## 6. Sample-Level Total Biomass

For an internally compatible sample:

`total_phyto_carbon = sum(carbon of eligible autotrophic phytoplankton records)`

The sum is allowed only when the records share a compatible sampled volume and size-domain interpretation. Net concentrates, whole-water microscopy, cytometry, and pigment fractions are not summed into one total without a validated integration model.

Record:

- observed size domain;
- fraction of reported taxa converted to carbon;
- unresolved abundance and biomass share;
- lower and upper carbon estimates;
- completeness class.

## 7. Lifeform Dominance

Where carbon or biovolume is sufficiently complete:

`lifeform_share_g = carbon_g / total_phyto_carbon`

Primary dominance definition:

- `dominant_g`: share greater than 0.50;
- `co_dominant_g`: share from 0.30 through 0.50 and no other group exceeds 0.50;
- `mixed`: no group reaches 0.30 or unresolved biomass prevents assignment;
- `unknown`: biomass completeness is inadequate.

Sensitivity analyses use a 0.40 dominance threshold and propagate carbon-conversion uncertainty. The primary threshold is not optimized against PhyC.

Abundance-only samples may define a within-lifeform bloom but cannot determine cross-lifeform dominance unless the compared taxa have a defensibly homogeneous size domain.

## 8. Seasonal Baseline

Bloom thresholds are local because absolute biomass differs among coastal, mixed, stratified, and transition waters.

For each eligible reference series:

1. assign a frozen hydrographic subregion;
2. estimate a day-of-year seasonal baseline using training years only;
3. use log-transformed carbon or biovolume where appropriate;
4. derive anomaly relative to that baseline;
5. preserve the raw biomass value alongside the anomaly.

No climatology, percentile, smoothing parameter, or standardization value may use the held-out event or year.

## 9. Primary Bloom Outcome

The primary label is `total_biomass_bloom_present`.

A candidate positive window must:

- have adequate biomass completeness;
- exceed the training-derived subregion-season 90th percentile of total carbon or biovolume;
- exceed a minimum positive anomaly defined in the registered protocol;
- satisfy a cadence-aware persistence rule or be independently supported by adjacent observations.

The 90th percentile is the default specification. The 85th and 95th percentiles are sensitivity analyses.

The persistence rule is expressed in elapsed time, not number of samples, and cannot imply precision finer than the observation cadence. A single isolated extreme with no adjacent support is flagged `possible_bloom`, not automatically positive.

## 10. Negative and Unknown Windows

A negative window requires:

- adequate sampling coverage for the method and analysis window;
- total biomass below the bloom threshold;
- no unresolved taxon or size fraction capable of reversing the label;
- no known method failure.

Unknown includes:

- no sample;
- excessive temporal gap;
- incompatible or changing sampling method without calibration;
- inadequate carbon/biovolume completeness;
- unresolved colony or small-cell fraction likely to alter the state;
- location outside valid CMEMS support.

Unknown is never recoded as non-bloom.

## 11. Event Construction

Adjacent positive or possible-positive windows are grouped into an event when their separation is below a cadence- and ecology-appropriate maximum gap. Each event records:

- earliest and latest supported positive time;
- interval-censored start and end;
- maximum observed biomass and its uncertainty;
- dominant or co-dominant lifeform;
- method and network support;
- sampling completeness;
- confidence class.

The event catalogue is built without PhyC values.

## 12. Annual Recurrence

For each `subregion × lifeform × network`, define an adequately sampled year before assessing recurrence. The definition specifies target season, minimum number of observations, and maximum gap based on the network cadence.

Report:

- number of adequately sampled years;
- number and proportion with at least one supported bloom;
- median events per year;
- median seasonal timing and interannual dispersion;
- biomass share and dominance confidence;
- observation-method continuity.

Classify recurrence as:

- `annually_recurrent`: a supported bloom in at least 80% of adequately sampled years in one high-confidence subregion/series with at least ten eligible years, or at least 70% in each of two independent networks with at least five eligible years per network;
- `frequently_recurrent`: a supported bloom in 60–79% of adequately sampled years but not meeting the two-network rule;
- `episodic`: a supported bloom in fewer than 60% of adequately sampled years;
- `indeterminate`: inadequate annual sampling.

Only `annually_recurrent` lifeforms enter the confirmatory lifeform-stratified analysis by default. Selection uses only independent observations and never PhyC performance.

## 13. Dataset Harmonization Without False Pooling

Three analysis layers are retained:

1. **within-dataset standardized layer:** each network uses its most defensible native reference;
2. **cross-dataset common layer:** only comparable carbon, biovolume, or lifeform measures are pooled;
3. **meta-analytic layer:** dataset-specific PhyC effects are combined without forcing raw observations into one scale.

The primary analysis uses the common layer only if comparability passes. Otherwise, the primary estimate is a hierarchical or meta-analytic synthesis of dataset-specific validation results.

## 14. PhyC Matchup

For every observation window, store:

- nearest valid CMEMS cell and distance;
- local-neighbourhood summary;
- hydrographic-subregion summary;
- surface and registered upper-layer PhyC;
- model depth and coastal-mask status;
- time support and any averaging window;
- product version and assimilation regime;
- observation-to-model scale mismatch.

Matchup choices are frozen inside the training design and applied unchanged to held-out events.

## 15. Confirmatory Analyses

### Primary

Compare `baseline` with `baseline + PhyC` for `total_biomass_bloom_present` using held-out complete events or years.

### Lifeform-stratified

Estimate sensitivity, calibration, and false-negative rate among independently assigned diatom-, *Phaeocystis*/haptophyte-, and dinoflagellate-dominant bloom events.

### External transfer

Repeat with an entire monitoring network or hydrographic region held out.

### Method sensitivity

Stratify by direct carbon, biovolume, converted counts, within-lifeform abundance, and large-particle imaging.

## 16. Prohibited Analyses

- predicting lifeform identity from total PhyC and calling it taxonomic identification;
- selecting recurrent lifeforms because they give favourable PhyC performance;
- deriving event thresholds from combined training and test years;
- treating aggregator copies as independent networks;
- comparing cross-lifeform raw cell counts as biomass;
- validating daily timing with monthly samples;
- using satellite chlorophyll as independent truth for an assimilative reanalysis.

## 17. Handoff Rule

The general 02A model and the *Phaeocystis*-specific handoff are separate decisions. The handoff manifest to 02B–02E must report:

- eligible *Phaeocystis*/haptophyte events and networks;
- exact life-stage and biomass definition;
- held-out calibration and discrimination;
- region and method restrictions;
- false-negative modes;
- frozen PhyC representation;
- preprocessing and uncertainty;
- explicit permitted and prohibited downstream uses.
