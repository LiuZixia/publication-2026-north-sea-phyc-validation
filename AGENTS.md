# Guide for AI Agents

## Mission

This repository exists to produce one peer-reviewed, publication-quality paper:

> **Can CMEMS North-West Shelf Phytoplankton Carbon Detect Recurrent North Sea Phytoplankton Blooms? A Multi-Network, Lifeform-Stratified Validation**

Treat the paper, its reproducible evidence base, and its reviewability as the only final products. Do not split the work into additional papers, dashboards, applications, or unrelated analyses. Supporting code, data registries, logs, tables, and figures exist to make this one paper auditable and reproducible.

The central question is whether daily CMEMS North-West Shelf total phytoplankton carbon (`PhyC`) adds held-out, event-level discrimination and calibration for independently observed total-biomass blooms. Lifeform strata test transportability and failure modes; they do not make total PhyC a taxonomic classifier.

## Read Before Working

At the start of every task, read the relevant parts of these files in order:

1. `README.md` — paper identity, hypothesis, scope, design, and decision rules.
2. `docs/CONTEXT.md` — scientific interpretation and independence boundaries.
3. `docs/DATASET_SYSTEMATIC_SEARCH.md` — search scope, eligibility, evidence tiers, and candidate register.
4. `docs/OUTCOME_AND_LIFEFORM_PROTOCOL.md` — reference construction, outcomes, recurrence, event definitions, and prohibited analyses.
5. `docs/STAGED_WORK_PLAN.md` — current stage order, gates, and expected artifacts.
6. `PROGRESS.md` and `PENDING.md` — current state, file changes, blockers, and next actions.
7. This file — implementation and provenance rules for agents.

The README and protocols are the scientific source of truth. Do not silently change a prespecified definition after inspecting PhyC performance. If a scientifically necessary change is found, document the reason, date, affected outputs, and whether it is prospective, a sensitivity analysis, or a protocol deviation.

## Progress and Pending-State Protocol

`PROGRESS.md` and `PENDING.md` are the canonical handoff between agent work sessions. Keep both accurate throughout the task; do not wait until the final response.

At the start of every substantive agent work session:

1. Read both live files and reconcile them with `git status`, the relevant file diffs, and actual generated artifacts.
2. If the live files already exist, archive an unchanged snapshot of each under `docs/agent_tracking/archive/` using UTC names:
   - `YYYYMMDDTHHMMSSZ_PROGRESS.md`;
   - `YYYYMMDDTHHMMSSZ_PENDING.md`.
3. Never overwrite an archive. Add a numeric suffix if a timestamp collision occurs.
4. Create fresh live files that carry forward all still-valid state. Do not drop an unfinished item merely because a new session began.
5. Record the session objective, current project stage, starting commit/branch, relevant dirty files, and the first concrete next action.

Repeat the snapshot-and-refresh procedure whenever a genuine milestone is reached, including completion of a staged-work-plan gate, a systematic-search run, a dataset acquisition or qualification batch, a frozen manifest, a full pipeline result, or a manuscript release candidate. Routine edits and conversational updates are not milestones.

`PROGRESS.md` must contain:

- UTC update time, current stage, and session objective;
- completed work supported by file paths, commands, generated artifacts, or checksums;
- a file-change ledger listing every added, modified, renamed, or deleted path and why;
- validation commands and their outcomes;
- data/search/model state stated conservatively; and
- the last completed milestone and archive snapshot name.

`PENDING.md` must contain:

- the next ordered actions with one clearly marked first priority;
- completion criteria and expected outputs for each action;
- blockers, missing inputs, credentials, access requests, or unresolved decisions;
- known warnings, failed checks, and scientific risks that require follow-up; and
- items explicitly deferred or out of scope, so they are not repeatedly rediscovered.

Before ending a session, reconcile both files with the actual worktree and artifacts. A file is not complete because code was drafted: record whether it was executed, partially tested, or not tested. Never invent historic progress when initializing missing tracking files.

Only the lead agent for a task updates the canonical live pair and creates milestone snapshots. Subagents, when explicitly authorized, report changes and pending items to the lead rather than editing the same tracking files concurrently.

## Non-Negotiable Scientific Boundaries

