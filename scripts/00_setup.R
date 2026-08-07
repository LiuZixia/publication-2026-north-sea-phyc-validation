#!/usr/bin/env Rscript
#' Stage 0 Setup and Validation
#'
#' This script initializes the R environment, ensures dependencies and storage
#' targets are correctly configured, and sets up session logging.

# Ensure core packages are loaded so renv detects them
library(httr2)
library(jsonlite)
library(digest)
library(sf)
library(testthat)

if (!requireNamespace("renv", quietly = TRUE)) {
  install.packages("renv", repos = "https://cloud.r-project.org")
}

# Create logs directory
if (!dir.exists("outputs/logs")) {
  dir.create("outputs/logs", recursive = TRUE)
}

# Initialize run log
log_file <- sprintf("outputs/logs/run_%s.log", format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC"))
sink(log_file, split = TRUE)
cat("Pipeline Execution Started at:", format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), "\n\n")

# Load helpers and core scripts
source("R/00_core_setup.R")
source("R/00_identifiers.R")
source("R/00_spatial_assignment.R")

# Validate environment and symlink target
message("Validating environment...")
tryCatch({
  verify_raw_data_target()
  message("Environment validation passed.")
}, error = function(e) {
  stop("Environment validation failed: ", e$message)
})

# Force renv snapshot to record used packages
message("Snapshotting dependencies...")
renv::snapshot(prompt = FALSE)

# Regenerate spatial outputs
message("Regenerating spatial outputs...")
source("scripts/00_downloads/00_download_spatial.R")

# Run tests
message("Running Stage 0 tests...")
res <- testthat::test_dir("tests", stop_on_failure = TRUE)

cat("--- Session Info ---\n")
print(sessionInfo())
cat("--------------------\n\n")

cat("Stage 0 Setup completed successfully.\n")
sink()
