# Staged Work Plan: In-Situ Discovery to CMEMS PhyC Validation

## 1. Purpose

This plan converts the paper protocol into an executable, publication-oriented workflow. It begins with a reproducible systematic search for in-situ phytoplankton observations and ends with held-out validation of CMEMS North-West Shelf total phytoplankton carbon (`PhyC`).

The order is deliberate. The eligible in-situ dataset manifest, observation-only recurrence assessment, hydrographic scope, and validation design must be frozen before PhyC values are inspected. CMEMS availability or apparent model agreement must not determine which observations are retained.

All search counts, coverage summaries, labels, statistics, tables, and figures are calculated by R scripts from archived raw inputs. LLM-generated or manually estimated results are prohibited. Python is permitted only for a narrowly documented operation for which there is no practical R interface, such as an official data client that cannot be replaced by a direct request from R.

This document expands, but does not replace, the scientific rules in `README.md`, `CONTEXT.md`, `DATASET_SYSTEMATIC_SEARCH.md`, and `OUTCOME_AND_LIFEFORM_PROTOCOL.md`.

## 2. Stage Overview

| Stage | Main question | Required gate before proceeding |
|---|---|---|
| 0. Governance and protocol freeze | What exactly is being tested, where, when, and at what unit? | Domain, subregions, outcome hierarchy, provenance rules, and change-control record are versioned |
| 1. Reproducible systematic search | Which potentially eligible in-situ datasets exist? | API/export responses, query log, candidate registry, and search-flow counts reproduce |
| 2. Acquisition and record-level screening | Which candidates provide usable records and legal access? | Raw files are archived and checksummed; inclusion decisions and duplicate relationships are recorded |
| 3. Coverage and observation-method audit | When, where, how often, and by what method were observations collected? | Temporal, spatial, cadence, depth, method, size-domain, and CMEMS-overlap reports reproduce |
| 4. Feasibility and design gate | Can the primary and lifeform-stratified questions be supported? | Eligible networks, regions, years, reference tiers, and estimable analyses are declared without PhyC inspection |
| 5. In-situ harmonization and biomass construction | Can heterogeneous records form defensible reference variables? | Canonical observation table, taxonomy, units, method epochs, and conversion uncertainty pass checks |
| 6. Observation-only summaries, recurrence, and outcomes | What bloom regimes and adequately observed states occur in the reference data? | Outer splits are frozen before threshold estimation; effort summaries, recurrence eligibility, fold-safe labels, events, and uncertainty are generated without PhyC |
| 7. Analysis-manifest and split freeze | What data and evaluation partitions are allowed in confirmatory analysis? | Dataset manifest, feature candidates, outer splits, exclusions, and analysis roles are locked and hashed |
| 8. CMEMS product audit and targeted download | Which exact PhyC product covers the frozen observations? | Product version and metadata are frozen; subset files cover all eligible matchups and pass integrity checks |
| 9. Spatiotemporal matchup and scale audit | Which model representation is comparable to each observation window? | Matchups, distance/time/depth diagnostics, masks, and candidate representations are generated reproducibly |
| 10. Held-out validation | Does PhyC improve on prespecified non-PhyC baselines? | Outer-fold, event/year, network-transfer, and region-transfer metrics are complete with clustered uncertainty |
| 11. Robustness, failure modes, and decision rules | Where is the conclusion stable, conditional, or invalid? | Sensitivity analyses and false-positive/false-negative audits support an explicit decision |
| 12. Manuscript assembly and reproducibility release | Can a reviewer regenerate every reported result? | One paper renders from registered inputs and generated results; archive and reporting checks pass |

Passing a stage means that its scripts ran successfully and its outputs passed the stated checks. Draft prose alone does not complete a stage.

## 3. Stage 0 — Governance and Protocol Freeze

### Objective

Define the study before data availability or model performance can reshape it.

### Actions

1. Freeze the Greater North Sea polygon and hydrographic subregions in machine-readable geospatial files. Define whether Skagerrak and Kattegat observations are core-domain or external-transfer observations.
2. Freeze coordinate reference systems, UTC time handling, depth conventions, coastline and land-mask sources, and the rule for assigning stations to subregions.
3. Confirm the primary row unit (`subregion_id × analysis_window`) and the hierarchy from sample through network.
4. Preserve the evidence-tier hierarchy, primary outcome, candidate lifeforms, recurrence criteria, required baselines, metrics, and decision rules already specified in the project protocols.
5. Create a protocol-change register with fields for date, change, rationale, affected stages, decision maker, and classification as prospective amendment, sensitivity analysis, or deviation.
6. Define stable identifiers for dataset, source record, sample, station, taxon record, observation window, event, year, network, subregion, search run, and model file.
7. Establish the R environment, dependency lockfile, run logging, checksum method, and directory conventions before acquiring data.

### Outputs

- frozen domain and subregion files;
- machine-readable analysis configuration;
- protocol-change register;
- identifier and data-dictionary specification;
- reproducible R environment and pipeline entry point.

### Gate

Do not begin record screening until spatial definitions, identifiers, and provenance fields are stable enough that the same raw record will receive the same identity in repeated runs.

## 4. Stage 1 — Reproducible Systematic Search for In-Situ Data

### Objective

Execute the search described in `DATASET_SYSTEMATIC_SEARCH.md` using APIs or reproducible machine-readable exports, not narrative web discovery alone.

