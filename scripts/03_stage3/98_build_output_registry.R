#!/usr/bin/env Rscript
# Register every authoritative Stage 3 generated artifact and its checksum.

source("R/00_core_setup.R")
source("R/03_stage2_contract.R")

required_paths <- c(
  "metadata/stage3/input/stage3_input_manifest.csv",
  "metadata/stage3/input/input_manifest_checksums.csv",
  "data/interim/stage3_sample_support.csv",
  "metadata/stage3/coverage/temporal_cadence_by_year.csv",
  "metadata/stage3/coverage/temporal_cadence_by_station_year.csv",
  "metadata/stage3/coverage/station_temporal_availability.csv",
  "metadata/stage3/coverage/time_of_day_coverage.csv",
  "metadata/stage3/coverage/seasonal_effort.csv",
  "metadata/stage3/coverage/spatial_support.csv",
  "metadata/stage3/coverage/vertical_support.csv",
  "metadata/stage3/method/method_biological_coverage.csv",
  "metadata/stage3/method/method_epoch_register.csv",
  "metadata/stage3/method/network_year_variable_matrix.csv",
  "metadata/stage3/gate/dataset_region_period_role_gate.csv",
  "metadata/stage3/gate/cmems_metadata_overlap.csv",
  "metadata/stage3/gate/coverage_gaps.csv",
  "metadata/stage3/gate/stage3_gate_status.csv",
  "outputs/figures/stage3_temporal_coverage.png",
  "outputs/figures/stage3_spatial_support.png"
)
cache_paths <- sort(list.files(
  "data/interim/stage3_support", pattern = "[.]csv$", full.names = TRUE
))
paths <- c(required_paths, cache_paths)
missing <- paths[!file.exists(paths)]
if (length(missing)) {
  stop(sprintf("Stage 3 output registry is missing: %s", paste(missing, collapse = ", ")),
       call. = FALSE)
}
if (length(cache_paths) != 14L || any(file.info(paths)$size <= 0)) {
  stop("Stage 3 output registry requires 14 non-empty adapter caches and all gate outputs.",
       call. = FALSE)
}

value <- data.frame(
  path = paths,
  checksum_sha256 = unname(vapply(paths, calculate_checksum, character(1))),
  size_bytes = as.numeric(file.info(paths)$size),
  artifact_class = ifelse(
    paths %in% cache_paths, "adapter_cache",
    ifelse(grepl("outputs/figures/", paths, fixed = TRUE), "figure", "authoritative_table")
  ),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
write_csv_atomic(value, "metadata/stage3/inventory/stage3_output_registry.csv")
message(sprintf("Registered %d checksummed Stage 3 outputs.", nrow(value)))
