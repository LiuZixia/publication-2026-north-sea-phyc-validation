#!/usr/bin/env Rscript
# Acquire and register the authoritative ICES spatial inputs used in Stage 0.

suppressPackageStartupMessages({
  library(httr2)
  library(jsonlite)
  library(sf)
})
source("R/00_core_setup.R")
source("R/00_spatial_provenance.R")

args <- commandArgs(trailingOnly = TRUE)
unknown_args <- setdiff(args, "--refresh")
if (length(unknown_args)) stop(sprintf("Unknown argument(s): %s", paste(unknown_args, collapse = ", ")), call. = FALSE)
refresh <- "--refresh" %in% args

verify_raw_data_target(required_gb = 1)
source_config <- read.csv("config/spatial_sources.csv", stringsAsFactors = FALSE)
required_source_columns <- c(
  "source_id", "provider", "dataset", "layer_url", "selection_field",
  "selection_value", "license", "license_url"
)
if (!identical(names(source_config), required_source_columns)) {
  stop("config/spatial_sources.csv does not match the frozen source schema.", call. = FALSE)
}
if (anyNA(source_config) || anyDuplicated(source_config$source_id)) {
  stop("Frozen spatial-source fields must be complete and source IDs unique.", call. = FALSE)
}
if (length(unique(source_config$license_url)) != 1L) stop("A single explicit ICES license-policy URL is required.", call. = FALSE)

# A normal rerun verifies and reuses the newest complete immutable acquisition.
existing_run <- try(latest_valid_spatial_run(verify_checksums = TRUE), silent = TRUE)
if (!refresh && !inherits(existing_run, "try-error")) {
  message(sprintf("Verified existing spatial acquisition; no download needed: %s", existing_run))
  quit(save = "no", status = 0L)
}

run_time <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
run_id <- paste0("SPATIAL-ICES-", run_time)
run_root <- file.path("data", "raw", "search_runs")
final_dir <- file.path(run_root, run_id)
suffix <- 1L
while (file.exists(final_dir) || file.exists(paste0(final_dir, ".partial"))) {
  final_dir <- file.path(run_root, sprintf("%s-%d", run_id, suffix))
  suffix <- suffix + 1L
}
run_id <- basename(final_dir)
staging_dir <- paste0(final_dir, ".partial")
dir.create(staging_dir, recursive = TRUE, showWarnings = FALSE)
committed <- FALSE
on.exit(if (!committed && dir.exists(staging_dir)) unlink(staging_dir, recursive = TRUE), add = TRUE)

manifest_rows <- list()
add_manifest_row <- function(...) {
  values <- list(...)
  manifest_rows[[length(manifest_rows) + 1L]] <<- as.data.frame(values, stringsAsFactors = FALSE)
}

# Archive the official policy that supports the recorded licence instead of relying on a typed claim.
license_file <- file.path(staging_dir, "ices_data_policy.html")
license_result <- download_with_retry(unique(source_config$license_url), license_file, minimum_bytes = 1000)
license_text <- paste(readLines(license_file, warn = FALSE), collapse = " ")
if (!grepl("CC BY 4\\.0|Creative Commons", license_text, ignore.case = TRUE)) {
  stop("Archived ICES policy does not contain the expected public-data licence statement.", call. = FALSE)
}
add_manifest_row(
  run_id = run_id, source_id = "ices_data_policy", provider = "ICES", dataset = "ICES Data Policy",
  artifact_id = "ices_data_policy", artifact_role = "license_policy", page_number = NA_integer_,
  request_url = license_result$url, api_version = NA_character_, service_item_id = NA_character_,
  license = "CC BY 4.0", license_url = unique(source_config$license_url), access_time_utc = run_time,
  http_status = license_result$status, content_type = license_result$content_type, size_bytes = license_result$size,
  expected_feature_count = NA_integer_, returned_feature_count = NA_integer_, max_record_count = NA_integer_,
  pagination_complete = NA, transfer_limit_state = NA_character_, filename = basename(license_file),
  checksum_sha256 = license_result$checksum, software_version = R.version.string
)

