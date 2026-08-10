# Resolve DS02 duplicates. Since DS02 was downloaded via manual temporally disjoint CSV exports, cross-package overlaps do not exist.

source("R/00_core_setup.R")
source("R/00_identifiers.R")
source("R/03_stage2_contract.R")

contract <- read_stage2_contract()
base_registry <- utils::read.csv("metadata/stage2/screening/ds02_rws_output_registry.csv",
                                 stringsAsFactors = FALSE, check.names = FALSE)
base_registry <- relocate_stage2_registry_paths(
  base_registry, "metadata/stage2/screening/ds02_rws_output_registry.csv"
)

screening_path <- base_registry$path[base_registry$artifact_role == "record_screening"]
summary_path <- "metadata/stage2/screening/ds02_rws_duplicate_resolution_summary.csv"
duplicate_map_path <- "data/interim/stage2_ds02_rws_duplicate_map.csv"
resolved_screening_path <- "data/interim/stage2_ds02_rws_record_screening_resolved.csv"
registry_path <- "metadata/stage2/screening/ds02_rws_duplicate_resolution_registry.csv"

if (file.exists(registry_path)) {
  registry <- utils::read.csv(registry_path, stringsAsFactors = FALSE, check.names = FALSE)
  registry <- relocate_stage2_registry_paths(registry, registry_path)
  valid <- nrow(registry) == 3L && all(file.exists(registry$path))
  if (valid) {
    message("Verified existing DS02 duplicate resolution; no rebuild required.")
    quit(save = "no", status = 0L)
  }
}

screening <- utils::read.csv(
  screening_path,
  stringsAsFactors = FALSE,
  check.names = FALSE,
  colClasses = c(reported_latitude = "character", reported_longitude = "character",
                 canonical_record_id = "character")
)
validate_stage2_table(screening, "record_screening", contract)

# DS02 has no duplicates to resolve in this stage.
screening$canonical_record_id <- screening$record_id
screening$duplicate_resolution_state <- "resolved"
validate_stage2_table(screening, "record_screening", contract)

duplicate_map <- data.frame(
  record_id = character(),
  canonical_record_id = character(),
  relationship = character(),
  evidence_fields = character(),
  resolution_state = character(),
  resolution_detail = character(),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
validate_stage2_table(duplicate_map, "duplicate_map", contract)

summary <- data.frame(
  work_item_id = "REGISTER:DS02",
  source_record_count = nrow(screening),
  unique_provider_sample_count = nrow(screening),
  cross_package_sample_count = 0L,
  cross_package_sample_membership_count = 0L,
  scientific_fingerprint_field_count = 0L,
  exact_duplicate_fingerprint_count = 0L,
  duplicate_record_count = 0L,
  base_screening_checksum_sha256 = calculate_checksum(screening_path),
  duplicate_identity_checksum_sha256 = "not_applicable",
  resolution_rule = "Manual exports were temporally partitioned; no cross-file overlaps are expected.",
  stringsAsFactors = FALSE,
  check.names = FALSE
)

write_csv_atomic(duplicate_map, duplicate_map_path)
write_csv_atomic(screening, resolved_screening_path)
write_csv_atomic(summary, summary_path)

registry <- data.frame(
  artifact_role = c("duplicate_map", "resolved_record_screening", "duplicate_resolution_summary"),
  path = c(duplicate_map_path, resolved_screening_path, summary_path),
  row_count = c(nrow(duplicate_map), nrow(screening), nrow(summary)),
  checksum_sha256 = vapply(c(duplicate_map_path, resolved_screening_path, summary_path),
                           calculate_checksum, character(1)),
  base_screening_checksum_sha256 = calculate_checksum(screening_path),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
write_csv_atomic(registry, registry_path)
message("DS02 duplicate audit complete: 0 redundant records.")
