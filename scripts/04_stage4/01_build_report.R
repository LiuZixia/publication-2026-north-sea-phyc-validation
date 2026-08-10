#!/usr/bin/env Rscript
# Render the Stage 4 feasibility report from generated registers only.

source("R/00_core_setup.R")

datasets <- utils::read.csv("metadata/stage4/feasibility/provisional_dataset_manifest.csv", stringsAsFactors = FALSE)
windows <- utils::read.csv("metadata/stage4/feasibility/window_candidate_register.csv", stringsAsFactors = FALSE)
regions <- utils::read.csv("metadata/stage4/feasibility/subregion_window_feasibility.csv", stringsAsFactors = FALSE)
limits <- utils::read.csv("metadata/stage4/feasibility/scope_limitations.csv", stringsAsFactors = FALSE)
questions <- utils::read.csv("metadata/stage4/feasibility/question_feasibility.csv", stringsAsFactors = FALSE)

primary <- datasets[datasets$independent_primary_network, , drop = FALSE]
candidate_windows <- windows$analysis_window[windows$window_design_role == "primary_window_candidate"]
lines <- c(
  "# Stage 4 Feasibility and Confirmatory-Design Report (generated)", "",
  "Do not edit. Regenerate with `Rscript scripts/04_stage4/01_build_report.R`.", "",
  "## Conclusion", "",
  sprintf("Stage 5 harmonization may proceed for %d independent primary candidates: %s.",
          nrow(primary), paste(primary$ds_id, collapse = ", ")),
  sprintf("Observation coverage supports the provisional primary-window candidate set: %s.",
          paste(candidate_windows, collapse = ", ")),
  "This is not proof that the primary validation is estimable: adequacy rules, conversion compatibility,",
  "events, recurrence, exact model overlap, and held-out splits remain unresolved without PhyC inspection.", "",
  "## Provisional dataset roles", "",
  "| DS | Network | Stage 4 role | Stage 5 action | Reference route |", "|---|---|---|---|---|",
  sprintf("| %s | %s | %s | %s | %s |", datasets$ds_id, datasets$monitoring_network,
          datasets$stage4_role, datasets$stage5_action, datasets$reference_route), "",
  "## Window candidates", "",
  "| Window | Supported frozen subregions | Independent networks | Design role |", "|---|---:|---:|---|",
  sprintf("| %s | %d | %d | %s |", windows$analysis_window,
          windows$frozen_subregions_with_two_network_and_year_ceiling,
          windows$total_independent_networks, windows$window_design_role), "",
  "## Scope limitations", "",
  "| Limitation | Current state | Consequence | Required resolution |", "|---|---|---|---|",
  sprintf("| %s | %s | %s | %s |", limits$limitation_id, limits$current_state,
          limits$consequence, limits$required_resolution), "",
  "## Question status", "",
  "| Question | Stage 4 state | Next gate |", "|---|---|---|",
  sprintf("| %s | %s | %s |", questions$question, questions$stage4_state, questions$next_gate), "",
  "No CMEMS PhyC value was accessed. Coverage years are upper feasibility ceilings, not adequately sampled years."
)
dir.create("outputs/reports", recursive = TRUE, showWarnings = FALSE)
writeLines(lines, "outputs/reports/stage4_feasibility.md", useBytes = TRUE)
message(sprintf("Generated Stage 4 report from %d dataset roles and %d region/window rows.",
                nrow(datasets), nrow(regions)))
