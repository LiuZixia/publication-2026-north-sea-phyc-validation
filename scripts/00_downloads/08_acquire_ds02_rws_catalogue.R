# Archive the canonical RWS catalogue needed to define the rank-3 DS02 observation requests.

source("R/00_core_setup.R")
source("R/03_stage2_contract.R")
required_namespace("httr2")
required_namespace("jsonlite")
required_namespace("digest")

config_path <- "config/stage2_ds02_rws_catalogue_acquisition.json"
cfg <- jsonlite::fromJSON(config_path, simplifyVector = FALSE)
contract <- read_stage2_contract(cfg$contract_path)
if (!identical(cfg$classification, "stage2_ranked_canonical_provider_catalogue_acquisition") ||
    !identical(cfg$work_item_id, "REGISTER:DS02") || cfg$acquisition_rank != 3L ||
    !identical(cfg$provider, "Rijkswaterstaat (RWS)")) {
  stop("DS02 RWS catalogue acquisition configuration is invalid.", call. = FALSE)
}

verify_raw_data_target(required_gb = cfg$required_free_gb)
run_relative <- file.path("stage2", "ds02_rws", cfg$acquisition_run_id)
final_dir <- file.path("data", "raw", run_relative)
staging_dir <- paste0(final_dir, ".partial")

validate_complete_run <- function(directory) {
  required <- file.path(directory, c(
    "rws_phytoplankton.html", "rws_waterwebservices.html", "catalogue_request.json",
    "rws_extended_catalogue.json", "manifest.csv", "run_summary.json", "run.log"
  ))
  if (any(!file.exists(required))) stop("Existing finalized DS02 catalogue run is incomplete.", call. = FALSE)
  manifest <- utils::read.csv(file.path(directory, "manifest.csv"), stringsAsFactors = FALSE,
                              check.names = FALSE)
  validate_stage2_table(manifest, "acquisition_manifest", contract)
  if (nrow(manifest) != 3L || any(vapply(seq_len(nrow(manifest)), function(i) {
    path <- file.path("data", "raw", manifest$raw_relative_path[[i]])
    !file.exists(path) || !identical(calculate_checksum(path), manifest$checksum_sha256[[i]])
  }, logical(1)))) {
    stop("Existing finalized DS02 catalogue manifest does not reconcile with raw artifacts.",
         call. = FALSE)
  }
  summary <- jsonlite::fromJSON(file.path(directory, "run_summary.json"), simplifyVector = FALSE)
  if (!identical(summary$status, "complete") ||
      !identical(summary$configuration_checksum_sha256, calculate_checksum(config_path))) {
    stop("Existing finalized DS02 catalogue summary differs from the frozen configuration.",
         call. = FALSE)
  }
  manifest
}

