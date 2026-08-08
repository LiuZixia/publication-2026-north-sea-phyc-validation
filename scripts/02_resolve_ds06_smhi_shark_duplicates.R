# Resolve DS06 cross-package duplicates without collapsing distinct technical or taxonomic rows.

source("R/00_core_setup.R")
source("R/00_identifiers.R")
source("R/03_stage2_contract.R")
required_namespace("digest")

contract <- read_stage2_contract()
manifest <- utils::read.csv("metadata/stage2_ds06_smhi_shark_acquisition_manifest.csv",
                            stringsAsFactors = FALSE, check.names = FALSE)
base_registry <- utils::read.csv("metadata/stage2_ds06_smhi_shark_output_registry.csv",
                                 stringsAsFactors = FALSE, check.names = FALSE)
validate_stage2_table(manifest, "acquisition_manifest", contract)
if (nrow(base_registry) != 4L || any(!file.exists(base_registry$path)) ||
    any(vapply(seq_len(nrow(base_registry)), function(i) {
      !identical(calculate_checksum(base_registry$path[[i]]), base_registry$checksum_sha256[[i]])
    }, logical(1)))) {
  stop("The DS06 base inventory registry is missing or differs from its pinned checksums.", call. = FALSE)
}

identity_path <- base_registry$path[base_registry$artifact_role == "duplicate_identity"]
screening_path <- base_registry$path[base_registry$artifact_role == "record_screening"]
summary_path <- "metadata/stage2_ds06_smhi_shark_duplicate_resolution_summary.csv"
overlap_path <- "metadata/stage2_ds06_smhi_shark_sample_overlap.csv"
duplicate_map_path <- "data/interim/stage2_ds06_smhi_shark_duplicate_map.csv"
resolved_screening_path <- "data/interim/stage2_ds06_smhi_shark_record_screening_resolved.csv"
registry_path <- "metadata/stage2_ds06_smhi_shark_duplicate_resolution_registry.csv"

# A verified registry prevents a completed duplicate audit from being silently rebuilt against
# altered base tables.
if (file.exists(registry_path)) {
  registry <- utils::read.csv(registry_path, stringsAsFactors = FALSE, check.names = FALSE)
  valid <- nrow(registry) == 4L && all(file.exists(registry$path)) &&
    all(vapply(seq_len(nrow(registry)), function(i) {
      identical(calculate_checksum(registry$path[[i]]), registry$checksum_sha256[[i]])
    }, logical(1))) && all(registry$base_screening_checksum_sha256 ==
                           base_registry$checksum_sha256[base_registry$artifact_role == "record_screening"])
  if (valid) {
    message("Verified existing DS06 duplicate resolution; no rebuild required.")
    quit(save = "no", status = 0L)
  }
  stop("DS06 duplicate-resolution registry exists but generated artifacts differ.", call. = FALSE)
}

# Only package membership and provider sample identity are needed to find possible cross-package
# copies. A shared value within one sample is not by itself duplicate evidence.
identity_membership <- utils::read.csv(
  identity_path,
  stringsAsFactors = FALSE,
  check.names = FALSE,
  colClasses = c("character", "character", "character", rep("NULL", 10L))
)
sample_package <- unique(identity_membership[c("shark_sample_id_md5", "provider_dataset_id")])
package_count <- table(sample_package$shark_sample_id_md5)
overlap_sample_ids <- names(package_count[package_count > 1L])
overlap_membership <- sample_package[sample_package$shark_sample_id_md5 %in% overlap_sample_ids, , drop = FALSE]
if (any(!nzchar(overlap_sample_ids)) || anyDuplicated(overlap_membership) ||
    any(!overlap_membership$provider_dataset_id %in% manifest$provider_dataset_id)) {
  stop("DS06 cross-package sample membership is invalid.", call. = FALSE)
}

read_shark_data <- function(zip_path) {
  connection <- unz(zip_path, "shark_data.txt", open = "rb")
  raw_text <- tryCatch(readBin(connection, what = "raw", n = 2^31 - 1L),
                       finally = close(connection))
  utf8_text <- iconv(rawToChar(raw_text), from = "latin1", to = "UTF-8")
  if (is.na(utf8_text)) stop(sprintf("Unable to convert SHARK source text: %s", zip_path), call. = FALSE)
  text_connection <- textConnection(utf8_text, open = "r", local = TRUE)
  tryCatch(utils::read.delim(text_connection, sep = "\t", quote = "", comment.char = "",
                             na.strings = "", stringsAsFactors = FALSE, check.names = FALSE),
           finally = close(text_connection))
}