### Actions

1. Implement one R acquisition module per source family, covering PLET, ICES DOME, EMODnet Biology/EurOBIS/OBIS, and SMHI SHARK, together with the families added by search update `MANUAL-20260807T195118Z` in `DATASET_SYSTEMATIC_SEARCH.md` §12.6: PANGAEA, GBIF, the `data.marine.gov.scot` CKAN API, Cefas Data Hub/DASSH, and ICES figshare. Add further provider catalogues with supported programmatic access as they are identified.
2. Freeze a source-specific search strategy before execution, including controlled terms, synonyms, filters, and expected response fields. Have a second scientific reviewer check exclusions and ambiguous query choices where possible.
3. Query the complete frozen geographic area and all specified biological and measurement terms. Do not restrict a query based on expected ecological results.
4. Record the exact endpoint, API version, query text, parameters or request body, geographic bounds, filters, UTC timestamp, page number or cursor, HTTP status, retry, and response filename.
5. Retrieve all pages and validate that reported totals reconcile with downloaded records. Detect pagination loops, server-side caps, partial content, and duplicate pages.
6. Archive raw JSON, XML, CSV, or provider export files unchanged and calculate checksums.
7. Normalize only dataset-level discovery metadata into a candidate registry. Preserve source-specific identifiers and the raw-response link.
8. Test known-item recall against established North Sea monitoring datasets in the candidate register, using the benchmark set proposed in `DATASET_SYSTEMATIC_SEARCH.md` §12.6: DS02, DS04, DS05, DS06, DS07, DS08, DS10, and DS16, cross-checked against the externally curated OSPAR COMP4 input list (DS24). A missing benchmark triggers query/API diagnosis; it does not justify manually adding an untraceable search hit.
9. Log manual searches, emails, and contact-only routes separately in `metadata/stage1/input/manual_discovery_log.csv`. Do not describe them as API searches. This includes the DS08 Helgoland Roads licence and moratorium enquiry.
10. Register the taxon-to-carbon conversion authority (DS22, `PEG_BVOL`) as a versioned, checksummed acquisition alongside the observation sources. It is republished annually, so an unpinned copy makes every Tier C carbon estimate irreproducible.
11. Generate search-flow totals from the candidate registry: records identified, duplicate catalogue records, unique dataset families, screened, excluded, pending, and advanced to acquisition.
12. Append later searches as new dated `search_run_id` values. Never overwrite the original run. Record per-endpoint retrieval timestamps: provider holdings are actively changing, so the pre-submission re-run is expected to return genuine additions that must be labelled external replication.
13. Resolve every entry of the narrative candidate register (`DATASET_SYSTEMATIC_SEARCH.md` §6 and §12) against the executed search and generate a ranked acquisition shortlist. A count of datasets advanced to acquisition is not a handoff: Stage 2 needs named candidates in a defensible order. Rank by declared reference tier, domain position, access feasibility, and CMEMS-era overlap, with the weights recorded in configuration. An unresolved register entry is a discovery failure to diagnose, never a manual registry insertion.
14. Open every contact-only and restricted access request now, in parallel, and register each one in `metadata/stage1/qualification/provider_access_requests.csv` with what is requested, what it blocks, a follow-up date, a decision deadline, and the fallback that applies if it is refused. Access latency, not computation, is this study's binding constraint: DS08 alone gates the lifeform stratification named in the paper title. Requests are non-blocking for Stage 1 and must not wait for the Stage 2 gate.

### Screening and identity rules

Dataset-metadata screening and catalogue-identity rules live in `config/screening_rules.json`, separate from the frozen `config/stage1_search_config.json`. The search configuration's checksum is embedded in every archived run summary, so correcting a screen must never invalidate a pinned response and force a re-run. Screening changes are versioned in the change register and require a regenerated registry.

Screening at this stage excludes only what is clearly irrelevant. Over-inclusion is corrected by Stage 2 record-level screening; over-exclusion silently removes a candidate from the study and is the more serious error. Where a catalogue's dataset names are provider codes rather than descriptions, a keyword screen on the name has no discriminative validity and must not be applied.

### Essential search fields

- `search_run_id`, source, endpoint, API version, query hash, execution time;
- raw-response path and checksum;
- provider dataset ID, catalogue ID, title, DOI or stable URL, version;
- geographic and temporal metadata as reported by the provider;
- measurement types, taxonomic content, method metadata, access status, and license;
- screening status, exclusion reason, reviewer, and decision date;
- links between duplicate catalogue entries and the canonical provider dataset.

### Quality checks

- Repeating the same query against the archived response produces the same registry rows.
- API record counts reconcile page by page.
- Every registry row points to raw evidence, **and every archived catalogue record produces a registry row**. A parser that skips records it cannot fully populate biases discovery in a direction no count will reveal: requiring a DOI silently discarded the restricted holdings that exist precisely to fill coverage gaps.
- Inclusion and exclusion categories are mutually exclusive and complete.
- Search-flow counts are calculated, never typed manually.
- Known-item recall is tested against benchmarks that the search modules were **not** built around, and each benchmark is checked for retention as well as presence. A benchmark that is recalled and then screened out is a screening defect, and it must fail the build rather than be reported as a successful recall.

### Gate