- `PhyC` is modelled total phytoplankton carbon. Never describe it as a taxon, lifeform, or *Phaeocystis* measurement.
- The primary outcome is `total_biomass_bloom_present` at `subregion_id × analysis_window`.
- Construct reference events, recurrence eligibility, lifeform labels, and the split registry from independent observations without inspecting PhyC values or performance.
- Prefer reference data in this order: measured carbon, measured biovolume, defensibly converted taxon counts, within-lifeform abundance, then secondary comparators such as chlorophyll or CPR PCI.
- Determine cross-lifeform dominance only from carbon or biovolume shares. Never compare raw counts across differently sized lifeforms as if they were biomass.
- Preserve positive, negative, and unknown states. Missing or inadequately observed windows are `unknown`, never assumed negative.
- Match temporal claims to observation cadence. Monthly observations cannot validate daily onset, peak date, or daily event boundaries.
- Keep complete events or years together in validation folds. Treat monitoring networks and hydrographic regions as external-transfer units; daily matched rows are not independent replicates.
- Fit climatologies, thresholds, transformations, feature choices, and tuning parameters on training data only.
- Treat satellite chlorophyll and fields influenced by ocean-colour assimilation as dependency-sensitive comparators, not independent truth.
- Keep the generic pass and the *Phaeocystis*/haptophyte handoff pass separate. Only the latter permits downstream *Phaeocystis* use.
- Respect the explicit out-of-scope and prohibited analyses in the README and protocols.

## R-First, Script-Driven Research

R is the default and expected language for acquisition, cleaning, harmonization, analysis, validation, tables, figures, and manuscript rendering.

- Every substantive result must be reproducible by a non-interactive `Rscript` invocation from the repository root.
- Store executable pipeline scripts under `scripts/`, organized by numbered stage. All API queries and raw-file downloads belong in `scripts/00_downloads/`.
- Keep reusable R functions under `R/`; do not hide downloads or one-off pipeline execution inside reusable-function files.
- Organize work as small, ordered scripts with explicit inputs and outputs. Use stable numeric prefixes when execution order matters, for example `00_`, `01_`, and `02_`.
- Put reusable operations in clearly named R functions rather than copying blocks between scripts.
- Add comments before logical code blocks that explain the scientific purpose, assumptions, and non-obvious choices. Do not comment every syntax line.
- Fail loudly when inputs, expected columns, units, coordinate reference systems, or allowed label values are wrong. Do not silently coerce scientifically meaningful errors.
- Use project-relative paths and a reproducible project-root mechanism. Do not depend on an agent's working directory, home directory, or interactive IDE state.
- Record package versions with a repository lockfile when dependencies are introduced. Record the R version and `sessionInfo()` with full pipeline runs.
- Set and record seeds for stochastic procedures. Prefer deterministic operations where possible.
- Do not make manual edits to derived CSV files, tables, figures, statistics, search counts, or manuscript numbers. Change the code or source data and regenerate them.

Python is allowed only when the required operation has no practical R implementation, such as an unsupported service client or file format. Before adding Python:

1. confirm that an R package, direct HTTP request, or command-line call cannot reasonably perform the task;
2. keep the Python component narrow and callable from the scripted pipeline;
3. document why it is necessary, its environment and versions, and its exact inputs and outputs;
4. return results to the R workflow in a documented, open format; and
5. perform the scientific calculation, validation, tables, and figures in R whenever possible.

Notebooks may be used for temporary exploration, but they are not authoritative pipeline steps. Transfer any retained work into scripts.

## No LLM-Generated Evidence

AI agents may help write code, tests, documentation, and prose grounded in verified sources and computed outputs. They must not supply evidence.

- Never invent or estimate observations, search hits, screening decisions, parameter values, sample sizes, effect sizes, uncertainty intervals, performance metrics, or conclusions.
- Never fill a missing result with a plausible value or infer an unavailable field from narrative context.
- Never hand-author a derived result because it is expected scientifically.
- Every number in the abstract, manuscript, supplement, tables, figures, and flow diagram must trace to a raw or curated input and an R script that calculates it.
- Every qualitative result statement must be supported by a generated output or an explicitly cited external source.
- Mark unavailable, unresolved, or not-yet-calculated information as such. Do not complete gaps from model memory.
- An LLM is not a citable source and is not part of the data-generating process.

Where practical, insert manuscript values from generated files during rendering rather than copying them by hand. If a value must be transcribed, add an automated check against the generated source.

## Systematic Dataset Search

The systematic search must be executable, append-only, and based on service APIs or reproducible machine-readable exports. A web page or an LLM search summary can aid discovery, but it is not a completed search record.

For each searchable source:

