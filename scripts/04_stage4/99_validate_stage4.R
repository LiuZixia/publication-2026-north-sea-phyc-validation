#!/usr/bin/env Rscript
# Validate deterministic, observation-only Stage 4 feasibility and authorize Stage 5 only.

source("R/00_core_setup.R")
source("R/03_stage2_contract.R")
required_namespace("testthat")

run_step <- function(script) {
  output <- system2("Rscript", script, stdout = TRUE, stderr = TRUE)
  status <- attr(output, "status") %||% 0L
  if (status != 0L) stop(paste(c(script, output), collapse = "\n"), call. = FALSE)
  output
}

tracked <- c(list.files("metadata/stage4/feasibility", pattern = "[.]csv$", full.names = TRUE),
             "outputs/reports/stage4_feasibility.md")
if (length(tracked) != 7L || any(!file.exists(tracked))) {
  stop("Generate all six Stage 4 feasibility tables and the report before validation.", call. = FALSE)
}
before <- vapply(tracked, calculate_checksum, character(1))
replay_output <- c(run_step("scripts/04_stage4/00_build_feasibility.R"),
                   run_step("scripts/04_stage4/01_build_report.R"))
after <- vapply(tracked, calculate_checksum, character(1))
if (!identical(before, after)) {
  stop(sprintf("Stage 4 same-input replay changed: %s", paste(tracked[before != after], collapse = ", ")),
       call. = FALSE)
}

datasets <- utils::read.csv("metadata/stage4/feasibility/provisional_dataset_manifest.csv", stringsAsFactors = FALSE)
windows <- utils::read.csv("metadata/stage4/feasibility/window_candidate_register.csv", stringsAsFactors = FALSE)
questions <- utils::read.csv("metadata/stage4/feasibility/question_feasibility.csv", stringsAsFactors = FALSE)
status <- data.frame(
  gate_state = "conditional_proceed_to_stage5_harmonization",
  primary_validation_feasibility = "not_yet_demonstrated",
  stage5_harmonization_authorized = TRUE, stage6_outcome_authorized = FALSE,
  cmems_acquisition_authorized = FALSE, stage2_work_items_retained = nrow(datasets),
  independent_primary_candidate_networks = sum(datasets$independent_primary_network),
  direct_carbon_anchor_networks = sum(datasets$stage4_role == "primary_direct_carbon_anchor"),
  conversion_candidate_networks = sum(datasets$stage4_role == "primary_conversion_candidate"),
  primary_window_candidates = paste(windows$analysis_window[windows$window_design_role ==
                                                              "primary_window_candidate"], collapse = "|"),
  adequately_sampled_years_calculated = FALSE, bloom_events_calculated = FALSE,
  confirmatory_lifeforms_frozen = FALSE,
  unresolved_question_count = sum(grepl("not_yet|not_operationally", questions$stage4_state)),
  deterministic_replay = TRUE, phy_c_values_accessed = FALSE,
  stringsAsFactors = FALSE, check.names = FALSE
)
dir.create("metadata/stage4/gate", recursive = TRUE, showWarnings = FALSE)
success <- FALSE
on.exit({
  if (!success) {
    status$gate_state <- "failed_validation"
    status$stage5_harmonization_authorized <- FALSE
    write_csv_atomic(status, "metadata/stage4/gate/stage4_gate_status.csv")
  }
}, add = TRUE)
write_csv_atomic(status, "metadata/stage4/gate/stage4_gate_status.csv")
test_output <- capture.output(
  testthat::test_file("tests/test_stage4_feasibility.R", reporter = "summary", stop_on_failure = TRUE),
  type = "output"
)
success <- TRUE
message(paste(c("Stage 4 validation passed conditionally for Stage 5 harmonization.",
                replay_output, test_output), collapse = "\n"))
