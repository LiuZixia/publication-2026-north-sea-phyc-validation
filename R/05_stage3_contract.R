# Contract and source-adapter helpers for the observation-only Stage 3 coverage audit.

stage3_required_ids <- function() {
  sprintf("DS%02d", c(6, 26, 2, 4, 5, 7, 8, 3, 23, 16, 10, 11, 9, 24, 27, 28, 15, 22, 12))
}

stage3_read_adapters <- function(path = "config/stage3_source_adapters.csv") {
  if (!file.exists(path)) stop("Stage 3 source-adapter configuration is missing.", call. = FALSE)
  value <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
  expected <- c("ds_id", "adapter_id", "monitoring_network", "independence_unit",
                "duplicate_family", "observation_kind", "stage3_scope")
  if (!identical(names(value), expected) || nrow(value) != 19L || anyDuplicated(value$ds_id) ||
      !identical(value$ds_id, stage3_required_ids()) || any(!nzchar(as.matrix(value)))) {
    stop("Stage 3 source-adapter configuration violates its 19-item contract.", call. = FALSE)
  }
  value
}

stage3_active_pins <- function(ds_id) {
  pattern <- paste0("^", tolower(ds_id), ".*_active_run[.]csv$")
  sort(list.files("metadata/stage2/acquisition", pattern = pattern, full.names = TRUE))
}

stage3_manifest_paths <- function(pin_paths) {
  if (!length(pin_paths)) return(character())
  unique(unlist(lapply(pin_paths, function(path) {
    pin <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
    if (!"run_relative_path" %in% names(pin) || nrow(pin) != 1L) {
      stop(sprintf("Invalid active-run pin: %s", path), call. = FALSE)
    }
    manifest <- file.path("data/raw", pin$run_relative_path[[1]], "manifest.csv")
    if (file.exists(manifest)) manifest else character()
  }), use.names = FALSE))
}

stage3_validate_raw_manifests <- function(manifest_paths) {
  if (!length(manifest_paths)) return("not_applicable")
  for (path in manifest_paths) {
    manifest <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
    required <- c("file_name", "checksum_sha256", "file_size_bytes")
    if (!all(required %in% names(manifest)) || !nrow(manifest)) {
      stop(sprintf("Raw manifest lacks required fields or rows: %s", path), call. = FALSE)
    }
    files <- file.path(dirname(path), manifest$file_name)
    if (any(!file.exists(files)) || any(file.size(files) != manifest$file_size_bytes)) {
      stop(sprintf("Raw manifest files fail existence/size validation: %s", path), call. = FALSE)
    }
    checksums <- unname(vapply(files, calculate_checksum, character(1)))
    if (!identical(checksums, manifest$checksum_sha256)) {
      stop(sprintf("Raw manifest checksum mismatch: %s", path), call. = FALSE)
    }
  }
  "verified"
}

stage3_parse_datetime <- function(value) {
  value <- trimws(as.character(value))
  value[!nzchar(value)] <- NA_character_
  # as.POSIXct(tryFormats=) chooses one format for the vector. A few malformed provider times can
  # therefore make it select date-only and silently zero valid hours for every other row. Route
  # mutually exclusive lexical forms explicitly and leave malformed values missing.
  parsed <- rep(as.POSIXct(NA, tz = "UTC"), length(value))
  routes <- list(
    list("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$", "%Y-%m-%dT%H:%M:%SZ"),
    list("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}$", "%Y-%m-%dT%H:%M:%S"),
    list("^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}[+-][0-9]{4}$", "%Y-%m-%d %H:%M:%S%z"),
    list("^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}[+-][0-9]{4}$", "%Y-%m-%d %H:%M%z"),
    list("^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$", "%Y-%m-%d %H:%M:%S"),
    list("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", "%Y-%m-%d"),
    list("^[0-9]{2}-[0-9]{2}-[0-9]{4} [0-9]{2}:[0-9]{2}:[0-9]{2} [+-][0-9]{4}$", "%d-%m-%Y %H:%M:%S %z")
  )
  for (route in routes) {
    index <- !is.na(value) & grepl(route[[1]], value, perl = TRUE)
    if (any(index)) {
      parsed[index] <- suppressWarnings(as.POSIXct(value[index], format = route[[2]], tz = "UTC"))
    }
  }
  parsed
}

stage3_season <- function(month) {
  result <- rep(NA_character_, length(month))
  result[month %in% c(12L, 1L, 2L)] <- "winter"
  result[month %in% 3:5] <- "spring"
  result[month %in% 6:8] <- "summer"
  result[month %in% 9:11] <- "autumn"
  result
}

