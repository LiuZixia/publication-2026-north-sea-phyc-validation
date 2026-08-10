#!/usr/bin/env Rscript
# Build observation-only temporal, cadence, seasonal, spatial, and vertical coverage evidence.

source("R/00_core_setup.R")
source("R/03_stage2_contract.R")
source("R/05_stage3_contract.R")

manifest_path <- "metadata/stage3/input/stage3_input_manifest.csv"
if (!file.exists(manifest_path)) stop("Run 00_build_input_manifest.R first.", call. = FALSE)
manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE, check.names = FALSE)
complete <- manifest[manifest$work_state == "complete", , drop = FALSE]

sample_parts <- list()
cache_dir <- "data/interim/stage3_support"
dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
force_rebuild <- identical(Sys.getenv("STAGE3_REBUILD"), "1")
rebuild_ids <- trimws(strsplit(Sys.getenv("STAGE3_REBUILD_IDS"), ",", fixed = TRUE)[[1]])
rebuild_ids <- rebuild_ids[nzchar(rebuild_ids)]
for (i in seq_len(nrow(complete))) {
  ds <- complete$ds_id[[i]]
  cache_path <- file.path(cache_dir, paste0(tolower(ds), "_sample_support.csv"))
  rebuild_this <- force_rebuild || ds %in% rebuild_ids
  if (file.exists(cache_path) && !rebuild_this) {
    message(sprintf("Reusing Stage 3 sample-support cache for %s.", ds))
    part <- utils::read.csv(cache_path, stringsAsFactors = FALSE, check.names = FALSE)
  } else {
    message(sprintf("Building Stage 3 sample-support rows for %s (%s).", ds, complete$adapter_id[[i]]))
    part <- stage3_load_samples(complete[i, , drop = FALSE])
    if (!is.null(part)) write_csv_atomic(part, cache_path)
  }
  # Caches are disposable accelerators. Normalize the superseded DS24 visit label deterministically
  # so a cache created during adapter development cannot masquerade as stable station identity.
  if (!is.null(part) && ds == "DS24" && any(grepl("^comp4_station:", part$station_id))) {
    agency <- sub("^comp4_station:([^:]+):.*$", "\\1", part$station_id)
    station <- sub("^comp4_station:[^:]+:", "", part$station_id)
    cruise <- sub("^[^:]+:([^|]+)[|].*$", "\\1", part$sample_id)
    part$station_id <- paste("reported_visit", agency, cruise, station, sep = ":")
    write_csv_atomic(part, cache_path)
  }
  if (!is.null(part)) sample_parts[[ds]] <- part
}
samples <- do.call(rbind, sample_parts)
rownames(samples) <- NULL
if (!nrow(samples) || anyDuplicated(paste(samples$ds_id, samples$sample_id, sep = "|"))) {
  stop("Stage 3 sample-support table is empty or violates its dataset/sample key.", call. = FALSE)
}
if (!all(unique(samples$ds_id) %in% complete$ds_id)) stop("Unknown dataset in sample support.", call. = FALSE)
dir.create("data/interim", recursive = TRUE, showWarnings = FALSE)
write_csv_atomic(samples, "data/interim/stage3_sample_support.csv")

temporal <- stage3_summarize_temporal(samples)
if (!nrow(temporal) || anyDuplicated(temporal[c("ds_id", "monitoring_network", "subregion_id",
                                                "method_epoch", "year")])) {
  stop("Temporal coverage is empty or violates its unique key.", call. = FALSE)
}
dir.create("metadata/stage3/coverage", recursive = TRUE, showWarnings = FALSE)
write_csv_atomic(temporal, "metadata/stage3/coverage/temporal_cadence_by_year.csv")

# Retain the provider station or explicitly labelled coordinate/transect proxy in a separate table.
# This prevents a dense multi-station network from appearing to have the cadence of each station.
x_station <- samples[nzchar(samples$datetime_utc) &
  !grepl("^(coordinate_proxy|transect|reported_visit):|^unknown_station$", samples$station_id), , drop = FALSE]
