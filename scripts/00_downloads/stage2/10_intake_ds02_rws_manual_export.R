# Register and integrity-check the four-part manual Waterinfo export for rank-3 DS02.

source("R/00_core_setup.R")
source("R/03_stage2_contract.R")
required_namespace("jsonlite")
required_namespace("digest")

config_path <- "config/stage2_ds02_rws_manual_export_intake.json"
cfg <- jsonlite::fromJSON(config_path, simplifyVector = FALSE)
contract <- read_stage2_contract(cfg$contract_path)
if (!identical(cfg$classification,
               "stage2_ranked_canonical_provider_manual_export_intake") ||
    !identical(cfg$work_item_id, "REGISTER:DS02") || cfg$acquisition_rank != 3L ||
    !identical(cfg$provider, "Rijkswaterstaat (RWS)") ||
    !identical(cfg$portal_category, "Overige biologische data") ||
    !setequal(unlist(cfg$portal_filters$taxon_type, use.names = FALSE),
              c("FYTPT", "DIATM"))) {
  stop("DS02 RWS manual-export intake configuration is invalid.", call. = FALSE)
}

verify_raw_data_target(required_gb = cfg$required_free_gb)
expected <- cfg$expected_files
filenames <- vapply(expected, `[[`, character(1), "filename")
if (length(filenames) != 4L || anyDuplicated(filenames)) {
  stop("DS02 manual-export intake must name four unique delivered files.", call. = FALSE)
}
source_relative_paths <- file.path(cfg$raw_parent_relative_path, filenames)
source_paths <- file.path("data", "raw", source_relative_paths)
if (any(!file.exists(source_paths)) || any(dir.exists(source_paths))) {
  stop(sprintf("Delivered DS02 files are missing: %s",
               paste(source_paths[!file.exists(source_paths)], collapse = ", ")),
       call. = FALSE)
}

# The checksums in the frozen intake configuration identify the files supplied by the user. The
# script never moves, rewrites, or normalizes those raw artifacts.
observed_sizes <- unname(file.info(source_paths)$size)
expected_sizes <- vapply(expected, function(x) as.numeric(x$size_bytes), numeric(1))
observed_checksums <- vapply(source_paths, calculate_checksum, character(1))
expected_checksums <- vapply(expected, `[[`, character(1), "checksum_sha256")
if (!identical(observed_sizes, expected_sizes) ||
    !identical(unname(observed_checksums), unname(expected_checksums))) {
  stop("Delivered DS02 files differ from the frozen size/checksum identities.", call. = FALSE)
}

run_relative <- file.path(cfg$raw_parent_relative_path, cfg$acquisition_run_id)
final_dir <- file.path("data", "raw", run_relative)
staging_dir <- paste0(final_dir, ".partial")

tracked_manifest_path <- "metadata/stage2/acquisition/ds02_rws_manual_export_acquisition_manifest.csv"
tracked_inventory_path <- "metadata/stage2/acquisition/ds02_rws_manual_export_file_inventory.csv"
tracked_summary_path <- "metadata/stage2/acquisition/ds02_rws_manual_export_intake_summary.csv"
tracked_pin_path <- "metadata/stage2/acquisition/ds02_rws_manual_export_active_run.csv"