stage3_assign_subregion <- function(latitude, longitude) {
  required_namespace("sf")
  latitude <- suppressWarnings(as.numeric(latitude))
  longitude <- suppressWarnings(as.numeric(longitude))
  valid <- is.finite(latitude) & is.finite(longitude) & latitude >= -90 & latitude <= 90 &
    longitude >= -180 & longitude <= 180
  result <- rep("outside_or_invalid", length(latitude))
  if (!any(valid)) return(result)
  subregions <- sf::st_read("config/spatial/hydrographic_subregions.geojson", quiet = TRUE)
  bounds <- sf::st_bbox(subregions)
  valid <- valid & longitude >= bounds[["xmin"]] & longitude <= bounds[["xmax"]] &
    latitude >= bounds[["ymin"]] & latitude <= bounds[["ymax"]]
  if (!any(valid)) return(result)
  valid_rows <- which(valid)
  coordinate_key <- paste(format(latitude[valid], digits = 12), format(longitude[valid], digits = 12), sep = "|")
  unique_index <- !duplicated(coordinate_key)
  unique_rows <- valid_rows[unique_index]
  points <- sf::st_as_sf(data.frame(row = unique_rows, longitude = longitude[unique_rows],
                                   latitude = latitude[unique_rows]),
                         coords = c("longitude", "latitude"), crs = 4326)
  hits <- suppressMessages(sf::st_intersects(points, subregions, prepared = TRUE))
  index <- vapply(hits, function(x) if (length(x)) x[[1]] else NA_integer_, integer(1))
  matched <- !is.na(index)
  unique_result <- rep("outside_or_invalid", nrow(points))
  unique_result[matched] <- subregions$subregion_id[index[matched]]
  result[valid_rows] <- unique_result[match(coordinate_key, coordinate_key[unique_index])]
  result
}

