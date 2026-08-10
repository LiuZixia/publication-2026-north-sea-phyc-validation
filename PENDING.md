# Pending Work

## Ordered Actions

1. **FIRST PRIORITY — Complete the explicitly authorized direct Git publication.** Stage the complete reviewed Stage 1/2 consolidation, commit it on the current `main` branch, and push `main` to `origin`. Completion evidence is the commit SHA, successful fast-forward push, and a clean worktree synchronized with `origin/main`.
2. **Begin Stage 3 with temporal and cadence coverage.** Generate per-dataset/network/station/subregion/method-epoch/year coverage tables from the usable Stage 2 records, preserving unknown cadence and preventing claims finer than the observations support.
3. **Generate the remaining Stage 3 coverage evidence and apply its role gate.** Produce spatial, vertical, method, biological, variable-availability, and CMEMS-period metadata summaries, then classify each dataset-region-period combination without inspecting PhyC values.

## Blockers and Missing Inputs

- GitHub CLI is not installed (`gh: command not found`), so no PR can be opened through the normal publishing workflow. The user explicitly authorized direct Bash `git` commit and push without a PR.
- DS28 LifeWatch HPLC lacks an exact DOI, IPT resource name, API URL, and archived payload; it is now explicitly temporarily unavailable pending provider identification.
- Contact-required DS08 high-tier children, DS17, DS18, DS19, DS20, DS21, DS23, and DS28 remain unavailable unless provider responses and usable terms arrive; current consequences must remain applied.

## Known Warnings and Scientific Risks

- The existing `data/raw/stage2/downloaded_files_inventory.md` is a historical generated Markdown artifact in immutable raw storage; it must remain immutable and be marked superseded by the tracked generated CSV inventory.
- The ranked Stage 2 work order is fully dispositioned, but this is not final scientific eligibility: later observation-only audits can still exclude or downgrade acquired evidence.
- DS27 relies on the installed system `ncdump` utility because no NetCDF R package is installed. The script processes all pinned files under R control and must fail rather than emit a zero-row placeholder if that decoder is unavailable.
- Moving or renaming raw evidence could break pinned response paths and checksums; raw files will remain immutable unless a scripted, provenance-preserving migration is demonstrably required.
- The Stage 2 publication gate, Stage 1 regression, static checks, and deterministic inventory pass; future changes must preserve those gates.
- The Stage 2 consolidation gate must remain an offline replay gate; any future provider acquisition must be invoked separately and explicitly.

## Deferred / Out of Scope

- Stage 4 feasibility, Stage 5 harmonization/biomass conversion, and all later outcome construction remain deferred until the Stage 3 coverage gate passes.
- CMEMS value acquisition, PhyC inspection, outcome construction, modelling, dashboards, and additional papers remain out of scope until their staged gates authorize them.
