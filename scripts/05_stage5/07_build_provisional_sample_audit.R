#!/usr/bin/env Rscript
# Build a sample-level compatibility audit without constructing biomass before the Stage 5 gate.

source("R/00_core_setup.R")
source("R/03_stage2_contract.R")
source("R/07_stage5_contract.R")

manifest_path <- "metadata/stage5/harmonization/canonical_partition_manifest.csv"
if (!file.exists(manifest_path)) stop("Canonical partition manifest is missing.", call. = FALSE)
manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE, check.names = FALSE)
if (nrow(manifest) != 6L || any(!file.exists(manifest$path))) {
  stop("Canonical Stage 5 partitions are incomplete.", call. = FALSE)
}

parts <- list(); part_index <- 0L
safe_min <- function(value) {
  value <- suppressWarnings(as.numeric(value)); value <- value[is.finite(value)]
  if (length(value)) min(value) else NA_real_
}
safe_max <- function(value) {
  value <- suppressWarnings(as.numeric(value)); value <- value[is.finite(value)]
  if (length(value)) max(value) else NA_real_
}

for (partition in manifest$path) {
  stage5_stream_csv(partition, function(chunk, row_number) {
    required <- c("ds_id", "monitoring_network", "sample_id", "datetime_utc", "subregion_id",
                  "depth_min_m", "depth_max_m", "harmonized_measurement", "sampling_method",
                  "analysis_method", "screening_decision")
    if (!all(required %in% names(chunk))) stop("Canonical sample-audit schema changed.", call. = FALSE)
    chunk$sample_id <- as.character(chunk$sample_id)
    chunk$sample_id[is.na(chunk$sample_id) | !nzchar(chunk$sample_id)] <-
      paste0("missing_sample_id_row_", row_number[is.na(chunk$sample_id) | !nzchar(chunk$sample_id)])
    key <- paste(chunk$ds_id, chunk$sample_id, sep = "\034")
    groups <- split(seq_len(nrow(chunk)), key)
    rows <- lapply(groups, function(index) {
      first <- index[[1]]
      measurement <- chunk$harmonized_measurement[index]
      sampling <- as.character(chunk$sampling_method[index]); sampling[is.na(sampling)] <- ""
      analysis <- as.character(chunk$analysis_method[index]); analysis[is.na(analysis)] <- ""
      data.frame(
        sample_key = key[[first]], ds_id = chunk$ds_id[[first]],
        monitoring_network = chunk$monitoring_network[[first]], sample_id = chunk$sample_id[[first]],
        datetime_utc = chunk$datetime_utc[[first]], subregion_id = chunk$subregion_id[[first]],
        depth_min_m = safe_min(chunk$depth_min_m[index]), depth_max_m = safe_max(chunk$depth_max_m[index]),
        reported_record_count = length(index),
        provider_carbon_record_count = sum(measurement == "carbon_concentration", na.rm = TRUE),
        provider_biovolume_record_count = sum(measurement == "biovolume_concentration", na.rm = TRUE),
        abundance_or_count_record_count = sum(measurement %in%
                                                c("abundance", "reported_count_or_percentage"), na.rm = TRUE),
        method_fields_present = any(nzchar(sampling) | nzchar(analysis)),
        in_frozen_subregion = any(chunk$subregion_id[index] %in%
                                    c("southern_and_central_north_sea", "skagerrak_kattegat")),
        stringsAsFactors = FALSE, check.names = FALSE
      )
    })
    part_index <<- part_index + 1L
    parts[[part_index]] <<- do.call(rbind, rows)
  }, chunk_lines = 10000L)
}

chunk_summary <- do.call(rbind, parts)
groups <- split(seq_len(nrow(chunk_summary)), chunk_summary$sample_key, drop = TRUE)
groups <- groups[lengths(groups) > 0L]
sample <- do.call(rbind, lapply(groups, function(index) {
  first <- index[[1]]
  x <- chunk_summary[index, , drop = FALSE]
  data.frame(
    ds_id = x$ds_id[[1]], monitoring_network = x$monitoring_network[[1]],
    sample_id = x$sample_id[[1]], datetime_utc = x$datetime_utc[[1]],
    subregion_id = x$subregion_id[[1]], depth_min_m = safe_min(x$depth_min_m),
    depth_max_m = safe_max(x$depth_max_m), reported_record_count = sum(x$reported_record_count),
    provider_carbon_record_count = sum(x$provider_carbon_record_count),
    provider_biovolume_record_count = sum(x$provider_biovolume_record_count),
    abundance_or_count_record_count = sum(x$abundance_or_count_record_count),
    sampling_method = "", analysis_method = "", method_epoch = "unresolved_not_yet_joined",
    method_compatibility_state = if (any(x$method_fields_present))
      "reported_fields_present_not_yet_epoch_classified" else "provider_method_fields_not_yet_joined",
    accepted_taxon_fraction = NA_real_, converted_taxon_fraction = NA_real_,
    unresolved_biomass_risk = "unknown", observed_size_domain = "unknown",
    total_phyto_carbon_lower_ug_l = NA_real_, total_phyto_carbon_central_ug_l = NA_real_,
    total_phyto_carbon_upper_ug_l = NA_real_, completeness_class = "unknown",
    total_biomass_outcome_eligible = FALSE,
    reference_route_candidate = if (sum(x$provider_carbon_record_count) > 0L) "provider_carbon_candidate" else
      if (sum(x$provider_biovolume_record_count) > 0L) "provider_biovolume_candidate" else
        "abundance_conversion_candidate",
    audit_state = "provisional_no_biomass_constructed",
    in_frozen_subregion = any(x$in_frozen_subregion), stringsAsFactors = FALSE, check.names = FALSE
  )
}))
row.names(sample) <- NULL

output <- "data/interim/stage5/sample_method_completeness.csv"
dir.create(dirname(output), recursive = TRUE, showWarnings = FALSE)
write_csv_atomic(sample, output)
summary <- do.call(rbind, lapply(split(sample, sample$ds_id), function(x) data.frame(
  ds_id = x$ds_id[[1]], monitoring_network = x$monitoring_network[[1]], samples_audited = nrow(x),
  samples_in_frozen_subregions = sum(x$in_frozen_subregion),
  provider_carbon_candidate_samples = sum(x$reference_route_candidate == "provider_carbon_candidate"),
  provider_biovolume_candidate_samples = sum(x$reference_route_candidate == "provider_biovolume_candidate"),
  abundance_conversion_candidate_samples = sum(x$reference_route_candidate == "abundance_conversion_candidate"),
  samples_with_resolved_method_epoch = sum(x$method_epoch != "unresolved_not_yet_joined"),
  total_biomass_outcome_eligible_samples = sum(x$total_biomass_outcome_eligible),
  audit_state = "provisional_no_biomass_constructed", stringsAsFactors = FALSE, check.names = FALSE
)))
row.names(summary) <- NULL
sample_manifest <- data.frame(
  path = output, row_count = nrow(sample), file_size_bytes = unname(file.size(output)),
  checksum_sha256 = calculate_checksum(output), row_unit = "provider_defined_sample",
  table_state = "provisional_method_and_completeness_unknown", stringsAsFactors = FALSE,
  check.names = FALSE
)
write_csv_atomic(summary, "metadata/stage5/harmonization/sample_method_completeness_summary.csv")
write_csv_atomic(sample_manifest, "metadata/stage5/harmonization/sample_method_completeness_manifest.csv")
message(sprintf("Audited %d provisional samples; zero authorized for total-biomass outcomes.", nrow(sample)))
