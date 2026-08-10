# Inventory and record-screen the manually exported DS02 RWS Waterinfo dataset.

source("R/00_core_setup.R")
source("R/00_identifiers.R")
source("R/03_stage2_contract.R")
required_namespace("sf")

contract <- read_stage2_contract()
pin_path <- "metadata/stage2_ds02_rws_manual_export_active_run.csv"
manifest_path <- "metadata/stage2_ds02_rws_manual_export_acquisition_manifest.csv"
location_path <- "metadata/stage2_ds02_rws_catalogue_location_screen.csv"
pin <- utils::read.csv(pin_path, stringsAsFactors = FALSE, check.names = FALSE)
manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE, check.names = FALSE)
locations <- utils::read.csv(location_path, stringsAsFactors = FALSE, check.names = FALSE)

if (nrow(pin) != 1L || pin$work_item_id[[1]] != "REGISTER:DS02" || nrow(manifest) != 4L) {
  stop("DS02 RWS manual export active run or tracked acquisition manifest is invalid.", call. = FALSE)
}
validate_stage2_table(manifest, "acquisition_manifest", contract)

inventory_path <- "metadata/stage2_ds02_rws_variable_inventory.csv"
summary_path <- "metadata/stage2_ds02_rws_package_summary.csv"
screening_path <- "data/interim/stage2_ds02_rws_record_screening.csv"
identity_path <- "data/interim/stage2_ds02_rws_duplicate_identity.csv"
registry_path <- "metadata/stage2_ds02_rws_output_registry.csv"

if (file.exists(registry_path)) {
  existing_registry <- utils::read.csv(registry_path, stringsAsFactors = FALSE, check.names = FALSE)
  valid <- nrow(existing_registry) == 4L && all(file.exists(existing_registry$path)) &&
    all(vapply(seq_len(nrow(existing_registry)), function(i) {
      identical(calculate_checksum(existing_registry$path[[i]]), existing_registry$checksum_sha256[[i]])
    }, logical(1)))
  if (valid) {
    message("Verified existing DS02 inventory and record-screen outputs; no rebuild required.")
    quit(save = "no", status = 0L)
  }
  stop("DS02 output registry exists but one or more generated artifacts differ.", call. = FALSE)
}

dir.create("data/interim", recursive = TRUE, showWarnings = FALSE)
screening_partial <- paste0(screening_path, ".partial")
identity_partial <- paste0(identity_path, ".partial")
for (path in c(screening_partial, identity_partial)) {
  if (file.exists(path)) unlink(path)
}