Advance only after the systematic search is reproducibly executed, every register entry is resolved or its absence diagnosed, and the ranked acquisition shortlist exists. Existing narrative candidate counts remain provisional until supported by archived query responses and generated screening records.

## 5. Stage 2 — Data Acquisition, Licensing, and Record-Level Screening

### Objective

Obtain the actual observations, confirm that they meet the declared criteria, and distinguish true independent networks from aggregator copies.

### Actions

1. Acquire in the order set by the Stage 1 ranked shortlist (`metadata/stage1/qualification/acquisition_shortlist.csv`), highest-resolution provider version first. The shortlist is a work order, not an eligibility decision. Acquiring in rank order front-loads the datasets that can change the Stage 4 feasibility verdict; acquiring in registry order spends the project's effort on catalogue bulk. For restricted datasets, record the request, response, terms, and current status without assuming eventual access, and keep the provider-response register current.
2. Re-check the shortlist against the register crosswalk before closing this stage. A candidate that proves unusable at record level is recorded with its reason and does not silently vanish from the coverage narrative.
3. Store each delivered file unchanged under a versioned raw-data location and record filename, size, checksum, acquisition date, provider version, license, and citation.
4. Inspect file schemas in R and create machine-readable inventories of tables, columns, units, missing-value codes, quality flags, coordinate fields, and date fields.
5. Perform record-level eligibility screening for domain intersection, repeated sampling, CMEMS-era overlap potential, biomass or conversion variables, sampling cadence, method metadata, and licensing.
6. Link duplicate records exposed by PLET, DOME, EMODnet, EurOBIS, OBIS, GBIF, DASSH, or provider portals. Use the highest-resolution provider record as canonical and retain aggregator identifiers for provenance and gap checking. GBIF and DASSH were added by search update `MANUAL-20260807T195118Z`; several holdings publish to one aggregator and not the other, so omitting either creates both false duplicates and false independence.
7. Assign a provisional evidence tier and role: primary reference, lifeform-only validation, comparator, discovery/sensitivity only, pending, or excluded.
8. Record exclusions with controlled reason codes and free-text detail. Never delete excluded rows from the registry.

### Outputs

- immutable raw in-situ files and checksum manifest;
- file and variable inventory;
- record-level screening register;
- dataset lineage and duplicate map;
- licensing and citation register;
- preliminary evidence-tier assignments.

### Gate

A dataset cannot enter a coverage or scientific summary merely because its catalogue description is promising. Actual records, usable terms, parseable dates and locations, and sufficient method metadata must be available.

## 6. Stage 3 — Temporal, Spatial, and Observation-Method Coverage

### Objective

Describe what the in-situ data can genuinely support before creating bloom outcomes or examining PhyC.

### 3.1 Temporal coverage

Calculate separately by dataset, network, station, subregion, method epoch, and year:

- first and last observation date and overlap with each candidate CMEMS product period;
- number of samples, unique sampling days, months, seasons, and adequately sampled years;
- sampling interval distribution, median cadence, upper-tail gaps, and longest gap in the target season;
- within-year seasonal coverage and the probability that expected bloom periods were observed;
- time-of-day and tidal-phase coverage where relevant and available;
- duration and consequences of interruptions, method changes, station relocations, and analyst/laboratory changes;
- support for daily, 3-day, 7-day, or cadence-matched windows without implying finer timing than observed.

Do not summarize only the minimum and maximum dates. A 20-year dataset with one sample per year is not equivalent to a work-daily time series.

### 3.2 Spatial and vertical coverage

Calculate and map:

- sample and station coordinates after coordinate validation;
- samples and adequately sampled years per hydrographic subregion;
- coastal-to-offshore, bathymetric, latitude, longitude, and water-type coverage;
- sampling depth distribution and whether values represent surface, discrete-depth, integrated, or water-column samples;
- station relocation and coordinate precision;
- seasonal spatial bias and network-specific sampling footprints;
- candidate CMEMS grid support, coastal-mask exposure, and distance to valid water cells, without extracting PhyC values;
- spatial clustering and regions with no independent coverage.

Use points and effort surfaces rather than misleading interpolation across unsampled sea areas. Convex hulls or density maps, if shown, must be clipped appropriately and labelled as sampling extent rather than ecological coverage.

### 3.3 Observation-method and biological coverage

Summarize:

- sampling gear, sampled volume, preservation, analytical method, size fractions, detection limits, laboratory, and quality flags;
- taxonomic resolution, proportion linked to accepted names and AphiaIDs, and unresolved taxa;
- availability of abundance, cell dimensions, biovolume, carbon, chlorophyll, pigments, life stages, and colony fields;
- fraction of records and samples potentially convertible to carbon;
- observed size domain and known blind spots, especially small cells, fragile taxa, and *Phaeocystis* colonies versus solitary cells;
- changes in method that require separate method epochs rather than naive pooling.

### Outputs

- temporal-coverage and cadence tables;
- station/subregion coverage maps and seasonal effort maps;
- depth and method-epoch summaries;
- network-by-year-by-variable availability matrix;
- CMEMS temporal-overlap table based on product metadata only;
- reproducible coverage figures for the paper and supplement;
- documented coverage gaps and likely observation biases.

### Gate

Every scientific use must be justified by observed coverage. Classify each dataset-region-period combination as eligible, secondary, exploratory, or unusable for each proposed analysis window and reference tier.

