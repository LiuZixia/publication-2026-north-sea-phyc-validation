# Inventory and record-screen the recurrent DS26 SMHI IFCB Darwin Core archive.

source("R/00_core_setup.R")
source("R/00_identifiers.R")
source("R/03_stage2_contract.R")
required_namespace("sf")

contract <- read_stage2_contract()
pin <- utils::read.csv("metadata/stage2_ds26_smhi_ifcb_active_run.csv",
                       stringsAsFactors = FALSE, check.names = FALSE)
manifest <- utils::read.csv("metadata/stage2_ds26_smhi_ifcb_acquisition_manifest.csv",
                            stringsAsFactors = FALSE, check.names = FALSE)
if (nrow(pin) != 1L || pin$work_item_id[[1]] != "REGISTER:DS26" || nrow(manifest) != 3L) {
  stop("DS26 active run or acquisition manifest is invalid.", call. = FALSE)
}
validate_stage2_table(manifest, "acquisition_manifest", contract)
run_dir <- file.path("data", "raw", pin$run_relative_path[[1]])
if (!identical(calculate_checksum(file.path(run_dir, "manifest.csv")),
               pin$manifest_checksum_sha256[[1]]) ||
    any(vapply(seq_len(nrow(manifest)), function(i) {
      !identical(calculate_checksum(file.path("data", "raw", manifest$raw_relative_path[[i]])),
                 manifest$checksum_sha256[[i]])
    }, logical(1)))) {
  stop("DS26 raw checksums do not reconcile with the active pin.", call. = FALSE)
}

archive_path <- file.path(run_dir, "shark_planktonimaging_dwca.zip")
inventory_path <- "metadata/stage2_ds26_smhi_ifcb_variable_inventory.csv"
table_summary_path <- "metadata/stage2_ds26_smhi_ifcb_table_summary.csv"
measurement_summary_path <- "metadata/stage2_ds26_smhi_ifcb_measurement_summary.csv"
event_summary_path <- "metadata/stage2_ds26_smhi_ifcb_event_summary.csv"
screening_path <- "data/interim/stage2_ds26_smhi_ifcb_record_screening.csv"
dataset_summary_path <- "metadata/stage2_ds26_smhi_ifcb_screening_summary.csv"
registry_path <- "metadata/stage2_ds26_smhi_ifcb_output_registry.csv"

if (file.exists(registry_path)) {
  registry <- utils::read.csv(registry_path, stringsAsFactors = FALSE, check.names = FALSE)
  valid <- nrow(registry) == 6L && all(file.exists(registry$path)) &&
    all(vapply(seq_len(nrow(registry)), function(i) {
      identical(calculate_checksum(registry$path[[i]]), registry$checksum_sha256[[i]])
    }, logical(1)))
  if (valid) {
    message("Verified existing DS26 inventory and screen; no rebuild required.")
    quit(save = "no", status = 0L)
  }
  stop("DS26 output registry exists but generated artifacts differ.", call. = FALSE)
}

read_member <- function(member) {
  connection <- unz(archive_path, member, open = "r", encoding = "UTF-8")
  tryCatch(utils::read.delim(connection, sep = "\t", quote = "", comment.char = "",
                             na.strings = "", stringsAsFactors = FALSE, check.names = FALSE,
                             colClasses = "character"),
           finally = close(connection))
}
events <- read_member("event.txt")
occurrences <- read_member("occurrence.txt")
measurements <- read_member("extendedmeasurementorfact.txt")
expected_rows <- c(event = 17731L, occurrence = 121103L, extendedmeasurementorfact = 1111062L)
if (!identical(c(event = nrow(events), occurrence = nrow(occurrences),
                 extendedmeasurementorfact = nrow(measurements)), expected_rows) ||
    anyDuplicated(events$id) || anyDuplicated(occurrences$occurrenceID)) {
  stop("DS26 Darwin Core table totals or provider keys are invalid.", call. = FALSE)
}
event_index <- match(occurrences$id, events$id)
if (anyNA(event_index)) stop("A DS26 occurrence lacks its Darwin Core event.", call. = FALSE)

