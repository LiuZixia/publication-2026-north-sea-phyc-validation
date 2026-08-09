# Rebuild frozen routing artifacts and validate the EMODnet closure plus rank-1 DS06 screen.

source("R/00_core_setup.R")
required_namespace("testthat")

run_step <- function(script, arguments = character()) {
  output <- system2("Rscript", c(script, arguments), stdout = TRUE, stderr = TRUE)
  status <- attr(output, "status")
  if (is.null(status)) status <- 0L
  if (status != 0L) stop(paste(c(script, output), collapse = "\n"), call. = FALSE)
  output
}

tracked <- c(
  "metadata/stage2_acquisition_work_order.csv",
  "metadata/stage2_wfs_geometry_queue.csv",
  "metadata/stage2_contract_freeze.json"
)
before <- vapply(tracked, calculate_checksum, character(1))
initialize_output <- run_step("scripts/02_initialize_stage2_contract.R")
after <- vapply(tracked, calculate_checksum, character(1))
if (!identical(before, after)) {
  stop("Frozen Stage 2 contract artifacts changed during deterministic rebuild.", call. = FALSE)
}

ranked_output <- unlist(lapply(c(
  "scripts/00_downloads/05_acquire_ds06_smhi_shark.R",
  "scripts/02_inventory_screen_ds06_smhi_shark.R",
  "scripts/02_resolve_ds06_smhi_shark_duplicates.R",
  "scripts/02_summarize_ds06_smhi_shark_screening.R",
  "scripts/00_downloads/06_acquire_ds26_smhi_ifcb.R",
  "scripts/00_downloads/07_acquire_ds26_ifcb_reference_library.R",
  "scripts/02_inventory_screen_ds26_smhi_ifcb.R",
  "scripts/02_refresh_stage2_acquisition_status.R"
), run_step), use.names = FALSE)

test_output <- capture.output(
  testthat::test_file("tests/test_stage2_contract.R", reporter = "summary", stop_on_failure = TRUE),
  type = "output"
)
dir.create(file.path("outputs", "logs"), recursive = TRUE, showWarnings = FALSE)
stamp <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
log_path <- file.path("outputs", "logs", paste0("stage2_contract_validation_", stamp, ".log"))
writeLines(c(
  paste("completed_utc:", format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")),
  "deterministic_artifact_sha256:", paste(names(after), after, sep = ": "),
  "initializer_output:", initialize_output,
  "ranked_acquisition_idempotent_output:", ranked_output,
  "test_output:", test_output,
  "session_info:", capture.output(sessionInfo())
), log_path, useBytes = TRUE)
message(sprintf(paste0(
  "Stage 2 contract plus completed dataset-level work through DS26 validated; ",
  "the Stage 2 gate remains open; log: %s"), log_path))