# Re-read only packages containing a shared provider sample ID. Exact duplicate fingerprints use
# every common source field except package identity, row position, and access URL. This is stricter
# than matching taxon, value, and unit and therefore preserves size classes and technical rows.
candidate_tables <- list()
for (provider_dataset_id in unique(overlap_membership$provider_dataset_id)) {
  i <- match(provider_dataset_id, manifest$provider_dataset_id)
  zip_path <- file.path("data", "raw", manifest$raw_relative_path[[i]])
  if (!identical(calculate_checksum(zip_path), manifest$checksum_sha256[[i]])) {
    stop(sprintf("Raw checksum failed during DS06 duplicate audit: %s", zip_path), call. = FALSE)
  }
  data <- read_shark_data(zip_path)
  raw_names <- names(data)
  if (!"row_number" %in% raw_names) data$row_number <- seq_len(nrow(data))
  keep <- data$shark_sample_id_md5 %in% overlap_sample_ids
  data <- data[keep, , drop = FALSE]
  data$provider_dataset_id_audit <- provider_dataset_id
  candidate_tables[[provider_dataset_id]] <- data
}
common_fields <- Reduce(intersect, lapply(candidate_tables, names))
fingerprint_fields <- c(
  "shark_sample_id_md5", "sample_date", "sample_time", "sample_latitude_dd",
  "sample_longitude_dd", "sample_min_depth_m", "sample_max_depth_m",
  "sampling_laboratory_name_en", "sampler_type_code", "sampled_volume_l",
  "plankton_sampling_method_code", "sample_part_id", "scientific_name",
  "species_flag_code", "dyntaxa_id", "aphia_id", "parameter", "value", "unit",
  "quality_flag", "calc_by_dc", "trophic_type_code", "size_class",
  "size_class_ref_list_code", "size_min_um", "size_max_um", "reported_cell_volume_um3",
  "taxonomist", "analysis_method_code", "counter_program", "method_documentation",
  "method_reference_code", "method_comment", "variable_comment",
  "analytical_laboratory_name_en", "analysis_date", "preservation_method_code",
  "mesh_size_um", "sedimentation_volume_ml", "sedimentation_time_h", "coefficient",
  "magnification", "replicate_no", "bvol_scientific_name", "bvol_size_class",
  "bvol_ref_list", "bvol_aphia_id", "reported_scientific_name", "reported_parameter",
  "reported_value", "reported_unit"
)
if (!all(fingerprint_fields %in% common_fields)) {
  stop("DS06 duplicate fingerprint lacks the expected common scientific fields.", call. = FALSE)
}
normalize_field <- function(value) {
  value <- trimws(as.character(value))
  value[is.na(value) | !nzchar(value)] <- "<NA>"
  value
}
candidate_rows <- list()
for (provider_dataset_id in names(candidate_tables)) {
  data <- candidate_tables[[provider_dataset_id]]
  normalized <- lapply(data[fingerprint_fields], normalize_field)
  record_text <- do.call(paste, c(normalized, sep = "\u001f"))
  fingerprint <- vapply(record_text, digest::digest, character(1),
                        algo = "sha256", serialize = FALSE)
  provider_record_id <- paste(provider_dataset_id, data$row_number, sep = ":")
  candidate_rows[[provider_dataset_id]] <- data.frame(
    record_id = vapply(provider_record_id, function(value) {
      generate_source_record_id("DS06", value, collision_index = 1L)
    }, character(1)),
    provider_dataset_id = provider_dataset_id,
    shark_sample_id_md5 = as.character(data$shark_sample_id_md5),
    source_row_number = as.integer(data$row_number),
    scientific_fingerprint_sha256 = fingerprint,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}
candidates <- do.call(rbind, candidate_rows)
if (anyDuplicated(candidates$record_id)) stop("Duplicate-audit candidate record IDs are not unique.", call. = FALSE)

fingerprint_packages <- tapply(candidates$provider_dataset_id,
                               candidates$scientific_fingerprint_sha256,
                               function(value) length(unique(value)))
duplicate_fingerprints <- names(fingerprint_packages[fingerprint_packages > 1L])
duplicates <- candidates[candidates$scientific_fingerprint_sha256 %in% duplicate_fingerprints, , drop = FALSE]

# All packages are the same provider release. Prefer the package containing the more complete
# representation of that shared sample, then provider ID and source row as deterministic ties.
sample_package_rows <- aggregate(record_id ~ shark_sample_id_md5 + provider_dataset_id,
                                 candidates, length)
names(sample_package_rows)[[3]] <- "sample_package_record_count"
duplicates <- merge(duplicates, sample_package_rows,
                    by = c("shark_sample_id_md5", "provider_dataset_id"), sort = FALSE)
duplicates <- duplicates[order(duplicates$scientific_fingerprint_sha256,
                               -duplicates$sample_package_record_count,
                               duplicates$provider_dataset_id,
                               duplicates$source_row_number), , drop = FALSE]
canonical_by_fingerprint <- duplicates$record_id[!duplicated(duplicates$scientific_fingerprint_sha256)]
names(canonical_by_fingerprint) <- duplicates$scientific_fingerprint_sha256[
  !duplicated(duplicates$scientific_fingerprint_sha256)
]
duplicates$canonical_record_id <- unname(canonical_by_fingerprint[
  duplicates$scientific_fingerprint_sha256
])
duplicate_map <- duplicates[duplicates$record_id != duplicates$canonical_record_id,
                            c("record_id", "canonical_record_id"), drop = FALSE]
duplicate_map$relationship <- rep("same_record", nrow(duplicate_map))
duplicate_map$evidence_fields <- rep(paste(fingerprint_fields, collapse = "|"), nrow(duplicate_map))
duplicate_map$resolution_state <- rep("resolved", nrow(duplicate_map))
duplicate_map$resolution_detail <- rep(paste0(
  "The same SHARK sample ID and SHA-256 fingerprint across all ", length(fingerprint_fields),
  " prespecified sample, taxon, size-class, measurement, method, and reported-value fields occurs ",
  "in more than one canonical-provider package; the package with the most rows for that sample is ",
  "canonical, with provider ID and source row as ties."
), nrow(duplicate_map))
validate_stage2_table(duplicate_map, "duplicate_map", contract)

overlap <- merge(overlap_membership, sample_package_rows,
                 by = c("shark_sample_id_md5", "provider_dataset_id"), sort = TRUE)
overlap$exact_cross_package_duplicate_rows <- vapply(seq_len(nrow(overlap)), function(i) {
  sum(duplicates$shark_sample_id_md5 == overlap$shark_sample_id_md5[[i]] &
      duplicates$provider_dataset_id == overlap$provider_dataset_id[[i]])
}, integer(1))
overlap$scientific_fingerprint_field_count <- length(fingerprint_fields)

# The resolved table is a new intermediate: the checksum-pinned base screen remains immutable.
screening <- utils::read.csv(
  screening_path,
  stringsAsFactors = FALSE,
  check.names = FALSE,
  colClasses = c(reported_latitude = "character", reported_longitude = "character",
                 canonical_record_id = "character")
)
validate_stage2_table(screening, "record_screening", contract)
if (anyDuplicated(screening$record_id) || nrow(screening) != nrow(identity_membership)) {
  stop("DS06 base screening IDs or row totals do not reconcile.", call. = FALSE)
}
screening$canonical_record_id <- screening$record_id
screening$duplicate_resolution_state <- "resolved"
duplicate_index <- match(screening$record_id, duplicate_map$record_id)
is_duplicate <- !is.na(duplicate_index)
screening$canonical_record_id[is_duplicate] <- duplicate_map$canonical_record_id[duplicate_index[is_duplicate]]
in_domain_duplicate <- is_duplicate & screening$domain_state != "outside_domain"
screening$provisional_tier[in_domain_duplicate] <- "not_applicable"
screening$analysis_role[in_domain_duplicate] <- "excluded"
screening$screening_decision[in_domain_duplicate] <- "excluded"
screening$exclusion_reason_code[in_domain_duplicate] <- "other_prespecified"
screening$screening_detail[in_domain_duplicate] <- paste0(
  "Exact cross-package canonical-provider duplicate; retained for provenance and mapped to ",
  screening$canonical_record_id[in_domain_duplicate], "."
)
validate_stage2_table(screening, "record_screening", contract)

summary <- data.frame(
  work_item_id = "REGISTER:DS06",
  source_record_count = nrow(screening),
  unique_provider_sample_count = length(unique(identity_membership$shark_sample_id_md5)),
  cross_package_sample_count = length(overlap_sample_ids),
  cross_package_sample_membership_count = nrow(overlap),
  scientific_fingerprint_field_count = length(fingerprint_fields),
  exact_duplicate_fingerprint_count = length(duplicate_fingerprints),
  duplicate_record_count = nrow(duplicate_map),
  base_screening_checksum_sha256 = calculate_checksum(screening_path),
  duplicate_identity_checksum_sha256 = calculate_checksum(identity_path),
  resolution_rule = paste0(
    "Only records sharing provider sample identity across packages can match; exact SHA-256 over all common scientific fields is required. ",
    "The most complete same-sample package is canonical; provider ID and source row break ties."
  ),
  stringsAsFactors = FALSE,
  check.names = FALSE
)

write_csv_atomic(overlap, overlap_path)
write_csv_atomic(duplicate_map, duplicate_map_path)
write_csv_atomic(screening, resolved_screening_path)
write_csv_atomic(summary, summary_path)
registry <- data.frame(
  artifact_role = c("sample_overlap", "duplicate_map", "resolved_record_screening",
                    "duplicate_resolution_summary"),
  path = c(overlap_path, duplicate_map_path, resolved_screening_path, summary_path),
  row_count = c(nrow(overlap), nrow(duplicate_map), nrow(screening), nrow(summary)),
  checksum_sha256 = vapply(c(overlap_path, duplicate_map_path, resolved_screening_path, summary_path),
                           calculate_checksum, character(1)),
  base_screening_checksum_sha256 = calculate_checksum(screening_path),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
write_csv_atomic(registry, registry_path)
message(sprintf(
  "DS06 duplicate audit complete: %d shared samples, %d exact fingerprints, %d redundant records.",
  length(overlap_sample_ids), length(duplicate_fingerprints), nrow(duplicate_map)
))
