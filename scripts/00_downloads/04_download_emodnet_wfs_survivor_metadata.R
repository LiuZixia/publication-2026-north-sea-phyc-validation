# Archive official MarineInfo metadata for WFS candidates that survived exact domain screening.

source("R/00_core_setup.R")
source("R/01_search_helpers.R")
required_namespace("jsonlite")
required_namespace("digest")

config_path <- "config/stage2_emodnet_wfs_survivor_metadata.json"
cfg <- jsonlite::fromJSON(config_path, simplifyVector = FALSE)
if (!identical(cfg$classification, "stage2_canonical_provider_and_licence_resolution") ||
    !identical(calculate_checksum(cfg$geometry_evidence_path), cfg$geometry_evidence_checksum_sha256)) {
  stop("Stage 2 WFS survivor metadata configuration or geometry evidence is invalid.", call. = FALSE)
}
evidence <- utils::read.csv(cfg$geometry_evidence_path, stringsAsFactors = FALSE,
                            colClasses = c(wfs_dataset_id = "character"))
survivors <- evidence$wfs_dataset_id[evidence$exact_domain_records > 0L]
dataset_ids <- unlist(cfg$dataset_ids, use.names = FALSE)
if (!setequal(survivors, dataset_ids)) stop("Configured metadata IDs differ from exact-domain survivors.", call. = FALSE)

raw <- verify_raw_data_target(required_gb = 0.01)
timestamp <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
run_relative <- file.path("stage2", "emodnet_wfs_survivor_metadata", timestamp)
final_dir <- file.path("data", "raw", run_relative)
staging_dir <- paste0(final_dir, ".partial")
if (file.exists(final_dir) || file.exists(staging_dir)) stop("Refusing to replace a metadata run.", call. = FALSE)
dir.create(staging_dir, recursive = TRUE, showWarnings = FALSE)

rows <- lapply(dataset_ids, function(dataset_id) {
  url <- sprintf(cfg$provider_metadata_url_template, dataset_id)
  destination <- file.path(staging_dir, sprintf("marineinfo_dataset_%s.html", dataset_id))
  result <- download_with_retry(url, destination, max_tries = 4L, minimum_bytes = 1000L,
                                timeout_seconds = 90L)
  page <- paste(readLines(destination, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  expected_title <- cfg$expected_titles[[dataset_id]]
  if (!grepl(expected_title, page, fixed = TRUE)) {
    stop(sprintf("MarineInfo page %s does not contain its frozen expected title.", dataset_id), call. = FALSE)
  }
  data.frame(
    dataset_id = dataset_id,
    provider = cfg$provider,
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
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
})
manifest <- do.call(rbind, rows)
utils::write.csv(manifest, file.path(staging_dir, "manifest.csv"), row.names = FALSE, na = "")
summary <- list(
  schema_version = cfg$schema_version,
  completed_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  status = "complete",
  dataset_count = nrow(manifest),
  configuration_path = config_path,
  configuration_checksum_sha256 = calculate_checksum(config_path),
  geometry_evidence_checksum_sha256 = calculate_checksum(cfg$geometry_evidence_path),
  software_version = R.version.string
)
jsonlite::write_json(summary, file.path(staging_dir, "run_summary.json"), pretty = TRUE, auto_unbox = TRUE)
writeLines(c(sprintf("completed_utc: %s", summary$completed_utc),
             sprintf("dataset_count: %d", summary$dataset_count),
             sprintf("configuration_sha256: %s", summary$configuration_checksum_sha256),
             sprintf("R: %s", R.version.string)),
           file.path(staging_dir, "run.log"), useBytes = TRUE)
if (!file.rename(staging_dir, final_dir)) stop("Unable to atomically finalize survivor metadata.", call. = FALSE)
message(sprintf("Archived official metadata for %d WFS survivors: %s", nrow(manifest), run_relative))