x_station$year <- as.integer(format(stage3_parse_datetime(x_station$datetime_utc), "%Y"))
station_groups <- split(x_station, interaction(
  x_station$ds_id, x_station$monitoring_network, x_station$station_id,
  x_station$subregion_id, x_station$method_epoch, x_station$year,
  drop = TRUE, lex.order = TRUE
))
station_temporal <- do.call(rbind, lapply(station_groups, function(g) {
  dates <- sort(unique(as.Date(g$datetime_utc)))
  gaps <- if (length(dates) > 1L) as.numeric(diff(dates)) else numeric()
  data.frame(
    ds_id = g$ds_id[[1]], monitoring_network = g$monitoring_network[[1]],
    station_id = g$station_id[[1]], subregion_id = g$subregion_id[[1]],
    method_epoch = g$method_epoch[[1]], year = g$year[[1]],
    station_identity_state = "provider_station",
    first_date = as.character(min(dates)), last_date = as.character(max(dates)),
    sample_count = nrow(g), unique_sampling_days = length(dates),
    median_gap_days = if (length(gaps)) stats::median(gaps) else NA_real_,
    gap_p90_days = if (length(gaps)) unname(stats::quantile(gaps, 0.9, names = FALSE)) else NA_real_,
    longest_gap_days = if (length(gaps)) max(gaps) else NA_real_,
    stringsAsFactors = FALSE, check.names = FALSE
  )
}))
station_key <- c("ds_id", "monitoring_network", "station_id", "subregion_id", "method_epoch", "year")
if (!nrow(station_temporal) || anyDuplicated(station_temporal[station_key])) {
  stop("Station-year temporal coverage is empty or violates its unique key.", call. = FALSE)
}
write_csv_atomic(station_temporal, "metadata/stage3/coverage/temporal_cadence_by_station_year.csv")

# State explicitly which sources could not support station-resolved temporal summaries.
station_availability <- do.call(rbind, lapply(split(samples, samples$ds_id), function(g) {
  proxy <- grepl("^(coordinate_proxy|transect|reported_visit):|^unknown_station$", g$station_id)
  data.frame(
    ds_id = g$ds_id[[1]], monitoring_network = g$monitoring_network[[1]],
    sample_support_rows = nrow(g), provider_station_rows = sum(!proxy),
    coordinate_or_transect_proxy_rows = sum(proxy),
    distinct_provider_stations = length(unique(g$station_id[!proxy])),
    station_temporal_support_state = if (all(proxy)) "unavailable_only_coordinate_or_transect_proxy"
      else if (any(proxy)) "partial_provider_station_identity" else "provider_station_identity_available",
    stringsAsFactors = FALSE, check.names = FALSE
  )
}))
write_csv_atomic(station_availability, "metadata/stage3/coverage/station_temporal_availability.csv")

# Report time-of-day support only where the provider supplied datetime precision. Tidal phase is not
# reconstructed without a frozen tide source and remains an explicit unknown rather than an estimate.
x_time <- samples[nzchar(samples$datetime_utc), , drop = FALSE]
x_time$year <- as.integer(format(stage3_parse_datetime(x_time$datetime_utc), "%Y"))
x_time$hour_utc <- as.integer(format(stage3_parse_datetime(x_time$datetime_utc), "%H"))
time_groups <- split(x_time, interaction(x_time$ds_id, x_time$monitoring_network,
                                         x_time$subregion_id, x_time$year,
                                         drop = TRUE, lex.order = TRUE))
time_coverage <- do.call(rbind, lapply(time_groups, function(g) {
  precise <- g$datetime_precision %in% c("datetime", "minute", "file_start_datetime")
  data.frame(
    ds_id = g$ds_id[[1]], monitoring_network = g$monitoring_network[[1]],
    subregion_id = g$subregion_id[[1]], year = g$year[[1]], sample_count = nrow(g),
    datetime_precision_count = sum(precise),
    distinct_utc_hours = length(unique(g$hour_utc[precise & is.finite(g$hour_utc)])),
    time_of_day_support_state = if (any(precise)) "reported_datetime_available" else "date_only_or_unknown",
    tidal_phase_support_state = "unknown_no_frozen_tide_source",
    stringsAsFactors = FALSE, check.names = FALSE
  )
}))
time_key <- c("ds_id", "monitoring_network", "subregion_id", "year")
if (!nrow(time_coverage) || anyDuplicated(time_coverage[time_key])) {
  stop("Time-of-day coverage is empty or violates its unique key.", call. = FALSE)
}
write_csv_atomic(time_coverage, "metadata/stage3/coverage/time_of_day_coverage.csv")

