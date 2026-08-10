#!/usr/bin/env Rscript
# Freeze the complete Stage 2 handoff as the only authorized Stage 3 input universe.

source("R/00_core_setup.R")
source("R/03_stage2_contract.R")
source("R/05_stage3_contract.R")

status_path <- "metadata/stage2/control/acquisition_status.csv"
status <- utils::read.csv(status_path, stringsAsFactors = FALSE, check.names = FALSE)
adapters <- stage3_read_adapters()
if (nrow(status) != 19L || anyDuplicated(status$ds_id) ||
    !identical(status$ds_id, stage3_required_ids())) {
  stop("Stage 2 handoff is not the expected ordered 19-item register.", call. = FALSE)
}
if (!identical(as.integer(table(factor(status$current_work_state,
                                        levels = c("complete", "unavailable")))), c(16L, 3L))) {
  stop("Stage 2 handoff must contain 16 complete and three unavailable work items.", call. = FALSE)
}

value <- merge(status, adapters, by = "ds_id", sort = FALSE)
value <- value[match(status$ds_id, value$ds_id), , drop = FALSE]
role <- character(nrow(value))
pin_paths <- manifest_paths <- character(nrow(value))
manifest_state <- character(nrow(value))
for (i in seq_len(nrow(value))) {
  ds <- value$ds_id[[i]]
  if (value$current_work_state[[i]] == "unavailable") {
    if (value$adapter_id[[i]] != "unavailable") {
      stop(sprintf("Unavailable work item has a non-unavailable adapter: %s", ds), call. = FALSE)
    }
    role[[i]] <- "unavailable"
    pin_paths[[i]] <- paste(stage3_active_pins(ds), collapse = "|")
    manifest_paths[[i]] <- ""
    manifest_state[[i]] <- "unavailable_not_observation_evidence"
    next
  }
  if (value$adapter_id[[i]] == "unavailable") {
    stop(sprintf("Complete work item has an unavailable adapter: %s", ds), call. = FALSE)
  }
  pins <- stage3_active_pins(ds)
  manifests <- stage3_manifest_paths(pins)
  if (!length(pins) || !length(manifests)) {
    stop(sprintf("Complete work item lacks an active pin or raw manifest: %s", ds), call. = FALSE)
  }
  pin_paths[[i]] <- paste(pins, collapse = "|")
  manifest_paths[[i]] <- paste(manifests, collapse = "|")
  manifest_state[[i]] <- "registered_stage2_checksums"
  evidence <- value$status_evidence_path[[i]]
  summary <- utils::read.csv(evidence, stringsAsFactors = FALSE, check.names = FALSE)
  role[[i]] <- if ("analysis_role" %in% names(summary)) summary$analysis_role[[1]] else value$stage3_scope[[i]]
}

manifest <- data.frame(
  work_item_id = value$work_item_id,
  acquisition_rank = value$acquisition_rank,
  ds_id = value$ds_id,
  work_state = value$current_work_state,
  adapter_id = value$adapter_id,
  monitoring_network = value$monitoring_network,
  independence_unit = value$independence_unit,
  duplicate_family = value$duplicate_family,
  observation_kind = value$observation_kind,
  stage2_tier = value$provisional_tier,
  stage2_decision = value$screening_decision,
  stage2_analysis_role = role,
  stage3_scope = value$stage3_scope,
  status_evidence_path = value$status_evidence_path,
  active_pin_paths = pin_paths,
  raw_manifest_paths = manifest_paths,
  raw_manifest_state = manifest_state,
  stringsAsFactors = FALSE,
  check.names = FALSE
)
if (anyDuplicated(manifest$work_item_id) || any(!file.exists(manifest$status_evidence_path)) ||
    sum(manifest$work_state == "complete") != 16L || sum(manifest$work_state == "unavailable") != 3L ||
    !all(c("DS02", "DS03", "DS04", "DS05", "DS06", "DS07", "DS16") %in%
         manifest$ds_id[manifest$stage3_scope %in% c("primary_candidate", "primary_candidate_duplicate_audit")])) {
  stop("Generated Stage 3 manifest fails identity, evidence, or role assertions.", call. = FALSE)
}

dir.create("metadata/stage3/input", recursive = TRUE, showWarnings = FALSE)
write_csv_atomic(manifest, "metadata/stage3/input/stage3_input_manifest.csv")
checksum <- data.frame(
  path = c(status_path, "config/stage3_source_adapters.csv",
           "metadata/stage3/input/stage3_input_manifest.csv"),
  sha256 = vapply(c(status_path, "config/stage3_source_adapters.csv",
                    "metadata/stage3/input/stage3_input_manifest.csv"), calculate_checksum, character(1)),
  stringsAsFactors = FALSE
)
write_csv_atomic(checksum, "metadata/stage3/input/input_manifest_checksums.csv")
message("Generated the complete 19-item Stage 3 input manifest.")