semantic_role <- function(column_name) {
  if (column_name %in% c("Meetobject", "Organisatie")) return("identifier")
  if (column_name == "Datum") return("datetime")
  if (column_name %in% c("Taxon type", "Taxon groep", "Taxon naam")) return("taxon")
  if (column_name %in% c("Parameter", "Waarde", "Eenheid", "Aantal", "Grootheid", "Compartiment")) return("measurement")
  if (column_name %in% c("Meetpakket", "AnalysisPackage", "MeasurementPackage", "SamplingMethod", "AnalysisMethod", "Capacity", "LengthClass", "Supplier", "Purpose")) return("method")
  if (column_name %in% c("Appearance", "LifeStage", "LifeForm")) return("taxon_context")
  "provenance_or_context"
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

# Sort manifest by part number to ensure stable record IDs
manifest <- manifest[order(manifest$filename), ]

for (i in seq_len(nrow(manifest))) {
  csv_path <- file.path("data", "raw", manifest$raw_relative_path[[i]])
  if (!identical(calculate_checksum(csv_path), manifest$checksum_sha256[[i]])) {
    stop(sprintf("Raw DS02 export checksum failed: %s", csv_path), call. = FALSE)
  }
  
  lines <- readLines(csv_path, encoding = "UTF-8")
  headers <- strsplit(lines[[1]], ";")[[1]]
  
  data_lines <- lines[-1]
  data_list <- strsplit(data_lines, ";")
  lengths <- lengths(data_list)
  
  if (any(lengths > length(headers))) {
    anomalous <- which(lengths > length(headers))
    for (idx in anomalous) {
      row <- data_list[[idx]]
      data_list[[idx]] <- row[-3]
    }
  }
  
  data_list <- lapply(data_list, function(row) {
    if (length(row) < length(headers)) {
      c(row, rep("", length(headers) - length(row)))
    } else {
      row[seq_along(headers)]
    }
  })
  
  data <- as.data.frame(do.call(rbind, data_list), stringsAsFactors = FALSE)
  colnames(data) <- headers
  
  required <- c("Datum", "Meetobject", "Parameter", "Waarde", "Eenheid")
  if (!all(required %in% names(data))) {
    stop(sprintf("DS02 source schema missing required columns: %s", csv_path), call. = FALSE)
  }
  
  data$row_number <- seq_len(nrow(data))
  
  for (column_name in headers) {
    values <- data[[column_name]]
    examples <- head(unique(as.character(values[!is.na(values) & nzchar(as.character(values))])), 3L)
    inventory_rows[[length(inventory_rows) + 1L]] <- data.frame(
      raw_relative_path = manifest$raw_relative_path[[i]],
      table_name = "Waterinfo_Export",
      column_name = column_name,
      storage_type = "character",
      reported_unit = if (column_name == "Waarde") paste(sort(unique(data$Eenheid[!is.na(data$Eenheid) & nzchar(data$Eenheid)])), collapse = "|") else "",
      semantic_role = semantic_role(column_name),
      missing_value_codes = "blank",
      quality_flag_meaning = "",
      example_values = paste(examples, collapse = "|"),
      inventory_state = "present",
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  }
  
  dates_raw <- as.character(data$Datum)
  parsed_dates <- strptime(dates_raw, format = "%d-%m-%Y %H:%M:%S +00:00", tz = "UTC")
  datetime_utc <- format(parsed_dates, "%Y-%m-%dT%H:%M:%SZ")
  dates_only <- as.Date(parsed_dates)
  
  if (anyNA(datetime_utc)) stop(sprintf("Unparseable dates in %s", csv_path), call. = FALSE)
  
  loc_idx <- match(data$Meetobject, locations$location_code)
  
  # For manual Waterinfo export, use crosswalk if direct match fails
  manual_crosswalk <- c(
    "WALCRN2" = "walcheren.2kmuitdekust",
    "WALCRN20" = "walcheren.20kmuitdekust",
    "WALCRN70" = "walcheren.70kmuitdekust",
    "TERSLG4" = "terschelling.4kmuitdekust",
    "TERSLG10" = "terschelling.10kmuitdekust",
    "TERSLG50" = "terschelling.50kmuitdekust",
    "TERSLG100" = "terschelling.100kmuitdekust",
    "TERSLG135" = "terschelling.135kmuitdekust",
    "TERSLG175" = "terschelling.175kmuitdekust",
    "TERSLG235" = "terschelling.235kmuitdekust",
    "NOORDWK2" = "noordwijk.2kmuitdekust.flachsee",
    "NOORDWK10" = "noordwijk.10kmuitdekust.flachsee",
    "NOORDWK20" = "noordwijk.20kmuitdekust",
    "NOORDWK70" = "noordwijk.70kmuitdekust",
    "TEXL10" = "texel.10kmuitdekust",
    "GOERE2" = "goeree2kmuitdekust",
    "GOERE6" = "goeree6kmuitdekust",
    "DANTZGT" = "dantziggat",
    "HUIBGOT" = "huibertgat",
    "MARSDND" = "marsdiep.noord"
  )
  
  unmatched <- is.na(loc_idx)
  if (any(unmatched)) {
    mapped_codes <- manual_crosswalk[data$Meetobject[unmatched]]
    loc_idx[unmatched] <- match(mapped_codes, locations$location_code)
  }
  
  still_unmatched <- is.na(loc_idx)
  latitude <- ifelse(still_unmatched, 0, locations$latitude[loc_idx])
  longitude <- ifelse(still_unmatched, 0, locations$longitude[loc_idx])
  domain_state <- ifelse(still_unmatched, "outside_domain", locations$domain_state[loc_idx])
  subregion_id <- ifelse(still_unmatched, NA_character_, locations$subregion_id[loc_idx])
  
  provider_record_id <- paste(manifest$filename[[i]], data$row_number, sep = ":")
  record_id <- vapply(provider_record_id, function(value) {
    generate_source_record_id("DS02", value, collision_index = 1L)
  }, character(1))
  
  if (anyDuplicated(record_id)) stop(sprintf("Stable DS02 record-ID collision in %s.", csv_path), call. = FALSE)
  
  parameter_lower <- tolower(as.character(data$Parameter))
  quantity_lower <- tolower(as.character(data$Grootheid))
  
  biomass_state <- ifelse(quantity_lower %in% c("aantfvlme", "aantpvlme", "biovol", "carbon") | 
                          grepl("carbon|biovolume", parameter_lower), "present", "absent")
  biomass_state <- ifelse(quantity_lower %in% c("aantfvlme", "aantpvlme", "aantfte", "aantvlme"), "present", biomass_state)
  
  method_state <- ifelse(!is.na(data$SamplingMethod) & nzchar(data$SamplingMethod), "present", "absent")
  
  outside_domain <- domain_state == "outside_domain"
  outside_time <- dates_only < as.Date("2000-01-01") | dates_only > as.Date("2019-12-31")
  excluded <- outside_domain | outside_time
  
  exclusion_reason <- ifelse(outside_domain, "outside_frozen_domain",
                             ifelse(outside_time, "no_cmems_era_overlap", "none"))
                             
  screening_detail <- ifelse(outside_domain, "Canonical row lies outside the checksum-pinned Greater North Sea polygon.",
                      ifelse(outside_time, "Canonical row lies outside the 2000-2019 target period.",
                             "Canonical row intersects the frozen domain and time period; ready for duplicate/taxonomic qualification."))
  
  record_screening <- data.frame(
    record_id = record_id,
    ds_id = "DS02",
    raw_relative_path = manifest$raw_relative_path[[i]],
    provider_record_id = provider_record_id,
    collision_index = 1L,
    source_row_number = as.integer(data$row_number),
    reported_datetime = dates_raw,
    datetime_utc = datetime_utc,
    reported_latitude = ifelse(still_unmatched, "0", as.character(locations$reported_latitude[loc_idx])),
    reported_longitude = ifelse(still_unmatched, "0", as.character(locations$reported_longitude[loc_idx])),
    latitude = latitude,
    longitude = longitude,
    coordinate_crs = "EPSG:4326",
    subregion_id = subregion_id,
    domain_state = domain_state,
    cmems_overlap_state = "unknown",
    repeated_sampling_state = "unknown",
    biomass_variable_state = biomass_state,
    method_metadata_state = method_state,
    license_state = "open",
    canonical_record_id = NA_character_,
    duplicate_resolution_state = "unresolved",
    provisional_tier = "pending",
    analysis_role = ifelse(excluded, "excluded", "pending"),
    screening_decision = ifelse(excluded, "excluded", "pending"),
    exclusion_reason_code = exclusion_reason,
    screening_detail = screening_detail,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  validate_stage2_table(record_screening, "record_screening", contract)
  append_csv(record_screening, screening_partial, screening_header)
  screening_header <- FALSE
  
  duplicate_identity <- data.frame(
    record_id = record_id,
    provider_dataset_id = "RWS_Waterinfo",
    station_code = data$Meetobject,
    taxon_name = data$`Taxon naam`,
    parameter = data$Parameter,
    quantity = data$Grootheid,
    value = data$Waarde,
    unit = data$Eenheid,
    duplicate_key = paste(data$Meetobject, data$`Taxon naam`, data$Parameter, data$Grootheid, data$Waarde, data$Eenheid, sep = "|"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  append_csv(duplicate_identity, identity_partial, identity_header)
  identity_header <- FALSE
  
  summary_rows[[length(summary_rows) + 1L]] <- data.frame(
    provider_dataset_id = "RWS_Waterinfo",
    provider_version = "Manual Export",
    raw_relative_path = manifest$raw_relative_path[[i]],
    source_rows = nrow(data),
    unique_sample_ids = length(unique(paste(data$Meetobject, datetime_utc))),
    unique_dates = length(unique(dates_only)),
    earliest_date = min(datetime_utc),
    latest_date = max(datetime_utc),
    unique_stations = length(unique(data$Meetobject)),
    core_rows = sum(domain_state == "core"),
    external_transfer_rows = sum(domain_state == "external_transfer"),
    outside_domain_rows = sum(domain_state == "outside_domain"),
    carbon_rows = 0L,
    biovolume_rows = sum(quantity_lower %in% c("aantpvlme", "biovol")),
    abundance_or_count_rows = sum(quantity_lower %in% c("aantfte", "aantvlme", "aantal")),
    method_metadata_rows = sum(method_state == "present"),
    parameters = paste(sort(unique(data$Parameter)), collapse = "|"),
    units = paste(sort(unique(data$Eenheid)), collapse = "|"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  message(sprintf("DS02 inventory %d/%d: %s (%d rows)", i, nrow(manifest), manifest$filename[[i]], nrow(data)))
}

inventory <- do.call(rbind, inventory_rows)
summary <- do.call(rbind, summary_rows)
validate_stage2_table(inventory, "variable_inventory", contract)
if (sum(summary$source_rows) != 505452L ||
    any(summary$source_rows != summary$core_rows + summary$external_transfer_rows + summary$outside_domain_rows)) {
  stop("DS02 package summaries do not reconcile with source or spatial row totals.", call. = FALSE)
}
write_csv_atomic(inventory, inventory_path)
write_csv_atomic(summary, summary_path)
for (pair in list(c(screening_partial, screening_path), c(identity_partial, identity_path))) {
  if (file.exists(pair[[2]]) && unlink(pair[[2]]) != 0L) stop("Unable to replace DS02 interim output.", call. = FALSE)
  if (!file.rename(pair[[1]], pair[[2]])) stop("Unable to finalize DS02 interim output.", call. = FALSE)
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
message(sprintf("DS02 inventory complete: %d source rows; %d core, %d external-transfer, %d outside-domain.",
                sum(summary$source_rows), sum(summary$core_rows), sum(summary$external_transfer_rows),
                sum(summary$outside_domain_rows)))
