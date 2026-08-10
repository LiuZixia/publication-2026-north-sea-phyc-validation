#!/usr/bin/env Rscript
# Rebuild and validate Stage 3 entirely from pinned Stage 2 evidence; never download or inspect PhyC.

source("R/00_core_setup.R")

run_step <- function(script) {
  message(sprintf("Stage 3 step started: %s", script))
  output <- system2("Rscript", script, stdout = TRUE, stderr = TRUE)
  status <- attr(output, "status") %||% 0L
  if (status != 0L) stop(paste(c(script, output), collapse = "\n"), call. = FALSE)
  message(sprintf("Stage 3 step completed: %s", script))
  c(paste0("script: ", script), output)
}

steps <- c(
  "scripts/03_stage3/00_build_input_manifest.R",
  "scripts/03_stage3/01_build_coverage.R",
  "scripts/03_stage3/02_build_method_biology.R",
  "scripts/03_stage3/03_apply_role_gate.R",
  "scripts/03_stage3/04_make_coverage_figures.R",
  "scripts/03_stage3/99_validate_stage3.R",
  "scripts/03_stage3/98_build_output_registry.R",
  "scripts/00_traceability/01_build_stage_file_inventory.R",
  "scripts/99_stage_status.R"
)
step_output <- unlist(lapply(steps, run_step), use.names = FALSE)

unresolved <- utils::read.csv("metadata/stage_file_inventory_unresolved.csv",
                              stringsAsFactors = FALSE, check.names = FALSE)
if (nrow(unresolved) && any(unresolved$stage == "stage3")) {
  bad <- unresolved$path[unresolved$stage == "stage3"]
  stop(sprintf("Stage 3 inventory contains unresolved artifacts: %s", paste(bad, collapse = ", ")),
       call. = FALSE)
}
gate <- utils::read.csv("metadata/stage3/gate/stage3_gate_status.csv",
                        stringsAsFactors = FALSE, check.names = FALSE)
if (nrow(gate) != 1L || gate$gate_state != "passed") {
  stop("Stage 3 validator did not issue a unique passed gate.", call. = FALSE)
}

dir.create("outputs/logs", recursive = TRUE, showWarnings = FALSE)
stamp <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
log_path <- file.path("outputs/logs", paste0("stage3_validation_", stamp, ".log"))
writeLines(c(
  paste("completed_utc:", format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")),
  "execution_mode: offline_existing_stage2_evidence_no_downloads_no_phyc",
  paste("full_adapter_rebuild_requested:", identical(Sys.getenv("STAGE3_REBUILD"), "1")),
  "step_output:", step_output,
  "session_info:", capture.output(sessionInfo())
), log_path, useBytes = TRUE)
message(sprintf("Stage 3 gate passed; validation log: %s", log_path))
