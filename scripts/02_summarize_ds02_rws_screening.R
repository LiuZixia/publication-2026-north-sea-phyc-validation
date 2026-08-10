# Create the contract-level DS02 screening disposition from verified acquisition and record audits.

source("R/00_core_setup.R")
source("R/03_stage2_contract.R")

contract <- read_stage2_contract()
packages <- utils::read.csv("metadata/stage2_ds02_rws_package_summary.csv",
                            stringsAsFactors = FALSE, check.names = FALSE)
duplicate_summary <- utils::read.csv(
  "metadata/stage2_ds02_rws_duplicate_resolution_summary.csv",
  stringsAsFactors = FALSE,
  check.names = FALSE
)
base_registry <- utils::read.csv("metadata/stage2_ds02_rws_output_registry.csv",
                                 stringsAsFactors = FALSE, check.names = FALSE)
duplicate_registry <- utils::read.csv(
  "metadata/stage2_ds02_rws_duplicate_resolution_registry.csv",
  stringsAsFactors = FALSE,
  check.names = FALSE
)

if (nrow(duplicate_summary) != 1L ||
    any(!file.exists(c(base_registry$path, duplicate_registry$path))) ||
    any(vapply(seq_len(nrow(base_registry)), function(i) {
      !identical(calculate_checksum(base_registry$path[[i]]), base_registry$checksum_sha256[[i]])
    }, logical(1))) ||
    any(vapply(seq_len(nrow(duplicate_registry)), function(i) {
      !identical(calculate_checksum(duplicate_registry$path[[i]]), duplicate_registry$checksum_sha256[[i]])
    }, logical(1)))) {
  stop("DS02 acquisition, inventory, or duplicate-resolution inputs do not reconcile.", call. = FALSE)
}

summary <- data.frame(
  work_item_id = "REGISTER:DS02",
  record_count = as.integer(sum(packages$source_rows)),
  core_record_count = as.integer(sum(packages$core_rows)),
  external_transfer_record_count = as.integer(sum(packages$external_transfer_rows)),
  cmems_overlap_record_count = 0L,
  duplicate_record_count = as.integer(duplicate_summary$duplicate_record_count[[1]]),
  provisional_tier = "A",
  analysis_role = "primary_reference",
  screening_decision = "pending",
  exclusion_reason_code = "none",
  screening_detail = paste0(
    "Manual temporal exports from RWS Waterinfo API V3 are complete and record-screened. Taxon-level biomass parameters ",
    "occur in ", sum(packages$source_rows), " rows; ", sum(packages$core_rows), " records intersect the core ",
    "region. Final inclusion remains pending until exact CMEMS product temporal coverage is frozen and ",
    "Stage 5 verifies compatible sample-level total-community construction. A zero ",
    "cmems_overlap_record_count denotes not-yet-assessed under this pending disposition, not absence."
  ),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
validate_stage2_table(summary, "dataset_screening_summary", contract)
write_csv_atomic(summary, "metadata/stage2_ds02_rws_screening_summary.csv")
message("DS02 screening summary written: provisional Tier A core reference remains pending.")
