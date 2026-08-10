# Pending Work

## Immediate Priorities (Stage 3)
1.  **=> Parse and Harmonize Existing Datasets:** Create robust R scripts to standardize columns (taxon, value, units, date, coordinates) without destroying original fields, for all datasets residing in `data/raw/stage2/`.
2.  **Dataset Deduplication:** Identify duplicated datasets between providers and aggregators (e.g., Cefas vs PLET, PANGAEA vs EurOBIS) based on geographic and temporal overlap.
3.  **Perform Biomass Conversion Audits:** Assess which specific dataset series require HELCOM PEG_BVOL conversions and execute them.

## Blocked / Awaiting Input
*   **DS28 (LifeWatch HPLC pigments):** Need exact dataset DOI, IPT resource name, or API URL to execute `scripts/00_downloads/27_acquire_ds28_lifewatch_hplc.R`.
*   **DS17, DS18, DS19, DS20, DS21, DS23:** Awaiting responses from Principal Investigators for restricted datasets or existence confirmation (these are tracked in `metadata/provider_access_requests.csv`).

## Out of Scope
*   Downloading entire multi-provider aggregators like DS13 (ICES DOME), DS14 (EMODnet Biology), or DS25 (EMODnet Chemistry). The specific constituent provider datasets are instead targeted to prevent large-scale data duplication.