semantic_role <- function(column_name) {
  if (column_name %in% c("id", "eventID", "parentEventID", "occurrenceID", "measurementID",
                         "locationID", "taxonID", "scientificNameID")) return("identifier")
  if (grepl("date|time|year|month|day", column_name, ignore.case = TRUE)) return("datetime")
  if (column_name %in% c("decimalLatitude", "decimalLongitude", "geodeticDatum",
                         "coordinateUncertaintyInMeters", "coordinatePrecision")) return("coordinate")
  if (grepl("depth", column_name, ignore.case = TRUE)) return("depth")
  if (column_name %in% c("scientificName", "acceptedNameUsage", "verbatimIdentification",
                         "identificationQualifier", "identificationVerificationStatus", "kingdom",
                         "phylum", "class", "order", "family", "genus", "taxonRank")) return("taxon")
  if (grepl("measurement", column_name, ignore.case = TRUE)) return("measurement")
  if (grepl("sampling|sample|preparation|identificationReferences|identifiedBy", column_name,
            ignore.case = TRUE)) return("method")
  if (grepl("license|rights|institution|dataset|recordedBy", column_name,
            ignore.case = TRUE)) return("provenance_or_context")
  "provenance_or_context"
}

inventory_rows <- list()
tables <- list(event = events, occurrence = occurrences, extendedmeasurementorfact = measurements)
raw_relative <- manifest$raw_relative_path[manifest$filename == "shark_planktonimaging_dwca.zip"]
for (table_name in names(tables)) {
  data <- tables[[table_name]]
  for (column_name in names(data)) {
    values <- data[[column_name]]
    examples <- head(unique(values[!is.na(values) & nzchar(values)]), 3L)
    reported_unit <- if (table_name == "extendedmeasurementorfact" && column_name == "measurementValue")
      paste(sort(unique(data$measurementUnit[!is.na(data$measurementUnit) &
                                               nzchar(data$measurementUnit)])), collapse = "|") else ""
    inventory_rows[[length(inventory_rows) + 1L]] <- data.frame(
      raw_relative_path = raw_relative,
      table_name = paste0(table_name, ".txt"),
      column_name = column_name,
      storage_type = "character",
      reported_unit = reported_unit,
      semantic_role = semantic_role(column_name),
      missing_value_codes = "blank",
      quality_flag_meaning = if (grepl("accuracy|verification|flag", column_name, ignore.case = TRUE))
        "Provider value retained verbatim; classifier and instrument quality fields audited separately." else "",
      example_values = paste(examples, collapse = "|"),
      inventory_state = "present",
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  }
}
inventory <- do.call(rbind, inventory_rows)
validate_stage2_table(inventory, "variable_inventory", contract)

# Exact Stage 0 point-in-polygon screening is performed once per provider event and inherited by
# its occurrence records. Missing coordinates remain invalid/unknown evidence, never negatives.
sf::sf_use_s2(FALSE)
domain <- sf::st_read("config/spatial/greater_north_sea.geojson", quiet = TRUE)
subregions <- sf::st_read("config/spatial/hydrographic_subregions.geojson", quiet = TRUE)
latitude <- suppressWarnings(as.numeric(events$decimalLatitude))
longitude <- suppressWarnings(as.numeric(events$decimalLongitude))
valid_coordinate <- is.finite(latitude) & is.finite(longitude) & latitude >= -90 & latitude <= 90 &
  longitude >= -180 & longitude <= 180
event_domain_state <- rep("invalid_coordinate", nrow(events))
event_subregion <- rep(NA_character_, nrow(events))
if (any(valid_coordinate)) {
  points <- sf::st_as_sf(data.frame(row = which(valid_coordinate), lon = longitude[valid_coordinate],
                                    lat = latitude[valid_coordinate]),
                         coords = c("lon", "lat"), crs = 4326)
  domain_hit <- lengths(suppressMessages(sf::st_intersects(points, domain, prepared = TRUE))) > 0L
  region_hit <- suppressMessages(sf::st_intersects(points[domain_hit, , drop = FALSE], subregions,
                                                    prepared = TRUE))
  region_index <- vapply(region_hit, function(value) if (length(value)) value[[1]] else NA_integer_,
                         integer(1))
  if (anyNA(region_index)) stop("An in-domain DS26 event lacks a frozen subregion.", call. = FALSE)
  valid_rows <- which(valid_coordinate)
  event_domain_state[valid_rows] <- "outside_domain"
  event_domain_state[valid_rows[domain_hit]] <- ifelse(subregions$role[region_index] == "core-domain",
                                                       "core", "external_transfer")
  event_subregion[valid_rows[domain_hit]] <- subregions$subregion_id[region_index]
}

parse_datetime <- function(date, time) {
  if (is.na(date) || !nzchar(date) || is.na(time) || !nzchar(time)) return(NA_character_)
  normalized_time <- sub("([+-][0-9]{2}):([0-9]{2})$", "\\1\\2", time)
  formats <- c("%Y-%m-%d %H:%M%z", "%Y-%m-%d %H:%M:%S%z", "%Y-%m-%d %H:%M:%OS%z")
  for (fmt in formats) {
    parsed <- suppressWarnings(as.POSIXct(paste(date, normalized_time), format = fmt, tz = "UTC"))
    if (!is.na(parsed)) return(format(parsed, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
  }
  NA_character_
}
event_datetime_utc <- mapply(parse_datetime, events$eventDate, events$eventTime,
                             USE.NAMES = FALSE)
occurrence_event <- events[event_index, , drop = FALSE]
domain_state <- event_domain_state[event_index]
subregion_id <- event_subregion[event_index]

measurement_occurrence_ids <- measurements$occurrenceID[!is.na(measurements$occurrenceID) &
                                                          nzchar(measurements$occurrenceID)]
measurement_type_lower <- tolower(measurements$measurementType)
carbon_ids <- unique(measurements$occurrenceID[measurement_type_lower == "carbon content"])
biovolume_ids <- unique(measurements$occurrenceID[measurement_type_lower == "biovolume concentration"])
abundance_ids <- unique(measurements$occurrenceID[measurement_type_lower == "abundance"])
classifier_ids <- unique(measurements$occurrenceID[measurement_type_lower %in%
                                                     c("classifier used", "classifier f1 score model accuracy")])
biomass_present <- occurrences$occurrenceID %in% union(carbon_ids, union(biovolume_ids, abundance_ids))
method_present <- occurrences$occurrenceID %in% classifier_ids |
  (!is.na(occurrences$identificationReferences) & nzchar(occurrences$identificationReferences)) |
  (!is.na(occurrences$identificationVerificationStatus) &
     nzchar(occurrences$identificationVerificationStatus))

provider_record_id <- occurrences$occurrenceID
record_id <- vapply(provider_record_id, function(value) {
  generate_source_record_id("DS26", value, collision_index = 1L)
}, character(1))
if (anyDuplicated(record_id)) stop("Stable DS26 record IDs collide.", call. = FALSE)
reported_datetime <- ifelse(!is.na(occurrence_event$eventTime) & nzchar(occurrence_event$eventTime),
                            paste(occurrence_event$eventDate, occurrence_event$eventTime),
                            occurrence_event$eventDate)
in_domain <- domain_state %in% c("core", "external_transfer")
screening <- data.frame(
  record_id = record_id,
  ds_id = "DS26",
  raw_relative_path = raw_relative,
  provider_record_id = provider_record_id,
  collision_index = 1L,
  source_row_number = seq_len(nrow(occurrences)),
  reported_datetime = reported_datetime,
  datetime_utc = event_datetime_utc[event_index],
  reported_latitude = occurrence_event$decimalLatitude,
  reported_longitude = occurrence_event$decimalLongitude,
  latitude = suppressWarnings(as.numeric(occurrence_event$decimalLatitude)),
  longitude = suppressWarnings(as.numeric(occurrence_event$decimalLongitude)),
  coordinate_crs = ifelse(valid_coordinate[event_index], "EPSG:4326", NA_character_),
  subregion_id = subregion_id,
  domain_state = domain_state,
  cmems_overlap_state = "unknown",
  repeated_sampling_state = "present",
  biomass_variable_state = ifelse(biomass_present, "present", "absent"),
  method_metadata_state = ifelse(method_present, "present", "absent"),
  license_state = "open",
  canonical_record_id = record_id,
  duplicate_resolution_state = "resolved",
  provisional_tier = ifelse(in_domain, "B", "not_applicable"),
  analysis_role = ifelse(in_domain, "lifeform_only", "excluded"),
  screening_decision = ifelse(in_domain, "secondary", "excluded"),
  exclusion_reason_code = ifelse(domain_state == "outside_domain", "outside_frozen_domain",
                                 ifelse(domain_state == "invalid_coordinate",
                                        "missing_or_invalid_coordinates", "none")),
  screening_detail = ifelse(in_domain,
    "SMHI IFCB machine-classified occurrence has provider carbon, biovolume, abundance, classifier, and method evidence where available; retained as a high-frequency lifeform/temporal benchmark, not independent total-community truth.",
    ifelse(domain_state == "outside_domain",
           "SMHI IFCB occurrence lies outside the checksum-pinned Greater North Sea polygon.",
           "SMHI IFCB occurrence lacks a valid coordinate and remains excluded rather than treated as negative.")),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
validate_stage2_table(screening, "record_screening", contract)

measurement_groups <- split(seq_len(nrow(measurements)),
                            paste(measurements$measurementType, measurements$measurementUnit,
                                  sep = "\u001f"))
measurement_summary <- do.call(rbind, lapply(measurement_groups, function(index) {
  values <- measurements$measurementValue[index]
  examples <- head(unique(values[!is.na(values) & nzchar(values)]), 3L)
  data.frame(
    measurement_type = measurements$measurementType[index[[1]]],
    measurement_unit = measurements$measurementUnit[index[[1]]],
    measurement_rows = length(index),
    linked_occurrence_rows = sum(!is.na(measurements$occurrenceID[index]) &
                                   nzchar(measurements$occurrenceID[index])),
    linked_event_rows = sum(is.na(measurements$occurrenceID[index]) |
                              !nzchar(measurements$occurrenceID[index])),
    example_values = paste(examples, collapse = "|"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}))
measurement_summary <- measurement_summary[order(measurement_summary$measurement_type,
                                                   measurement_summary$measurement_unit), , drop = FALSE]

table_summary <- data.frame(
  table_name = c("event.txt", "occurrence.txt", "extendedmeasurementorfact.txt"),
  row_count = as.integer(c(nrow(events), nrow(occurrences), nrow(measurements))),
  column_count = as.integer(c(ncol(events), ncol(occurrences), ncol(measurements))),
  key_field = c("id", "occurrenceID", "id|occurrenceID|measurementID"),
  unique_key_count = as.integer(c(length(unique(events$id)), length(unique(occurrences$occurrenceID)),
                                  length(unique(paste(measurements$id, measurements$occurrenceID,
                                                      measurements$measurementID, sep = "|"))))),
  stringsAsFactors = FALSE,
  check.names = FALSE
)

source_dataset <- sub(".*SharkDataset: ([^,]+).*", "\\1", occurrences$dynamicProperties)
source_dataset[is.na(occurrences$dynamicProperties) | !grepl("SharkDataset:", occurrences$dynamicProperties,
                                                             fixed = TRUE)] <- "unreported"
event_source <- data.frame(source_dataset = source_dataset,
                           event_id = occurrences$id,
                           event_date = occurrence_event$eventDate,
                           domain_state = domain_state,
                           has_carbon = occurrences$occurrenceID %in% carbon_ids,
                           has_biovolume = occurrences$occurrenceID %in% biovolume_ids,
                           has_abundance = occurrences$occurrenceID %in% abundance_ids,
                           stringsAsFactors = FALSE)
event_summary <- do.call(rbind, lapply(split(seq_len(nrow(event_source)), event_source$source_dataset),
                                       function(index) data.frame(
  source_dataset = event_source$source_dataset[index[[1]]],
  occurrence_rows = length(index),
  unique_events = length(unique(event_source$event_id[index])),
  earliest_date = min(event_source$event_date[index], na.rm = TRUE),
  latest_date = max(event_source$event_date[index], na.rm = TRUE),
  core_occurrence_rows = sum(event_source$domain_state[index] == "core"),
  external_transfer_occurrence_rows = sum(event_source$domain_state[index] == "external_transfer"),
  outside_domain_occurrence_rows = sum(event_source$domain_state[index] == "outside_domain"),
  invalid_coordinate_occurrence_rows = sum(event_source$domain_state[index] == "invalid_coordinate"),
  carbon_occurrence_rows = sum(event_source$has_carbon[index]),
  biovolume_occurrence_rows = sum(event_source$has_biovolume[index]),
  abundance_occurrence_rows = sum(event_source$has_abundance[index]),
  stringsAsFactors = FALSE,
  check.names = FALSE
)))
event_summary <- event_summary[order(event_summary$source_dataset), , drop = FALSE]

dataset_summary <- data.frame(
  work_item_id = "REGISTER:DS26",
  record_count = as.integer(nrow(screening)),
  core_record_count = as.integer(sum(screening$domain_state == "core")),
  external_transfer_record_count = as.integer(sum(screening$domain_state == "external_transfer")),
  cmems_overlap_record_count = 0L,
  duplicate_record_count = 0L,
  provisional_tier = "B",
  analysis_role = "lifeform_only",
  screening_decision = "secondary",
  exclusion_reason_code = "none",
  screening_detail = paste0(
    "Publisher-managed SMHI IFCB archive contains ", nrow(events) - 1L, " sampling events and ",
    nrow(occurrences), " machine-classified occurrence rows from ",
    min(occurrence_event$eventDate, na.rm = TRUE), " to ", max(occurrence_event$eventDate, na.rm = TRUE),
    ". Exact geometry retains ", sum(screening$domain_state == "core"), " core and ",
    sum(screening$domain_state == "external_transfer"), " external-transfer rows. Carbon, biovolume, ",
    "abundance, classifier identity, F1 score, trophic type, and unidentified-ROI fields are present. ",
    "Only four calendar years (2016 and 2022-2024) are represented, classifications are machine-predicted, ",
    "and the imaged size domain is incomplete for total phytoplankton; retain as a Tier B lifeform and ",
    "temporal-resolution benchmark, not an independent recurrent total-biomass reference. Exact CMEMS ",
    "overlap remains not assessed; zero denotes unknown under this secondary disposition."
  ),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
validate_stage2_table(dataset_summary, "dataset_screening_summary", contract)

dir.create("data/interim", recursive = TRUE, showWarnings = FALSE)
write_csv_atomic(inventory, inventory_path)
write_csv_atomic(table_summary, table_summary_path)
write_csv_atomic(measurement_summary, measurement_summary_path)
write_csv_atomic(event_summary, event_summary_path)
write_csv_atomic(screening, screening_path)
write_csv_atomic(dataset_summary, dataset_summary_path)
registry <- data.frame(
  artifact_role = c("variable_inventory", "table_summary", "measurement_summary", "event_summary",
                    "record_screening", "dataset_screening_summary"),
  path = c(inventory_path, table_summary_path, measurement_summary_path, event_summary_path,
           screening_path, dataset_summary_path),
  row_count = c(nrow(inventory), nrow(table_summary), nrow(measurement_summary), nrow(event_summary),
                nrow(screening), nrow(dataset_summary)),
  checksum_sha256 = vapply(c(inventory_path, table_summary_path, measurement_summary_path,
                             event_summary_path, screening_path, dataset_summary_path),
                           calculate_checksum, character(1)),
  generated_from_manifest_sha256 = pin$manifest_checksum_sha256[[1]],
  stringsAsFactors = FALSE,
  check.names = FALSE
)
write_csv_atomic(registry, registry_path)
message(sprintf("DS26 screen complete: %d occurrences; %d core, %d external-transfer, %d outside, %d invalid.",
                nrow(screening), sum(screening$domain_state == "core"),
                sum(screening$domain_state == "external_transfer"),
                sum(screening$domain_state == "outside_domain"),
                sum(screening$domain_state == "invalid_coordinate")))
