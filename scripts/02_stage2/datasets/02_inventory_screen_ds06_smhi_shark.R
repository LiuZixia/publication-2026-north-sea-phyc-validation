# Inventory and record-screen all canonical DS06 SHARK packages without altering the raw ZIP files.

source("R/00_core_setup.R")
source("R/00_identifiers.R")
source("R/03_stage2_contract.R")
required_namespace("sf")

contract <- read_stage2_contract()
pin_path <- "metadata/stage2/acquisition/ds06_smhi_shark_active_run.csv"
manifest_path <- "metadata/stage2/acquisition/ds06_smhi_shark_acquisition_manifest.csv"
pin <- utils::read.csv(pin_path, stringsAsFactors = FALSE, check.names = FALSE)
manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE, check.names = FALSE)
if (nrow(pin) != 1L || pin$work_item_id[[1]] != "REGISTER:DS06" || nrow(manifest) != 219L ||
    !identical(calculate_checksum(file.path("data", "raw", pin$run_relative_path[[1]], "manifest.csv")),
               pin$manifest_checksum_sha256[[1]]) ||
    !identical(calculate_checksum(file.path("data", "raw", pin$run_relative_path[[1]], "run_summary.json")),
               pin$run_summary_checksum_sha256[[1]])) {
  stop("DS06 SHARK active run or tracked acquisition manifest is invalid.", call. = FALSE)
}
validate_stage2_table(manifest, "acquisition_manifest", contract)

inventory_path <- "metadata/stage2/screening/ds06_smhi_shark_variable_inventory.csv"
summary_path <- "metadata/stage2/screening/ds06_smhi_shark_package_summary.csv"
screening_path <- "data/interim/stage2_ds06_smhi_shark_record_screening.csv"
identity_path <- "data/interim/stage2_ds06_smhi_shark_duplicate_identity.csv"
registry_path <- "metadata/stage2/screening/ds06_smhi_shark_output_registry.csv"

# A verified output registry makes reruns cheap while refusing stale or partially replaced outputs.
if (file.exists(registry_path)) {
  existing_registry <- utils::read.csv(registry_path, stringsAsFactors = FALSE, check.names = FALSE)
  existing_registry <- relocate_stage2_registry_paths(existing_registry, registry_path)
  valid <- nrow(existing_registry) == 4L && all(file.exists(existing_registry$path)) &&
    all(vapply(seq_len(nrow(existing_registry)), function(i) {
      identical(calculate_checksum(existing_registry$path[[i]]), existing_registry$checksum_sha256[[i]])
    }, logical(1)))
  if (valid) {
    message("Verified existing DS06 inventory and record-screen outputs; no rebuild required.")
    quit(save = "no", status = 0L)
  }
  stop("DS06 output registry exists but one or more generated artifacts differ.", call. = FALSE)
}

dir.create("data/interim", recursive = TRUE, showWarnings = FALSE)
screening_partial <- paste0(screening_path, ".partial")
identity_partial <- paste0(identity_path, ".partial")
for (path in c(screening_partial, identity_partial)) {
  if (file.exists(path)) unlink(path)
}

sf::sf_use_s2(FALSE)
domain <- sf::st_read("config/spatial/greater_north_sea.geojson", quiet = TRUE)
subregions <- sf::st_read("config/spatial/hydrographic_subregions.geojson", quiet = TRUE)
if (nrow(domain) != 1L || !all(sf::st_is_valid(domain)) || !all(sf::st_is_valid(subregions))) {
  stop("Frozen spatial files are invalid.", call. = FALSE)
}

semantic_role <- function(column_name) {
  if (column_name %in% c("dataset_name", "row_number", "sample_id", "shark_sample_id_md5",
                         "sample_location_id", "station_id", "expedition_id", "sample_part_id")) return("identifier")
  if (column_name %in% c("sample_date", "sample_time", "reported_sample_date", "visit_year", "visit_month")) return("datetime")
  if (column_name %in% c("sample_latitude_dm", "sample_longitude_dm", "sample_latitude_dd",
                         "sample_longitude_dd", "positioning_system_code")) return("coordinate")
  if (grepl("depth", column_name, fixed = TRUE)) return("depth")
  if (column_name %in% c("scientific_name", "reported_scientific_name", "aphia_id", "dyntaxa_id",
                         "species_flag_code", "trophic_type_code", "size_class", "bvol_scientific_name")) return("taxon")
  if (column_name %in% c("parameter", "value", "unit", "reported_parameter", "reported_value",
                         "reported_unit", "reported_cell_volume_um3", "bvol_size_class", "bvol_aphia_id")) return("measurement")
  if (grepl("quality|check_status|data_checked", column_name)) return("quality")
  if (grepl("method|sampler|mesh|sedimentation|magnification|coefficient|sampled_volume", column_name)) return("method")
  "provenance_or_context"
}