## 7. Stage 4 — Feasibility and Confirmatory-Design Gate

### Objective

Decide, without PhyC values, which paper questions are estimable and where the study must narrow its claims.

### Actions

1. Determine whether at least two genuinely independent monitoring networks support total carbon, total biovolume, or defensible carbon conversion over the CMEMS period.
2. Determine which subregions have both adequately sampled bloom seasons and adequately observed non-bloom windows. Search update `MANUAL-20260807T195118Z` (§12.5) predicts that the offshore central and northern North Sea may have no Tier A–C reference at all, because every identified high-tier source lies at a coastal margin or in the transition region. A subregion with no eligible reference data must be declared here as an observation-adequacy limit, before PhyC is inspected, so that it can never appear as a post-hoc exclusion.
3. Assess whether event/year counts can support held-out evaluation rather than only descriptive matchups.
4. Screen whether the available years, networks, cadence, and variables could possibly satisfy the prespecified recurrence rules. Final recurrence classification follows harmonization in Stage 6.
5. Identify method and size-domain gaps that could reverse a total-biomass label.
6. Declare which questions are confirmatory, secondary, exploratory, or currently infeasible.
7. Record a stop or redesign decision if direct biomass coverage cannot support the primary question. Do not substitute chlorophyll, CPR PCI, or derived occurrence maps silently.
8. Treat every contact-required dataset as unavailable and confirm that its consequence, recorded in `metadata/stage1/qualification/provider_access_requests.csv`, has already been applied. Under `config/access_and_licence_policy.json` there are no response deadlines: a dataset obtainable only by request is unavailable from the moment the search establishes that, and the study proceeds without it. Requests are still sent, and a reply re-admits the dataset through the normal Stage 2 route as a dated addition to the change register — never as a silent improvement to a result. The datasets the study proceeds without are listed in `metadata/stage1/qualification/unavailable_candidates.csv` so that an access-driven scope limit can never be mistaken later for an ecological or performance-driven exclusion.
9. Declare the Tier A base explicitly. The executed search found only DS06 with a usable direct carbon route, in the external-transfer region by the Stage 0 assignment; DS08's carbon and biovolume children are contact-required and therefore unavailable, leaving its CC-BY abundance children only. The confirmatory analysis therefore rests on Tier C abundance-to-carbon conversion. State this here, before any PhyC value is seen, and carry the consequence into Stage 5 action 10 and Stage 10.
10. Do not narrow the analysable domain pre-emptively. The paper's basin-wide framing is retained, so every subregion must be pursued through every open route before any is set aside — offshore coverage rests on the DS12 CPR records reachable through OBIS/EurOBIS at Tier D/E. A subregion is declared an observation-adequacy limit only after that has been done, and always before PhyC is inspected.

### Outputs

- feasibility report with counts generated from the screened registry;
- provisional included-dataset manifest by analysis role;
- justified primary window candidates based on observation cadence;
- confirmatory and exploratory lifeform list;
- explicit scope reductions or data-access priorities.

### Gate

Proceed to detailed harmonization only for scientifically supportable roles. If the primary validation is infeasible, pause for data acquisition or transparently revise the paper protocol before any PhyC analysis.

## 8. Stage 5 — In-Situ Harmonization and Biomass Construction

### Objective

Create auditable reference variables without erasing provider data or manufacturing comparability.

### Actions

1. Parse dates and times to UTC while preserving the reported timestamp, time zone, and precision. Flag date-only records.
2. Validate coordinates, depths, stations, units, missing codes, and provider quality flags. Preserve originals beside harmonized fields.
3. Resolve taxonomy through the WoRMS service using scripted, cached API responses. Preserve reported names, accepted names, AphiaIDs, match type, and unresolved cases.
4. Apply the frozen lifeform crosswalk and retain autotrophy, mixotrophy, colony, and life-stage uncertainty.
5. Define internally comparable samples and method epochs. Do not combine net concentrates, whole-water microscopy, cytometry, imaging, and pigments as though they observed the same size domain.
6. Use provider carbon first, then provider biovolume, then defensible abundance-to-volume-to-carbon conversion. Register every equation, coefficient, geometric assumption, cell dimension, and literature source.
7. Propagate plausible conversion uncertainty and retain lower, central, and upper estimates rather than treating converted carbon as error-free.
8. Calculate sample completeness, converted taxon fraction, unresolved biomass risk, and observed size domain.
9. Preserve *Phaeocystis* colonies, colonial cells, solitary cells, and total cells as separate fields unless a validated conversion is available.
10. Carry the lower, central, and upper conversion estimates from action 7 forward as three parallel reference series, not as an annotation on a single series. They must remain separable through outcome construction in Stage 6 and reach the Stage 10 metrics intact. Because the Tier A base is too narrow to carry the primary analysis, the confirmatory result is expected to rest on Tier C conversion, and `DATASET_SYSTEMATIC_SEARCH.md` §9.7 warns that conversion uncertainty may then dominate apparent model error. Whether the incremental value of PhyC survives that uncertainty is a prespecified result of this study, not a caveat to be discovered late.

### Outputs

- canonical taxon-level observation table;
- sample-level method and completeness table;
- versioned taxonomy and lifeform crosswalk;
- carbon/biovolume conversion registry;
- sample-level total biomass estimates with uncertainty;
- harmonization issue log and unit tests.

