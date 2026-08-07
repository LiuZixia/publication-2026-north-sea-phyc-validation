#!/usr/bin/env Rscript
# Execute the complete Stage 0 derivation and governance gate from registered inputs.

suppressPackageStartupMessages({
  library(digest)
  library(jsonlite)
  library(sf)
  library(testthat)
})
if (!requireNamespace("renv", quietly = TRUE)) {
  stop("renv is unavailable; restore the repository environment before running Stage 0.", call. = FALSE)
}

dir.create("outputs/logs", recursive = TRUE, showWarnings = FALSE)
run_time <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
log_file <- file.path("outputs", "logs", paste0("stage0_", run_time, ".log"))
log_connection <- file(log_file, open = "wt")
sink(log_connection, type = "output", split = TRUE)
sink(log_connection, type = "message")
on.exit({
  sink(type = "message")
  sink(type = "output")
  close(log_connection)
}, add = TRUE)

cat(sprintf("Stage 0 execution started: %s\n", format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")))
cat(sprintf("Git commit: %s\n", system2("git", c("rev-parse", "HEAD"), stdout = TRUE)))
source("R/00_core_setup.R")
verify_raw_data_target(required_gb = 0)

cat("\n--- renv status ---\n")
renv::status()

cat("\n--- deterministic spatial derivation ---\n")
derive_output <- system2(
  file.path(R.home("bin"), "Rscript"),
  "scripts/00_derive_spatial.R",
  stdout = TRUE,
  stderr = TRUE
)
derive_status <- attr(derive_output, "status")
cat(paste(derive_output, collapse = "\n"), "\n")
if (!is.null(derive_status) && derive_status != 0L) stop("Stage 0 spatial derivation failed.", call. = FALSE)

cat("\n--- Stage 0 tests ---\n")
testthat::test_dir("tests", stop_on_failure = TRUE, stop_on_warning = TRUE)

cat("\n--- session information ---\n")
print(sessionInfo())
cat(sprintf("\nStage 0 gate completed successfully: %s\n", format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")))
cat(sprintf("Log: %s\n", log_file))
