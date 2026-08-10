# Stage 4 — Feasibility and Confirmatory-Design Gate

## Purpose and boundary

Stage 4 determines which Stage 3 observation roles may proceed to detailed harmonization and which paper questions remain estimable in principle. It uses coverage, monitoring-network independence, reference routes, frozen subregions, and the recurrence rules already stated in the protocol. It does not create biomass, adequately sampled years, bloom/non-bloom windows, events, recurrence labels, splits, or CMEMS matchups, and it never inspects PhyC.

## Conclusions permitted at this stage

Six independent primary candidates may proceed to Stage 5: DS02, DS04, DS05, DS06, DS07, and DS16. DS06 is the only direct-carbon/biovolume anchor; the other five require audited abundance-to-carbon conversion. DS22 is the required conversion authority. `7_day` and `cadence_matched` are provisional primary-window candidates because both frozen broad subregions have at least two independent networks and an observation-year ceiling that could satisfy the prespecified recurrence year-count rule. This is only a coverage ceiling, not recurrence evidence.

Stage 4 cannot yet demonstrate primary-validation feasibility. Numeric target-season adequacy rules are not present in the frozen protocol; events do not exist before Stage 6; the exact CMEMS product is not frozen; and the current two-polygon spatial configuration cannot distinguish the anticipated offshore central/northern data gap from the broad southern/central core. These are explicit prospective decisions, not evidence of no data.

No lifeform is confirmatory now. Diatoms, *Phaeocystis*/haptophytes, and dinoflagellates remain confirmatory candidates pending Stage 5 converted carbon/biovolume dominance and Stage 6 recurrence. Coccolithophores and pico/nanophytoplankton remain exploratory unless the same observation-only rules pass.

## Commands and outputs

Run from the repository root:

```sh
Rscript scripts/04_stage4/00_run_stage4.R
```

The runner generates six feasibility/design registers, a calculated Markdown report, the conditional Stage 5 gate, an output checksum registry, traceability inventories, generated project status, and a dated validation log. The machine-readable gate is `metadata/stage4/gate/stage4_gate_status.csv`; `outputs/reports/stage4_feasibility.md` is the human-readable report.

The conditional gate authorizes only named Stage 5 harmonization work. It does not authorize Stage 6 outcomes, CMEMS acquisition, or PhyC analysis.
