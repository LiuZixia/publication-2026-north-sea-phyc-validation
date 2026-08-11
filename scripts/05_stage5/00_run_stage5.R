#!/usr/bin/env Rscript
# Run the Stage 5 observation-only harmonization audit using Stage 2 provider inputs.

source("R/00_core_setup.R")

run_step <- function(script) {
  message(sprintf("Stage 5 step started: %s", script))
  output <- system2("Rscript", script, stdout = TRUE, stderr = TRUE)
  status <- attr(output, "status") %||% 0L
  if (status != 0L) stop(paste(c(script, output), collapse = "\n"), call. = FALSE)
  message(sprintf("Stage 5 step completed: %s", script))
  c(paste0("script: ", script), output)
}

steps <- c(
  "scripts/05_stage5/00_audit_inputs.R",
  "scripts/05_stage5/01_extract_conversion_authority.R",
  "scripts/05_stage5/02_profile_taxon_conversion.R",
  "scripts/00_downloads/stage5/02_acquire_worms_taxonomy.R",
  "scripts/05_stage5/04_build_taxonomy_crosswalk.R",
  "scripts/05_stage5/05_build_conversion_readiness.R",
  "scripts/05_stage5/06_build_lifeform_crosswalk.R",
  "scripts/05_stage5/03_build_provisional_canonical.R",
  "scripts/05_stage5/07_build_provisional_sample_audit.R",
  "scripts/05_stage5/99_validate_stage5.R",
  "scripts/05_stage5/08_build_report.R",
  "scripts/05_stage5/98_build_output_registry.R",
  "scripts/00_traceability/01_build_stage_file_inventory.R",
  "scripts/99_stage_status.R"
)
step_output <- unlist(lapply(steps, run_step), use.names = FALSE)
unresolved <- utils::read.csv("metadata/stage_file_inventory_unresolved.csv", stringsAsFactors = FALSE)
if (nrow(unresolved) && any(unresolved$stage == "stage5")) {
  stop(sprintf("Stage 5 inventory contains unresolved artifacts: %s",
               paste(unresolved$path[unresolved$stage == "stage5"], collapse = ", ")), call. = FALSE)
}
gate <- utils::read.csv("metadata/stage5/gate/stage5_gate_status.csv", stringsAsFactors = FALSE)
if (nrow(gate) != 1L || gate$stage5_gate_passed || gate$stage6_outcome_authorized ||
    gate$cmems_acquisition_authorized) {
  stop("Stage 5 did not retain the expected blocked observation-only gate.", call. = FALSE)
}
dir.create("outputs/logs", recursive = TRUE, showWarnings = FALSE)
stamp <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
log_path <- file.path("outputs/logs", paste0("stage5_validation_", stamp, ".log"))
writeLines(c(paste("completed_utc:", format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")),
             "execution_mode: observation_only_with_idempotent_acquisitions_no_outcomes_no_phyc",
             "step_output:", step_output, "session_info:", capture.output(sessionInfo())),
           log_path, useBytes = TRUE)
message(sprintf("Stage 5 partial gate complete; log: %s", log_path))
