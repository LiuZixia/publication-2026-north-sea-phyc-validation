# Rebuild Stage 1 from pinned responses, prove deterministic registry rows, and run the full test suite.

source("R/00_core_setup.R")
required_namespace("testthat")

run_step <- function(script) {
  output <- system2("Rscript", script, stdout = TRUE, stderr = TRUE)
  status <- attr(output, "status")
  if (is.null(status)) status <- 0L
  if (status != 0L) stop(paste(c(script, output), collapse = "\n"), call. = FALSE)
  output
}

# Every generated Stage 1 artefact must reproduce byte-for-byte from the same pinned responses.
tracked <- c("metadata/candidate_registry.csv", "metadata/stage1_known_item_recall.csv",
             "metadata/stage1_ds_crosswalk.csv", "metadata/stage1_acquisition_shortlist.csv",
             "metadata/stage1_unavailable_candidates.csv", "metadata/stage1_query_log.csv",
             "metadata/stage1_emodnet_wfs_overlap.csv",
             "metadata/stage1_emodnet_wfs_overlap_summary.csv")
missing <- tracked[!file.exists(tracked)]
if (length(missing)) stop(sprintf("Generate Stage 1 artefacts before validation: %s", paste(missing, collapse = ", ")), call. = FALSE)
before <- vapply(tracked, calculate_checksum, character(1))

compile_output <- run_step("scripts/01_compile_candidate_registry.R")
crosswalk_output <- run_step("scripts/01_build_ds_crosswalk.R")

after <- vapply(tracked, calculate_checksum, character(1))
changed <- tracked[before != after]
if (length(changed)) {
  stop(sprintf("Stage 1 artefacts changed when rebuilt from the same pinned responses: %s",
    paste(changed, collapse = ", ")), call. = FALSE)
}
compile_output <- c(compile_output, crosswalk_output)

test_output <- capture.output(
  testthat::test_dir("tests", reporter = "summary", stop_on_failure = TRUE),
  type = "output"
)

dir.create(file.path("outputs", "logs"), recursive = TRUE, showWarnings = FALSE)
stamp <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
log_path <- file.path("outputs", "logs", paste0("stage1_validation_", stamp, ".log"))
log_lines <- c(
  paste("completed_utc:", format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")),
  "artifact_sha256_before:", paste(names(before), before, sep = ": "),
  "artifact_sha256_after:", paste(names(after), after, sep = ": "),
  "compile_output:", compile_output,
  "test_output:", test_output,
  "session_info:", capture.output(sessionInfo())
)
writeLines(log_lines, log_path, useBytes = TRUE)
message(sprintf("Stage 1 validation passed; log: %s", log_path))