declared_unit <- function(column_name, data) {
  if (column_name == "value") return(paste(sort(unique(data$unit[!is.na(data$unit) & nzchar(data$unit)])), collapse = "|"))
  if (column_name == "reported_value") return(paste(sort(unique(data$reported_unit[!is.na(data$reported_unit) & nzchar(data$reported_unit)])), collapse = "|"))
  if (column_name %in% c("sample_latitude_dd", "sample_longitude_dd")) return("decimal degrees WGS84")
  if (grepl("_m$", column_name)) return("m")
  if (grepl("_um$", column_name)) return("um")
  if (grepl("_ml$", column_name)) return("ml")
  if (grepl("_h$", column_name)) return("h")
  ""
}

append_csv <- function(value, path, include_header) {
  utils::write.table(value, path, sep = ",", row.names = FALSE, col.names = include_header,
                     append = !include_header, quote = TRUE, na = "", qmethod = "double",
                     fileEncoding = "UTF-8")
}

inventory_rows <- list()
summary_rows <- list()
screening_header <- TRUE
identity_header <- TRUE

for (i in seq_len(nrow(manifest))) {
  zip_path <- file.path("data", "raw", manifest$raw_relative_path[[i]])
  if (!identical(calculate_checksum(zip_path), manifest$checksum_sha256[[i]])) {
    stop(sprintf("Raw DS06 package checksum failed: %s", zip_path), call. = FALSE)
  }
  connection <- unz(zip_path, "shark_data.txt", open = "rb")
  raw_text <- tryCatch(readBin(connection, what = "raw", n = 2^31 - 1L),
                       finally = close(connection))
  utf8_text <- iconv(rawToChar(raw_text), from = "latin1", to = "UTF-8")
  if (is.na(utf8_text)) stop(sprintf("Unable to convert SHARK source text to UTF-8: %s", zip_path), call. = FALSE)
  text_connection <- textConnection(utf8_text, open = "r", local = TRUE)
  data <- tryCatch(utils::read.delim(text_connection, sep = "\t", quote = "", comment.char = "",
                                    na.strings = "", stringsAsFactors = FALSE, check.names = FALSE),
                   finally = close(text_connection))
  raw_column_names <- names(data)
  required <- c("dataset_name", "shark_sample_id_md5", "sample_date", "sample_time",
                "sample_latitude_dd", "sample_longitude_dd", "scientific_name", "aphia_id",
                "parameter", "value", "unit", "quality_flag", "analysis_method_code")
  if (!all(required %in% names(data)) || !nrow(data) ||
      any(as.character(data$dataset_name) != manifest$provider_dataset_id[[i]])) {
    stop(sprintf("DS06 source schema, dataset identity, or row key failed: %s", zip_path), call. = FALSE)
  }
  # SHARK's older export schema supplies row_number, while its current 96-column
  # schema does not. In the latter, the immutable source-file line position is
  # the only lossless row locator and is therefore used as source_row_number.
  if (!"row_number" %in% raw_column_names) data$row_number <- seq_len(nrow(data))
  if (anyNA(suppressWarnings(as.integer(data$row_number))) || anyDuplicated(data$row_number)) {
    stop(sprintf("DS06 source row key is missing or duplicated: %s", zip_path), call. = FALSE)
  }

  for (column_name in raw_column_names) {
    values <- data[[column_name]]
    examples <- head(unique(as.character(values[!is.na(values) & nzchar(as.character(values))])), 3L)
    inventory_rows[[length(inventory_rows) + 1L]] <- data.frame(
      raw_relative_path = manifest$raw_relative_path[[i]],
      table_name = "shark_data.txt",
      column_name = column_name,
      storage_type = class(values)[[1]],
      reported_unit = declared_unit(column_name, data),
      semantic_role = semantic_role(column_name),
      missing_value_codes = "blank",
      quality_flag_meaning = if (semantic_role(column_name) == "quality")
        "Provider code retained verbatim; code-list interpretation pending." else "",
      example_values = paste(examples, collapse = "|"),
      inventory_state = "present",
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  }

  latitude <- suppressWarnings(as.numeric(data$sample_latitude_dd))
  longitude <- suppressWarnings(as.numeric(data$sample_longitude_dd))
  if (any(!is.finite(latitude)) || any(!is.finite(longitude)) ||
      any(latitude < -90 | latitude > 90 | longitude < -180 | longitude > 180)) {
    stop(sprintf("Invalid DS06 coordinates in %s.", zip_path), call. = FALSE)
  }
  coordinate_key <- paste(sprintf("%.8f", longitude), sprintf("%.8f", latitude), sep = "|")
  unique_index <- !duplicated(coordinate_key)
  unique_points <- sf::st_as_sf(data.frame(key = coordinate_key[unique_index],
                                           lon = longitude[unique_index], lat = latitude[unique_index]),
                                coords = c("lon", "lat"), crs = 4326)
  domain_hit <- lengths(suppressMessages(
    sf::st_intersects(unique_points, domain, prepared = TRUE)
  )) > 0L
  region_hit <- suppressMessages(
    sf::st_intersects(unique_points[domain_hit, , drop = FALSE], subregions, prepared = TRUE)
  )
  region_index <- vapply(region_hit, function(value) if (length(value)) value[[1]] else NA_integer_, integer(1))
  if (anyNA(region_index)) stop(sprintf("An in-domain DS06 point lacks a subregion in %s.", zip_path), call. = FALSE)
  unique_state <- rep("outside_domain", nrow(unique_points))
  unique_subregion <- rep(NA_character_, nrow(unique_points))
  unique_state[domain_hit] <- ifelse(subregions$role[region_index] == "core-domain", "core", "external_transfer")
  unique_subregion[domain_hit] <- subregions$subregion_id[region_index]
  map_index <- match(coordinate_key, unique_points$key)
  domain_state <- unique_state[map_index]
  subregion_id <- unique_subregion[map_index]

  dates <- as.character(data$sample_date)
  times <- as.character(data$sample_time)
  has_time <- !is.na(times) & nzchar(trimws(times))
  normalized_time <- ifelse(grepl("^[0-9]{2}:[0-9]{2}$", times), paste0(times, ":00"), times)
  datetime_utc <- ifelse(has_time, paste0(dates, "T", normalized_time, "Z"), NA_character_)
  provider_record_id <- paste(manifest$provider_dataset_id[[i]], data$row_number, sep = ":")
  record_id <- vapply(provider_record_id, function(value) {
    generate_source_record_id("DS06", value, collision_index = 1L)
  }, character(1))
  if (anyDuplicated(record_id)) stop(sprintf("Stable DS06 record-ID collision in %s.", zip_path), call. = FALSE)
  repeated_state <- if (length(unique(dates)) > 1L) "present" else "absent"
  parameter_lower <- tolower(as.character(data$parameter))
  biomass_state <- ifelse(grepl("carbon|biovolume|abundance|count", parameter_lower), "present", "absent")
  method_state <- ifelse((!is.na(data$analysis_method_code) & nzchar(as.character(data$analysis_method_code))) |
                         (!is.na(data$plankton_sampling_method_code) & nzchar(as.character(data$plankton_sampling_method_code))),
                         "present", "absent")
  outside <- domain_state == "outside_domain"
  record_screening <- data.frame(
    record_id = record_id,
    ds_id = "DS06",
    raw_relative_path = manifest$raw_relative_path[[i]],
    provider_record_id = provider_record_id,
    collision_index = 1L,
    source_row_number = as.integer(data$row_number),
    reported_datetime = ifelse(has_time, paste(dates, times), dates),
    datetime_utc = datetime_utc,
    reported_latitude = as.character(data$sample_latitude_dd),
    reported_longitude = as.character(data$sample_longitude_dd),
    latitude = latitude,
    longitude = longitude,
    coordinate_crs = "EPSG:4326",
    subregion_id = subregion_id,
    domain_state = domain_state,
    cmems_overlap_state = "unknown",
    repeated_sampling_state = repeated_state,
    biomass_variable_state = biomass_state,
    method_metadata_state = method_state,
    license_state = "open",
    canonical_record_id = NA_character_,
    duplicate_resolution_state = "unresolved",
    provisional_tier = "pending",
    analysis_role = ifelse(outside, "excluded", "pending"),
    screening_decision = ifelse(outside, "excluded", "pending"),
    exclusion_reason_code = ifelse(outside, "outside_frozen_domain", "none"),
    screening_detail = ifelse(outside,
      "Canonical SHARK row lies outside the checksum-pinned Greater North Sea polygon.",
      "Canonical SHARK row intersects the frozen domain; variable, method, and duplicate qualification remains pending."),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  validate_stage2_table(record_screening, "record_screening", contract)
  append_csv(record_screening, screening_partial, screening_header)
  screening_header <- FALSE

  duplicate_identity <- data.frame(
    record_id = record_id,
    provider_dataset_id = manifest$provider_dataset_id[[i]],
    shark_sample_id_md5 = as.character(data$shark_sample_id_md5),
    sample_min_depth_m = as.character(data$sample_min_depth_m),
    sample_max_depth_m = as.character(data$sample_max_depth_m),
    scientific_name = as.character(data$scientific_name),
    aphia_id = as.character(data$aphia_id),
    parameter = as.character(data$parameter),
    value = as.character(data$value),
    unit = as.character(data$unit),
    sample_part_id = as.character(data$sample_part_id),
    replicate_no = as.character(data$replicate_no),
    duplicate_key = paste(data$shark_sample_id_md5, data$sample_min_depth_m, data$sample_max_depth_m,
                          data$scientific_name, data$aphia_id, data$parameter, data$value, data$unit,
                          data$sample_part_id, data$replicate_no, sep = "|"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  append_csv(duplicate_identity, identity_partial, identity_header)
  identity_header <- FALSE

  summary_rows[[length(summary_rows) + 1L]] <- data.frame(
    provider_dataset_id = manifest$provider_dataset_id[[i]],
    provider_version = manifest$provider_version[[i]],
    raw_relative_path = manifest$raw_relative_path[[i]],
    source_rows = nrow(data),
    unique_sample_ids = length(unique(data$shark_sample_id_md5)),
    unique_dates = length(unique(dates)),
    earliest_date = min(dates),
    latest_date = max(dates),
    unique_stations = length(unique(data$station_id)),
    core_rows = sum(domain_state == "core"),
    external_transfer_rows = sum(domain_state == "external_transfer"),
    outside_domain_rows = sum(domain_state == "outside_domain"),
    carbon_rows = sum(grepl("carbon", parameter_lower)),
    biovolume_rows = sum(grepl("biovolume", parameter_lower)),
    abundance_or_count_rows = sum(grepl("abundance|count", parameter_lower)),
    method_metadata_rows = sum(method_state == "present"),
    parameters = paste(sort(unique(data$parameter)), collapse = "|"),
    units = paste(sort(unique(data$unit)), collapse = "|"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  message(sprintf("DS06 inventory %d/%d: %s (%d rows)", i, nrow(manifest),
                  manifest$provider_dataset_id[[i]], nrow(data)))
}

inventory <- do.call(rbind, inventory_rows)
summary <- do.call(rbind, summary_rows)
validate_stage2_table(inventory, "variable_inventory", contract)
if (sum(summary$source_rows) != 909693L ||
    any(summary$source_rows != summary$core_rows + summary$external_transfer_rows + summary$outside_domain_rows)) {
  stop("DS06 package summaries do not reconcile with source or spatial row totals.", call. = FALSE)
}
write_csv_atomic(inventory, inventory_path)
write_csv_atomic(summary, summary_path)
for (pair in list(c(screening_partial, screening_path), c(identity_partial, identity_path))) {
  if (file.exists(pair[[2]]) && unlink(pair[[2]]) != 0L) stop("Unable to replace DS06 interim output.", call. = FALSE)
  if (!file.rename(pair[[1]], pair[[2]])) stop("Unable to finalize DS06 interim output.", call. = FALSE)
}

registry <- data.frame(
  artifact_role = c("variable_inventory", "package_summary", "record_screening", "duplicate_identity"),
  path = c(inventory_path, summary_path, screening_path, identity_path),
  row_count = c(nrow(inventory), nrow(summary), sum(summary$source_rows), sum(summary$source_rows)),
  checksum_sha256 = vapply(c(inventory_path, summary_path, screening_path, identity_path),
                           calculate_checksum, character(1)),
  generated_from_manifest_sha256 = pin$manifest_checksum_sha256[[1]],
  stringsAsFactors = FALSE,
  check.names = FALSE
)
write_csv_atomic(registry, registry_path)
message(sprintf("DS06 inventory complete: %d source rows; %d core, %d external-transfer, %d outside-domain.",
                sum(summary$source_rows), sum(summary$core_rows), sum(summary$external_transfer_rows),
                sum(summary$outside_domain_rows)))
