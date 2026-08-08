# Create the contract-level DS06 screening disposition from verified acquisition and record audits.

source("R/00_core_setup.R")
source("R/03_stage2_contract.R")

contract <- read_stage2_contract()
manifest <- utils::read.csv("metadata/stage2_ds06_smhi_shark_acquisition_manifest.csv",
                            stringsAsFactors = FALSE, check.names = FALSE)
packages <- utils::read.csv("metadata/stage2_ds06_smhi_shark_package_summary.csv",
                            stringsAsFactors = FALSE, check.names = FALSE)
duplicate_summary <- utils::read.csv(
  "metadata/stage2_ds06_smhi_shark_duplicate_resolution_summary.csv",
  stringsAsFactors = FALSE,
  check.names = FALSE
)
base_registry <- utils::read.csv("metadata/stage2_ds06_smhi_shark_output_registry.csv",
                                 stringsAsFactors = FALSE, check.names = FALSE)
duplicate_registry <- utils::read.csv(
  "metadata/stage2_ds06_smhi_shark_duplicate_resolution_registry.csv",
  stringsAsFactors = FALSE,
  check.names = FALSE
)
validate_stage2_table(manifest, "acquisition_manifest", contract)
if (nrow(manifest) != nrow(packages) || nrow(duplicate_summary) != 1L ||
    any(!file.exists(c(base_registry$path, duplicate_registry$path))) ||
    any(vapply(seq_len(nrow(base_registry)), function(i) {
      !identical(calculate_checksum(base_registry$path[[i]]), base_registry$checksum_sha256[[i]])
    }, logical(1))) ||
    any(vapply(seq_len(nrow(duplicate_registry)), function(i) {
      !identical(calculate_checksum(duplicate_registry$path[[i]]), duplicate_registry$checksum_sha256[[i]])
    }, logical(1)))) {
  stop("DS06 acquisition, inventory, or duplicate-resolution inputs do not reconcile.", call. = FALSE)
}

# Tier A is provisional because canonical SHARK supplies taxon-level carbon concentration directly.
# Final eligibility still requires the exact CMEMS product-era audit and Stage 5 sample-compatibility,
# total-community, and method-epoch checks; the dataset therefore remains pending at Stage 2.
summary <- data.frame(
  work_item_id = "REGISTER:DS06",
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
    "Canonical CC0 SHARK acquisition is complete and record-screened. Taxon-level carbon ",
    "concentration occurs in ", sum(packages$carbon_rows), " rows and biovolume concentration in ",
    sum(packages$biovolume_rows), " rows; ", sum(packages$core_rows), " records intersect the core ",
    "and ", sum(packages$external_transfer_rows), " the prespecified external-transfer region. ",
    "Final inclusion remains pending until the exact CMEMS product temporal coverage is frozen and ",
    "Stage 5 verifies compatible sample-level total-community construction and method epochs. A zero ",
    "cmems_overlap_record_count denotes not-yet-assessed under this pending disposition, not absence."
  ),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
validate_stage2_table(summary, "dataset_screening_summary", contract)
write_csv_atomic(summary, "metadata/stage2_ds06_smhi_shark_screening_summary.csv")
message("DS06 screening summary written: provisional Tier A external-transfer reference remains pending.")
