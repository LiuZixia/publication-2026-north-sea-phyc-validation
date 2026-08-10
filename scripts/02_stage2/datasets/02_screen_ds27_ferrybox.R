# Screen the existing DS27 PANGAEA FerryBox files through an R-controlled ncdump bridge.
#
# No NetCDF R package is installed in the frozen environment. The system NetCDF utility is therefore
# used narrowly to decode the provider files; all scientific screening, geometry, summaries, and
# outputs remain in R. PANGAEA.930383 is retained in provenance but excluded from phytoplankton use
# because its archived children contain pCO2, temperature, and salinity, not chlorophyll or biomass.

source("R/00_core_setup.R")
source("R/03_stage2_contract.R")
required_namespace("sf")

main <- function() {
  if (!nzchar(Sys.which("ncdump"))) {
    stop("DS27 requires the system ncdump utility because no NetCDF R package is installed.",
         call. = FALSE)
  }
  contract <- read_stage2_contract()
  pin <- utils::read.csv("metadata/stage2/acquisition/ds27_pangaea_ferrybox_active_run.csv",
                         stringsAsFactors = FALSE, check.names = FALSE)
  if (nrow(pin) != 1L || pin$work_item_id[[1]] != "REGISTER:DS27") {
    stop("DS27 active-run pin is invalid.", call. = FALSE)
  }
  run_dir <- file.path("data", "raw", pin$run_relative_path[[1]])
  manifest_path <- file.path(run_dir, "manifest.csv")
  if (!file.exists(manifest_path) ||
      calculate_checksum(manifest_path) != pin$manifest_checksum_sha256[[1]]) {
    stop("DS27 manifest checksum does not reconcile with the active pin.", call. = FALSE)
  }
  manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE, check.names = FALSE)
  manifest_files <- file.path(run_dir, manifest$file_name)
  if (any(!file.exists(manifest_files)) ||
      any(file.size(manifest_files) != manifest$file_size_bytes) ||
      !identical(unname(vapply(manifest_files, calculate_checksum, character(1))),
                 manifest$checksum_sha256)) {
    stop("One or more DS27 manifest files fail existence, size, or checksum validation.", call. = FALSE)
  }
  nc_rows <- grepl("\\.nc$", manifest$file_name, ignore.case = TRUE)
  nc_files <- manifest_files[nc_rows]
  if (length(nc_files) != 679L || sum(!nc_rows) != 1L ||
      basename(manifest_files[!nc_rows]) != "PANGAEA_930383.zip") {
    stop("DS27 manifest does not contain the expected 679 NetCDF transects and one comparator ZIP.",
         call. = FALSE)
  }

  description_path <- file.path(run_dir, "PANGAEA_883824.txt")
  if (!file.exists(description_path)) stop("DS27 PANGAEA.883824 description is missing.", call. = FALSE)
  description <- readLines(description_path, warn = FALSE, encoding = "UTF-8")
  if (!any(grepl("chlorophyll-a fluorescence", description, fixed = TRUE)) ||
      !any(grepl("Creative Commons Attribution 3.0", description, fixed = TRUE))) {
    stop("DS27 PANGAEA.883824 description lacks expected variable or licence evidence.", call. = FALSE)
  }
  pco2_zip <- manifest_files[!nc_rows]
  pco2_summary <- readLines(unz(pco2_zip, "summary.txt"), warn = FALSE, encoding = "UTF-8")
  if (!any(grepl("pCO2, temperature and salinity", pco2_summary, fixed = TRUE)) ||
      any(grepl("chlorophyll", pco2_summary, ignore.case = TRUE))) {
    stop("DS27 PANGAEA.930383 is not the expected non-phytoplankton pCO2 collection.", call. = FALSE)
  }

  extract_block <- function(lines, variable) {
    data_start <- which(trimws(lines) == "data:")
    if (length(data_start) != 1L) stop("ncdump output lacks one data section.", call. = FALSE)
    lines <- lines[(data_start + 1L):length(lines)]
    start <- grep(paste0("^[[:space:]]*", variable, "[[:space:]]*="), lines)
    if (length(start) != 1L) {
      stop(sprintf("ncdump data block for %s is missing or duplicated.", variable), call. = FALSE)
    }
    relative_end <- which(grepl(";[[:space:]]*$", lines[start:length(lines)]))[[1]]
    block <- paste(lines[start:(start + relative_end - 1L)], collapse = " ")
    block <- sub(paste0("^[[:space:]]*", variable, "[[:space:]]*="), "", block)
    block <- sub(";[[:space:]]*$", "", block)
    values <- trimws(strsplit(block, ",", fixed = TRUE)[[1]])
    values[values %in% c("_", "NaN", "nan")] <- NA_character_
    suppressWarnings(as.numeric(sub("[bBsSfFdD]$", "", values)))
  }

  parse_header_inventory <- function(lines, relative_path) {
    declaration <- grep(
      "^[[:space:]]*(double|float|byte|short|int|char)[[:space:]]+[A-Za-z0-9_]+[;(]",
      lines, value = TRUE
    )
    storage <- sub("^[[:space:]]*([A-Za-z]+)[[:space:]].*$", "\\1", declaration)
    variable <- sub("^[[:space:]]*[A-Za-z]+[[:space:]]+([A-Za-z0-9_]+).*$", "\\1", declaration)
    if (anyDuplicated(variable) ||
        !all(c("TIME", "LATITUDE", "LONGITUDE", "CHLT", "CHLT_QC") %in% variable)) {
      stop(sprintf("Required DS27 variables are missing from %s.", relative_path), call. = FALSE)
    }
    attr_value <- function(name, attribute) {
      pattern <- paste0("^[[:space:]]*", name, ":", attribute, "[[:space:]]*=")
      hit <- grep(pattern, lines, value = TRUE)
      if (!length(hit)) return("")
      value <- sub(pattern, "", hit[[1]])
      value <- sub(";[[:space:]]*$", "", value)
      gsub('^"|"$', "", trimws(value))
    }
    semantic <- function(name) {
      if (name == "TIME") return("time")
      if (name %in% c("LATITUDE", "LONGITUDE")) return("coordinate")
      if (name == "DEPH") return("depth")
      if (grepl("_QC$", name)) return("quality_flag")
      if (name == "CHLT") return("chlorophyll_fluorescence")
      "measurement_value"
    }
    data.frame(
      raw_relative_path = relative_path,
      table_name = "netcdf_root",
      column_name = variable,
      storage_type = storage,
      reported_unit = vapply(variable, attr_value, character(1), attribute = "units"),
      semantic_role = vapply(variable, semantic, character(1)),
      missing_value_codes = vapply(variable, function(name) {
        paste(unique(c(attr_value(name, "_FillValue"), attr_value(name, "missing_value"))[
          nzchar(c(attr_value(name, "_FillValue"), attr_value(name, "missing_value")))]),
          collapse = "|")
      }, character(1)),
      quality_flag_meaning = vapply(variable, attr_value, character(1), attribute = "flagmeanings"),
      example_values = "",
      inventory_state = "present",
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  }

  sf::sf_use_s2(FALSE)
  domain <- sf::st_read("config/spatial/greater_north_sea.geojson", quiet = TRUE)
  subregions <- sf::st_read("config/spatial/hydrographic_subregions.geojson", quiet = TRUE)
  screen_one_file <- function(i) {
    output <- system2(
      "ncdump", c("-v", "TIME,LATITUDE,LONGITUDE,CHLT,CHLT_QC", nc_files[[i]]),
      stdout = TRUE, stderr = TRUE
    )
    status <- attr(output, "status") %||% 0L
    if (status != 0L) {
      stop(sprintf("ncdump failed for %s: %s", nc_files[[i]], paste(output, collapse = "\n")),
           call. = FALSE)
    }
    relative_path <- file.path(pin$run_relative_path[[1]], basename(nc_files[[i]]))
    inventory <- parse_header_inventory(output, relative_path)
    time <- extract_block(output, "TIME")
    latitude <- extract_block(output, "LATITUDE")
    longitude <- extract_block(output, "LONGITUDE")
    chlorophyll <- extract_block(output, "CHLT")
    chlorophyll_qc <- extract_block(output, "CHLT_QC")
    lengths <- c(length(time), length(latitude), length(longitude), length(chlorophyll),
                 length(chlorophyll_qc))
    if (length(unique(lengths)) != 1L || !length(time)) {
      stop(sprintf("DS27 variable lengths do not reconcile in %s.", nc_files[[i]]), call. = FALSE)
    }
    valid_coordinate <- is.finite(latitude) & is.finite(longitude) & latitude >= -90 & latitude <= 90 &
      longitude >= -180 & longitude <= 180
    valid_time <- is.finite(time)
    chlorophyll_present <- is.finite(chlorophyll) & chlorophyll > -900
    qc_eligible <- chlorophyll_qc %in% c(1, 2)
    usable <- valid_coordinate & valid_time & chlorophyll_present & qc_eligible

    domain_state <- rep("invalid_coordinate", length(time))
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
      region_index <- vapply(hits, function(value) if (length(value)) value[[1]] else NA_integer_,
                             integer(1))
      if (anyNA(region_index)) stop("An in-domain DS27 point lacks a frozen subregion.", call. = FALSE)
      selected <- points$row[in_domain]
      domain_state[selected] <- ifelse(subregions$role[region_index] == "core-domain",
                                       "core", "external_transfer")
    }
    datetime <- as.POSIXct(time * 86400, origin = "1950-01-01", tz = "UTC")
    file_summary <- data.frame(
      file_name = basename(nc_files[[i]]),
      raw_relative_path = relative_path,
      source_rows = length(time),
      valid_coordinate_rows = sum(valid_coordinate),
      valid_time_rows = sum(valid_time),
      chlorophyll_present_rows = sum(chlorophyll_present),
      qc_eligible_chlorophyll_rows = sum(chlorophyll_present & qc_eligible),
      usable_secondary_rows = sum(usable),
      core_usable_rows = sum(usable & domain_state == "core"),
      external_transfer_usable_rows = sum(usable & domain_state == "external_transfer"),
      outside_domain_usable_rows = sum(usable & domain_state == "outside_domain"),
      invalid_coordinate_usable_rows = sum(usable & domain_state == "invalid_coordinate"),
      first_datetime_utc = if (any(valid_time)) format(min(datetime[valid_time]), "%Y-%m-%dT%H:%M:%SZ",
                                                       tz = "UTC") else "",
      last_datetime_utc = if (any(valid_time)) format(max(datetime[valid_time]), "%Y-%m-%dT%H:%M:%SZ",
                                                      tz = "UTC") else "",
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
    list(file_summary = file_summary, variable_inventory = inventory)
  }

  worker_count <- min(8L, parallel::detectCores(logical = FALSE), length(nc_files))
  results <- parallel::mclapply(
    seq_along(nc_files), screen_one_file, mc.cores = worker_count, mc.preschedule = FALSE
  )
  failed <- vapply(results, inherits, logical(1), what = "try-error")
  if (any(failed)) {
    stop(sprintf("DS27 parallel NetCDF screening failed: %s",
                 paste(as.character(results[failed]), collapse = "\n")), call. = FALSE)
  }
  file_summaries <- lapply(results, `[[`, "file_summary")
  inventories <- lapply(results, `[[`, "variable_inventory")
  file_summary <- do.call(rbind, file_summaries)
  variable_inventory <- do.call(rbind, inventories)
  validate_stage2_table(variable_inventory, "variable_inventory", contract)
  if (nrow(file_summary) != 679L || anyDuplicated(file_summary$file_name) ||
      sum(file_summary$usable_secondary_rows) <= 0L ||
      sum(file_summary$core_usable_rows) + sum(file_summary$external_transfer_usable_rows) <= 0L) {
    stop("DS27 file-level screening failed count, identity, or domain assertions.", call. = FALSE)
  }

  component_summary <- data.frame(
    provider_dataset_id = c("PANGAEA.883824", "PANGAEA.930383"),
    archived_component = c("679 FerryBox NetCDF transects", "17 pCO2 child tables"),
    checksum_evidence = c(calculate_checksum(description_path), calculate_checksum(pco2_zip)),
    relevant_variable = c("chlorophyll-a fluorescence", "none"),
    provisional_tier = c("E", "not_applicable"),
    analysis_role = c("comparator", "excluded"),
    screening_decision = c("secondary", "excluded"),
    exclusion_reason_code = c("none", "non_phytoplankton_record"),
    screening_detail = c(
      "CC-BY-3.0 surface chlorophyll fluorescence retained as a route-constrained Tier E comparator.",
      "The archived collection contains pCO2, temperature, and salinity only; it is retained in provenance but excluded from phytoplankton evidence."
    ),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  summary <- data.frame(
    work_item_id = "REGISTER:DS27",
    record_count = as.integer(sum(file_summary$usable_secondary_rows)),
    core_record_count = as.integer(sum(file_summary$core_usable_rows)),
    external_transfer_record_count = as.integer(sum(file_summary$external_transfer_usable_rows)),
    cmems_overlap_record_count = 0L,
    duplicate_record_count = 0L,
    provisional_tier = "E",
    analysis_role = "comparator",
    screening_decision = "secondary",
    exclusion_reason_code = "none",
    screening_detail = paste0(
      "PANGAEA.883824 record-screened across 679 NetCDF transects using an R-controlled ncdump ",
      "bridge: ", sum(file_summary$usable_secondary_rows), " QC-eligible chlorophyll-fluorescence ",
      "rows are retained as a Tier E surface, route-constrained comparator. Fluorescence is not ",
      "carbon and cannot define total-biomass bloom truth. PANGAEA.930383 is excluded from ",
      "phytoplankton evidence because it contains only pCO2, temperature, and salinity. Exact CMEMS ",
      "overlap remains a later-stage audit; zero here means unknown, not absent."
    ),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  validate_stage2_table(summary, "dataset_screening_summary", contract)

  output_paths <- c(
    file_screening = "metadata/stage2/screening/ds27_ferrybox_file_screening.csv",
    variable_inventory = "metadata/stage2/screening/ds27_ferrybox_variable_inventory.csv",
    component_summary = "metadata/stage2/screening/ds27_ferrybox_component_summary.csv",
    dataset_screening_summary = "metadata/stage2/screening/ds27_ferrybox_screening_summary.csv"
  )
  output_values <- list(file_summary, variable_inventory, component_summary, summary)
  for (i in seq_along(output_paths)) write_csv_atomic(output_values[[i]], output_paths[[i]])
  registry <- data.frame(
    artifact_role = names(output_paths),
    path = unname(output_paths),
    row_count = vapply(output_values, nrow, integer(1)),
    checksum_sha256 = vapply(unname(output_paths), calculate_checksum, character(1)),
    generated_from_manifest_sha256 = pin$manifest_checksum_sha256[[1]],
    decoder = "R-controlled ncdump",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  write_csv_atomic(registry, "metadata/stage2/screening/ds27_ferrybox_output_registry.csv")
  message(sprintf(
    "DS27 screening complete: %d Tier E rows across %d NetCDF transects; pCO2 component excluded.",
    summary$record_count, nrow(file_summary)
  ))
}

main()
