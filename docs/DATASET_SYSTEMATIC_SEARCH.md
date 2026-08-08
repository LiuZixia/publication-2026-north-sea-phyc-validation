# Systematic Dataset Search and Candidate Register

## 1. Purpose and Status

This document records a systematic search for observational datasets capable of validating CMEMS North-West Shelf total phytoplankton carbon as a proxy for recurrent North Sea phytoplankton blooms.

- **Search date:** 7 August 2026
- **Geographic scope:** Greater North Sea, including the Skagerrak and Kattegat transition where it informs North Sea inflow or transferability
- **Biological scope:** total phytoplankton biomass and recurrent dominant phytoplankton lifeforms
- **Target overlap:** the CMEMS reanalysis period, to be confirmed against the exact downloaded product version
**Status:** systematic discovery completed; record-level eligibility and raw-file acquisition remain to be executed and versioned

This is a living registry. New searches append dated entries; they do not overwrite the original search.

**Discovery yield:** 21 candidate dataset or service families were retained. Sixteen have a public or defined acquisition route, four require targeted provider contact or restricted access, and one is known from metadata but is not released. Aggregator and provider copies are not independent datasets, so a sample-level count will be reported only after deduplication.

**Update history:** this original run is preserved unchanged. Later runs append dated sections and do not modify §2–§11.