### Gate

Only internally compatible and sufficiently complete samples may form total-biomass outcomes. Other records can retain narrower roles, such as within-lifeform abundance validation.

## 9. Stage 6 — In-Situ Summaries, Recurrence, Outcomes, and Events

### Objective

Summarize the independent observations and construct the reference outcome without using CMEMS values.

### 6.1 Observation and effort summary

Generate, by network, subregion, year, season, method, and reference tier:

- sample and station counts;
- adequately sampled years and windows;
- biomass, biovolume, abundance, completeness, and conversion-uncertainty distributions;
- seasonal trajectories with the actual sampling support shown;
- lifeform carbon or biovolume shares where defensible;
- missing, censored, below-detection, flagged, and unresolved records;
- agreement and systematic differences where networks or methods overlap.

Separate sampling-effort results from ecological results so that low observations are not confused with no bloom.

### 6.2 Recurrence and lifeform eligibility

1. Define an adequately sampled year for each network and target season using its cadence.
2. Calculate observation-only annual recurrence, event counts, biomass shares, and dominance confidence.
3. Apply the registered `annually_recurrent`, `frequently_recurrent`, `episodic`, and `indeterminate` rules.
4. Assign confirmatory lifeforms only from these results. Do not inspect their relationship with PhyC.

### 6.3 Fold-safe outcome and event construction

Bloom thresholds and seasonal baselines are estimated from training years only. Therefore:

1. define and freeze the grouped outer validation splits before estimating a threshold, using only identifiers, coverage, and independent observations;
2. within each outer split, estimate the subregion-season baseline and 90th-percentile threshold from its training observations;
3. apply that frozen threshold to the held-out observations;
4. label positive, negative, possible-bloom, and unknown windows using cadence, completeness, and persistence rules;
5. group supported adjacent windows into interval-censored events without using PhyC;
6. retain fold-specific threshold provenance so each held-out label identifies the training data that defined it.

A separate full-observation event catalogue may be generated for descriptive recurrence figures, but it must be clearly labelled descriptive and cannot provide leaked labels or thresholds to held-out performance estimation.

A fixed 90th-percentile rule defines bloom prevalence at roughly one window in ten **by construction**, so the rarity that motivates emphasising PR-AUC is a property of the threshold rather than an observation. Two checks are therefore required and registered here, before any threshold is applied:

1. repeat outcome construction across a prespecified percentile range and report how event counts, prevalence, and downstream metrics respond, using training folds only;
2. verify that the resulting events correspond to recognised North Sea bloom phenology by season and subregion. A threshold that produces events uniformly through the year is measuring variance, not blooms, whatever its percentile.

Also construct the outcome separately from the lower, central, and upper conversion series of Stage 5 action 10, so that a window whose bloom state depends on the conversion assumption is identifiable rather than silently resolved.

### Outputs

- in-situ descriptive tables and figures;
- adequately sampled year register;
- observation-only lifeform recurrence table;
- confirmatory-lifeform eligibility decision;
- fold-specific seasonal baselines, thresholds, labels, and event catalogue;
- descriptive full-data event catalogue, if used, clearly separated from validation data;
- uncertainty and unknown-state summaries.

### Gate

An outcome is usable only when its observation effort, reference tier, threshold provenance, cadence, and completeness are known. Unknown windows remain outside positive-versus-negative scoring.

## 10. Stage 7 — Freeze the Confirmatory Analysis Manifest

### Objective

Lock the evidence and evaluation structure before obtaining PhyC values.

### Actions

1. Freeze included datasets, provider versions, checksums, eligible records, method epochs, evidence tiers, analysis roles, subregions, years, windows, and exclusion reasons.
2. Verify that the Stage 6 outer splits were not altered after thresholds, labels, or event outcomes were generated. Incorporate their hashes into the final manifest and freeze the held-out network and region transfer sets. Ensure all rows from an event remain in one partition.
3. Freeze the small candidate set of PhyC representations allowed for training-only comparison: for example surface, registered upper layer, local cell/neighbourhood, and subregion summary.
4. Freeze required non-PhyC baselines, their physical and nutrient covariate sources, the CMEMS chlorophyll comparator, metrics, selection rules, false-alarm target, clustered uncertainty method, and decision thresholds.
5. Freeze the intended CMEMS product and dataset ID from official metadata, or prospectively freeze the selection criteria if the final version is not yet released. Product choice cannot be changed because another product agrees better with the observations.
6. Hash the manifest and configuration and create a timestamped protocol snapshot suitable for registration. Later additions become documented protocol amendments or separately labelled external replication data.

### Gate

No CMEMS PhyC extraction or visualization begins until the manifest is immutable for the confirmatory run.

## 11. Stage 8 — CMEMS Product Audit and Targeted Download

### Objective

Acquire the exact model product needed to cover the frozen eligible observations, with enough context for scientifically valid matchups.

### 8.1 Product audit

Using the official Copernicus Marine catalogue and documentation, record:

