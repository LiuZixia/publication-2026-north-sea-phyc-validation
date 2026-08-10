# Rebuild Stage 1 from pinned responses, prove deterministic registry rows, and run its tests.

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
tracked <- c("metadata/stage1/search/candidate_registry.csv", "metadata/stage1/search/known_item_recall.csv",
             "metadata/stage1/qualification/ds_crosswalk.csv", "metadata/stage1/qualification/acquisition_shortlist.csv",
             "metadata/stage1/qualification/unavailable_candidates.csv", "metadata/stage1/search/query_log.csv",
             "metadata/stage1/search/search_flow.csv",
             "metadata/stage1/search/emodnet_wfs_overlap.csv",
             "metadata/stage1/search/emodnet_wfs_overlap_summary.csv")
missing <- tracked[!file.exists(tracked)]
if (length(missing)) stop(sprintf("Generate Stage 1 artefacts before validation: %s", paste(missing, collapse = ", ")), call. = FALSE)
before <- vapply(tracked, calculate_checksum, character(1))

compile_output <- run_step("scripts/01_stage1/01_compile_candidate_registry.R")
crosswalk_output <- run_step("scripts/01_stage1/02_build_ds_crosswalk.R")

after <- vapply(tracked, calculate_checksum, character(1))
changed <- tracked[before != after]
if (length(changed)) {
  stop(sprintf("Stage 1 artefacts changed when rebuilt from the same pinned responses: %s",
    paste(changed, collapse = ", ")), call. = FALSE)
}
compile_output <- c(compile_output, crosswalk_output)

# Stage 2 has its own gate. Including its live-state tests here previously made Stage 1 fail when a
# later acquisition advanced, even though every Stage 1 artifact still reproduced.
test_files <- c(
  "tests/test_stage0_governance.R",
  "tests/test_stage0_identifiers.R",
  "tests/test_stage0_spatial.R",
  "tests/test_stage1_search.R"
)
test_output <- unlist(lapply(test_files, function(path) {
  capture.output(testthat::test_file(path, reporter = "summary", stop_on_failure = TRUE), type = "output")
}), use.names = FALSE)

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

# Refresh the complete file inventory after the new validation log exists, then assert that every
# Stage 1 generated or raw artifact has both a producer and a checksum route.
inventory_output <- run_step("scripts/00_traceability/01_build_stage_file_inventory.R")
inventory <- utils::read.csv("metadata/stage1/inventory/file_inventory.csv",
                             stringsAsFactors = FALSE, check.names = FALSE)
unresolved <- inventory$path[inventory$traceability_state == "unresolved"]
if (length(unresolved)) {
  stop(sprintf("Stage 1 inventory contains unresolved artifacts: %s", paste(unresolved, collapse = ", ")),
       call. = FALSE)
}
message(sprintf("Stage 1 validation passed; log: %s; inventory: %s",
                log_path, "metadata/stage1/inventory/file_inventory.csv"))
