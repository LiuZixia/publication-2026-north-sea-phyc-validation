# Inventory and record-screen the existing public DS12 CPR Darwin Core Archive.
#
# The archive includes zooplankton as well as phytoplankton. Stage 2 therefore screens its sampling
# events and preserves linked PCI/taxon evidence without treating every occurrence as phytoplankton
# or total biomass. Taxonomic qualification belongs to Stage 5.

source("R/00_core_setup.R")
source("R/00_identifiers.R")
source("R/03_stage2_contract.R")
required_namespace("sf")

main <- function() {
  contract <- read_stage2_contract()
  pin_path <- "metadata/stage2/acquisition/ds12_dassh_ipt_active_run.csv"
  pin <- utils::read.csv(pin_path, stringsAsFactors = FALSE, check.names = FALSE)
  if (nrow(pin) != 1L || pin$work_item_id[[1]] != "REGISTER:DS12") {
    stop("DS12 active-run pin is invalid.", call. = FALSE)
  }

  run_dir <- file.path("data", "raw", pin$run_relative_path[[1]])
  manifest_path <- file.path(run_dir, "manifest.csv")
  if (!file.exists(manifest_path) ||
      calculate_checksum(manifest_path) != pin$manifest_checksum_sha256[[1]]) {
    stop("DS12 manifest checksum does not reconcile with the active pin.", call. = FALSE)
  }
  manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE, check.names = FALSE)
  if (nrow(manifest) != 1L) stop("DS12 manifest must contain one DwC-A.", call. = FALSE)
  archive_path <- file.path(run_dir, manifest$file_name[[1]])
  if (!file.exists(archive_path) || file.size(archive_path) != manifest$file_size_bytes[[1]] ||
      calculate_checksum(archive_path) != manifest$checksum_sha256[[1]]) {
    stop("DS12 archive failed checksum or size validation.", call. = FALSE)
  }

  members <- utils::unzip(archive_path, list = TRUE)$Name
  required_members <- c("event.txt", "occurrence.txt", "extendedmeasurementorfact.txt",
                        "meta.xml", "eml.xml")
  if (!all(required_members %in% members)) {
    stop("DS12 DwC-A lacks a required core, extension, or metadata file.", call. = FALSE)
  }

  # Extract only to a disposable directory; immutable raw evidence remains unchanged.
  extract_dir <- tempfile("ds12_cpr_")
  dir.create(extract_dir, recursive = TRUE)
  on.exit(unlink(extract_dir, recursive = TRUE, force = TRUE), add = TRUE)
  utils::unzip(archive_path, files = required_members, exdir = extract_dir)

  event_path <- file.path(extract_dir, "event.txt")
  occurrence_path <- file.path(extract_dir, "occurrence.txt")
  measurement_path <- file.path(extract_dir, "extendedmeasurementorfact.txt")

  event <- utils::read.delim(event_path, stringsAsFactors = FALSE, quote = "", sep = "\t",
                             check.names = FALSE)
  required_event <- c("id", "license", "eventID", "sampleSizeValue", "sampleSizeUnit",
                      "eventDate", "minimumDepthInMeters", "maximumDepthInMeters",
                      "decimalLatitude", "decimalLongitude", "geodeticDatum")
  if (!all(required_event %in% names(event)) || anyDuplicated(event$id)) {
    stop("DS12 event core lacks required fields or has duplicate event IDs.", call. = FALSE)
  }

  # Read only the occurrence fields needed for linkage and taxon inventory. The archive's internal
  # taxon IDs and reported names are preserved; no lifeform inference is made here.
  occurrence_classes <- rep("NULL", 13L)
  occurrence_classes[c(1L, 4L, 6L, 10L, 11L, 13L)] <- "character"
  occurrence <- utils::read.delim(
    occurrence_path, stringsAsFactors = FALSE, quote = "", sep = "\t",
    check.names = FALSE, colClasses = occurrence_classes
  )
  required_occurrence <- c("id", "occurrenceID", "individualCount", "eventID", "taxonID",
                           "scientificName")
  if (!identical(names(occurrence), required_occurrence)) {
    stop("DS12 selected occurrence fields differ from the expected provider schema.", call. = FALSE)
  }

  # Retain the provider measurement type, value, and unit so PCI support can be distinguished from
  # taxon counts. Empty occurrenceID is expected for event-level PCI measurements.
  measurement_classes <- rep("NULL", 9L)
  measurement_classes[c(1L, 3L, 4L, 6L, 8L)] <- "character"
  measurement <- utils::read.delim(
    measurement_path, stringsAsFactors = FALSE, quote = "", sep = "\t",
    check.names = FALSE, colClasses = measurement_classes
  )
  required_measurement <- c("id", "occurrenceID", "measurementType", "measurementValue",
                            "measurementUnit")
  if (!identical(names(measurement), required_measurement)) {
    stop("DS12 selected measurement fields differ from the expected provider schema.", call. = FALSE)
  }

  # Build a schema inventory from provider headers and representative values. A declared column is
  # present even if the representative values are blank; missingness is carried separately.
  sample_table <- function(path) {
    utils::read.delim(path, stringsAsFactors = FALSE, quote = "", sep = "\t",
                      check.names = FALSE, nrows = 1000L, colClasses = "character")
  }
  samples <- list(
    event.txt = sample_table(event_path),
    occurrence.txt = sample_table(occurrence_path),
    extendedmeasurementorfact.txt = sample_table(measurement_path)
  )
  semantic_role <- function(table_name, column_name) {
    if (column_name %in% c("id", "eventID", "occurrenceID", "catalogNumber", "taxonID",
                           "scientificNameID", "measurementID", "datasetID", "fieldNumber")) {
      return("identifier")
    }
    if (column_name %in% c("decimalLatitude", "decimalLongitude", "geodeticDatum")) return("coordinate")
    if (column_name == "eventDate") return("time")
    if (column_name %in% c("scientificName")) return("taxon_name")
    if (column_name %in% c("individualCount")) return("abundance_or_count")
    if (column_name %in% c("measurementType")) return("variable_name")
    if (column_name %in% c("measurementValue")) return("measurement_value")
    if (column_name %in% c("measurementUnit", "sampleSizeUnit")) return("measurement_unit")
    if (column_name %in% c("sampleSizeValue")) return("sampling_effort")
    if (column_name %in% c("minimumDepthInMeters", "maximumDepthInMeters")) return("depth")
    if (column_name %in% c("license", "rightsHolder")) return("licence_or_rights")
    if (grepl("quality|flag", column_name, ignore.case = TRUE)) return("quality_flag")
    "provenance_or_context"
  }
  inventory_rows <- lapply(names(samples), function(table_name) {
    tab <- samples[[table_name]]
    do.call(rbind, lapply(names(tab), function(column_name) {
      values <- unique(tab[[column_name]][!is.na(tab[[column_name]]) & nzchar(tab[[column_name]])])
      data.frame(
        raw_relative_path = file.path(pin$run_relative_path[[1]], manifest$file_name[[1]]),
        table_name = table_name,
        column_name = column_name,
        storage_type = "character",
        reported_unit = ifelse(column_name %in% c("minimumDepthInMeters", "maximumDepthInMeters"),
                               "m", ""),
        semantic_role = semantic_role(table_name, column_name),
        missing_value_codes = "blank",
        quality_flag_meaning = "not_reported",
        example_values = paste(utils::head(values, 3L), collapse = "|"),
        inventory_state = "present",
        stringsAsFactors = FALSE,
        check.names = FALSE
      )
    }))
  })
  variable_inventory <- do.call(rbind, inventory_rows)
  validate_stage2_table(variable_inventory, "variable_inventory", contract)

  # Parse provider offsets to UTC without claiming more precision than the reported timestamp.
  reported_datetime <- event$eventDate
  datetime_for_parse <- ifelse(grepl("[+-][0-9]{2}$", reported_datetime),
                               paste0(reported_datetime, "00"), reported_datetime)
  parsed_datetime <- as.POSIXct(datetime_for_parse, format = "%Y-%m-%d %H:%M:%S%z", tz = "UTC")
  datetime_utc <- ifelse(
    is.na(parsed_datetime), "", format(parsed_datetime, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  )
  latitude <- suppressWarnings(as.numeric(event$decimalLatitude))
  longitude <- suppressWarnings(as.numeric(event$decimalLongitude))
  valid_coordinate <- is.finite(latitude) & is.finite(longitude) & latitude >= -90 & latitude <= 90 &
    longitude >= -180 & longitude <= 180

  domain_state <- rep("invalid_coordinate", nrow(event))
  subregion_id <- rep("", nrow(event))
  sf::sf_use_s2(FALSE)
  domain <- sf::st_read("config/spatial/greater_north_sea.geojson", quiet = TRUE)
  subregions <- sf::st_read("config/spatial/hydrographic_subregions.geojson", quiet = TRUE)
  points <- sf::st_as_sf(
    data.frame(row = which(valid_coordinate), longitude = longitude[valid_coordinate],
               latitude = latitude[valid_coordinate]),
    coords = c("longitude", "latitude"), crs = 4326
  )
  in_domain <- lengths(suppressMessages(sf::st_intersects(points, domain, prepared = TRUE))) > 0L
  domain_state[points$row] <- "outside_domain"
  if (any(in_domain)) {
    hits <- suppressMessages(sf::st_intersects(points[in_domain, , drop = FALSE], subregions,
                                               prepared = TRUE))
    region_index <- vapply(hits, function(value) if (length(value)) value[[1]] else NA_integer_, integer(1))
    if (anyNA(region_index)) stop("An in-domain DS12 event lacks a frozen subregion.", call. = FALSE)
    selected <- points$row[in_domain]
    domain_state[selected] <- ifelse(subregions$role[region_index] == "core-domain",
                                     "core", "external_transfer")
    subregion_id[selected] <- subregions$subregion_id[region_index]
  }

  occurrence_count <- as.integer(table(factor(occurrence$id, levels = event$id)))
  pci <- measurement[toupper(trimws(measurement$measurementType)) == "PCI", , drop = FALSE]
  pci_count <- as.integer(table(factor(pci$id, levels = event$id)))
  usable <- occurrence_count > 0L | pci_count > 0L
  method_present <- nzchar(event$sampleSizeValue) & nzchar(event$sampleSizeUnit) &
    nzchar(event$minimumDepthInMeters) & nzchar(event$maximumDepthInMeters)

  record_id <- vapply(event$id, function(value) {
    generate_source_record_id("DS12", value, collision_index = 1L)
  }, character(1))
  record_screening <- data.frame(
    record_id = record_id,
    ds_id = "DS12",
    raw_relative_path = file.path(pin$run_relative_path[[1]], manifest$file_name[[1]]),
    provider_record_id = event$id,
    collision_index = 1L,
    source_row_number = seq_len(nrow(event)),
    reported_datetime = reported_datetime,
    datetime_utc = datetime_utc,
    reported_latitude = as.character(event$decimalLatitude),
    reported_longitude = as.character(event$decimalLongitude),
    latitude = latitude,
    longitude = longitude,
    coordinate_crs = ifelse(nzchar(event$geodeticDatum), event$geodeticDatum, "EPSG:4326"),
    subregion_id = subregion_id,
    domain_state = domain_state,
    cmems_overlap_state = "unknown",
    repeated_sampling_state = "present",
    biomass_variable_state = "absent",
    method_metadata_state = ifelse(method_present, "present", "unknown"),
    license_state = ifelse(grepl("CC-BY-4.0", event$license, fixed = TRUE), "open", "unverified"),
    canonical_record_id = record_id,
    duplicate_resolution_state = "resolved",
    provisional_tier = ifelse(usable, "D", "pending"),
    analysis_role = ifelse(usable, "lifeform_only", "pending"),
    screening_decision = ifelse(usable, "secondary", "pending"),
    exclusion_reason_code = "none",
    screening_detail = ifelse(
      usable,
      "CPR event retained only for size-selective PCI/taxon recurrence evidence; not total biomass.",
      "No linked PCI or taxon occurrence was found; retain as unknown pending provider qualification."
    ),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  validate_stage2_table(record_screening, "record_screening", contract)

  duplicate_map <- stage2_empty_table(contract, "duplicate_map")
  validate_stage2_table(duplicate_map, "duplicate_map", contract)

  measurement_summary <- aggregate(
    list(measurement_rows = measurement$id),
    by = list(measurement_type = measurement$measurementType,
              measurement_unit = measurement$measurementUnit),
    FUN = length
  )
  measurement_summary$unique_event_count <- vapply(
    seq_len(nrow(measurement_summary)),
    function(i) length(unique(measurement$id[
      measurement$measurementType == measurement_summary$measurement_type[[i]] &
        measurement$measurementUnit == measurement_summary$measurement_unit[[i]]
    ])),
    integer(1)
  )
  measurement_summary <- measurement_summary[order(measurement_summary$measurement_type,
                                                   measurement_summary$measurement_unit), ]
  rownames(measurement_summary) <- NULL

  taxon_key <- paste(occurrence$taxonID, occurrence$scientificName, sep = "\r")
  taxon_counts <- sort(table(taxon_key), decreasing = TRUE)
  split_taxon <- strsplit(names(taxon_counts), "\r", fixed = TRUE)
  taxon_summary <- data.frame(
    provider_taxon_id = vapply(split_taxon, `[[`, character(1), 1L),
    scientific_name = vapply(split_taxon, function(value) paste(value[-1L], collapse = "\r"), character(1)),
    occurrence_rows = as.integer(taxon_counts),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  location_summary <- data.frame(
    event_rows = nrow(event),
    usable_secondary_event_rows = sum(usable),
    occurrence_rows = nrow(occurrence),
    measurement_rows = nrow(measurement),
    pci_measurement_rows = nrow(pci),
    events_with_pci = sum(pci_count > 0L),
    events_with_occurrences = sum(occurrence_count > 0L),
    unique_reported_taxa = nrow(taxon_summary),
    core_event_rows = sum(domain_state == "core" & usable),
    external_transfer_event_rows = sum(domain_state == "external_transfer" & usable),
    outside_domain_event_rows = sum(domain_state == "outside_domain" & usable),
    invalid_coordinate_event_rows = sum(domain_state == "invalid_coordinate" & usable),
    parseable_datetime_rows = sum(nzchar(datetime_utc)),
    first_parseable_datetime_utc = if (any(nzchar(datetime_utc))) min(datetime_utc[nzchar(datetime_utc)]) else "",
    last_parseable_datetime_utc = if (any(nzchar(datetime_utc))) max(datetime_utc[nzchar(datetime_utc)]) else "",
    unique_years = length(unique(substr(datetime_utc[nzchar(datetime_utc)], 1L, 4L))),
    duplicate_event_id_rows = sum(duplicated(event$id)),
    open_licence_event_rows = sum(record_screening$license_state == "open"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  if (location_summary$usable_secondary_event_rows <= 0L ||
      location_summary$core_event_rows + location_summary$external_transfer_event_rows <= 0L ||
      location_summary$duplicate_event_id_rows != 0L) {
    stop("DS12 event screening failed its usability, domain, or identity assertions.", call. = FALSE)
  }

  summary <- data.frame(
    work_item_id = "REGISTER:DS12",
    record_count = as.integer(location_summary$usable_secondary_event_rows),
    core_record_count = as.integer(location_summary$core_event_rows),
    external_transfer_record_count = as.integer(location_summary$external_transfer_event_rows),
    cmems_overlap_record_count = 0L,
    duplicate_record_count = 0L,
    provisional_tier = "D",
    analysis_role = "lifeform_only",
    screening_decision = "secondary",
    exclusion_reason_code = "none",
    screening_detail = paste0(
      "Public CC-BY-4.0 CPR DwC-A record-screened at the event level: ",
      location_summary$usable_secondary_event_rows, " events have linked PCI or taxon evidence; ",
      location_summary$core_event_rows, " intersect the core domain and ",
      location_summary$external_transfer_event_rows, " the external-transfer region. Retain only ",
      "as Tier D/E size-selective recurrence corroboration, never total-community biomass. Exact ",
      "CMEMS product overlap and taxon/lifeform qualification remain later-stage audits; zero overlap ",
      "here means unknown, not absent."
    ),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  validate_stage2_table(summary, "dataset_screening_summary", contract)

  output_paths <- c(
    variable_inventory = "metadata/stage2/screening/ds12_cpr_variable_inventory.csv",
    location_summary = "metadata/stage2/screening/ds12_cpr_location_summary.csv",
    measurement_summary = "metadata/stage2/screening/ds12_cpr_measurement_summary.csv",
    taxon_summary = "metadata/stage2/screening/ds12_cpr_taxon_summary.csv",
    record_screening = "data/interim/stage2_ds12_cpr_record_screening.csv",
    duplicate_map = "data/interim/stage2_ds12_cpr_duplicate_map.csv",
    dataset_screening_summary = "metadata/stage2/screening/ds12_cpr_screening_summary.csv"
  )
  output_values <- list(variable_inventory, location_summary, measurement_summary, taxon_summary,
                        record_screening, duplicate_map, summary)
  for (i in seq_along(output_paths)) write_csv_atomic(output_values[[i]], output_paths[[i]])

  output_registry <- data.frame(
    artifact_role = names(output_paths),
    path = unname(output_paths),
    row_count = vapply(output_values, nrow, integer(1)),
    checksum_sha256 = vapply(unname(output_paths), calculate_checksum, character(1)),
    generated_from_manifest_sha256 = pin$manifest_checksum_sha256[[1]],
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  write_csv_atomic(output_registry, "metadata/stage2/screening/ds12_cpr_output_registry.csv")

  message(sprintf(
    "DS12 CPR screening complete: %d usable secondary events (%d core; %d external transfer).",
    summary$record_count, summary$core_record_count, summary$external_transfer_record_count
  ))
}

main()