stage3_standard_samples <- function(ds_id, monitoring_network, sample_id, station_id, datetime,
                                    latitude, longitude, depth_min_m = NA_real_, depth_max_m = NA_real_,
                                    subregion_id = NULL, method_epoch = "unknown_not_harmonized",
                                    datetime_precision = "unknown") {
  n <- length(sample_id)
  fields <- list(station_id, datetime, latitude, longitude, depth_min_m, depth_max_m,
                 method_epoch, datetime_precision)
  if (any(vapply(fields, length, integer(1)) %in% c(0L)) ||
      any(!vapply(fields, length, integer(1)) %in% c(1L, n))) {
    stop(sprintf("Stage 3 adapter returned inconsistent vector lengths for %s.", ds_id), call. = FALSE)
  }
  recycle <- function(x) if (length(x) == 1L) rep(x, n) else x
  datetime <- stage3_parse_datetime(recycle(datetime))
  latitude <- suppressWarnings(as.numeric(recycle(latitude)))
  longitude <- suppressWarnings(as.numeric(recycle(longitude)))
  if (is.null(subregion_id)) subregion_id <- stage3_assign_subregion(latitude, longitude)
  subregion_id <- recycle(subregion_id)
  value <- data.frame(
    ds_id = ds_id,
    monitoring_network = monitoring_network,
    sample_id = as.character(sample_id),
    station_id = as.character(recycle(station_id)),
    datetime_utc = format(datetime, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    datetime_precision = as.character(recycle(datetime_precision)),
    latitude = latitude,
    longitude = longitude,
    subregion_id = as.character(subregion_id),
    depth_min_m = suppressWarnings(as.numeric(recycle(depth_min_m))),
    depth_max_m = suppressWarnings(as.numeric(recycle(depth_max_m))),
    method_epoch = as.character(recycle(method_epoch)),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  value$datetime_utc[is.na(datetime)] <- ""
  value$station_id[!nzchar(value$station_id)] <- "unknown_station"
  value
}

stage3_collapse_samples <- function(value) {
  key <- paste(value$ds_id, value$monitoring_network, value$sample_id, sep = "|")
  value[!duplicated(key), , drop = FALSE]
}

stage3_summarize_temporal <- function(samples) {
  valid <- nzchar(samples$datetime_utc) & !is.na(samples$subregion_id) & nzchar(samples$subregion_id)
  x <- samples[valid, , drop = FALSE]
  if (!nrow(x)) return(data.frame())
  dt <- stage3_parse_datetime(x$datetime_utc)
  x$year <- as.integer(format(dt, "%Y"))
  x$month <- as.integer(format(dt, "%m"))
  x$season <- stage3_season(x$month)
  groups <- split(x, interaction(x$ds_id, x$monitoring_network, x$subregion_id, x$method_epoch,
                                 x$year, drop = TRUE, lex.order = TRUE))
  do.call(rbind, lapply(groups, function(g) {
    dates <- sort(unique(as.Date(g$datetime_utc)))
    gaps <- if (length(dates) > 1L) as.numeric(diff(dates)) else numeric()
    data.frame(
      ds_id = g$ds_id[[1]], monitoring_network = g$monitoring_network[[1]],
      subregion_id = g$subregion_id[[1]], method_epoch = g$method_epoch[[1]], year = g$year[[1]],
      first_date = as.character(min(dates)), last_date = as.character(max(dates)),
      sample_count = nrow(g), unique_sampling_days = length(dates),
      sampled_months = length(unique(g$month)), sampled_seasons = length(unique(g$season)),
      median_gap_days = if (length(gaps)) stats::median(gaps) else NA_real_,
      gap_p90_days = if (length(gaps)) unname(stats::quantile(gaps, 0.9, names = FALSE)) else NA_real_,
      longest_gap_days = if (length(gaps)) max(gaps) else NA_real_,
      supports_daily = length(gaps) && stats::median(gaps) <= 1,
      supports_3_day = length(gaps) && stats::median(gaps) <= 3,
      supports_7_day = length(gaps) && stats::median(gaps) <= 7,
      supports_cadence_matched = length(dates) >= 2L,
      adequacy_state = "not_assessed_until_target_season_is_frozen",
      stringsAsFactors = FALSE, check.names = FALSE
    )
  }))
}

stage3_pin_run_dirs <- function(ds_id) {
  pins <- stage3_active_pins(ds_id)
  unique(vapply(pins, function(path) {
    pin <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
    file.path("data/raw", pin$run_relative_path[[1]])
  }, character(1)))
}

stage3_adapter_screened_records <- function(ds_id, network) {
  candidates <- list.files("data/interim", pattern = paste0("stage2_", tolower(ds_id),
                           ".*record_screening.*[.]csv$"), full.names = TRUE)
  resolved <- candidates[grepl("_resolved[.]csv$", candidates)]
  path <- if (length(resolved)) resolved[[1]] else if (length(candidates)) candidates[[1]] else ""
  if (!nzchar(path)) stop(sprintf("No screened-record input for %s.", ds_id), call. = FALSE)
  x <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
  required <- c("record_id", "reported_datetime", "datetime_utc", "latitude", "longitude",
                "subregion_id", "screening_decision")
  if (!all(required %in% names(x))) stop(sprintf("Screened-record schema failure for %s.", ds_id), call. = FALSE)
  x <- x[x$screening_decision != "excluded", , drop = FALSE]
  datetime <- ifelse(nzchar(x$datetime_utc), x$datetime_utc, x$reported_datetime)
  precision <- ifelse(grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", x$reported_datetime), "date", "datetime")
  sample_key <- paste(datetime, x$latitude, x$longitude, sep = "|")
  if (ds_id == "DS12" && "provider_record_id" %in% names(x)) sample_key <- x$provider_record_id
  station <- paste0("coordinate_proxy:", format(x$latitude, digits = 8), ":",
                    format(x$longitude, digits = 8))
  region <- x$subregion_id
  region[!nzchar(region)] <- "outside_or_invalid"
  stage3_collapse_samples(stage3_standard_samples(
    ds_id, network, sample_key, station, datetime, x$latitude, x$longitude,
    subregion_id = region, datetime_precision = precision
  ))
}

stage3_adapter_plet <- function(ds_id, network) {
  dirs <- stage3_pin_run_dirs(ds_id)
  manifests <- file.path(dirs, "manifest.csv")
  files <- unlist(lapply(manifests[file.exists(manifests)], function(path) {
    m <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
    file.path(dirname(path), m$file_name[grepl("[.]csv$", m$file_name, ignore.case = TRUE)])
  }), use.names = FALSE)
  if (ds_id == "DS11") files <- files[basename(files) != "bsh_phyto_zoo.csv"]
  if (!length(files)) stop(sprintf("No PLET CSV for %s.", ds_id), call. = FALSE)
  rows <- lapply(files, function(path) {
    x <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
    required <- c("date", "latitude", "longitude", "depth_min", "depth_max")
    if (!all(required %in% names(x))) stop(sprintf("PLET schema failure for %s.", ds_id), call. = FALSE)
    time <- if ("time" %in% names(x)) as.character(x$time) else rep("", nrow(x))
    time[is.na(time)] <- ""
    time <- trimws(time)
    datetime <- ifelse(nzchar(time), trimws(paste(x$date, time)), as.character(x$date))
    precision <- ifelse(nzchar(time), "datetime", "date")
    station <- paste0("coordinate_proxy:", format(x$latitude, digits = 8), ":",
                      format(x$longitude, digits = 8))
    sample_key <- paste(basename(path), datetime, station, x$depth_min, x$depth_max, sep = "|")
    keep <- !duplicated(sample_key)
    stage3_standard_samples(
      ds_id, network, sample_key[keep], station[keep], datetime[keep], x$latitude[keep], x$longitude[keep],
      x$depth_min[keep], x$depth_max[keep], datetime_precision = precision[keep]
    )
  })
  stage3_collapse_samples(do.call(rbind, rows))
}

stage3_adapter_eurobis <- function(ds_id, network) {
  dirs <- stage3_pin_run_dirs(ds_id)
  manifests <- file.path(dirs, "manifest.csv")
  zips <- unlist(lapply(manifests[file.exists(manifests)], function(path) {
    m <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
    file.path(dirname(path), m$file_name[grepl("[.]zip$", m$file_name, ignore.case = TRUE)])
  }), use.names = FALSE)
  rows <- lapply(zips, function(path) {
    x <- utils::read.delim(unz(path, "event.txt"), stringsAsFactors = FALSE, quote = "", check.names = FALSE)
    required <- c("eventID", "eventDate", "locality", "decimalLatitude", "decimalLongitude")
    if (!all(required %in% names(x))) stop("DS03 event schema failure.", call. = FALSE)
    depth_min <- if ("minimumDepthInMeters" %in% names(x)) x$minimumDepthInMeters else NA_real_
    depth_max <- if ("maximumDepthInMeters" %in% names(x)) x$maximumDepthInMeters else NA_real_
    stage3_standard_samples(
      ds_id, network, x$eventID, x$locality, x$eventDate, x$decimalLatitude, x$decimalLongitude,
      depth_min, depth_max, datetime_precision = "date"
    )
  })
  stage3_collapse_samples(do.call(rbind, rows))
}

stage3_read_pangaea_table <- function(path) {
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  end <- which(trimws(lines) == "*/")
  if (length(end) != 1L || end[[1]] >= length(lines)) return(NULL)
  text <- paste(lines[(end[[1]] + 1L):length(lines)], collapse = "\n")
  utils::read.delim(text = text, stringsAsFactors = FALSE, check.names = FALSE,
                    quote = "", comment.char = "")
}

stage3_adapter_pangaea <- function(ds_id, network) {
  dirs <- stage3_pin_run_dirs(ds_id)
  files <- unlist(lapply(file.path(dirs, "manifest.csv"), function(path) {
    if (!file.exists(path)) return(character())
    m <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
    file.path(dirname(path), m$file_name[grepl("[.]txt$", m$file_name, ignore.case = TRUE)])
  }), use.names = FALSE)
  rows <- lapply(files, function(path) {
    x <- stage3_read_pangaea_table(path)
    if (is.null(x) || !nrow(x)) return(NULL)
    date_name <- names(x)[grepl("Date/Time", names(x), fixed = TRUE)][1]
    lat_name <- names(x)[grepl("^Latitude", names(x))][1]
    lon_name <- names(x)[grepl("^Longitude", names(x))][1]
    depth_name <- names(x)[grepl("^Depth", names(x), ignore.case = TRUE)][1]
    event_name <- names(x)[grepl("^Event", names(x))][1]
    if (any(is.na(c(date_name, lat_name, lon_name, event_name)))) return(NULL)
    depth <- if (!is.na(depth_name)) x[[depth_name]] else NA_real_
    stage3_standard_samples(
      ds_id, network, paste(basename(path), seq_len(nrow(x)), sep = ":"), x[[event_name]],
      x[[date_name]], x[[lat_name]], x[[lon_name]], depth, depth, datetime_precision = "date"
    )
  })
  rows <- rows[!vapply(rows, is.null, logical(1))]
  if (!length(rows)) stop("DS09 contains no parseable observation tables.", call. = FALSE)
  stage3_collapse_samples(do.call(rbind, rows))
}

stage3_adapter_ferrybox <- function(ds_id, network) {
  path <- "metadata/stage2/screening/ds27_ferrybox_file_screening.csv"
  x <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
  required <- c("file_name", "first_datetime_utc", "last_datetime_utc", "core_usable_rows")
  if (!all(required %in% names(x)) || nrow(x) != 679L) stop("DS27 file summary contract failure.", call. = FALSE)
  stage3_standard_samples(
    ds_id, network, x$file_name, paste0("transect:", x$file_name), x$first_datetime_utc,
    NA_real_, NA_real_, subregion_id = ifelse(x$core_usable_rows > 0, "southern_and_central_north_sea",
                                               "outside_or_invalid"),
    datetime_precision = "file_start_datetime"
  )
}

stage3_adapter_comp4 <- function(ds_id, network) {
  dirs <- stage3_pin_run_dirs(ds_id)
  files <- unlist(lapply(file.path(dirs, "manifest.csv"), function(path) {
    if (!file.exists(path)) return(character())
    m <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
    file.path(dirname(path), m$file_name[grepl("StationSamples.*[.]txt[.]gz$", m$file_name)])
  }), use.names = FALSE)
  if (length(files) != 3L) stop("DS24 requires three StationSamples tables.", call. = FALSE)
  required_namespace("sf")
  bounds <- sf::st_bbox(sf::st_read("config/spatial/hydrographic_subregions.geojson", quiet = TRUE))
  rows <- lapply(files, function(path) {
    # Decode and exactly deduplicate the nine provider visit fields before R performs all scientific
    # parsing and coverage aggregation. This avoids tokenizing millions of repeated measurement rows.
    bbox_filter <- sprintf(
      "awk -F '\\t' '($8 >= %.12f && $8 <= %.12f && $9 >= %.12f && $9 <= %.12f)'",
      bounds[["xmin"]], bounds[["xmax"]], bounds[["ymin"]], bounds[["ymax"]]
    )
    command <- paste(sprintf("gzip -cd %s | cut -f1,2,4-10 | tail -n +2", shQuote(path)),
                     bbox_filter, "LC_ALL=C sort -u", sep = " | ")
    connection <- pipe(command, open = "r")
    wanted <- c("Cruise", "Station", "Year", "Month", "Day", "Hour", "Minute",
                "Longitude [degrees_east]", "Latitude [degrees_north]")
    x <- utils::read.delim(connection, sep = "\t", header = FALSE, col.names = wanted,
                           stringsAsFactors = FALSE, check.names = FALSE)
    close(connection)
    if (!all(wanted %in% names(x))) stop(sprintf("DS24 schema failure: %s", basename(path)), call. = FALSE)
    datetime <- sprintf("%04d-%02d-%02d %02d:%02d:00", x$Year, x$Month, x$Day, x$Hour, x$Minute)
    agency <- sub("^StationSamples2015-2020([A-Z]+)_.*$", "\\1", basename(path))
    # Cruise identifies a visit, not a monitoring station. Preserve it in the sample key while the
    # station key combines provider agency and reported station name across repeated cruises.
    station <- paste0("reported_visit:", agency, ":", x$Cruise, ":", x$Station)
    key <- paste(x$Cruise, station, datetime, x[["Longitude [degrees_east]"]],
                 x[["Latitude [degrees_north]"]], sep = "|")
    keep <- !duplicated(key)
    stage3_standard_samples(
      ds_id, network, paste0(basename(path), ":", key[keep]), station[keep], datetime[keep],
      x[["Latitude [degrees_north]"]][keep], x[["Longitude [degrees_east]"]][keep],
      method_epoch = agency,
      datetime_precision = "minute"
    )
  })
  stage3_collapse_samples(do.call(rbind, rows))
}

stage3_load_samples <- function(manifest_row) {
  ds <- manifest_row$ds_id[[1]]
  network <- manifest_row$monitoring_network[[1]]
  adapter <- manifest_row$adapter_id[[1]]
  if (adapter == "screened_records") return(stage3_adapter_screened_records(ds, network))
  if (adapter == "plet_csv") return(stage3_adapter_plet(ds, network))
  if (adapter == "eurobis_dwca") return(stage3_adapter_eurobis(ds, network))
  if (adapter == "pangaea_tabular") return(stage3_adapter_pangaea(ds, network))
  if (adapter == "ferrybox_summary") return(stage3_adapter_ferrybox(ds, network))
  if (adapter == "comp4_station") return(stage3_adapter_comp4(ds, network))
  if (adapter %in% c("non_observational_product", "conversion_authority", "unavailable")) {
    return(NULL)
  }
  stop(sprintf("Unsupported Stage 3 adapter: %s", adapter), call. = FALSE)
}