1. Write an R acquisition script in `scripts/00_downloads/` using the documented API. Prefer direct, transparent HTTP requests when a package hides query details.
2. Store the exact endpoint, API version, query terms, geographic bounds, filters, request body or parameters, UTC execution time, pagination state, and software version.
3. Retrieve every page, implement documented rate limits and retry behavior, and check for truncated or partial responses.
4. Archive the unmodified response or export as a raw artifact before parsing it.
5. Calculate and register a checksum for every raw artifact.
6. Parse records into a stable candidate registry while preserving provider identifiers, dataset versions, URLs/DOIs, licenses, and access dates.
7. Record the numbers identified, deduplicated, screened, included, excluded, and pending. Generate the search flow diagram from this registry in R.
8. Preserve exclusion reasons and evidence-tier decisions as data, not only prose.

If a source has no usable API, record that fact and use the provider's reproducible bulk export or documented request procedure. Save request parameters, returned files, dates, and correspondence metadata. Manual portal inspection must be logged and must not be represented as an API search. Restricted, contact-only, or unreleased data remain `pending` or `excluded` until actual records and terms are available.

Search updates append a new dated run; they do not overwrite earlier runs. Rerun searches immediately before protocol registration and manuscript submission as required by the search protocol. Data discovered after model evaluation must be labelled external replication unless a documented protocol amendment says otherwise.

The statement in `docs/DATASET_SYSTEMATIC_SEARCH.md` that discovery is complete is a narrative status, not proof that record-level acquisition is complete. Until query scripts, raw responses, checksums, and screening records exist, report the corresponding API search or dataset as not yet reproducibly executed.

## Data Provenance and Storage

Use this structure as the repository grows, creating only directories needed for the current work:

```text
scripts/00_downloads/ reproducible API searches and all raw-file downloads
scripts/              remaining ordered, executable pipeline stages
R/                    reusable R functions called by scripts
config/               frozen machine-readable parameters and split definitions
data/raw               ignored symlink to the immutable external raw-data store
data/interim/          reproducible intermediate data
data/processed/        analysis-ready generated data
metadata/              tracked registries, schemas, checksums, and provenance
outputs/figures/       generated figures
outputs/tables/        generated tables
outputs/logs/          run, API-search, and validation logs
manuscript/            one paper and its supplement
tests/                 lightweight automated checks
docs/                  scientific context and protocols
```

Large or restricted data and generated outputs may remain untracked as specified in `.gitignore`, but their manifests, checksums, provenance, schemas, and regeneration instructions should be version controlled. Never commit credentials, access tokens, private correspondence, or provider-restricted data.

Raw data are immutable. If a provider file changes, save it as a new version and retain the old checksum in the acquisition registry. A processing script may standardize a copy into `data/interim/` or `data/processed/`; it must never rewrite `data/raw/`.

### External raw-data store

All raw downloads must physically reside in:

`/mnt/hdd/publication-2026-north-sea-phyc-validation/`

The repository path `data/raw` is a local symbolic link to that directory and the symlink itself is ignored by Git. Before any download, the script must:

1. confirm that `data/raw` exists and is a symbolic link;
2. resolve it and require the exact target `/mnt/hdd/publication-2026-north-sea-phyc-validation/`;
3. confirm that the target is mounted, writable, and has sufficient free space for the declared request;
4. stop with a clear error if any check fails; and
5. never replace the link, create a fallback `data/raw` directory, or write raw data elsewhere.

All raw-data creation must be performed by version-controlled scripts in `scripts/00_downloads/`. Do not place files in the raw store through a browser, an interactive R command, ad hoc `curl`/`wget`, file copying, or an unrecorded portal action. When a provider requires a manual export, create a scripted intake step in `scripts/00_downloads/` that verifies the named delivered file, records the manual acquisition reason and date, calculates its checksum, and registers it before use.

Download scripts must be restartable and idempotent. Use source/run/version subdirectories, temporary partial filenames followed by an atomic rename, retry and rate-limit handling, size/content validation, and checksums. If a verified file already exists, skip it; if content changes, save a new version instead of overwriting it. Each run must write a machine-readable manifest and a human-readable log without exposing credentials.

Each dataset must have the acquisition fields required by `docs/DATASET_SYSTEMATIC_SEARCH.md`, including provider, version, license, access date, coverage, methods, units, quality flags, overlap, evidence tier, and inclusion decision. Preserve original reported names, values, units, life stages, methods, and quality flags alongside harmonized fields.

