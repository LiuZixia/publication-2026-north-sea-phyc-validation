# Archive complete geometry evidence for the 40 EMODnet Biology WFS candidates routed by Stage 2.

source("R/00_core_setup.R")
source("R/01_search_helpers.R")
source("R/03_stage2_contract.R")
required_namespace("jsonlite")
required_namespace("digest")

config_path <- "config/stage2_emodnet_wfs_geometry.json"
cfg <- jsonlite::fromJSON(config_path, simplifyVector = FALSE)
contract <- read_stage2_contract(cfg$contract_path)
if (!identical(cfg$classification, "stage2_record_geometry_and_provenance_screen")) {
  stop("Unsupported Stage 2 EMODnet WFS configuration.", call. = FALSE)
}
if (!identical(calculate_checksum(cfg$queue_path), cfg$queue_checksum_sha256) ||
    !identical(calculate_checksum(cfg$domain_geometry_path), cfg$domain_geometry_checksum_sha256)) {
  stop("Stage 2 WFS queue or frozen domain geometry differs from the pinned configuration.", call. = FALSE)
}

queue <- utils::read.csv(cfg$queue_path, stringsAsFactors = FALSE, check.names = FALSE,
                         colClasses = c(wfs_dataset_id = "character"))
validate_stage2_wfs_queue(queue, contract)
raw_target <- verify_raw_data_target(required_gb = 0.1)

timestamp <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
run_relative <- file.path("stage2", "emodnet_wfs_geometry", timestamp)
final_dir <- file.path("data", "raw", run_relative)
staging_dir <- paste0(final_dir, ".partial")
if (file.exists(final_dir) || file.exists(staging_dir)) {
  stop(sprintf("Refusing to replace an existing Stage 2 WFS run: %s", timestamp), call. = FALSE)
}
dir.create(staging_dir, recursive = TRUE, showWarnings = FALSE)

parse_hits <- function(path) {
  text <- paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "")
  matched <- sub('.*(?:numberMatched|numberOfFeatures)="([0-9]+|unknown)".*', "\\1", text, perl = TRUE)
  returned <- sub('.*numberReturned="([0-9]+)".*', "\\1", text, perl = TRUE)
  if (identical(returned, text)) returned <- "0"
  if (identical(matched, text) || matched == "unknown") {
    stop(sprintf("Unable to parse WFS hit counts from %s", path), call. = FALSE)
  }
  c(number_matched = as.integer(matched), number_returned = as.integer(returned))
}

