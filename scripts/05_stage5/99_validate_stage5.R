#!/usr/bin/env Rscript
# Validate Stage 5 evidence and issue a conservative gate; do not create outcomes or access PhyC.

source("R/00_core_setup.R")
source("R/03_stage2_contract.R")
source("R/07_stage5_contract.R")
required_namespace("testthat")

stage4 <- utils::read.csv("metadata/stage4/gate/stage4_gate_status.csv", stringsAsFactors = FALSE)
if (nrow(stage4) != 1L || !stage4$stage5_harmonization_authorized ||
    stage4$cmems_acquisition_authorized) {
  stop("Stage 4 does not authorize this observation-only Stage 5 run.", call. = FALSE)
}

source_state <- utils::read.csv("metadata/stage5/input/source_readiness.csv", stringsAsFactors = FALSE)
canonical <- utils::read.csv("metadata/stage5/harmonization/canonical_observation_summary.csv",
                             stringsAsFactors = FALSE)
canonical_manifest <- utils::read.csv("metadata/stage5/harmonization/canonical_partition_manifest.csv",
                                      stringsAsFactors = FALSE)
sample_summary <- utils::read.csv("metadata/stage5/harmonization/sample_method_completeness_summary.csv",
                                  stringsAsFactors = FALSE)
sample_manifest <- utils::read.csv("metadata/stage5/harmonization/sample_method_completeness_manifest.csv",
                                   stringsAsFactors = FALSE)
readiness <- utils::read.csv("metadata/stage5/harmonization/conversion_readiness_summary.csv",
                             stringsAsFactors = FALSE)
issues <- utils::read.csv("metadata/stage5/harmonization/harmonization_issues.csv",
                          stringsAsFactors = FALSE)

if (nrow(source_state) != 7L || any(source_state$checksum_state != "verified")) {
  stop("Stage 5 source readiness is incomplete or unverified.", call. = FALSE)
}
if (nrow(canonical_manifest) != 6L || any(!file.exists(canonical_manifest$path)) ||
    any(file.size(canonical_manifest$path) != canonical_manifest$file_size_bytes) ||
    !identical(unname(vapply(canonical_manifest$path, calculate_checksum, character(1))),
               canonical_manifest$checksum_sha256)) {
  stop("Canonical partition checksums or sizes do not match their manifest.", call. = FALSE)
}
if (nrow(sample_manifest) != 1L || !file.exists(sample_manifest$path) ||
    file.size(sample_manifest$path) != sample_manifest$file_size_bytes ||
    !identical(calculate_checksum(sample_manifest$path), sample_manifest$checksum_sha256)) {
  stop("Sample method/completeness table does not match its manifest.", call. = FALSE)
}

source_state$harmonization_state <- ifelse(
  source_state$ds_id == "DS22", "conversion_authority_parsed_and_audited",
  "provisional_canonical_taxonomy_audited_biomass_not_ready"
)
write_csv_atomic(source_state, "metadata/stage5/input/source_readiness.csv")

unresolved <- issues$state == "unresolved"
status <- data.frame(
  gate_state = "harmonization_in_progress_biomass_construction_blocked",
  stage5_gate_passed = FALSE, stage6_outcome_authorized = FALSE,
  cmems_acquisition_authorized = FALSE, source_inputs_verified = nrow(source_state),
  canonical_datasets = nrow(canonical), canonical_observation_rows = sum(canonical$source_rows),
  provisional_samples_audited = sum(sample_summary$samples_audited),
  accepted_taxonomy_rows = sum(readiness$rows_with_accepted_taxonomy),
  unique_conversion_authority_candidate_rows = sum(readiness$rows_with_unique_authority_row),
  abundance_rows_authorized_for_conversion = sum(readiness$rows_authorized_for_abundance_conversion),
  total_biomass_outcome_eligible_samples = sum(sample_summary$total_biomass_outcome_eligible_samples),
  lower_central_upper_reference_series_constructed = FALSE,
  unresolved_blocker_count = sum(unresolved), deterministic_metadata_checks = TRUE,
  raw_and_interim_checksum_validation = TRUE, bloom_outcomes_calculated = FALSE,
  phy_c_values_accessed = FALSE, stringsAsFactors = FALSE, check.names = FALSE
)
dir.create("metadata/stage5/gate", recursive = TRUE, showWarnings = FALSE)
write_csv_atomic(status, "metadata/stage5/gate/stage5_gate_status.csv")

test_output <- capture.output(
  testthat::test_file("tests/test_stage5_harmonization.R", reporter = "summary", stop_on_failure = TRUE),
  type = "output"
)
message(paste(c("Stage 5 partial artifacts validated; biomass construction and Stage 6 remain blocked.",
                test_output), collapse = "\n"))