write_tracked <- function(directory) {
  manifest <- utils::read.csv(file.path(directory, "manifest.csv"),
                              stringsAsFactors = FALSE, check.names = FALSE)
  inventory <- utils::read.csv(file.path(directory, "file_inventory.csv"),
                               stringsAsFactors = FALSE, check.names = FALSE)
  intake_summary <- utils::read.csv(file.path(directory, "intake_summary.csv"),
                                    stringsAsFactors = FALSE, check.names = FALSE)
  run_summary <- jsonlite::fromJSON(file.path(directory, "run_summary.json"),
                                    simplifyVector = FALSE)
  validate_stage2_table(manifest, "acquisition_manifest", contract)
  pin <- data.frame(
    work_item_id = cfg$work_item_id,
    run_relative_path = run_relative,
    completed_utc = run_summary$completed_utc,
    configuration_path = config_path,
    configuration_checksum_sha256 = run_summary$configuration_checksum_sha256,
    manifest_checksum_sha256 = calculate_checksum(file.path(directory, "manifest.csv")),
    file_inventory_checksum_sha256 = calculate_checksum(file.path(directory, "file_inventory.csv")),
    intake_summary_checksum_sha256 = calculate_checksum(file.path(directory, "intake_summary.csv")),
    run_summary_checksum_sha256 = calculate_checksum(file.path(directory, "run_summary.json")),
    source_artifact_count = nrow(manifest),
    total_size_bytes = sum(manifest$size_bytes),
    observation_rows = intake_summary$observation_rows[[1]],
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  write_csv_atomic(manifest, tracked_manifest_path)
  write_csv_atomic(inventory, tracked_inventory_path)
  write_csv_atomic(intake_summary, tracked_summary_path)
  write_csv_atomic(pin, tracked_pin_path)
  invisible(list(manifest = manifest, inventory = inventory, summary = intake_summary))
}

validate_complete_run <- function(directory) {
  required <- file.path(directory, c(
    "intake_parameters.json", "manifest.csv", "file_inventory.csv", "intake_summary.csv",
    "run_summary.json", "run.log"
  ))
  if (any(!file.exists(required))) {
    stop("Existing finalized DS02 manual-export intake is incomplete.", call. = FALSE)
  }
  run_summary <- jsonlite::fromJSON(file.path(directory, "run_summary.json"),
                                    simplifyVector = FALSE)
  if (!identical(run_summary$status, "complete") ||
      !identical(run_summary$configuration_checksum_sha256,
                 calculate_checksum(config_path))) {
    stop("Existing DS02 manual-export intake differs from its frozen configuration.",
         call. = FALSE)
  }
  tracked <- write_tracked(directory)
  if (nrow(tracked$manifest) != 4L ||
      any(vapply(seq_len(nrow(tracked$manifest)), function(i) {
        path <- file.path("data", "raw", tracked$manifest$raw_relative_path[[i]])
        !file.exists(path) ||
          !identical(calculate_checksum(path), tracked$manifest$checksum_sha256[[i]])
      }, logical(1)))) {
    stop("Existing DS02 manual-export manifest does not reconcile with delivered files.",
         call. = FALSE)
  }
  tracked
}

if (dir.exists(final_dir)) {
  tracked <- validate_complete_run(final_dir)
  message(sprintf(
    "Verified existing DS02 RWS manual export: %d files and %.0f observation rows.",
    nrow(tracked$manifest), tracked$summary$observation_rows[[1]]
  ))
  quit(save = "no", status = 0L)
}
if (dir.exists(staging_dir)) {
  stop(sprintf("Incomplete intake staging directory exists: %s", staging_dir), call. = FALSE)
}
dir.create(staging_dir, recursive = TRUE, showWarnings = FALSE)

# Parse only enough provider fields to validate the delivery. A known Waterinfo export defect adds
# one unheaded location-description field to 105 part-4 rows. Those bytes remain untouched; the
# extra field is removed only from an in-memory view after its exact signature is verified.
parse_export_part <- function(path, raw_relative_path, expected_columns) {
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8", skipNul = FALSE)
  if (length(lines) < 2L) stop(sprintf("DS02 export has no data rows: %s", path), call. = FALSE)
  header_line <- lines[[1]]
  header <- strsplit(header_line, ";", fixed = TRUE)[[1]]
  if (length(header) != length(expected_columns) || anyDuplicated(header) ||
      !setequal(header, expected_columns)) {
    stop(sprintf("DS02 export schema differs from the expected 25-column set: %s", path),
         call. = FALSE)
  }
  data_lines <- lines[-1L]
  # Appending a sentinel preserves terminal empty fields, which base strsplit otherwise drops.
  fields <- strsplit(paste0(data_lines, "__DS02_LINE_END__"), ";", fixed = TRUE)
  fields <- lapply(fields, function(row) {
    row[[length(row)]] <- sub("__DS02_LINE_END__$", "", row[[length(row)]])
    row
  })
  field_counts <- lengths(fields)
  if (any(!field_counts %in% c(length(header), length(header) + 1L))) {
    stop(sprintf("DS02 export contains an unsupported field count: %s", path), call. = FALSE)
  }
  irregular <- which(field_counts == length(header) + 1L)
  if (length(irregular)) {
    valid_signature <- vapply(fields[irregular], function(row) {
      identical(row[[2]], "HARVSZBNZKT") &&
        identical(row[[3]], "Haringvlietsluizen binnen zuidkant") &&
        identical(row[[4]], "RWS")
    }, logical(1))
    if (!all(valid_signature)) {
      stop("Unheaded DS02 fields do not match the documented location-description anomaly.",
           call. = FALSE)
    }
    fields[irregular] <- lapply(fields[irregular], function(row) row[-3L])
  }
  if (any(lengths(fields) != length(header))) {
    stop("DS02 in-memory field alignment failed.", call. = FALSE)
  }
  field_index <- stats::setNames(seq_along(header), header)
  extract <- function(name) vapply(fields, `[[`, character(1), field_index[[name]])
  date_text <- extract("Datum")
  date_utc <- as.POSIXct(
    sub(" \\+00:00$", "", date_text),
    format = "%d-%m-%Y %H:%M:%S", tz = "UTC"
  )
  if (anyNA(date_utc)) stop(sprintf("DS02 export contains an invalid UTC date: %s", path),
                            call. = FALSE)
  target_start <- as.POSIXct("2000-01-01 00:00:00", tz = "UTC")
  target_end <- as.POSIXct("2020-01-01 00:00:00", tz = "UTC")
  in_target <- date_utc >= target_start & date_utc < target_end
  meetobjects <- extract("Meetobject")
  parameters <- extract("Parameter")
  taxon_types <- extract("Taxon type")
  quantities <- extract("Grootheid")
  units <- extract("Eenheid")
  organisations <- extract("Organisatie")
  compartments <- extract("Compartiment")
  if (any(!taxon_types %in% unlist(cfg$portal_filters$taxon_type, use.names = FALSE)) ||
      any(organisations != "RWS")) {
    stop(sprintf("DS02 export content does not match the stated provider/taxon filter: %s", path),
         call. = FALSE)
  }
  inventory <- data.frame(
    filename = basename(path),
    raw_relative_path = raw_relative_path,
    size_bytes = unname(file.info(path)$size),
    checksum_sha256 = calculate_checksum(path),
    header_checksum_sha256 = digest::digest(header_line, algo = "sha256", serialize = FALSE),
    column_count = length(header),
    observation_rows = length(data_lines),
    regular_field_count_rows = sum(field_counts == length(header)),
    extra_location_description_rows = length(irregular),
    date_min_utc = format(min(date_utc), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    date_max_utc = format(max(date_utc), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    target_2000_2019_rows = sum(in_target),
    outside_target_period_rows = sum(!in_target),
    meetobject_count = length(unique(meetobjects)),
    parameter_count = length(unique(parameters)),
    taxon_type_values = paste(sort(unique(taxon_types)), collapse = "|"),
    quantity_values = paste(sort(unique(quantities)), collapse = "|"),
    unit_values = paste(sort(unique(units)), collapse = "|"),
    compartment_values = paste(sort(unique(compartments)), collapse = "|"),
    organisation_values = paste(sort(unique(organisations)), collapse = "|"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  list(
    inventory = inventory,
    raw_data_lines = data_lines,
    meetobjects = unique(meetobjects),
    parameters = unique(parameters),
    date_utc = date_utc,
    taxon_types = unique(taxon_types),
    quantities = unique(quantities),
    units = unique(units),
    compartments = unique(compartments)
  )
}

expected_columns <- unlist(cfg$expected_columns, use.names = FALSE)
parts <- lapply(seq_along(source_paths), function(i) {
  parse_export_part(source_paths[[i]], source_relative_paths[[i]], expected_columns)
})
inventory <- do.call(rbind, lapply(parts, `[[`, "inventory"))
if (!identical(inventory$size_bytes, expected_sizes) ||
    !identical(inventory$checksum_sha256, unname(expected_checksums))) {
  stop("DS02 parsed inventory differs from frozen source identities.", call. = FALSE)
}

station_overlap <- 0L
for (i in seq_len(length(parts) - 1L)) {
  for (j in seq.int(i + 1L, length(parts))) {
    station_overlap <- station_overlap +
      length(intersect(parts[[i]]$meetobjects, parts[[j]]$meetobjects))
  }
}
all_lines <- unlist(lapply(parts, `[[`, "raw_data_lines"), use.names = FALSE)
all_dates <- do.call(c, lapply(parts, `[[`, "date_utc"))
all_meetobjects <- unique(unlist(lapply(parts, `[[`, "meetobjects"), use.names = FALSE))
all_parameters <- unique(unlist(lapply(parts, `[[`, "parameters"), use.names = FALSE))
all_taxon_types <- sort(unique(unlist(lapply(parts, `[[`, "taxon_types"), use.names = FALSE)))
all_quantities <- sort(unique(unlist(lapply(parts, `[[`, "quantities"), use.names = FALSE)))
all_units <- sort(unique(unlist(lapply(parts, `[[`, "units"), use.names = FALSE)))
all_compartments <- sort(unique(unlist(lapply(parts, `[[`, "compartments"), use.names = FALSE)))
if (station_overlap != 0L || !setequal(all_taxon_types, c("FYTPT", "DIATM"))) {
  stop("DS02 export parts overlap in stations or do not retain both stated taxon types.",
       call. = FALSE)
}

intake_summary <- data.frame(
  work_item_id = cfg$work_item_id,
  ds_id = cfg$ds_id,
  acquisition_run_id = cfg$acquisition_run_id,
  manual_export_date = cfg$manual_export_date,
  portal_url = cfg$portal_url,
  portal_category = cfg$portal_category,
  stated_taxon_type_filter = paste(unlist(cfg$portal_filters$taxon_type,
                                          use.names = FALSE), collapse = "|"),
  other_portal_filters_state = "not_reported",
  source_file_count = nrow(inventory),
  total_size_bytes = sum(inventory$size_bytes),
  observation_rows = sum(inventory$observation_rows),
  target_2000_2019_rows = sum(inventory$target_2000_2019_rows),
  outside_target_period_rows = sum(inventory$outside_target_period_rows),
  date_min_utc = format(min(all_dates), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  date_max_utc = format(max(all_dates), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  meetobject_count = length(all_meetobjects),
  parameter_count = length(all_parameters),
  taxon_type_values = paste(all_taxon_types, collapse = "|"),
  quantity_values = paste(all_quantities, collapse = "|"),
  unit_values = paste(all_units, collapse = "|"),
  compartment_values = paste(all_compartments, collapse = "|"),
  pairwise_station_overlap_count = station_overlap,
  raw_exact_duplicate_rows = sum(duplicated(all_lines)),
  extra_location_description_rows = sum(inventory$extra_location_description_rows),
  acquisition_state = "canonical_observations_acquired_pending_record_screening",
  screening_decision = "pending",
  status_detail = paste0(
    "Four unmodified canonical Waterinfo export parts are checksum-pinned. Dates, locations, ",
    "duplicates, the provider's unheaded-field anomaly, spatial eligibility, method epochs, and ",
    "biomass convertibility require record-level screening; no row is yet an event or negative."
  ),
  stringsAsFactors = FALSE,
  check.names = FALSE
)

configuration_checksum <- calculate_checksum(config_path)
file_mtimes <- format(file.info(source_paths)$mtime, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
manifest <- do.call(rbind, lapply(seq_along(source_paths), function(i) data.frame(
  ds_id = cfg$ds_id,
  acquisition_rank = as.integer(cfg$acquisition_rank),
  provider = cfg$provider,
  provider_dataset_id = paste0("RWS:", cfg$provider_service),
  canonical_provider_dataset_id = paste0("RWS:", cfg$provider_service),
  provider_version = paste0(cfg$provider_service, " manual export received ",
                            cfg$manual_export_date),
  source_role = "canonical_provider",
  request_method = "MANUAL_BROWSER_EXPORT",
  request_url = cfg$portal_url,
  request_parameters_sha256 = configuration_checksum,
  retrieved_utc = file_mtimes[[i]],
  raw_relative_path = source_relative_paths[[i]],
  filename = filenames[[i]],
  size_bytes = observed_sizes[[i]],
  checksum_sha256 = observed_checksums[[i]],
  content_type = "text/csv; delimiter=semicolon; encoding=ASCII",
  file_validation_state = "verified",
  license_state = "open",
  license_evidence = paste0(
    "Official RWS WaterWebservices documentation states that service contents are CC0; ",
    "the official phytoplankton page identifies Waterinfo as a provider route."
  ),
  redistribution_state = "allowed",
  citation = paste0(
    "Rijkswaterstaat. Waterinfo AquaDesk phytoplankton observations, manual bulk export. ",
    "Downloaded ", cfg$manual_export_date, "."
  ),
  doi_or_stable_url = cfg$official_phytoplankton_page,
  manifest_status = "verified",
  status_detail = paste0(
    "Unmodified provider-export part registered by scripted intake; local file modification time ",
    "is recorded as retrieved_utc because the manual portal did not deliver a machine-readable ",
    "request receipt."
  ),
  stringsAsFactors = FALSE,
  check.names = FALSE
)))
validate_stage2_table(manifest, "acquisition_manifest", contract)

intake_parameters <- list(
  portal_url = cfg$portal_url,
  portal_category = cfg$portal_category,
  portal_filters = cfg$portal_filters,
  manual_export_date = cfg$manual_export_date,
  manual_export_reason = cfg$manual_export_reason,
  delivered_filenames = filenames,
  selection_rule = cfg$selection_rule
)
write_json_atomic(intake_parameters, file.path(staging_dir, "intake_parameters.json"))
write_csv_atomic(manifest, file.path(staging_dir, "manifest.csv"))
write_csv_atomic(inventory, file.path(staging_dir, "file_inventory.csv"))
write_csv_atomic(intake_summary, file.path(staging_dir, "intake_summary.csv"))

completed_utc <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
run_summary <- list(
  schema_version = cfg$schema_version,
  completed_utc = completed_utc,
  status = "complete",
  work_item_id = cfg$work_item_id,
  acquisition_phase = "canonical_observations_acquired_pending_record_screening",
  source_artifact_count = nrow(manifest),
  total_size_bytes = sum(manifest$size_bytes),
  observation_rows = intake_summary$observation_rows[[1]],
  target_2000_2019_rows = intake_summary$target_2000_2019_rows[[1]],
  outside_target_period_rows = intake_summary$outside_target_period_rows[[1]],
  meetobject_count = intake_summary$meetobject_count[[1]],
  raw_exact_duplicate_rows = intake_summary$raw_exact_duplicate_rows[[1]],
  extra_location_description_rows = intake_summary$extra_location_description_rows[[1]],
  configuration_checksum_sha256 = configuration_checksum,
  contract_checksum_sha256 = calculate_checksum(cfg$contract_path),
  software_version = R.version.string
)
write_json_atomic(run_summary, file.path(staging_dir, "run_summary.json"))
writeLines(c(
  sprintf("completed_utc: %s", completed_utc),
  sprintf("acquisition_phase: %s", run_summary$acquisition_phase),
  sprintf("source_artifact_count: %d", run_summary$source_artifact_count),
  sprintf("total_size_bytes: %.0f", run_summary$total_size_bytes),
  sprintf("observation_rows: %.0f", run_summary$observation_rows),
  sprintf("target_2000_2019_rows: %.0f", run_summary$target_2000_2019_rows),
  sprintf("outside_target_period_rows: %.0f", run_summary$outside_target_period_rows),
  sprintf("meetobject_count: %.0f", run_summary$meetobject_count),
  sprintf("raw_exact_duplicate_rows: %.0f", run_summary$raw_exact_duplicate_rows),
  sprintf("extra_location_description_rows: %.0f",
          run_summary$extra_location_description_rows),
  sprintf("R: %s", R.version.string)
), file.path(staging_dir, "run.log"), useBytes = TRUE)

if (!file.rename(staging_dir, final_dir)) {
  stop("Unable to atomically finalize the DS02 RWS manual-export intake.", call. = FALSE)
}
tracked <- validate_complete_run(final_dir)
message(sprintf(
  paste0("DS02 RWS manual export registered: %d files, %.0f rows, %d stations; ",
         "record screening pending."),
  nrow(tracked$manifest), tracked$summary$observation_rows[[1]],
  tracked$summary$meetobject_count[[1]]
))
