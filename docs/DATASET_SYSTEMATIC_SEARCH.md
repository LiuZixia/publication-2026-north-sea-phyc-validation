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