# Seasonal support remains an effort statement; it is not a bloom or ecological result.
x <- samples[nzchar(samples$datetime_utc), , drop = FALSE]
dt <- stage3_parse_datetime(x$datetime_utc)
x$year <- as.integer(format(dt, "%Y")); x$month <- as.integer(format(dt, "%m"))
x$season <- stage3_season(x$month); x$sampling_date <- as.Date(dt)
season_groups <- split(x, interaction(x$ds_id, x$monitoring_network, x$subregion_id,
                                      x$method_epoch, x$year, x$season, drop = TRUE, lex.order = TRUE))
seasonal <- do.call(rbind, lapply(season_groups, function(g) data.frame(
  ds_id = g$ds_id[[1]], monitoring_network = g$monitoring_network[[1]],
  subregion_id = g$subregion_id[[1]], method_epoch = g$method_epoch[[1]],
  year = g$year[[1]], season = g$season[[1]], sample_count = nrow(g),
  unique_sampling_days = length(unique(g$sampling_date)),
  sampled_months = length(unique(g$month)),
  target_bloom_season_adequacy = "not_assessed_until_stage4_design",
  stringsAsFactors = FALSE, check.names = FALSE
)))
write_csv_atomic(seasonal, "metadata/stage3/coverage/seasonal_effort.csv")

# Report support locations without claiming that moving coordinates are monitoring stations.
samples$location_key <- ifelse(is.finite(samples$latitude) & is.finite(samples$longitude),
  paste(format(samples$latitude, digits = 9), format(samples$longitude, digits = 9), sep = ":"), "")
spatial_groups <- split(samples, interaction(samples$ds_id, samples$monitoring_network,
                                             samples$subregion_id, drop = TRUE, lex.order = TRUE))
spatial <- do.call(rbind, lapply(spatial_groups, function(g) {
  valid <- is.finite(g$latitude) & is.finite(g$longitude)
  actual_station <- !grepl("^(coordinate_proxy|transect|reported_visit):|^unknown_station$", g$station_id)
  data.frame(
    ds_id = g$ds_id[[1]], monitoring_network = g$monitoring_network[[1]],
    subregion_id = g$subregion_id[[1]], sample_count = nrow(g),
    coordinate_complete_count = sum(valid),
    unique_support_locations = length(unique(g$location_key[nzchar(g$location_key)])),
    named_station_count = length(unique(g$station_id[actual_station])),
    station_identity_state = if (all(actual_station)) "provider_station" else if (any(actual_station))
      "mixed_provider_and_proxy" else "coordinate_or_transect_proxy_not_station",
    latitude_min = if (any(valid)) min(g$latitude[valid]) else NA_real_,
    latitude_max = if (any(valid)) max(g$latitude[valid]) else NA_real_,
    longitude_min = if (any(valid)) min(g$longitude[valid]) else NA_real_,
    longitude_max = if (any(valid)) max(g$longitude[valid]) else NA_real_,
    spatial_interpolation_permitted = FALSE,
    stringsAsFactors = FALSE, check.names = FALSE
  )
}))
write_csv_atomic(spatial, "metadata/stage3/coverage/spatial_support.csv")

vertical_groups <- split(samples, interaction(samples$ds_id, samples$monitoring_network,
                                               samples$method_epoch, drop = TRUE, lex.order = TRUE))
vertical <- do.call(rbind, lapply(vertical_groups, function(g) {
  depth <- c(g$depth_min_m, g$depth_max_m); depth <- depth[is.finite(depth)]
  data.frame(
    ds_id = g$ds_id[[1]], monitoring_network = g$monitoring_network[[1]],
    method_epoch = g$method_epoch[[1]], sample_count = nrow(g),
    depth_reported_count = sum(is.finite(g$depth_min_m) | is.finite(g$depth_max_m)),
    depth_min_m = if (length(depth)) min(depth) else NA_real_,
    depth_max_m = if (length(depth)) max(depth) else NA_real_,
    vertical_support_state = if (length(depth)) "reported_depth_range_available" else "unknown_no_depth_in_stage3_adapter",
    stringsAsFactors = FALSE, check.names = FALSE
  )
}))
write_csv_atomic(vertical, "metadata/stage3/coverage/vertical_support.csv")

message(sprintf("Generated Stage 3 coverage from %d defensible sample/support units across %d datasets.",
                nrow(samples), length(unique(samples$ds_id))))