write_tracked_pins <- function(directory, manifest) {
  summary <- jsonlite::fromJSON(file.path(directory, "run_summary.json"), simplifyVector = FALSE)
  pin <- data.frame(
    work_item_id = cfg$work_item_id,
    run_relative_path = run_relative,
    completed_utc = summary$completed_utc,
    configuration_path = config_path,
    configuration_checksum_sha256 = summary$configuration_checksum_sha256,
    manifest_checksum_sha256 = calculate_checksum(file.path(directory, "manifest.csv")),
    catalogue_checksum_sha256 = calculate_checksum(file.path(directory, "rws_extended_catalogue.json")),
    request_checksum_sha256 = calculate_checksum(file.path(directory, "catalogue_request.json")),
    run_summary_checksum_sha256 = calculate_checksum(file.path(directory, "run_summary.json")),
    artifact_count = nrow(manifest),
    total_size_bytes = sum(manifest$size_bytes),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  write_csv_atomic(manifest, "metadata/stage2_ds02_rws_catalogue_acquisition_manifest.csv")
  write_csv_atomic(pin, "metadata/stage2_ds02_rws_catalogue_active_run.csv")
}

if (dir.exists(final_dir)) {
  manifest <- validate_complete_run(final_dir)
  write_tracked_pins(final_dir, manifest)
  message("Verified existing DS02 RWS catalogue run; no request required.")
  quit(save = "no", status = 0L)
}
dir.create(staging_dir, recursive = TRUE, showWarnings = FALSE)

page_requests <- list(
  list(filename = "rws_phytoplankton.html", url = cfg$official_phytoplankton_page,
       minimum = 1000L),
  list(filename = "rws_waterwebservices.html", url = cfg$official_api_documentation_page,
       minimum = 1000L)
)
page_results <- lapply(page_requests, function(request) {
  result <- download_with_retry(request$url, file.path(staging_dir, request$filename),
                                max_tries = 4L, minimum_bytes = request$minimum,
                                timeout_seconds = 120L)
  c(request, result)
})

request_body <- list(CatalogusFilter = cfg$catalogue_filter)
jsonlite::write_json(request_body, file.path(staging_dir, "catalogue_request.json"),
                     pretty = TRUE, auto_unbox = TRUE)
catalogue_path <- file.path(staging_dir, "rws_extended_catalogue.json")
partial_path <- paste0(catalogue_path, ".partial")
request <- httr2::request(cfg$catalogue_endpoint) |>
  httr2::req_user_agent("north-sea-phyc-validation/Stage2-DS02") |>
  httr2::req_headers(`Content-Type` = "application/json") |>
  httr2::req_body_json(request_body, auto_unbox = TRUE) |>
  httr2::req_retry(max_tries = 4L, max_seconds = 90) |>
  httr2::req_timeout(seconds = 300) |>
  httr2::req_error(is_error = function(response) FALSE)
response <- httr2::req_perform(request, path = partial_path)
status <- httr2::resp_status(response)
catalogue_size <- file.info(partial_path)$size
if (status != 200L || !is.finite(catalogue_size) ||
    catalogue_size < cfg$minimum_catalogue_bytes) {
  stop(sprintf("RWS catalogue request failed validation: HTTP %d, %.0f bytes.",
               status, catalogue_size), call. = FALSE)
}
if (!file.rename(partial_path, catalogue_path)) {
  stop("Unable to atomically finalize the RWS catalogue response.", call. = FALSE)
}
catalogue <- jsonlite::fromJSON(catalogue_path, simplifyVector = FALSE)
if (!isTRUE(catalogue$Succesvol) || is.null(catalogue$AquoMetadataLijst) ||
    is.null(catalogue$LocatieLijst) || is.null(catalogue$AquoMetadataLocatieLijst)) {
  stop("RWS catalogue response lacks the required successful metadata/location tables.",
       call. = FALSE)
}

retrieved_utc <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
catalogue_result <- list(
  filename = "rws_extended_catalogue.json",
  url = cfg$catalogue_endpoint,
  checksum = calculate_checksum(catalogue_path),
  status = status,
  size = unname(catalogue_size),
  content_type = httr2::resp_header(response, "content-type") %||% "application/json"
)
all_results <- c(page_results, list(catalogue_result))
manifest <- do.call(rbind, lapply(all_results, function(result) data.frame(
  ds_id = cfg$ds_id,
  acquisition_rank = as.integer(cfg$acquisition_rank),
  provider = cfg$provider,
  provider_dataset_id = paste0("RWS:", cfg$provider_service),
  canonical_provider_dataset_id = paste0("RWS:", cfg$provider_service),
  provider_version = paste0(cfg$provider_service, " catalogue accessed ", substr(retrieved_utc, 1L, 10L)),
  source_role = "canonical_provider",
  request_method = if (result$filename == "rws_extended_catalogue.json") "POST" else "GET",
  request_url = result$url,
  request_parameters_sha256 = if (result$filename == "rws_extended_catalogue.json")
    calculate_checksum(file.path(staging_dir, "catalogue_request.json")) else
    digest::digest(result$url, algo = "sha256", serialize = FALSE),
  retrieved_utc = retrieved_utc,
  raw_relative_path = file.path(run_relative, result$filename),
  filename = result$filename,
  size_bytes = as.numeric(result$size),
  checksum_sha256 = result$checksum,
  content_type = result$content_type %||% "text/html",
  file_validation_state = "verified",
  license_state = "open",
  license_evidence = paste0(
    "Official RWS WaterWebservices documentation states that service contents are CC0; ",
    "the phytoplankton page identifies Waterinfo/WaterWebservices as the provider route."),
  redistribution_state = "allowed",
  citation = paste0(
    "Rijkswaterstaat. WaterWebservices DD API 2.0 catalogue and phytoplankton monitoring metadata. ",
    "Accessed ", substr(retrieved_utc, 1L, 10L), "."),
  doi_or_stable_url = cfg$official_phytoplankton_page,
  manifest_status = "verified",
  status_detail = if (result$filename == "rws_extended_catalogue.json")
    "Complete extended RWS catalogue archived before selecting DS02 metadata/location combinations; observation acquisition remains pending." else
    "Official provider documentation archived as licence, method, and access-route evidence.",
  stringsAsFactors = FALSE,
  check.names = FALSE
)))
validate_stage2_table(manifest, "acquisition_manifest", contract)
write_csv_atomic(manifest, file.path(staging_dir, "manifest.csv"))

summary <- list(
  schema_version = cfg$schema_version,
  completed_utc = retrieved_utc,
  status = "complete",
  work_item_id = cfg$work_item_id,
  acquisition_phase = "canonical_catalogue_archived_observations_pending",
  artifact_count = nrow(manifest),
  total_size_bytes = sum(manifest$size_bytes),
  aquo_metadata_rows = length(catalogue$AquoMetadataLijst),
  location_rows = length(catalogue$LocatieLijst),
  metadata_location_rows = length(catalogue$AquoMetadataLocatieLijst),
  configuration_checksum_sha256 = calculate_checksum(config_path),
  contract_checksum_sha256 = calculate_checksum(cfg$contract_path),
  software_version = R.version.string
)
jsonlite::write_json(summary, file.path(staging_dir, "run_summary.json"),
                     pretty = TRUE, auto_unbox = TRUE)
writeLines(c(
  sprintf("completed_utc: %s", summary$completed_utc),
  sprintf("acquisition_phase: %s", summary$acquisition_phase),
  sprintf("artifact_count: %d", summary$artifact_count),
  sprintf("total_size_bytes: %.0f", summary$total_size_bytes),
  sprintf("aquo_metadata_rows: %d", summary$aquo_metadata_rows),
  sprintf("location_rows: %d", summary$location_rows),
  sprintf("metadata_location_rows: %d", summary$metadata_location_rows),
  sprintf("R: %s", R.version.string)
), file.path(staging_dir, "run.log"), useBytes = TRUE)
if (!file.rename(staging_dir, final_dir)) {
  stop("Unable to atomically finalize the DS02 RWS catalogue acquisition.", call. = FALSE)
}
manifest <- validate_complete_run(final_dir)
write_tracked_pins(final_dir, manifest)
message(sprintf(
  "DS02 canonical RWS catalogue archived: %d metadata, %d locations, %d links; observations pending.",
  summary$aquo_metadata_rows, summary$location_rows, summary$metadata_location_rows
))