- product ID, dataset ID, product type, version, DOI/citation, and retrieval date;
- `PhyC` variable name, definition, units, valid range, missing value, and whether it is a stock, concentration, daily mean, or other temporal statistic;
- native grid, horizontal resolution, coordinate convention, vertical levels, bathymetry, land/coastal mask, and calendar;
- temporal coverage, time step, production/reanalysis releases, discontinuities, and update history;
- NEMO–ERSEM configuration and relevant phytoplankton functional representation;
- the ecological and dimensional equivalence between the modelled PhyC pool and the observed autotrophic carbon pool, including any model compartments or observed taxa that do not map cleanly;
- assimilated variables, ocean-colour assimilation periods, and other dependencies relevant to validation;
- whether versions or assimilation regimes require stratification or prohibit a single pooled interpretation.

Do not infer these properties from filenames. Archive the official metadata used for the decision.

### 8.2 Define the subset from the frozen manifest

Calculate the requested extent in R:

- minimum and maximum eligible observation dates plus the prespecified temporal buffer required for daily averaging, persistence, and anomaly features;
- union of eligible point-neighbourhood and hydrographic-subregion extents plus a prespecified spatial buffer;
- all vertical levels required to calculate the registered surface or upper-layer representations;
- only required variables, plus coordinate, depth, mask, and quality metadata needed to interpret them. Acquire any frozen physical, nutrient, and chlorophyll comparator fields with the same versioned provenance; do not add convenient covariates after performance is seen.

Use subsetting to limit volume, but never crop so tightly that neighbourhood, subregion, depth integration, edge checks, or temporal windows are incomplete.

### 8.3 Download and verify

1. Prefer a documented direct service callable from R. If Copernicus Marine requires its official Python-based toolbox, invoke that narrow client reproducibly from an R-controlled step and document the exception.
2. Chunk downloads deterministically when service limits require it. Record the complete request, returned filenames, checksums, sizes, and server metadata.
3. Verify that chunks have no unintended gaps or overlaps, coordinates are monotonic and unique as expected, time/depth units decode correctly, and values lie within documented ranges.
4. Preserve raw model files unchanged. Create processed model subsets only through R scripts.
5. Generate a coverage audit listing every eligible observation window and whether all required model cells, depths, and times are available.

### Outputs

- frozen CMEMS product specification and dependency/assimilation note;
- R-generated download manifest and requested bounds;
- immutable, checksummed CMEMS files;
- file-integrity and completeness report;
- observation-to-product coverage matrix.

### Gate

Proceed only if product identity, units, masks, depths, times, version boundaries, and coverage are verified. Missing model support creates an explicit unmatched reason; it must not silently remove difficult coastal observations.

## 12. Stage 9 — Spatiotemporal Matchup and Representation Audit

### Objective

Create comparable observation–model pairs while quantifying point-to-grid, time-window, depth, and coastal representativeness error.

### Actions

1. Match model time support to the actual observation support. For date-only or composite samples, do not assume an exact collection time.
2. Match depth explicitly: compare surface observations with a registered surface representation and integrated samples with an appropriately depth-weighted layer only when defensible.
3. Produce each prespecified candidate spatial representation:
   - nearest valid water cell with geodesic distance;
   - local water-only neighbourhood summaries;
   - hydrographic-subregion summaries using valid-cell areas where required.
4. Record coastline and land-mask effects, distance to shore and valid cell, local bathymetry, model depth, number and fraction of valid neighbourhood cells, and whether a search crossed a hydrographic barrier.
5. Never substitute a distant offshore cell for a masked coastal station without a registered maximum distance and a flagged sensitivity analysis.
6. Prevent pseudoreplication when several taxon rows or technical replicates belong to one sample. Aggregate only after the canonical sample identity is established.
7. Calculate scale-mismatch diagnostics: within-neighbourhood variance, station-to-subregion difference, temporal variability within the observation window, and sampling support.
8. Build a matchup uncertainty budget that separates observation error, carbon-conversion uncertainty, temporal mismatch, spatial representativeness, vertical mismatch, and model-grid/mask limitations where estimable.
9. Select one primary PhyC representation using training folds only; apply it unchanged to held-out events. Retain the other registered representations as sensitivity analyses.
10. Build the two registered pipeline controls alongside the real matchups, using the identical matchup machinery:
    - a **positive control** matching CMEMS chlorophyll to in-situ chlorophyll, which should agree well precisely because of the ocean-colour assimilation coupling;
    - a **negative control** in which PhyC dates are permuted within subregion, destroying the real temporal correspondence while preserving every distributional property.

    Every safeguard elsewhere in this plan suppresses false optimism, and none of them establishes that the pipeline can detect a signal at all. Without these controls a null result cannot be distinguished from a broken matchup, and a null is a publishable outcome of this study only if that distinction can be made. The controls are declared here and scored at Stage 10; their expected directions are registered before they are run.

### Outputs

- complete matchup table with observation, model, and provenance keys;
- unmatched-observation register with controlled reasons;
- spatial, temporal, depth, and mask diagnostics;
- training-only representation-selection record;
- matchup maps and scale-mismatch figures.

### Gate

Every matched value must be traceable to a source model file and exact grid/time/depth operation. Matchup exclusions cannot depend on whether agreement is favourable.

## 13. Stage 10 — Held-Out CMEMS PhyC Validation

### Objective

Test whether PhyC adds calibrated discrimination of independently observed total-biomass bloom state beyond simpler baselines.

### 10.1 Required comparisons

Fit in this order within training data:

1. seasonal prevalence or day-of-year climatology;
2. previous adequately observed bloom state;
3. seasonality plus physical and nutrient covariates;
4. CMEMS chlorophyll-only comparator;
5. the primary baseline plus total PhyC.