read_json_response <- function(path) {
  value <- jsonlite::fromJSON(path, simplifyVector = TRUE)
  if (!is.null(value$error)) stop(sprintf("Provider error in %s", path), call. = FALSE)
  value
}

detect_transfer_limit <- function(path) {
  size <- file.info(path)$size
  con <- file(path, open = "rb")
  on.exit(close(con), add = TRUE)
  seek(con, where = max(0, size - 1048576), origin = "start")
  tail_text <- rawToChar(readBin(con, what = "raw", n = min(size, 1048576)))
  if (grepl('"exceededTransferLimit"[[:space:]]*:[[:space:]]*true', tail_text, ignore.case = TRUE)) return("true")
  if (grepl('"exceededTransferLimit"[[:space:]]*:[[:space:]]*false', tail_text, ignore.case = TRUE)) return("false")
  "not_reported"
}

for (source_row in seq_len(nrow(source_config))) {
  source <- source_config[source_row, , drop = FALSE]
  source_id <- source$source_id[[1]]
  layer_url <- source$layer_url[[1]]
  service_url <- sub("/0$", "", layer_url)

  service_metadata_url <- build_query_url(service_url, c(f = "pjson"))
  layer_metadata_url <- build_query_url(layer_url, c(f = "pjson"))
  count_url <- build_query_url(
    paste0(layer_url, "/query"),
    c(where = "1=1", returnCountOnly = "true", f = "json")
  )

  service_file <- file.path(staging_dir, paste0(source_id, "_service_metadata.json"))
  layer_file <- file.path(staging_dir, paste0(source_id, "_layer_metadata.json"))
  count_file <- file.path(staging_dir, paste0(source_id, "_count.json"))
  service_result <- download_with_retry(service_metadata_url, service_file, minimum_bytes = 100)
  layer_result <- download_with_retry(layer_metadata_url, layer_file, minimum_bytes = 100)
  count_result <- download_with_retry(count_url, count_file, minimum_bytes = 10)

  service_metadata <- read_json_response(service_file)
  layer_metadata <- read_json_response(layer_file)
  count_response <- read_json_response(count_file)
  api_version <- as.character(service_metadata$currentVersion)
  service_item_id <- as.character(service_metadata$serviceItemId)
  max_record_count <- as.integer(layer_metadata$maxRecordCount)
  expected_count <- as.integer(count_response$count)
  object_id_field <- if (is.null(layer_metadata$objectIdField)) "" else as.character(layer_metadata$objectIdField[[1]])
  if ((!length(object_id_field) || is.na(object_id_field) || !nzchar(object_id_field)) && !is.null(layer_metadata$fields)) {
    oid_rows <- which(layer_metadata$fields$type == "esriFieldTypeOID")
    if (length(oid_rows)) object_id_field <- as.character(layer_metadata$fields$name[oid_rows[[1]]])
  }
  if (is.na(max_record_count) || max_record_count < 1L || is.na(expected_count) || expected_count < 1L ||
      !length(object_id_field) || is.na(object_id_field) || !nzchar(object_id_field)) {
    stop(sprintf("Incomplete ArcGIS metadata for %s.", source_id), call. = FALSE)
  }

  metadata_artifacts <- list(
    list("service_metadata", service_result, service_file),
    list("layer_metadata", layer_result, layer_file),
    list("feature_count", count_result, count_file)
  )
  for (artifact in metadata_artifacts) {
    add_manifest_row(
      run_id = run_id, source_id = source_id, provider = source$provider[[1]], dataset = source$dataset[[1]],
      artifact_id = paste(source_id, artifact[[1]], sep = "__"), artifact_role = artifact[[1]], page_number = NA_integer_,
      request_url = artifact[[2]]$url, api_version = api_version, service_item_id = service_item_id,
      license = source$license[[1]], license_url = source$license_url[[1]], access_time_utc = run_time,
      http_status = artifact[[2]]$status, content_type = artifact[[2]]$content_type, size_bytes = artifact[[2]]$size,
      expected_feature_count = expected_count, returned_feature_count = NA_integer_, max_record_count = max_record_count,
      pagination_complete = NA, transfer_limit_state = NA_character_, filename = basename(artifact[[3]]),
      checksum_sha256 = artifact[[2]]$checksum, software_version = R.version.string
    )
  }

  offsets <- seq.int(0L, expected_count - 1L, by = max_record_count)
  returned_total <- 0L
  page_records <- list()
  for (page_index in seq_along(offsets)) {
    query_url <- build_query_url(
      paste0(layer_url, "/query"),
      c(
        where = "1=1", outFields = "*", returnGeometry = "true", f = "json",
        orderByFields = object_id_field, resultOffset = offsets[[page_index]],
        resultRecordCount = min(max_record_count, expected_count - offsets[[page_index]])
      )
    )
    page_file <- file.path(staging_dir, sprintf("%s_features_page_%04d.json", source_id, page_index))
    page_result <- download_with_retry(query_url, page_file, minimum_bytes = 100)
    # GDAL may emit a performance-only warning for source polygons with many parts.
    page_sf <- suppressWarnings(sf::st_read(page_file, quiet = TRUE))
    returned_count <- nrow(page_sf)
    if (returned_count < 1L) stop(sprintf("Empty feature page for %s.", source_id), call. = FALSE)
    returned_total <- returned_total + returned_count
    page_records[[page_index]] <- list(
      page_index = page_index, query_url = query_url, page_file = page_file,
      page_result = page_result, returned_count = returned_count,
      transfer_limit_state = detect_transfer_limit(page_file)
    )
  }
  if (returned_total != expected_count) {
    stop(sprintf("Returned %d of %d expected features for %s.", returned_total, expected_count, source_id), call. = FALSE)
  }
  for (page_record in page_records) {
    add_manifest_row(
      run_id = run_id, source_id = source_id, provider = source$provider[[1]], dataset = source$dataset[[1]],
      artifact_id = sprintf("%s__features_page_%04d", source_id, page_record$page_index),
      artifact_role = "features_page", page_number = page_record$page_index,
      request_url = page_record$query_url, api_version = api_version, service_item_id = service_item_id,
      license = source$license[[1]], license_url = source$license_url[[1]], access_time_utc = run_time,
      http_status = page_record$page_result$status, content_type = page_record$page_result$content_type,
      size_bytes = page_record$page_result$size, expected_feature_count = expected_count,
      returned_feature_count = page_record$returned_count, max_record_count = max_record_count,
      pagination_complete = TRUE, transfer_limit_state = page_record$transfer_limit_state,
      filename = basename(page_record$page_file), checksum_sha256 = page_record$page_result$checksum,
      software_version = R.version.string
    )
  }
}

manifest <- do.call(rbind, manifest_rows)
manifest <- manifest[, spatial_manifest_columns()]
write.csv(manifest, file.path(staging_dir, "manifest.csv"), row.names = FALSE, na = "")
writeLines(
  c(
    sprintf("Spatial acquisition run: %s", run_id),
    sprintf("Execution time (UTC): %s", run_time),
    sprintf("Artifacts registered: %d", nrow(manifest)),
    sprintf("Feature counts: %s", paste(sprintf("%s=%d", unique(manifest$source_id[manifest$artifact_role == "features_page"]), tapply(manifest$returned_feature_count[manifest$artifact_role == "features_page"], manifest$source_id[manifest$artifact_role == "features_page"], sum)), collapse = "; ")),
    sprintf("R version: %s", R.version.string)
  ),
  file.path(staging_dir, "acquisition.log")
)

if (!isTRUE(file.rename(staging_dir, final_dir))) stop("Unable to atomically finalize the spatial acquisition directory.", call. = FALSE)
committed <- TRUE
validate_spatial_run(final_dir, verify_checksums = TRUE)
message(sprintf("Registered complete spatial acquisition: %s", final_dir))
