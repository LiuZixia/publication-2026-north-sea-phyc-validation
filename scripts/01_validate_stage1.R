# Rebuild Stage 1 from pinned responses, prove deterministic registry rows, and run the full test suite.

source("R/00_core_setup.R")
required_namespace("testthat")

registry_path <- "metadata/candidate_registry.csv"
if (!file.exists(registry_path)) stop("Compile the Stage 1 registry before validation.", call. = FALSE)
before <- calculate_checksum(registry_path)

compile_output <- system2("Rscript", "scripts/01_compile_candidate_registry.R", stdout = TRUE, stderr = TRUE)
compile_status <- attr(compile_output, "status")
if (is.null(compile_status)) compile_status <- 0L
if (compile_status != 0L) stop(paste(compile_output, collapse = "\n"), call. = FALSE)
after <- calculate_checksum(registry_path)
if (!identical(before, after)) stop("Candidate registry changed when rebuilt from the same pinned responses.", call. = FALSE)

test_output <- capture.output(
  testthat::test_dir("tests", reporter = "summary", stop_on_failure = TRUE),
  type = "output"
)

dir.create(file.path("outputs", "logs"), recursive = TRUE, showWarnings = FALSE)
stamp <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
log_path <- file.path("outputs", "logs", paste0("stage1_validation_", stamp, ".log"))
log_lines <- c(
  paste("completed_utc:", format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")),
  paste("candidate_registry_sha256_before:", before),
  paste("candidate_registry_sha256_after:", after),
  "compile_output:", compile_output,
  "test_output:", test_output,
  "session_info:", capture.output(sessionInfo())
)
writeLines(log_lines, log_path, useBytes = TRUE)
message(sprintf("Stage 1 validation passed; log: %s", log_path))
