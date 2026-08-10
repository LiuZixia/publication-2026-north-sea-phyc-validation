# Raw-Data Download Scripts

Every systematic-search request and every operation that creates a raw input belongs in this directory as a version-controlled R script.

Stage-owned acquisition modules are grouped beneath this directory. Stage 1 catalogue searches are
in `scripts/00_downloads/stage1/`; Stage 2 provider acquisitions are in
`scripts/00_downloads/stage2/`, separately from their downstream screening scripts. Operational
descriptions are in `docs/stages/`.

Ordinary Stage 2 development and publication validation uses existing checksum-pinned raw files:
`Rscript scripts/02_stage2/00_run_stage2.R`. It does not call any script in this directory. A Stage 2
acquisition script must be invoked explicitly only when a new or resumed provider acquisition is
authorized.

Each script must:

1. run non-interactively from the repository root;
2. verify that `data/raw` is a symbolic link resolving exactly to `/mnt/hdd/publication-2026-north-sea-phyc-validation/`;
3. stop if the external target is unavailable, not writable, or lacks sufficient declared space;
4. record the endpoint or provider, query/request parameters, UTC time, API or dataset version, license, and output paths;
5. download to a temporary partial file and rename atomically only after validation;
6. support pagination, rate limits, retries, and safe restart where applicable;
7. validate response type, size, record count, and provider errors before accepting a file;
8. calculate checksums and write a machine-readable acquisition manifest;
9. skip an existing file only after its checksum is verified; and
10. never overwrite a changed provider file or print credentials to a log.

Use source, search-run, and provider-version subdirectories below `data/raw`. Raw responses are immutable. Parsing and scientific transformations belong in later scripts and write only to interim or processed data locations.

If an unavoidable provider workflow begins with a manual export, add a scripted intake step here. It must verify the delivered filename, record why direct API acquisition was impossible, capture the provider and acquisition date, calculate the checksum, and register the file before downstream use.