Keep secrets in environment variables or ignored local configuration. Scripts should name required variables and stop with a useful message when they are absent. Never print secrets to logs.

## Pipeline and Analysis Expectations

Build the workflow in auditable stages:

1. acquire API responses and provider files;
2. validate file integrity and register provenance;
3. parse and harmonize without destroying original fields;
4. deduplicate provider and aggregator copies;
5. audit biomass convertibility, methods, cadence, coverage, and CMEMS overlap;
6. freeze the eligible dataset manifest, observation-only event catalogue, recurrence strata, and validation splits;
7. acquire and match the frozen CMEMS product;
8. fit required baselines before adding PhyC;
9. evaluate held-out events/years and network/region transfer;
10. generate manuscript tables, figures, decision rules, and diagnostics.

Prefer explicit intermediate data contracts. For each generated dataset, document the row unit, unique key, required columns, units, allowed missingness, and upstream source. Assert keys and allowed values in code.

Do not pool datasets merely because column names can be aligned. Retain the within-dataset, cross-dataset common, and meta-analytic layers specified in the outcome protocol. Provider records duplicated through PLET, ICES DOME, EMODnet, EurOBIS, or another aggregator count as one underlying observation source.

Report uncertainty at event, year, and network levels as appropriate. Do not report confidence intervals that treat daily rows from the same event as independent. Include the required baseline comparisons and failure modes even when they weaken the headline conclusion.

## Verification Before Accepting Work

For every change, run the narrowest relevant checks and then, when feasible, the affected pipeline stage from a clean R session. Before treating an analysis or manuscript update as complete, verify that:

- the command runs non-interactively from the repository root;
- declared inputs exist and generated outputs can be rebuilt;
- schemas, unique keys, units, value ranges, and missingness are checked;
- API pagination and record counts reconcile with archived responses;
- raw inputs match registered checksums;
- train/test separation and observation-only construction have tests or assertions;
- tables and figures contain no manually entered result values;
- warnings are resolved or explicitly recorded and justified;
- output logs include timestamps, package versions, and session information; and
- conclusions do not exceed the reference tier, sampling cadence, spatial support, or held-out evidence.

When a full run is impossible because data, credentials, access approval, or compute are unavailable, do not claim success. State exactly what was tested, what remains unverified, and what input is required.

## Publication Standard

Write for skeptical peer reviewers. Methods must be detailed enough to reproduce; results must distinguish confirmatory, sensitivity, exploratory, and external-replication analyses; limitations must include sampling selectivity, temporal resolution, taxonomic harmonization, carbon-conversion uncertainty, assimilation dependence, and transferability.

Maintain one manuscript source with a consistent title, question, outcome, and terminology. Prefer a reproducibly rendered R Markdown or Quarto manuscript if one is introduced. Keep supplementary methods and tables subordinate to the same paper rather than turning them into separate projects.

Citations must be checked against the original paper, dataset record, or official documentation. Preserve dataset citations, DOIs, versions, licenses, and access dates. Do not cite a search-engine snippet, an aggregator in place of the canonical provider, or an AI-generated summary when the primary source is available.

Null, conditional, and failed validation results are valid outcomes. Do not tune definitions, omit networks, promote exploratory strata, or rewrite the question to manufacture a positive paper.

## Agent Working Practice

- At session start, follow the progress/pending snapshot procedure, inspect repository status, and preserve unrelated user changes.
- Name the staged-work-plan stage being advanced and define its completion evidence before editing.
- Make the smallest coherent change that advances the paper and follows the frozen protocol.
- Do not replace existing raw data, decisions, or prose without documenting why.
- Add code comments and documentation while the reasoning is fresh.
- Keep the `PROGRESS.md` file-change ledger current after each coherent edit batch, not only at handoff.
- Keep `PENDING.md` ordered and remove an item only after its completion evidence is recorded in `PROGRESS.md`.
- Prefer resumable, idempotent steps. A rerun with unchanged inputs must not corrupt data, duplicate records, or change frozen outputs silently.
- Report the files changed, commands run, generated artifacts, and any unresolved scientific or reproducibility issue.
- Never claim that the paper, search, dataset, or result is complete solely because prose or code has been drafted. Completion requires successful execution against the registered inputs.

The project is done only when the systematic search and screening are reproducible, inputs and decisions are frozen and versioned, the complete R pipeline regenerates all reported results, validation is genuinely held out at the event/year/network level, and one publication-ready manuscript reports generic and *Phaeocystis*-specific decisions separately.