Keep dependency-sensitive model and satellite comparators separate from independent reference evidence.

### 10.2 Validation structure

- Use grouped outer validation by complete event or year.
- Use inner training partitions for representation choice, tuning, transformations, and false-alarm threshold selection.
- Hold out entire monitoring networks and hydrographic regions for external-transfer tests.
- Prevent the same event, station-time window, duplicate provider record, or threshold information from crossing training and test partitions.
- Generate out-of-fold predictions for every scored row and retain fold IDs and model provenance.

### 10.3 Primary metrics and uncertainty

Calculate:

- Brier score and incremental Brier improvement;
- calibration intercept and slope with calibration plots;
- PR-AUC, emphasized when blooms are uncommon;
- ROC-AUC as a complementary measure;
- sensitivity at a false-alarm rate selected in training data;
- lifeform-specific sensitivity and false-negative rate;
- event-, year-, network-, and region-level performance distributions;
- performance loss under network- and region-held-out transfer.

For reference tiers with commensurate units, also report supporting continuous-agreement diagnostics such as signed bias, median absolute error, RMSE on a justified scale, and rank association. Use clustered uncertainty and show observed-versus-modelled distributions. Correlation alone is not validation, and continuous metrics do not replace the registered bloom-classification outcome.

Estimate uncertainty by clustered bootstrap or an appropriate hierarchical approach at event/year/network level. Do not use daily rows as independent replicates. Report event counts and effective independent units beside each metric.

Report every headline metric three times, once against each of the lower, central, and upper conversion series carried from Stage 5 action 10. The incremental value of PhyC over the primary baseline is accepted only where it holds across all three. Where it does not, report the conversion-dependence explicitly: for a study whose reference is expected to rest on Tier C conversion, an increment that exists only under the central coefficients is a finding about the coefficients, not about the product.

Score the two Stage 9 controls in the same table as the real comparisons. The positive control (CMEMS chlorophyll against in-situ chlorophyll) should show clear agreement; the negative control (date-permuted PhyC) should show none. Read the primary result only after both behave as registered. If the positive control fails, the pipeline is under suspicion and no conclusion about PhyC may be drawn; if the negative control succeeds, leakage is present and the splits must be re-audited.

Report both window-level and event-balanced summaries where long events would otherwise dominate. Handle missing covariates through a prespecified, fold-safe method and report the effect of complete-case exclusions. Keep model complexity proportional to the number of independent events and account for the limited, prespecified set of comparisons.

### 10.4 Ecological interpretation

Evaluate whether errors concentrate by:

- lifeform dominance and mixed communities;
- bloom season and hydrographic regime;
- coastal versus offshore water;
- observation method, reference tier, and size-domain completeness;
- biomass magnitude and carbon-conversion uncertainty;
- sampling cadence and temporal mismatch;
- product version or assimilation era.

PhyC success for one lifeform means the generic biomass proxy was sensitive during blooms dominated by that group. It does not demonstrate taxonomic identification.

### Outputs

- versioned model specifications and out-of-fold predictions;
- baseline-versus-PhyC performance tables;
- calibration, discrimination, transfer, and lifeform-stratified figures;
- clustered uncertainty estimates;
- model diagnostics and complete error-case registry.

### Gate

No in-sample metric can support a paper decision. Confirmatory interpretation requires held-out calibration and discrimination, more than one independent network where prespecified, and transparent event-level uncertainty.

## 14. Stage 11 — Robustness, Failure Modes, and Final Decisions

### Objective

Determine whether the result is general, conditional, or a failure, and show why.

### Prespecified sensitivity analyses

- 85th and 95th percentile bloom thresholds around the primary 90th percentile;
- 0.40 lifeform-dominance threshold around the primary 0.50 definition;
- lower and upper carbon-conversion estimates;
- direct carbon, biovolume, converted counts, within-lifeform abundance, and imaging strata;
- alternative registered time windows and PhyC spatial/depth representations;
- exclusion of incomplete size domains or major method-transition periods;
- stricter coastal-cell distance and neighbourhood-validity limits;
- leave-one-network, leave-one-region, leave-one-year, and influential-event analyses;
- event-balanced versus window-weighted scoring and alternative prespecified missing-data handling;
- product-version and assimilation-era strata;
- negative-control or grouped permutation checks capable of exposing leakage or spurious seasonality skill.

### Failure-mode review

Audit and map:

- observed blooms missed by PhyC;
- high-PhyC adequately observed non-blooms;
- unmatched observations caused by coastal masks or missing times/depths;
- events supported by only one method or uncertain carbon conversion;
- disagreement among networks or between local and subregional representations.

Do not discard influential failures. Determine whether they imply a named ecological, geographic, seasonal, method, or product restriction.

### Decisions

Apply the registered rules for:

- `generic_pass`;
- `conditional_pass`;
- `fail`;
- `phaeocystis_handoff_pass`.

The generic and *Phaeocystis*/haptophyte decisions are reported separately. A generic or diatom-driven pass does not authorize a *Phaeocystis* handoff.

## 15. Stage 12 — Manuscript, Supplement, and Reproducibility Package

### Objective

Produce one high-quality paper whose claims and artifacts regenerate from the archived evidence.

### Actions

