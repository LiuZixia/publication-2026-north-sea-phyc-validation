# Rebuild the frozen Stage 2 routing artifacts and validate the completed EMODnet WFS closure.

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
  "test_output:", test_output,
  "session_info:", capture.output(sessionInfo())
), log_path, useBytes = TRUE)
message(sprintf("Stage 2 contract and EMODnet closure validation passed; log: %s", log_path))
