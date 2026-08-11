#!/usr/bin/env Rscript
# Build partitioned provisional taxon-observation tables while preserving original measurement fields.

source("R/00_core_setup.R")
source("R/03_stage2_contract.R")
source("R/05_stage3_contract.R")
source("R/07_stage5_contract.R")

contract <- stage5_read_source_contract()
output_dir <- "data/interim/stage5/canonical"
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
manifest_rows <- list()
summary_rows <- list()

canonical_names <- c(
  "record_id", "ds_id", "monitoring_network", "source_path", "source_row_number",
  "provider_dataset_id", "provider_record_id", "sample_id", "reported_station_id",
  "reported_datetime", "datetime_utc", "datetime_precision", "latitude", "longitude",
  "subregion_id", "depth_min_m", "depth_max_m", "reported_taxon_name", "reported_aphia_id",
  "reported_size_class", "reported_lifeforms", "reported_life_stage", "reported_colony_form",
  "reported_measurement", "reported_value", "reported_unit", "value_numeric",
  "harmonized_measurement", "harmonized_unit", "quality_flag", "sampling_method",
  "analysis_method", "screening_decision", "taxonomy_state", "conversion_state"
)

blank <- function(n) rep("", n)
character_or_blank <- function(value, n) {
  if (is.null(value)) return(blank(n))
  value <- as.character(value)
  value[is.na(value)] <- ""
  value
}
numeric_text <- function(value) {
  result <- suppressWarnings(as.numeric(gsub(",", ".", as.character(value), fixed = TRUE)))
  result
}
format_datetime <- function(value) {
  parsed <- stage3_parse_datetime(value)
  result <- format(parsed, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  result[is.na(parsed)] <- ""
  result
}

open_partition <- function(ds_id) {
  partial <- file.path(output_dir, paste0(tolower(ds_id), "_taxon_observations.csv.partial"))
  if (file.exists(partial)) unlink(partial)
  list(partial = partial, final = sub("[.]partial$", "", partial), header = TRUE, rows = 0L,
       in_domain = 0L, with_aphia = 0L, carbon = 0L, biovolume = 0L, abundance = 0L)
}
append_partition <- function(state, value) {
  if (!identical(names(value), canonical_names)) stop("Canonical Stage 5 column order changed.", call. = FALSE)
  utils::write.table(value, state$partial, sep = ",", row.names = FALSE, col.names = state$header,
                     append = !state$header, quote = TRUE, na = "", qmethod = "double",
                     fileEncoding = "UTF-8")
  state$header <- FALSE
  state$rows <- state$rows + nrow(value)
  state$in_domain <- state$in_domain + sum(value$subregion_id %in%
                                             c("southern_and_central_north_sea", "skagerrak_kattegat"))
  state$with_aphia <- state$with_aphia + sum(nzchar(value$reported_aphia_id))
  state$carbon <- state$carbon + sum(value$harmonized_measurement == "carbon_concentration")
  state$biovolume <- state$biovolume + sum(value$harmonized_measurement == "biovolume_concentration")
  state$abundance <- state$abundance + sum(value$harmonized_measurement %in%
                                             c("abundance", "reported_count_or_percentage"))
  state
}
finish_partition <- function(ds_id, state) {
  if (!file.exists(state$partial) || state$rows < 1L) stop(sprintf("Empty canonical partition: %s", ds_id), call. = FALSE)
  if (file.exists(state$final) && unlink(state$final) != 0L) stop("Cannot replace canonical output.", call. = FALSE)
  if (!file.rename(state$partial, state$final)) stop("Cannot finalize canonical output.", call. = FALSE)
  manifest_rows[[ds_id]] <<- data.frame(
    ds_id = ds_id, path = state$final, row_count = state$rows,
    file_size_bytes = unname(file.size(state$final)), checksum_sha256 = calculate_checksum(state$final),
    row_unit = "provider_taxon_measurement_record",
    canonical_state = "provisional_core_fields_method_and_taxon_resolution_incomplete",
    stringsAsFactors = FALSE, check.names = FALSE
  )
  summary_rows[[ds_id]] <<- data.frame(
    ds_id = ds_id, monitoring_network = contract$monitoring_network[match(ds_id, contract$ds_id)],
    source_rows = state$rows, in_frozen_subregion_rows = state$in_domain,
    rows_with_reported_aphia_id = state$with_aphia, provider_carbon_rows = state$carbon,
    provider_biovolume_rows = state$biovolume, abundance_or_count_rows = state$abundance,
    total_biomass_ready_rows = 0L, canonical_state = "provisional_not_stage5_gate_passed",
    stringsAsFactors = FALSE, check.names = FALSE
  )
}

build_identity_partition <- function(ds_id, identity_path, screening_path) {
  state <- open_partition(ds_id)
  network <- contract$monitoring_network[match(ds_id, contract$ds_id)]
  total <- stage5_stream_csv_pair(identity_path, screening_path, function(identity, screening, row_number) {
    if (!identical(as.character(identity$record_id), as.character(screening$record_id))) {
      stop(sprintf("%s identity and screening rows are misaligned.", ds_id), call. = FALSE)
    }
    n <- nrow(identity)
    if (ds_id == "DS02") {
      measurement <- rep("reported_count_or_percentage", n)
      unit <- character_or_blank(identity$unit, n)
      sample_id <- paste(screening$datetime_utc, identity$station_code, sep = "|")
      value <- data.frame(
        record_id = identity$record_id, ds_id = ds_id, monitoring_network = network,
        source_path = screening$raw_relative_path, source_row_number = screening$source_row_number,
        provider_dataset_id = identity$provider_dataset_id, provider_record_id = screening$provider_record_id,
        sample_id = sample_id, reported_station_id = identity$station_code,
        reported_datetime = screening$reported_datetime, datetime_utc = screening$datetime_utc,
        datetime_precision = "datetime", latitude = screening$latitude, longitude = screening$longitude,
        subregion_id = character_or_blank(screening$subregion_id, n), depth_min_m = NA_real_, depth_max_m = NA_real_,
        reported_taxon_name = identity$parameter, reported_aphia_id = blank(n),
        reported_size_class = blank(n), reported_lifeforms = blank(n), reported_life_stage = blank(n),
        reported_colony_form = blank(n), reported_measurement = identity$quantity,
        reported_value = identity$value, reported_unit = unit, value_numeric = numeric_text(identity$value),
        harmonized_measurement = measurement, harmonized_unit = unit, quality_flag = blank(n),
        sampling_method = blank(n), analysis_method = blank(n),
        screening_decision = screening$screening_decision,
        taxonomy_state = "reported_name_requires_cached_worms_resolution",
        conversion_state = "not_applied_pending_taxonomy_size_unit_and_method_audit",
        stringsAsFactors = FALSE, check.names = FALSE
      )
    } else {
      parameter <- tolower(trimws(identity$parameter))
      harmonized <- ifelse(grepl("carbon", parameter), "carbon_concentration",
                    ifelse(grepl("biovolume", parameter), "biovolume_concentration",
                    ifelse(grepl("abundance|count", parameter), "abundance", "unresolved_measurement")))
      sample_id <- identity$shark_sample_id_md5
      value <- data.frame(
        record_id = identity$record_id, ds_id = ds_id, monitoring_network = network,
        source_path = screening$raw_relative_path, source_row_number = screening$source_row_number,
        provider_dataset_id = identity$provider_dataset_id, provider_record_id = screening$provider_record_id,
        sample_id = sample_id, reported_station_id = blank(n),
        reported_datetime = screening$reported_datetime, datetime_utc = screening$datetime_utc,
        datetime_precision = ifelse(nzchar(screening$datetime_utc), "datetime", "date"),
        latitude = screening$latitude, longitude = screening$longitude,
        subregion_id = character_or_blank(screening$subregion_id, n),
        depth_min_m = numeric_text(identity$sample_min_depth_m), depth_max_m = numeric_text(identity$sample_max_depth_m),
        reported_taxon_name = identity$scientific_name,
        reported_aphia_id = character_or_blank(identity$aphia_id, n), reported_size_class = blank(n),
        reported_lifeforms = blank(n), reported_life_stage = blank(n), reported_colony_form = blank(n),
        reported_measurement = identity$parameter, reported_value = identity$value,
        reported_unit = identity$unit, value_numeric = numeric_text(identity$value),
        harmonized_measurement = harmonized, harmonized_unit = identity$unit,
        quality_flag = blank(n), sampling_method = blank(n), analysis_method = blank(n),
        screening_decision = screening$screening_decision,
        taxonomy_state = ifelse(nzchar(character_or_blank(identity$aphia_id, n)),
                                "reported_aphia_requires_cached_worms_validation",
                                "reported_name_requires_cached_worms_resolution"),
        conversion_state = ifelse(harmonized == "carbon_concentration", "provider_carbon_preserved",
                           ifelse(harmonized == "biovolume_concentration", "provider_biovolume_preserved",
                                  "not_applied_pending_size_and_method_audit")),
        stringsAsFactors = FALSE, check.names = FALSE
      )
    }
    state <<- append_partition(state, value[canonical_names])
  }, chunk_lines = 10000L)
  if (total != state$rows) stop(sprintf("%s canonical row total mismatch.", ds_id), call. = FALSE)
  finish_partition(ds_id, state)
}

build_plet_partition <- function(ds_id) {
  state <- open_partition(ds_id)
  network <- contract$monitoring_network[match(ds_id, contract$ds_id)]
  row <- contract[contract$ds_id == ds_id, , drop = FALSE]
  files <- stage5_resolve_source(row)$files
  path <- files$path[grepl("[.]csv$", files$path, ignore.case = TRUE)]
  if (length(path) != 1L) stop(sprintf("Expected one PLET payload for %s.", ds_id), call. = FALSE)
  raw_checksum <- files$checksum_sha256[match(path, files$path)]
  total <- stage5_stream_csv(path, function(chunk, row_number) {
    n <- nrow(chunk)
    required <- c("dataset_name", "date", "time", "latitude", "longitude", "depth_min", "depth_max",
                  "aphia_id", "size_class", "taxon", "abundance", "lifeforms")
    if (!all(required %in% names(chunk))) stop(sprintf("%s PLET schema changed.", ds_id), call. = FALSE)
    time <- character_or_blank(chunk$time, n)
    reported_datetime <- ifelse(nzchar(trimws(time)), paste(chunk$date, time), as.character(chunk$date))
    datetime_utc <- format_datetime(reported_datetime)
    latitude <- suppressWarnings(as.numeric(chunk$latitude)); longitude <- suppressWarnings(as.numeric(chunk$longitude))
    subregion <- stage3_assign_subregion(latitude, longitude)
    sample_id <- paste(chunk$date, time, latitude, longitude, chunk$depth_min, chunk$depth_max,
                       character_or_blank(chunk$comment_sample, n), sep = "|")
    record_id <- paste(ds_id, substr(raw_checksum, 1L, 12L), row_number, sep = "-")
    value <- data.frame(
      record_id = record_id, ds_id = ds_id, monitoring_network = network,
      source_path = path, source_row_number = row_number, provider_dataset_id = chunk$dataset_name,
      provider_record_id = paste(chunk$dataset_name, row_number, sep = ":"), sample_id = sample_id,
      reported_station_id = blank(n), reported_datetime = reported_datetime, datetime_utc = datetime_utc,
      datetime_precision = ifelse(nzchar(trimws(time)), "datetime", "date"),
      latitude = latitude, longitude = longitude, subregion_id = subregion,
      depth_min_m = suppressWarnings(as.numeric(chunk$depth_min)), depth_max_m = suppressWarnings(as.numeric(chunk$depth_max)),
      reported_taxon_name = chunk$taxon, reported_aphia_id = character_or_blank(chunk$aphia_id, n),
      reported_size_class = character_or_blank(chunk$size_class, n),
      reported_lifeforms = character_or_blank(chunk$lifeforms, n), reported_life_stage = blank(n),
      reported_colony_form = blank(n), reported_measurement = "abundance",
      reported_value = as.character(chunk$abundance), reported_unit = "not_reported_in_plet_export",
      value_numeric = suppressWarnings(as.numeric(chunk$abundance)), harmonized_measurement = "abundance",
      harmonized_unit = "", quality_flag = blank(n), sampling_method = blank(n), analysis_method = blank(n),
      screening_decision = ifelse(subregion == "outside_or_invalid", "excluded_outside_frozen_subregions",
                                  "pending_stage5_compatibility"),
      taxonomy_state = ifelse(nzchar(character_or_blank(chunk$aphia_id, n)),
                              "reported_aphia_requires_cached_worms_validation",
                              "reported_name_requires_cached_worms_resolution"),
      conversion_state = "not_applied_pending_unit_taxonomy_size_and_method_audit",
      stringsAsFactors = FALSE, check.names = FALSE
    )
    state <<- append_partition(state, value[canonical_names])
  }, chunk_lines = 5000L)
  if (total != state$rows) stop(sprintf("%s canonical row total mismatch.", ds_id), call. = FALSE)
  finish_partition(ds_id, state)
}

build_identity_partition("DS02", "data/interim/stage2_ds02_rws_duplicate_identity.csv",
                         "data/interim/stage2_ds02_rws_record_screening_resolved.csv")
build_identity_partition("DS06", "data/interim/stage2_ds06_smhi_shark_duplicate_identity.csv",
                         "data/interim/stage2_ds06_smhi_shark_record_screening_resolved.csv")
for (ds_id in c("DS04", "DS05", "DS07", "DS16")) build_plet_partition(ds_id)

manifest <- do.call(rbind, manifest_rows)
summary <- do.call(rbind, summary_rows)
row.names(manifest) <- NULL; row.names(summary) <- NULL
if (!identical(summary$ds_id, c("DS02", "DS06", "DS04", "DS05", "DS07", "DS16")) ||
    any(summary$source_rows < 1L) || any(summary$total_biomass_ready_rows != 0L)) {
  stop("Provisional canonical Stage 5 summary violates its conservative contract.", call. = FALSE)
}
dir.create("metadata/stage5/harmonization", recursive = TRUE, showWarnings = FALSE)
write_csv_atomic(manifest, "metadata/stage5/harmonization/canonical_partition_manifest.csv")
write_csv_atomic(summary, "metadata/stage5/harmonization/canonical_observation_summary.csv")
message(sprintf("Built six provisional canonical partitions containing %d provider records.",
                sum(summary$source_rows)))
