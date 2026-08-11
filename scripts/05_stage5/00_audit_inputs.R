#!/usr/bin/env Rscript
# Verify every Stage 5 source against its canonical Stage 2 pinned raw evidence.

source("R/00_core_setup.R")
source("R/03_stage2_contract.R")
source("R/07_stage5_contract.R")

verify_raw_data_target(required_gb = 0.1)
contract <- stage5_read_source_contract()
readiness_rows <- list()
artifact_rows <- list()

for (i in seq_len(nrow(contract))) {
  row <- contract[i, , drop = FALSE]
  resolved <- stage5_resolve_source(row)
  files <- resolved$files
  readiness_rows[[i]] <- data.frame(
    ds_id = row$ds_id, monitoring_network = row$monitoring_network,
    stage5_role = row$stage5_role, source_format = row$source_format,
    raw_artifact_count = nrow(files), raw_size_bytes = sum(files$file_size_bytes),
    checksum_state = "verified", provenance_state = resolved$provenance_state,
    harmonization_state = "not_yet_harmonized", stage5_action = row$stage5_action,
    phy_c_values_accessed = FALSE, stringsAsFactors = FALSE, check.names = FALSE
  )
  artifact_rows[[i]] <- data.frame(
    ds_id = row$ds_id, path = files$path, checksum_sha256 = files$checksum_sha256,
    file_size_bytes = files$file_size_bytes, source_format = row$source_format,
    stringsAsFactors = FALSE, check.names = FALSE
  )
}

readiness <- do.call(rbind, readiness_rows)
artifacts <- do.call(rbind, artifact_rows)
dir.create("metadata/stage5/input", recursive = TRUE, showWarnings = FALSE)
write_csv_atomic(readiness, "metadata/stage5/input/source_readiness.csv")
write_csv_atomic(artifacts, "metadata/stage5/input/input_artifact_manifest.csv")
message(sprintf("Stage 5 input audit verified %d datasets and %d immutable artifacts.",
                nrow(readiness), nrow(artifacts)))
