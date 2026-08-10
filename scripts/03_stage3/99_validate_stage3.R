#!/usr/bin/env Rscript
# Prove Stage 3 is PhyC-blind, complete, traceable, and deterministic from pinned Stage 2 evidence.

source("R/00_core_setup.R")
source("R/03_stage2_contract.R")
required_namespace("testthat")

run_step <- function(script) {
  message(sprintf("Validating replay step: %s", script))
  output <- system2("Rscript", script, stdout = TRUE, stderr = TRUE)
  status <- attr(output, "status") %||% 0L
  if (status != 0L) stop(paste(c(script, output), collapse = "\n"), call. = FALSE)
  output
}

# Exclude gate status, registries, inventories, and logs because they summarize the validation run.
tracked <- c(
  "metadata/stage3/input/stage3_input_manifest.csv",
  "metadata/stage3/input/input_manifest_checksums.csv",
  "data/interim/stage3_sample_support.csv",
  list.files("data/interim/stage3_support", pattern = "[.]csv$", full.names = TRUE),
  list.files("metadata/stage3/coverage", pattern = "[.]csv$", full.names = TRUE),
  list.files("metadata/stage3/method", pattern = "[.]csv$", full.names = TRUE),
  c(
    "metadata/stage3/gate/dataset_region_period_role_gate.csv",
    "metadata/stage3/gate/cmems_metadata_overlap.csv",
    "metadata/stage3/gate/coverage_gaps.csv"
  ),
  "outputs/figures/stage3_temporal_coverage.png",
  "outputs/figures/stage3_spatial_support.png"
)
tracked <- sort(unique(tracked))
missing <- tracked[!file.exists(tracked)]
if (length(missing)) {
  stop(sprintf("Generate Stage 3 artifacts before validation: %s", paste(missing, collapse = ", ")),
       call. = FALSE)
}
before <- vapply(tracked, calculate_checksum, character(1))

# The first pipeline pass may deliberately rebuild every adapter. The determinism replay always
# uses those freshly generated caches so a publication run does not parse the 21 GB DS24 source twice.
old_rebuild <- Sys.getenv("STAGE3_REBUILD", unset = NA_character_)
Sys.setenv(STAGE3_REBUILD = "0")
on.exit({
  if (is.na(old_rebuild)) Sys.unsetenv("STAGE3_REBUILD") else Sys.setenv(STAGE3_REBUILD = old_rebuild)
}, add = TRUE)
replay_output <- unlist(lapply(c(
  "scripts/03_stage3/00_build_input_manifest.R",
  "scripts/03_stage3/01_build_coverage.R",
  "scripts/03_stage3/02_build_method_biology.R",
  "scripts/03_stage3/03_apply_role_gate.R",
  "scripts/03_stage3/04_make_coverage_figures.R"
), run_step), use.names = FALSE)

after <- vapply(tracked, calculate_checksum, character(1))
changed <- tracked[before != after]
if (length(changed)) {
  stop(sprintf("Stage 3 artifacts changed during same-input replay: %s",
               paste(changed, collapse = ", ")), call. = FALSE)
}

test_output <- capture.output(
  testthat::test_file("tests/test_stage3_coverage.R", reporter = "summary",
                      stop_on_failure = TRUE),
  type = "output"
)
manifest <- utils::read.csv("metadata/stage3/input/stage3_input_manifest.csv",
                            stringsAsFactors = FALSE, check.names = FALSE)
samples <- utils::read.csv("data/interim/stage3_sample_support.csv",
                           stringsAsFactors = FALSE, check.names = FALSE)
gate <- utils::read.csv("metadata/stage3/gate/dataset_region_period_role_gate.csv",
                        stringsAsFactors = FALSE, check.names = FALSE)
roles <- table(factor(gate$stage3_role,
                      levels = c("eligible", "secondary", "exploratory", "unusable")))
if (nrow(manifest) != 19L || length(unique(samples$ds_id)) != 14L || any(gate$phy_c_inspected)) {
  stop("Stage 3 gate cannot pass: incomplete handoff/adapters or PhyC boundary violation.",
       call. = FALSE)
}

status <- data.frame(
  gate_state = "passed",
  execution_mode = "offline_existing_stage2_evidence_no_downloads_no_phyc",
  stage2_work_items = nrow(manifest),
  complete_work_items = sum(manifest$work_state == "complete"),
  unavailable_work_items = sum(manifest$work_state == "unavailable"),
  observation_datasets_parsed = length(unique(samples$ds_id)),
  sample_support_units = nrow(samples),
  eligible_gate_rows = unname(roles[["eligible"]]),
  secondary_gate_rows = unname(roles[["secondary"]]),
  exploratory_gate_rows = unname(roles[["exploratory"]]),
  unusable_gate_rows = unname(roles[["unusable"]]),
  deterministic_replay = TRUE,
  phy_c_values_accessed = FALSE,
  stage4_authorized_next = TRUE,
  stringsAsFactors = FALSE,
  check.names = FALSE
)
write_csv_atomic(status, "metadata/stage3/gate/stage3_gate_status.csv")
message(paste(c("Stage 3 validation passed.", replay_output, test_output), collapse = "\n"))