request_artifact <- function(dataset_id, query_kind, page, params, extension, minimum_bytes = 20L) {
  url <- build_query_url(cfg$endpoint, params)
  stem <- sprintf("dataset_%s_%s_%04d", dataset_id, query_kind, as.integer(page))
  destination <- file.path(staging_dir, paste0(stem, extension))
  result <- download_with_retry(url, destination, max_tries = 4L, minimum_bytes = minimum_bytes,
                                timeout_seconds = 90)
  data.frame(
    dataset_id = dataset_id,
    query_kind = query_kind,
    page = as.integer(page),
    request_method = "GET",
    request_url = url,
    request_parameters_sha256 = digest::digest(url, algo = "sha256", serialize = FALSE),
    retrieved_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    raw_relative_path = file.path(run_relative, basename(destination)),
    filename = basename(destination),
    size_bytes = as.numeric(result$size),
    checksum_sha256 = result$checksum,
    content_type = result$content_type %||% "",
    http_status = as.integer(result$status),
    records_returned = NA_integer_,
    provider_total = NA_integer_,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

manifest_rows <- list()
summary_rows <- list()
bbox_text <- paste(c(unlist(cfg$domain_bbox_crs84, use.names = FALSE), cfg$bbox_crs), collapse = ",")

for (i in seq_len(nrow(queue))) {
  dataset_id <- queue$wfs_dataset_id[[i]]
  dataset_view <- sprintf("%s:%s", cfg$dataset_filter_field, dataset_id)
  common <- c(service = cfg$service, version = cfg$version, request = "GetFeature",
              typeNames = cfg$occurrence_layer, viewParams = dataset_view)

  bbox_row <- request_artifact(dataset_id, "bbox_hits", 1L,
                               c(common, bbox = bbox_text, resultType = "hits"), ".xml")
  bbox_counts <- parse_hits(file.path(staging_dir, bbox_row$filename))
  bbox_row$records_returned <- bbox_counts[["number_returned"]]
  bbox_row$provider_total <- bbox_counts[["number_matched"]]
  manifest_rows[[length(manifest_rows) + 1L]] <- bbox_row

  bbox_total <- bbox_counts[["number_matched"]]
  downloaded <- 0L
  page <- 1L
  while (downloaded < bbox_total) {
    params <- c(common, bbox = bbox_text, outputFormat = "application/json",
                srsName = cfg$output_crs,
                maxFeatures = as.integer(cfg$page_size), startIndex = downloaded, sortBy = cfg$sort_field)
    page_row <- request_artifact(dataset_id, "bbox_records", page, params, ".json")
    response <- jsonlite::fromJSON(file.path(staging_dir, page_row$filename), simplifyVector = FALSE)
    provider_total <- response$numberMatched %||% response$totalFeatures
    reported_returned <- response$numberReturned %||% length(response$features %||% list())
    if (is.null(response$features) || is.null(provider_total)) {
      stop(sprintf("Malformed WFS records response for dataset %s page %d.", dataset_id, page), call. = FALSE)
    }
    records_returned <- length(response$features)
    provider_total_numeric <- suppressWarnings(as.integer(provider_total))
    if (is.na(provider_total_numeric) && identical(as.character(provider_total), "unknown")) {
      provider_total_numeric <- bbox_total
    }
    if (records_returned != as.integer(reported_returned) ||
        provider_total_numeric != bbox_total || records_returned == 0L) {
      stop(sprintf("WFS pagination reconciliation failed for dataset %s page %d.", dataset_id, page), call. = FALSE)
    }
    returned_ids <- vapply(response$features, function(feature) {
      sub("^.*/dataset/", "", as.character(feature$properties$datasetid %||% ""))
    }, character(1))
    if (any(returned_ids != dataset_id)) {
      stop(sprintf("WFS returned a record from another dataset while screening %s.", dataset_id), call. = FALSE)
    }
    page_row$records_returned <- records_returned
    page_row$provider_total <- bbox_total
    manifest_rows[[length(manifest_rows) + 1L]] <- page_row
    downloaded <- downloaded + records_returned
    page <- page + 1L
  }

  summary_rows[[length(summary_rows) + 1L]] <- data.frame(
    wfs_dataset_id = dataset_id,
    domain_bbox_records = bbox_total,
    bbox_records_downloaded = downloaded,
    stringsAsFactors = FALSE
  )
  Sys.sleep(0.1)
}

manifest <- do.call(rbind, manifest_rows)
summary <- do.call(rbind, summary_rows)
if (nrow(summary) != 40L || anyDuplicated(summary$wfs_dataset_id) ||
    any(summary$domain_bbox_records != summary$bbox_records_downloaded)) {
  stop("Stage 2 WFS geometry run did not reconcile all queued dataset IDs.", call. = FALSE)
}

utils::write.csv(manifest, file.path(staging_dir, "manifest.csv"), row.names = FALSE, na = "")
utils::write.csv(summary, file.path(staging_dir, "dataset_hit_summary.csv"), row.names = FALSE, na = "")
run_summary <- list(
  schema_version = cfg$schema_version,
  completed_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  status = "complete",
  queued_datasets = nrow(queue),
  queried_datasets = nrow(summary),
  manifest_rows = nrow(manifest),
  bbox_records_archived = sum(summary$bbox_records_downloaded),
  configuration_path = config_path,
  configuration_checksum_sha256 = calculate_checksum(config_path),
  contract_checksum_sha256 = calculate_checksum(cfg$contract_path),
  queue_checksum_sha256 = calculate_checksum(cfg$queue_path),
  domain_geometry_checksum_sha256 = calculate_checksum(cfg$domain_geometry_path),
  software_version = R.version.string
)
jsonlite::write_json(run_summary, file.path(staging_dir, "run_summary.json"),
                     pretty = TRUE, auto_unbox = TRUE)
writeLines(c(
  sprintf("completed_utc: %s", run_summary$completed_utc),
  sprintf("queued_datasets: %d", run_summary$queued_datasets),
  sprintf("manifest_rows: %d", run_summary$manifest_rows),
  sprintf("bbox_records_archived: %d", run_summary$bbox_records_archived),
  sprintf("configuration_sha256: %s", run_summary$configuration_checksum_sha256),
  sprintf("R: %s", R.version.string)
), file.path(staging_dir, "run.log"), useBytes = TRUE)

if (!file.rename(staging_dir, final_dir)) {
  stop("Unable to atomically finalize the Stage 2 WFS geometry run.", call. = FALSE)
}
message(sprintf("Stage 2 WFS geometry run complete: %s", run_relative))
