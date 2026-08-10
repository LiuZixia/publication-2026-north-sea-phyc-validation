#!/usr/bin/env Rscript
# Run the offline Stage 4 feasibility gate without downloads, outcomes, or PhyC access.

source("R/00_core_setup.R")

run_step <- function(script) {
  message(sprintf("Stage 4 step started: %s", script))
  output <- system2("Rscript", script, stdout = TRUE, stderr = TRUE)
  status <- attr(output, "status") %||% 0L
  if (status != 0L) stop(paste(c(script, output), collapse = "\n"), call. = FALSE)
  message(sprintf("Stage 4 step completed: %s", script))
  c(paste0("script: ", script), output)
}

steps <- c("scripts/04_stage4/00_build_feasibility.R", "scripts/04_stage4/01_build_report.R",
           "scripts/04_stage4/99_validate_stage4.R", "scripts/04_stage4/98_build_output_registry.R",
           "scripts/00_traceability/01_build_stage_file_inventory.R", "scripts/99_stage_status.R")
step_output <- unlist(lapply(steps, run_step), use.names = FALSE)
unresolved <- utils::read.csv("metadata/stage_file_inventory_unresolved.csv", stringsAsFactors = FALSE)
if (nrow(unresolved) && any(unresolved$stage == "stage4")) {
  stop(sprintf("Stage 4 inventory contains unresolved artifacts: %s",
               paste(unresolved$path[unresolved$stage == "stage4"], collapse = ", ")), call. = FALSE)
}
gate <- utils::read.csv("metadata/stage4/gate/stage4_gate_status.csv", stringsAsFactors = FALSE)
if (nrow(gate) != 1L || gate$gate_state != "conditional_proceed_to_stage5_harmonization") {
  stop("Stage 4 did not issue the expected conditional Stage 5 handoff.", call. = FALSE)
}
dir.create("outputs/logs", recursive = TRUE, showWarnings = FALSE)
stamp <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
log_path <- file.path("outputs/logs", paste0("stage4_validation_", stamp, ".log"))
writeLines(c(paste("completed_utc:", format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")),
             "execution_mode: observation_only_no_downloads_no_outcomes_no_phyc",
             "step_output:", step_output, "session_info:", capture.output(sessionInfo())),
           log_path, useBytes = TRUE)
message(sprintf("Stage 4 conditional gate complete; log: %s", log_path))
