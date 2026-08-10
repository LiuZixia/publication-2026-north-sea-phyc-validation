# Validate the consolidated Stage 2 evidence entirely from existing raw files and generated results.
#
# Acquisition scripts are intentionally excluded. Provider contact and downloads are separate,
# explicit operations under scripts/00_downloads/stage2/ and never occur during this replay gate.

source("R/00_core_setup.R")
required_namespace("testthat")

run_step <- function(script, arguments = character()) {
  output <- system2("Rscript", c(script, arguments), stdout = TRUE, stderr = TRUE)
  status <- attr(output, "status") %||% 0L
  if (status != 0L) stop(paste(c(script, output), collapse = "\n"), call. = FALSE)
  output
}

frozen_outputs <- c(
  "metadata/stage2/control/acquisition_work_order.csv",
  "metadata/stage2/control/wfs_geometry_queue.csv",
  "metadata/stage2/control/contract_freeze.json"
)
if (any(!file.exists(frozen_outputs))) {
  stop("Stage 2 control outputs are incomplete before validation.", call. = FALSE)
}
before <- vapply(frozen_outputs, calculate_checksum, character(1))
initializer_output <- run_step("scripts/02_stage2/control/00_initialize_contract.R")
after <- vapply(frozen_outputs, calculate_checksum, character(1))
if (!identical(before, after)) {
  stop("Frozen Stage 2 control outputs changed during deterministic rebuild.", call. = FALSE)
}

access_output <- run_step("scripts/02_stage2/control/02_build_access_dispositions.R")
ds12_output <- run_step("scripts/02_stage2/datasets/02_screen_ds12_cpr.R")
ds27_output <- run_step("scripts/02_stage2/datasets/02_screen_ds27_ferrybox.R")
status_output <- run_step("scripts/02_stage2/control/01_refresh_acquisition_status.R")
status <- utils::read.csv("metadata/stage2/control/acquisition_status.csv",
                          stringsAsFactors = FALSE, check.names = FALSE)
if (any(status$current_work_state %in% c("not_started", "in_progress", "failed")) ||
    !all(status$current_work_state %in% c("complete", "unavailable"))) {
  stop("The Stage 2 work order still contains unfinished or failed items.", call. = FALSE)
}
test_output <- capture.output(
  testthat::test_file("tests/test_stage2_contract.R", reporter = "summary",
                      stop_on_failure = TRUE),
  type = "output"
)

dir.create("outputs/logs", recursive = TRUE, showWarnings = FALSE)
stamp <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
log_path <- file.path("outputs", "logs", paste0("stage2_contract_validation_", stamp, ".log"))
writeLines(c(
  paste("completed_utc:", format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")),
  "execution_mode: offline_replay_existing_raw_no_provider_calls",
  "deterministic_artifact_sha256:", paste(names(after), after, sep = ": "),
  "initializer_output:", initializer_output,
  "access_disposition_output:", access_output,
  "ds12_screening_output:", ds12_output,
  "ds27_screening_output:", ds27_output,
  "status_output:", status_output,
  "test_output:", test_output,
  "session_info:", capture.output(sessionInfo())
), log_path, useBytes = TRUE)

inventory_output <- run_step("scripts/00_traceability/01_build_stage_file_inventory.R")
unresolved <- utils::read.csv("metadata/stage_file_inventory_unresolved.csv",
                              stringsAsFactors = FALSE, check.names = FALSE)
stage2_inventory <- utils::read.csv("metadata/stage2/inventory/file_inventory.csv",
                                    stringsAsFactors = FALSE, check.names = FALSE)
if (nrow(unresolved) || any(stage2_inventory$traceability_state == "unresolved")) {
  stop("Stage 2 contains unresolved generated or raw artifacts after inventory refresh.",
       call. = FALSE)
}

message(sprintf(
  "Stage 2 offline replay gate passed without downloads; log: %s; %s",
  log_path, paste(inventory_output, collapse = " ")
))