| Run | Date | Method | Result |
|---|---|---|---|
| initial | 2026-08-07 | narrative discovery across §3 sources | DS01–DS21, recorded in §6 |
| `MANUAL-20260807T195118Z` | 2026-08-07 | manual web discovery and provider-page inspection | DS22–DS34 and dated refinements, recorded in [§12](#12-search-update-2026-08-07--manual-discovery-run-manual-20260807t195118z) |

Neither run is a reproducibly executed search. All candidate counts remain provisional until Stage 1 archives query responses and generates the registry.

## 2. Search Question

> Which accessible or requestable North Sea datasets provide repeated, georeferenced observations of phytoplankton carbon, biovolume, abundance, composition, pigments, or bloom state at sufficient temporal and taxonomic resolution to validate concurrent CMEMS PhyC and quantify performance across recurrent dominant bloom lifeforms?

## 3. Sources Searched

### 3.1 Regional aggregators and harmonized services

1. [Plankton Lifeform Extraction Tool](https://www.dassh.ac.uk/lifeforms/)
2. [ICES DOME phytoplankton view](https://dome.ices.dk/views/phytoplankton.aspx)
3. [ICES DOME API](https://dome.ices.dk/api/swagger/index.html)
4. [EMODnet Biology](https://emodnet.ec.europa.eu/en/biology-databox)
5. [EMODnet ERDDAP Greater North Sea phytoplankton product](https://erddap.emodnet.eu/erddap/info/biology_6587_phyto_north_sea_4bd1_a08c_0019/index.html)
6. [EurOBIS/OBIS](https://obis.org/)

### 3.2 National and institutional sources

1. Netherlands: Rijkswaterstaat and Deltares records exposed through PLET, EMODnet, and VLIZ
2. Germany: BSH, AWI Helgoland Roads and Sylt Roads, LLUR, and NLWKN
3. Denmark: NOVANA/Aarhus University and ODA references
4. Sweden: [SMHI SHARK](https://www.smhi.se/data/hav-och-havsmiljo/datavardskap-oceanografi-och-marinbiologi) and [SHARK API](https://shark.smhi.se/api/docs/)
5. Belgium: [VLIZ LifeWatch plankton](https://lifewatch.be/plankton) and EurOBIS/OBIS
6. United Kingdom: Cefas, the Marine Biological Association/CPR Survey, DASSH, Environment Agency, and Scottish Coastal Observatory records
7. Norway: Institute of Marine Research, Norwegian Marine Data Centre references, and North Sea Ecosystem Survey reports

### 3.3 Query families

The search combined the geographic terms `North Sea`, `Greater North Sea`, `German Bight`, `Dutch Continental Shelf`, `Belgian Part of the North Sea`, `Skagerrak`, and `Kattegat` with:

- `phytoplankton abundance dataset`;
- `phytoplankton biomass`;
- `phytoplankton biovolume`;
- `phytoplankton carbon`;
- `species composition monitoring`;
- `long-term time series`;
- `bloom monitoring`;
- `diatom`, `dinoflagellate`, `Phaeocystis`, `coccolithophore`, `picoplankton`, and `nanophytoplankton`;
- `download`, `API`, `DOI`, `open data`, and `data request`.

Portal catalogues were then searched manually for provider, access status, measurement type, temporal coverage, and North Sea intersection.

## 4. Eligibility Criteria

### 4.1 Include for record-level screening

A dataset is retained when it has all of the following:

- marine observations intersecting the defined North Sea domain or a prespecified transition region;
- dates and coordinates or a fixed station with known coordinates;
- at least three years of repeated observations, unless it is a uniquely high-frequency sentinel series or a method-comparison dataset;
- at least one relevant variable: taxon abundance, lifeform abundance, biovolume, carbon biomass, size class, chlorophyll, pigments, or an independently defined bloom state;
- documented provider and a feasible public, API, DOI, or request-based access route;
- enough method metadata to identify sampling gear, preservation, analytical method, or size range.

### 4.2 Include in primary validation

Primary validation additionally requires:

- temporal overlap with the exact CMEMS product version;
- an independently measured or defensibly derived total-carbon or total-biovolume endpoint;
- adequate positive, negative, and unknown-state definition;
- sampling cadence compatible with the declared analysis window;
- no direct derivation from the CMEMS product being validated;
- analyzable licensing and redistribution terms.

### 4.3 Exclude from primary truth but retain as supporting evidence

- satellite chlorophyll used in ocean-colour assimilation;
- CMEMS chlorophyll or ERSEM functional-type fields;
- model-derived bloom products;
- interpolated occurrence-probability maps;
- presence-only records without defensible sampling-effort information;
- CPR PCI or taxon counts where size selectivity prevents total-community biomass interpretation;
- pigment-only observations without a validated conversion to total biomass.

### 4.4 Exclude entirely

- one-off cruises with no recurrence or transfer role;
- records lacking time or location;
- datasets outside the domain with no transition relevance;
- inaccessible datasets with no identifiable request route;
- zooplankton-only datasets.

## 5. Evidence Tiers

| Tier | Reference information | Permitted role |
|---|---|---|
| A | independently estimated total phytoplankton carbon | primary reference |
| B | total biovolume with documented method | primary reference; conversion sensitivity |
| C | taxon counts plus size/shape information supporting carbon conversion | primary if conversion audit passes |
| D | within-lifeform abundance without comparable cross-lifeform biomass | lifeform-specific detection only |
| E | chlorophyll, pigments, CPR PCI, or coarse relative abundance | comparator and triangulation |
| F | derived presence/absence or interpolated occurrence | discovery, spatial coverage, and sensitivity only |

## 6. Candidate Dataset Register

### 6.1 High-priority core candidates

| ID | Dataset or service | Coverage and access | Relevant observations | Principal value | Principal limitation | Planned role |
|---|---|---|---|---|---|---|
| DS01 | [PLET harmonized datasets](https://www.dassh.ac.uk/lifeforms/) | European monitoring datasets; query by date and polygon; public and restricted holdings explicitly labelled | harmonized lifeform abundance plus raw extracts; some biomass datasets | common lifeform crosswalk, DOI-versioned inputs, rapid multi-network screening | monthly aggregation can hide short events; underlying methods remain heterogeneous | discovery backbone and harmonized sensitivity analysis |
| DS02 | RWS `RWS_Fpzout_2000-2019_phyto` | Dutch North Sea; public through PLET; DOI `10.17031/66f557fe4103f` | taxon-resolved phytoplankton monitoring | long multi-station southern North Sea coverage; strong *Phaeocystis*, diatom, and dinoflagellate relevance | cadence and methods may vary; carbon conversion must be audited | primary core if biomass conversion passes |
| DS03 | Dutch long-term monitoring, 1990–1999 and 2000–2018 versions | Dutch Exclusive Economic Zone; CC0 metadata and WFS/EurOBIS routes | genus/species/other-taxon abundance; reported sampling of roughly 12–24 times per year in the earlier record | extends interannual recurrence and coastal-to-offshore gradients | dataset-version overlap and duplicate records require reconciliation | primary/core historical extension |
| DS04 | BSH `BSH_Phyto_Zoo` and abundance extract | German North Sea; public through PLET; DOI `10.17031/66f41f3f2a72e` | phytoplankton abundance and community data | independent German sector and method contrast | biomass fields and station cadence must be confirmed | primary if Tier B/C; otherwise lifeform validation |
| DS05 | NOVANA phytoplankton | Danish monitoring; public through PLET; DOI `10.17031/66f42801afddd` | phytoplankton composition and abundance | Danish and Wadden Sea coverage; important hydrographic transition | exact North Sea subset and biomass variables require record-level audit | primary or lifeform validation |
| DS06 | SMHI Kattegat and Skagerrak phytoplankton | public through PLET and SHARK; CC0 API; PLET DOI `10.17031/1633` | abundance, biovolume, chlorophyll, phyto/picoplankton | explicit biovolume; long national monitoring; valuable transfer region | transition waters are not interchangeable with central North Sea | Tier B external-transfer dataset |
| DS07 | [Cefas SmartBuoy phytoplankton 2001–2017](https://doi.org/10.14466/CefasDataHub.58) | Dowsing, Gabbard/West Gabbard, Warp and other UK waters; public under OGL | full-community Utermöhl counts, cells L⁻¹, taxon size class | repeated automated sampling at nominal 1 m; size classes support conversion | site deployments and gaps vary; some listed stations lie outside the North Sea | Tier C core for eligible North Sea stations |
| DS08 | [Helgoland Roads](https://www.awi.de/en/fleet-stations/stations/marine-stations-helgoland-and-sylt/long-term-observation.html) | German Bight fixed station; work-daily phytoplankton series since 1962; raw products/dashboard and PANGAEA series | species counts, total abundance, annual carbon/biomass products, nutrients and hydrography | highest-frequency sentinel for recurrent spring-bloom occurrence and event shape | single location; PANGAEA series are fragmented and some licensing/access is unclear | Tier A/B sentinel and temporal-resolution benchmark |
| DS09 | Sylt Roads | Wadden Sea transition; approximately twice weekly since 1974; AWI dashboard | phytoplankton, chlorophyll, nutrients, hydrography | long coastal time series and method complement to Helgoland | highly local/tidal environment; raw access and harmonization require confirmation | external coastal sentinel |
| DS10 | [VLIZ LifeWatch phytoplankton FlowCam](https://obis.org/dataset/956d618f-91dc-4930-a253-cdf80ddb9371) | Belgian North Sea since May 2017; nine monthly coastal and eight seasonal offshore stations; CC BY 4.0 | 55–300 µm imaged particles, mainly diatoms and dinoflagellates, manually validated classifications | open, image-linked, spatial coastal/offshore design | 55 µm net and imaged range exclude much of the small community; cannot represent total biomass alone | large-cell lifeform validation and method sensitivity |
| DS11 | Cefas, RWS, VLIZ, BSH, NOVANA, and SMHI chlorophyll companions in PLET | public for several networks | in-situ chlorophyll | method-matched comparator and observation-network context | chlorophyll is not carbon and may be coupled to assimilated ocean colour | secondary comparator only |

### 6.2 Basin-scale and aggregation candidates

| ID | Dataset or service | Coverage and access | Relevant observations | Principal value | Principal limitation | Planned role |
|---|---|---|---|---|---|---|
| DS12 | [Continuous Plankton Recorder Survey](https://www.cprsurvey.org/data/our-data/) | basin-scale North Sea routes since 1931; PLET lists public extracts; customized raw requests involve CPR collaboration | taxon counts and Phytoplankton Colour Index; stable long-term protocol | strongest basin-scale recurrence and spatial-transfer evidence | approximately 270 µm silk and semi-quantitative retention for many phytoplankton taxa; route/sampling bias; custom-access obligations | Tier D/E coarse lifeform and annual-recurrence corroboration |
| DS13 | [ICES DOME phytoplankton](https://dome.ices.dk/views/phytoplankton.aspx) | OSPAR/HELCOM/ICES monitoring submissions; downloadable and API-accessible; DOME data under CC BY 4.0 | biological community parameters and programme metadata | cross-national completion, provenance, and country/programme filtering | aggregation may duplicate national source datasets; method harmonization remains necessary | discovery, deduplication, and gap filling |
| DS14 | [EMODnet Biology and EurOBIS](https://emodnet.ec.europa.eu/en/biology-databox) | Greater North Sea occurrence, abundance, and biomass holdings | standardized occurrence and measurement records | broad discovery, persistent dataset identifiers, WoRMS-linked taxonomy | presence-only and heterogeneous effort can create false negatives | dataset discovery and raw-record completion |
| DS15 | [EMODnet Greater North Sea presence/absence product](https://erddap.emodnet.eu/erddap/info/biology_6587_phyto_north_sea_4bd1_a08c_0019/index.html) | gridded product for 100 common plankton species; CC BY | inferred occurrence/absence and probability | identifies candidate taxa and spatial data gaps | absences were complemented under fixed-list assumptions and maps are interpolated; not independent event truth | coverage map and exploratory sensitivity only |
| DS16 | Scottish Coastal Observatory/PLET stations, especially Stonehaven | public PLET records; phytoplankton monitoring at Stonehaven since 1997 | diatom and dinoflagellate counts, chlorophyll at some sites | northern North Sea margin and independent fixed-station transfer | station-specific and partly coastal; exact raw access/version requires confirmation | external-transfer validation |

### 6.3 Restricted, incomplete, or contact-priority candidates

| ID | Dataset or service | Status | Reason to retain | Required action |
|---|---|---|---|---|
| DS17 | LLUR Schleswig-Holstein `OSPAR_LLUR-SH_2010-2020` | restricted in PLET | fills German coastal sector and *Phaeocystis* monitoring gap | request data, method metadata, and terms |
| DS18 | NLWKN `OSPAR_NLWKN_1999-19_phyto` and abundance version | restricted in PLET; DOI metadata available | long Lower Saxony coastal record and OSPAR relevance | request data and determine overlap with DOME/EMODnet |
| DS19 | Norwegian IMR North Sea Ecosystem Survey phytoplankton | annual spring survey since 2010 with cell-count and species-composition sampling documented; a 2025 IMR monitoring plan states that no phytoplankton database had yet been developed | important northern offshore coverage and annual spring mapping | contact IMR/NMDC for analyzable phytoplankton files and licensing; do not treat reports as row-level data |
| DS20 | Norwegian coastal and Torungen–Hirtshals series | monitoring descriptions indicate algae/plankton observations and repeated sampling | potentially fills Skagerrak and Norwegian inflow gaps | contact IMR data support and verify digitized taxon/biovolume access |
| DS21 | Cefas 2016–2017 Ferrybox flow-cytometry functional groups | metadata found but publisher indicates data not released | directly relevant to small functional groups and six cytometric classes | contact publisher; exclude until released with methods and coordinates |

## 7. Preliminary Dataset Decisions

### Include in the acquisition queue

- DS01–DS16, with DS11 and DS15 restricted to their secondary roles;
- DS17–DS20 as targeted access requests;
- DS21 only if the publisher releases a complete version.

### Do not use as primary independent truth

- DS11 chlorophyll companions;
- DS12 CPR PCI and total-community interpretations;
- DS15 derived presence/absence maps;
- any satellite-derived bloom product or CMEMS functional-type field.

### Deduplication rule

The same national monitoring record may appear in PLET, ICES DOME, EMODnet Biology, EurOBIS, and a provider portal. The provider's highest-resolution version is the canonical raw record. Aggregator copies are used for identifiers, harmonized traits, and gap checking, not counted as independent datasets.

## 8. Candidate Recurrent Lifeforms

The search supports five candidate lifeform regimes, but only the first three are expected to have enough cross-network microscopy coverage for confirmatory analysis.

| Candidate | Ecological and data rationale | Initial status |
|---|---|---|
| Diatoms | major coastal/shelf group; recurrent spring blooms; broadly enumerated by Utermöhl microscopy and monitoring programmes | confirmatory candidate |
| *Phaeocystis*/haptophytes | recurrent southern coastal nuisance blooms and the downstream Module 02 target | confirmatory candidate, subject to colony/life-stage harmonization |
| Dinoflagellates | major North Sea lifeform with summer/autumn recurrence and broad monitoring coverage | confirmatory candidate |
| Coccolithophores | potentially important in northern/stratified waters but species and biomass resolution may be uneven | conditional candidate |
| Pico/nanophytoplankton | can dominate biomass or production but is poorly represented by traditional microscopy and net/imaging methods | conditional candidate requiring cytometry, pigment, or size-resolved data |

The final set is frozen from observation-only recurrence and biomass coverage using [OUTCOME_AND_LIFEFORM_PROTOCOL.md](OUTCOME_AND_LIFEFORM_PROTOCOL.md).

## 9. Search Gaps and Bias Risks

1. Public Norwegian taxon-resolved phytoplankton records are less discoverable than survey reports and hydrochemical data.
2. Small cells are systematically underrepresented by CPR, net sampling, and the LifeWatch 55–300 µm FlowCam workflow.
3. Colony and solitary-cell reporting for *Phaeocystis* is not standardized across programmes.
4. National datasets may change taxonomic names, analysts, counting protocols, and detection limits over time.
5. Many networks are monthly or seasonal and cannot validate daily event boundaries.
6. Aggregators can create the appearance of multiple independent datasets from one national source.
7. Carbon conversion uncertainty may dominate apparent model error for abundance-only records.

## 10. Required Acquisition Outputs

For every acquired dataset, create one registry row with:

- `dataset_id` and canonical provider;
- title, DOI/URL, version, license, and access date;
- raw-file checksum;
- spatial and temporal coverage;
- station count and sampling cadence distribution;
- depth and sampling gear;
- preservation and analytical method;
- minimum and maximum observed particle/cell size where known;
- taxonomic resolution and identifier system;
- abundance, biovolume, carbon, chlorophyll, pigment, and size fields;
- reported quality flags and missing-value codes;
- overlap with other holdings;
- CMEMS overlap years;
- eligible reference tier;
- inclusion, exclusion, or pending decision with reason.

## 11. Search Update Rule

Rerun the structured search immediately before protocol registration and again before manuscript submission. Record new datasets, changed access status, updated versions, and broken endpoints. Dataset additions after model evaluation require a separately labelled external replication analysis; they cannot be silently added to improve the primary result.

## 12. Search Update 2026-08-07 — Manual Discovery Run `MANUAL-20260807T195118Z`

### 12.1 Status and evidentiary standing

This run was performed by interactive web search and direct inspection of provider, repository, and publication pages before Stage 1 execution. It is **not** an executed API search and does not advance the Stage 1 gate.

- **Run identifier:** `MANUAL-20260807T195118Z`
- **Date (UTC):** 2026-08-07
- **Method:** interactive search-engine discovery followed by retrieval of provider, repository, and journal pages
- **Purpose:** broaden the candidate pool and stress-test the assumptions in §6 before query strategies are frozen
- **Machine-readable log:** [`metadata/manual_discovery_log.csv`](../metadata/manual_discovery_log.csv)

Section 6 is not modified by this run. Refinements to existing rows appear in §12.3 as dated addenda so the original register remains auditable.

Every entry carries a `verification_status`:

| Value | Meaning |
|---|---|
| `page_inspected` | the cited provider, repository, or publication page was retrieved and read during this run |
| `search_summary_only` | the entry rests on search-engine result text; the primary page was not retrieved |
| `not_verified` | retrieval was attempted and returned no usable content |

Coverage, cadence, variable, and licence statements below are **as reported by the cited source on the access date**. They remain provisional evidence under §12 of `AGENTS.md` until an archived query response and checksum support them. No count, cadence, or record total in this section may be carried into the manuscript without regeneration from an executed search.

### 12.2 New candidate entries

| ID | Dataset, service, or reference | Coverage and access | Relevant content | Principal value | Principal limitation | Planned role | Verification |
|---|---|---|---|---|---|---|---|
| DS22 | HELCOM EG Phyto biovolume file (`PEG_BVOL`), ICES-hosted, mirrored by [Nordic Microalgae](https://nordicmicroalgae.org/biovolume-lists/) | republished annually as a new version; [ICES library record](https://ices-library.figshare.com/articles/report/HELCOM_Expert_Group_on_Phytoplankton_Biovolume_File/27900237) | taxon geometric shapes, size classes, biovolume and carbon-content coefficients | the conversion authority on which every Tier C carbon estimate depends; used by SMHI and Nordic monitoring | Baltic-centred origin; coverage of North Sea taxa must be audited; annual versioning means an unpinned copy is a moving target | **conversion reference, not observations**; must be version-frozen and checksummed before any Tier C conversion | `search_summary_only` |
| DS23 | [NIOZ Wadden Sea phytoplankton](https://www.gbif.org/dataset/1d276c75-d90c-40c8-973d-2eac7c8089e5), GBIF `10.15468/okwkou` | NIOZ-Texel jetty at the Marsdiep tidal inlet; reported as running since 1974 at roughly 40 samples per year | phytoplankton species densities with associated Secchi, SPM, nutrients, chlorophyll, primary production | long independent Dutch coastal record absent from the original register; method contrast to RWS ship-based sampling | tidal-inlet jetty station; strongly local hydrography; not representative of a shelf subregion | external coastal sentinel; duplicate check against DS02/DS03 | `search_summary_only` |
| DS24 | [OSPAR COMP4 COMPEAT input data files](https://ices-library.figshare.com/articles/dataset/Input_data_files_for_the_OSPAR_COMP_4_eutrophication_assessment_using_COMPEAT/22189111) and [COMPEAT code](https://github.com/ices-tools-prod/COMPEAT) | Greater North Sea, Celtic Seas, Bay of Biscay; assessment period 2015–2020; extracted from the ICES Data Portal | harmonized in-situ chlorophyll and nutrients aggregated to OSPAR COMP4 assessment areas | frozen, versioned, externally curated dataset with published assessment-area geometry and open R code | chlorophyll is Tier E and COMP4 also ingests remote sensing; assessment areas are not the frozen subregions | Tier E comparator, non-PhyC baseline candidate, and **known-item recall benchmark for Stage 1** | `search_summary_only` |
| DS25 | [EMODnet Chemistry](https://emodnet.ec.europa.eu/en/chemistry) aggregated eutrophication product | Greater North Sea; SeaDataNet ODV and NetCDF; OGC WMS/WFS/CSW | validated and harmonized in-situ chlorophyll-a and nutrients | machine-readable route to a climatological chlorophyll baseline over the whole domain | chlorophyll only; feeds Copernicus, so independence from the assimilation chain must be established per source before use | Tier E comparator and non-PhyC baseline candidate | `search_summary_only` |
| DS26 | [SMHI IFCB imaging](https://figshare.scilifelab.se/articles/dataset/Manually_annotated_IFCB_plankton_images_from_the_Skagerrak_Kattegat_and_Baltic_Proper_by_SMHI/25883455) with the `iRfcb` R client | Skagerrak, Kattegat, Baltic Proper; manually annotated image reference library; data flow into SHARK | imaged plankton with classifications supporting biovolume | highest temporal resolution available in the external-transfer region | transition waters; imaged size range and classifier performance must be audited; not the core domain | Tier B external-transfer and temporal-resolution benchmark | `search_summary_only` |
| DS27 | [COSYNA/Hereon FerryBox](https://www.hereon.de/institutes/carbon_cycles/cosyna/observations/ferrybox/index.php.en); [2002–2005 ESSD release](https://essd.copernicus.org/articles/10/1729/2018/) `10.1594/PANGAEA.883824`; [pCO2 series since 2013](https://doi.pangaea.de/10.1594/PANGAEA.930383) | ships of opportunity on Cuxhaven–Immingham, Büsum–Helgoland, and Halden–Zeebrugge–Immingham–Moss; open data policy; ASCII and NetCDF export | chlorophyll-a fluorescence, phytoplankton group fluorescence, turbidity, oxygen, salinity, temperature, partly nutrients | the only sub-daily spatially resolved surface record in the southern North Sea | fluorescence is not carbon and is subject to photoacclimation and non-photochemical quenching; surface-only; route-constrained | Tier E; quantify the timing blur introduced by monthly networks | `search_summary_only` |
| DS28 | LifeWatch Belgium HPLC pigment series | Belgian Part of the North Sea; reported as monthly since 2002 under the LifeWatch programme | HPLC pigments supporting CHEMTAX group decomposition | the only identified route to a haptophyte and *Phaeocystis* pigment share in Belgian waters | CHEMTAX ratios are regionally tuned and non-unique; Tier E under §5; no direct total-biomass conversion | Tier E lifeform comparator and triangulation for DS10 | `search_summary_only` |
| DS29 | [Inner Oslofjord phytoplankton 1896–2020](https://www.nature.com/articles/s41597-022-01869-3), GBIF `10.15468/gugesq`, CC-BY 4.0 | inner Oslofjord, principally station Dk1/S1 in Vestfjorden; approximately monthly 2006–2020; 605 sampling events and 22,636 records reported | cell abundance, biomass in µg C/L for 1994–2020 with gaps, 412 accepted taxa, associated hydrography and nutrients | rare published carbon-unit record with an open licence | **inner fjord, outside the frozen domain and outside the Skagerrak/Kattegat external-transfer definition**; pre-1920 records not comparable | not eligible under §4.4; retain only as a documented out-of-domain assessment | `page_inspected` |
| DS30 | [GBIF](https://www.gbif.org/) as an aggregator family | global biodiversity aggregator publishing marine monitoring datasets | occurrence and sampling-event records including DS23 and Norwegian holdings | closes a genuine gap: DS23 and the NIVA holdings are published to GBIF and not to EurOBIS | presence-heavy records and heterogeneous effort; aggregator copies are not independent sources | discovery and **deduplication family, to be added to the §7 rule** | `search_summary_only` |

### 12.3 Dated refinements to existing register rows

These addenda refine §6 without replacing it. Each states what changed and why it matters.

**DS06 SMHI — tier raised from B to A/B candidate.** SHARK is reported to store phytoplankton carbon (µg C/L) derived from biovolume through the HELCOM PEG/NOMP lists, not biovolume alone. Programmatic access is supported by the `SHARK4R` and `iRfcb` R clients in addition to the documented API. Consequence: DS06 is the most tractable high-tier acquisition target and should be the reference implementation for the Stage 1 module pattern. It remains an external-transfer region under the frozen Stage 0 assignment. `search_summary_only`

**DS08 Helgoland Roads — structure confirmed, access status downgraded.** The PANGAEA publication series [`10.1594/PANGAEA.960407`](https://doi.pangaea.de/10.1594/PANGAEA.960407) reports 145 child datasets covering 1962–2023 and carries total abundance, total biovolume, **and** biomass as carbon, with carbon resolved by group (diatoms split into centrales and pennales, dinoflagellates, silicoflagellates, coccolithophorids, flagellates, green algae, ciliates). `page_inspected`

This is the only source identified in either run that can express **lifeform dominance as a carbon share**, which `docs/CONTEXT.md` requires and which cell counts cannot supply. DS08 is therefore load-bearing for the lifeform stratification, not merely a temporal-resolution sentinel.

Access is not clean. The series states CC-BY-4.0 that "comes into effect after moratorium ends" and requires login to download; an inspected annual carbon dataset ([`10.1594/PANGAEA.862910`](https://doi.pangaea.de/10.1594/PANGAEA.862910), 2015) renders as "Licensing unknown: Please contact principal investigator/authors to gain access and request licensing terms". `page_inspected` The years under moratorium may be exactly the CMEMS-overlap years. DS08 is reclassified from public acquisition to **request-and-verify**, and the licence enquiry must be logged through the manual/contact channel of Stage 1 action 9, never as an API result.

**DS09 Sylt Roads — two distinct series; the continuing one is lower tier.** The quantitative microplankton series is reported for [1992–2013](https://doi.pangaea.de/10.1594/PANGAEA.150033). What continues to the present is a *semi-quantitative* net-based microplankton analysis published in annual datasets ([2018](https://doi.pangaea.de/10.1594/PANGAEA.937744), [2019](https://doi.pangaea.de/10.1594/PANGAEA.937747)). Net selectivity plus semi-quantitative enumeration places the modern years at Tier D/E, not the Tier B a coastal-sentinel role implies, and the quantitative window may end before much of the reanalysis period. `search_summary_only`

**DS10 LifeWatch FlowCam — coverage extended and characterised.** Reported as May 2017 to August 2024; 9 nearshore stations monthly and 8 offshore stations seasonally; 138 biological groups including 76 diatom and 17 dinoflagellate groups; 55–300 µm ESD; EurOBIS `10.14284/760`, Marine Data Archive `10.14284/710`, annotated image library `10.14284/680`; CC-BY 4.0. The 55 µm lower bound is confirmed and remains the binding constraint on total-biomass interpretation. `page_inspected`

**DS16 Scottish Coastal Observatory Stonehaven — upgraded and identified.** [DOI `10.7489/610-1`](https://data.marine.gov.scot/dataset/scottish-coastal-observatory-stonehaven-site), UK Open Government Licence, 1997–2017, weekly. Ten CSV resources including phytoplankton counts (first 400 cells), counts by fields of view, presence/absence, target-species analysis, and **flow cytometry**, plus environmental, Secchi, temperature, and zooplankton data. `page_inspected`

The flow-cytometry resource addresses the pico/nano gap that §8 currently makes conditional on DS21, which is unreleased. Caution: a first-400-cells protocol yields relative composition rather than absolute density; the fields-of-view resource is required for abundance.

**DS07 Cefas SmartBuoy — method confirmed, duplicate family extended.** Approximately weekly automated 150 mL samples preserved in acidified Lugol's iodine and enumerated by the Utermöhl technique to the lowest practical taxon in cells L⁻¹. The same holding is also published through [DASSH](https://doi.dassh.ac.uk/data/1634), which must be linked as an aggregator copy under §7 rather than counted separately. `search_summary_only`

### 12.4 Assessed and not retained

| ID | Source | Decision | Reason |
|---|---|---|---|
| DS31 | Copernicus Marine In Situ TAC product `INSITU_NWS_PHYBGCWAV_DISCRETE_MYNRT_013_036` | excluded from primary truth; retained as a documented decision | North-West Shelf scoped and superficially ideal, but it is a Copernicus in-situ product drawing on the same chlorophyll streams that inform the ocean-colour chain. Using it as independent reference would breach the assimilation boundary in `docs/CONTEXT.md`. Recorded explicitly so a reviewer sees it was considered and rejected. |
| DS32 | [HAEDAT](https://haedat.iode.org/) harmful algal event database | excluded as event truth | *Phaeocystis* is systematically under-reported because events rarely carry demonstrable economic impact; the published northern-Europe review identifies only two North Sea *Phaeocystis* entries (Wilhelmshaven 2010; Dutch mussel mortality 2001). Absence of an entry does not evidence absence of a bloom, so HAEDAT cannot define negative windows. |
| DS33 | [PhytoBase](https://essd.copernicus.org/articles/12/907/2020/) and MAREDAT | excluded from acquisition | Global syntheses assembled from OBIS, GBIF, CPR, and monitoring programmes already in the register. Inclusion would inflate the dataset count with duplicates of held sources. Retained only as a taxonomy crosswalk and recall aid. |
| DS34 | BODC / NERC Shelf Sea Biogeochemistry cruise and glider holdings | excluded from primary | Campaign-based rather than recurrent; fails the three-year repeated-observation criterion in §4.1. Retain only as a potential method-comparison dataset. |

### 12.5 Consequences for the tier hierarchy and study feasibility

Two structural findings follow from this run and are recorded as risks, not as design changes.

1. **The Tier A base is narrow and sits at the domain margins.** Only DS08 (German Bight coastal fixed station) and DS06 (Skagerrak/Kattegat external-transfer region) were found to report phytoplankton carbon directly, and DS08 has an unresolved moratorium. DS29 was the only other carbon-unit record found and is out of domain.
2. **The offshore central and northern North Sea has no identified Tier A–C candidate.** Every high-tier source found is at a coastal margin (DS02–DS05, DS07–DS10, DS16, DS23) or in the transition region (DS06, DS26). Offshore coverage rests on DS12 (CPR, Tier D/E) and DS19–DS20, which are contact-only and reported to lack an analyzable phytoplankton database.

Because the primary row unit is `subregion_id × analysis_window`, some frozen subregions may have no eligible reference data at all. This is a Stage 4 feasibility determination. It must be declared from observation coverage before PhyC is inspected, so that an empty subregion is recorded as an adequacy limit and never appears as a post-hoc exclusion.

### 12.6 Consequences for Stage 1 execution

1. **Additional source families need acquisition modules** beyond PLET, ICES DOME, EMODnet/EurOBIS/OBIS, and SMHI SHARK: PANGAEA (to enumerate the 145 DS08 children), GBIF (DS23 and Norwegian holdings), the `data.marine.gov.scot` CKAN API (DS16), Cefas Data Hub and DASSH (DS07), and ICES figshare (DS22, DS24).
2. **The §7 deduplication rule gains GBIF** as an aggregator family. DASSH is likewise an aggregator copy for DS07.
3. **A known-item recall benchmark set is proposed** for Stage 1 action 8: DS02, DS04, DS05, DS06, DS07, DS08, DS10, and DS16, with the DS24 input-file list as an externally curated cross-check. A benchmark that fails to appear triggers query or API diagnosis, never a manual registry insertion.
4. **DS22 must be version-frozen before any Tier C conversion.** `PEG_BVOL` is republished annually; without a pinned, checksummed version the conversion is irreproducible and the §9.7 risk that conversion uncertainty dominates apparent model error cannot be quantified.
5. **Provider holdings are actively changing.** The DTO-BioFlow open calls ran to 2026-04-30 with the explicit aim of mobilising previously unavailable plankton datasets into EMODnet and EDITO. Record per-endpoint retrieval timestamps, and expect the §11 pre-submission re-run to return genuine additions that must be labelled external replication rather than folded into the primary result.

### 12.7 Proposed additions to the exclusion rules

To be applied when §4 is next revised, with the rationale recorded in `config/protocol_change_register.csv`:

- **§4.3, exclude from primary truth:** Copernicus in-situ products whose chlorophyll streams inform the ocean-colour chain; global syntheses assembled from aggregators already held.
- **§4.4, exclude entirely:** harmful-algal event registries as bloom-state truth where reporting is impact-triggered rather than observation-triggered; single-campaign cruise and glider programmes without recurrence.

### 12.8 Sources consulted in this run

Pages retrieved and read (`page_inspected`): [PANGAEA Helgoland series 960407](https://doi.pangaea.de/10.1594/PANGAEA.960407); [PANGAEA 862910](https://doi.pangaea.de/10.1594/PANGAEA.862910); [Stonehaven dataset record](https://data.marine.gov.scot/dataset/scottish-coastal-observatory-stonehaven-site); [Inner Oslofjord data descriptor](https://pmc.ncbi.nlm.nih.gov/articles/PMC9751269/); [BPNS FlowCam data descriptor](https://pmc.ncbi.nlm.nih.gov/articles/PMC12727804/).

Retrieval attempted without usable content (`not_verified`): the SMHI SHARK Swagger endpoint returned only a page shell; the API surface remains unverified and must be established during Stage 1.

All remaining URLs cited in §12.2–§12.4 are `search_summary_only` and are listed with their status in [`metadata/manual_discovery_log.csv`](../metadata/manual_discovery_log.csv).

## 13. Executed Stage 1 Search — 2026-08-08

Stage 1 has now been reproducibly executed against the frozen configuration in [`config/stage1_search_config.json`](../config/stage1_search_config.json). The executable modules cover PLET, ICES DOME, EMODnet ERDDAP, OBIS, SMHI SHARK, PANGAEA, GBIF, Marine Scotland DKAN, Cefas Data Hub/DASSH, and ICES Figshare. The successful immutable runs are pinned in [`metadata/stage1_active_runs.csv`](../metadata/stage1_active_runs.csv); abandoned preflight and diagnosed provider-behaviour runs remain immutable but are not used by the compiler.

The following generated artifacts, rather than the narrative discovery totals in §§1 and 12, are the current Stage 1 evidence:

- [`metadata/stage1_query_log.csv`](../metadata/stage1_query_log.csv): exact requests, pages or cursors, timestamps, response paths, HTTP states, record counts, and SHA-256 checksums;
- [`metadata/candidate_registry.csv`](../metadata/candidate_registry.csv): dataset-level discovery metadata linked to raw evidence, conservative screening states, and duplicate/canonical links;
- [`metadata/stage1_known_item_recall.csv`](../metadata/stage1_known_item_recall.csv): evidence-backed recall of every prespecified benchmark;
- [`metadata/stage1_search_flow.csv`](../metadata/stage1_search_flow.csv): calculated identification, duplicate, screening, exclusion, pending, and acquisition totals; and
- `outputs/logs/stage1_validation_20260808T083225Z.log`: deterministic-regeneration checksum, complete test result, R version, package versions, and session information.

The DS22 Figshare page was not treated as the conversion table itself. The official ICES-hosted `PEG_BVOL` ZIP was downloaded by the Figshare/ICES module, archive-validated, checksummed, and registered as the one Stage 1 item advanced to acquisition. Dataset-level `pending` does not mean eligible for analysis: access, licences, recurrence, methods, record schemas, geographic intersection, and duplicate observations remain Stage 2 decisions. The unavailable second scientific review is explicitly recorded as pending in the frozen configuration and is not represented as approval.

### 13.1 Requirement audit and remediation — 2026-08-08

An independent audit against `STAGED_WORK_PLAN.md` §4 found that the executed search reproduced deterministically while several of its scientific requirements were unmet. The automated suite passed throughout, so "the tests pass" was not evidence that the requirements were satisfied. All defects below are repaired; the artefacts listed in §13 were regenerated.

| Defect | Consequence | Repair |
|---|---|---|
| The biological screen matched only `phytoplank` | DS02 (RWS) and DS04 (BSH) were excluded as outside biological scope while recall still reported them found | Screening terms moved to `config/screening_rules.json` and broadened; recall now reports and asserts retention, not only presence |
| The PLET parser required a DOI cell | Seven archived catalogue datasets marked "No DOI" produced no registry row, including DS17 `OSPAR_LLUR-SH_2010-2020`; discovery was biased against restricted holdings, which are the least likely to carry a DOI and the most important for gap filling | DOI requirement removed; a test asserts every archived PLET data row reaches the registry |
| PLET dataset names are provider codes | DS17 was recalled but then screened out on its name, while DS18 survived only because that provider appended `_phyto` | PLET declared a scope-guaranteed catalogue; a keyword screen on a provider code has no discriminative validity |
| Title identity applied `[^a-z0-9]` before folding case | Every capital letter was deleted, so title identity depended on a provider's capitalisation and the previous SmartBuoy alias rule could never match | Case is folded first; the rule is unit tested |
| Identity grouped on any shared DOI | PLET publishes eight Marine Scotland series under `10.17031/1637`, so Loch Ewe, Scalloway, Scapa, and Stonehaven became one dataset family and DS16 appeared as a duplicate of DS16's neighbour | A DOI attached by one source to more than one distinct title is a collection DOI and is excluded from identity |
| The GBIF geographic screen was an inclusion term in a disjunction | Any phytoplankton dataset satisfied it through the biological pattern, so no GBIF row was ever screened on geography while the handoff reported out-of-domain results as filtered | Replaced by an explicit `geographic_screen_state` on every row; geography is recorded, never enforced, at dataset level |
| Provider strings carrying non-ASCII characters were unknown-encoding under the C locale | `perl = TRUE` matching declined to match them with only a warning, so a benchmark could have gone unrecalled with nothing failing | Provider text is marked UTF-8 at parse time |
| The benchmark set contained only datasets the modules were built around | A systematic discovery failure could not be detected | Extended from nine to sixteen: DS03, DS09, DS12, DS17, DS18, DS23, and DS26 added. The extension immediately exposed two of the defects above |

### 13.2 Register crosswalk, acquisition shortlist, and access register

Stage 1 previously reported one dataset advanced to acquisition — the DS22 conversion authority — against 8,060 undifferentiated pending rows. That is a compliant count and an unusable handoff. Three generated artefacts now bridge the narrative register and the executed search:

- [`metadata/stage1_ds_crosswalk.csv`](../metadata/stage1_ds_crosswalk.csv): every DS01–DS34 entry resolved against archived evidence, with the resolution pattern, retained rows, canonical families, and geographic-screen states;
- [`metadata/stage1_acquisition_shortlist.csv`](../metadata/stage1_acquisition_shortlist.csv): 22 named datasets ranked by declared reference tier, domain position, access feasibility, and CMEMS-era overlap, with the weights recorded in `config/ds_register_crosswalk.json`;
- [`metadata/provider_access_requests.csv`](../metadata/provider_access_requests.csv): the seven contact-only requests, each with what it blocks, a follow-up date, a decision deadline, and the scope reduction that applies if it is refused.

Thirty-one of thirty-four register entries resolved. The three that did not are DS21 (reported unreleased by its publisher, consistent with §6.3), DS31 and DS33 (excluded-by-decision entries that were never searched for). None is a discovery failure.

**Two findings bear on feasibility and are recorded here before any PhyC value is inspected.**

1. **The offshore gap in §12.5.2 is now empirically supported, not merely predicted.** DS19, the Norwegian IMR North Sea Ecosystem Survey, resolves to a single registry row that does not survive screening. Together with DS12 (CPR, contact-only) and DS20 (contact-only), the offshore central and northern North Sea has no retained candidate of any tier in the executed search. Whether those subregions are analysable at all now depends entirely on the DS12 and DS19 access requests.
2. **The Tier A base is two datasets, and neither is straightforwardly usable.** DS08 is a single German Bight coastal station whose carbon-resolved years are under moratorium; DS06 lies in the external-transfer region by the Stage 0 assignment. The confirmatory analysis is therefore expected to rest on Tier C abundance-to-carbon conversion through the pinned DS22 `PEG_BVOL` file, and §9.7's warning that conversion uncertainty may dominate apparent model error becomes a prespecified result rather than a caveat. `STAGED_WORK_PLAN.md` Stage 5 action 10 and Stage 10 now carry the lower, central, and upper conversion series through to the reported metrics.