1. Render one manuscript and supplement from R-generated results.
2. Generate all owned figures listed in the README, including the systematic-search flow, coverage/method matrix, recurrence, matchups, held-out performance, transfer, and failure cases.
3. Insert calculated values programmatically where practical. Automatically compare any transcribed value with its generated source.
4. Report search dates and API versions, dataset versions and licenses, CMEMS product identity, protocol amendments, exclusions, unknown-state counts, and effective independent sample sizes.
5. Separate confirmatory, sensitivity, exploratory, and external-replication results.
6. Archive code, configuration, registries, checksums, session information, and data-access instructions. Do not publish restricted raw data.
7. Rerun the systematic search immediately before submission. Treat eligible late discoveries as external replication unless prospectively amended.
8. Run the pipeline from a clean R session and verify that all manuscript tables, figures, and reported metrics are rebuilt.

### Completion criteria

The study is complete only when:

- the search and screening flow is reproduced from raw API/export evidence;
- spatial, temporal, method, and biological coverage are explicit;
- in-situ outcomes and recurrence are observation-only and leakage-safe;
- the exact CMEMS version and every matchup are traceable;
- conclusions rely on held-out event/year and transfer evidence;
- uncertainty and failure modes are reported at the correct independence level; and
- one peer-review-ready paper renders without invented or manually adjusted results.

## 16. Recommended R Implementation Map

The exact filenames may evolve, but the responsibility and dependency order should remain clear.

| Suggested script | Responsibility | Principal generated artifact |
|---|---|---|
| `scripts/00_setup.R` | validate environment, paths, configuration, and logging | run metadata and environment check |
| `scripts/00_downloads/stage1/01_search_*.R` | execute one systematic API/export search per source | raw responses and query log |
| `scripts/00_downloads/02_download_insitu_*.R` | acquire provider datasets | raw files and acquisition manifest |
| `scripts/00_downloads/03_download_cmems.R` | execute and verify targeted CMEMS acquisition after the manifest freeze | checksummed raw model files |
| `scripts/01_build_candidate_registry.R` | normalize search results and calculate flow counts | candidate and search-flow registries |
| `scripts/02_screen_and_deduplicate.R` | screen records and map duplicate lineages | screened manifest and lineage table |
| `scripts/03_audit_coverage.R` | calculate time, space, cadence, depth, method, and overlap | coverage tables and figures |
| `scripts/04_harmonize_taxonomy.R` | resolve taxonomy and lifeforms from cached service responses | taxonomic crosswalk |
| `scripts/05_construct_biomass.R` | harmonize units and derive carbon/biovolume with uncertainty | canonical observation and biomass tables |
| `scripts/06_define_splits_and_outcomes.R` | create grouped splits, fold-safe thresholds, labels, and events | split, threshold, outcome, and event registries |
| `scripts/07_summarize_insitu.R` | generate effort, recurrence, and ecological summaries | in-situ tables and figures |
| `scripts/08_audit_cmems_product.R` | register official product metadata and calculate subset bounds | product and download manifests |
| `scripts/09_matchup_phyc.R` | construct point, neighbourhood, and subregion matchups | matchup and scale-diagnostic tables |
| `scripts/10_fit_validate_models.R` | fit baselines and PhyC models in grouped validation | out-of-fold predictions and metrics |
| `scripts/11_sensitivity_failures.R` | run robustness and error-case analyses | sensitivity and failure registries |
| `scripts/12_make_publication_outputs.R` | generate final tables and figures | manuscript-ready outputs |
| `scripts/99_render_manuscript.R` | render and verify the paper and supplement | final manuscript files and render log |

Reusable functions should live in focused R files and be covered by tests for identifiers, units, spatial assignment, pagination, deduplication, threshold leakage, event grouping, and matchup behavior. A pipeline tool such as `targets` may orchestrate dependencies, but scientific transformations must remain readable, commented, and callable from non-interactive R.

## 17. Critical Risks to Track Throughout

Maintain a live risk register for at least these issues:

1. **False independence:** the same national record appears through several aggregators.
2. **Size-selective observation:** small cells, fragile taxa, or colonies are missed by a method.
3. **Method discontinuity:** analytical or sampling changes mimic ecological change.
4. **Taxonomic ambiguity:** accepted names, trophic status, or life stages cannot be harmonized reliably.
5. **Carbon-conversion error:** uncertain cell dimensions or colony structure dominate apparent model error.
6. **Sampling-effort bias:** poorly sampled years or seasons are mistaken for non-bloom conditions.
7. **Temporal leakage:** held-out years influence climatologies, thresholds, persistence, or feature scaling.
8. **Spatial leakage:** nearby stations or the same event appear in both training and testing.
9. **Scale mismatch:** a point or integrated bottle sample is compared naively with a model grid-cell daily mean.
10. **Coastal-mask displacement:** model values come from a hydrographically inappropriate distant cell.
11. **Assimilation dependence:** apparent agreement reflects shared ocean-colour information rather than independent skill.
12. **Version drift:** API datasets or CMEMS products change between acquisition and publication.
13. **Selective reporting:** weak networks, null lifeforms, or influential failure events are omitted.
14. **Overclaiming taxonomy:** total PhyC performance is described as identification of a lifeform.

Each risk must have a detection check, mitigation, residual limitation, and manuscript reporting location.
