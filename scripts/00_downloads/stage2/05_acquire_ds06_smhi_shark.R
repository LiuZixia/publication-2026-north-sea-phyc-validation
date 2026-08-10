# Acquire every canonical SMHI SHARK phytoplankton package for rank-1 DS06.

source("R/00_core_setup.R")
source("R/03_stage2_contract.R")
required_namespace("jsonlite")
required_namespace("digest")

config_path <- "config/stage2_ds06_smhi_shark_acquisition.json"
cfg <- jsonlite::fromJSON(config_path, simplifyVector = FALSE)
contract <- read_stage2_contract(cfg$contract_path)
if (!identical(cfg$classification, "stage2_ranked_canonical_provider_acquisition") ||
    !identical(cfg$work_item_id, "REGISTER:DS06") || cfg$acquisition_rank != 1L ||
    !identical(calculate_checksum(cfg$catalogue_path), cfg$catalogue_checksum_sha256)) {
  stop("DS06 SHARK acquisition configuration or pinned catalogue is invalid.", call. = FALSE)
}

catalogue <- jsonlite::fromJSON(cfg$catalogue_path, simplifyVector = FALSE)
required_catalogue_fields <- c("dataset_name", "datatype", "version", "dataset_file_name")
if (length(catalogue) != cfg$expected_catalogue_rows ||
    any(vapply(catalogue, function(row) !all(required_catalogue_fields %in% names(row)), logical(1))) ||
    any(vapply(catalogue, function(row) !identical(row$datatype, cfg$catalogue_datatype), logical(1)))) {
  stop("Pinned SHARK phytoplankton catalogue does not meet the frozen acquisition contract.", call. = FALSE)
}
dataset_names <- vapply(catalogue, function(row) row$dataset_name, character(1))
file_names <- vapply(catalogue, function(row) row$dataset_file_name, character(1))
if (any(!nzchar(dataset_names)) || any(!nzchar(file_names)) || anyDuplicated(dataset_names) ||
    anyDuplicated(file_names) || any(grepl("[/\\\\]", file_names))) {
  stop("SHARK catalogue names are blank, duplicated, or unsafe path components.", call. = FALSE)
}

raw <- verify_raw_data_target(required_gb = cfg$required_free_gb)
run_relative <- file.path("stage2", "ds06_smhi_shark", cfg$acquisition_run_id)
final_dir <- file.path("data", "raw", run_relative)
staging_dir <- paste0(final_dir, ".partial")
manifest_path <- file.path(staging_dir, "manifest.csv")

validate_complete_run <- function(directory) {
  required <- file.path(directory, c("manifest.csv", "run_summary.json", "run.log"))
  if (any(!file.exists(required))) stop("Existing finalized DS06 run is incomplete.", call. = FALSE)
  manifest <- utils::read.csv(file.path(directory, "manifest.csv"), stringsAsFactors = FALSE,
                              check.names = FALSE)
  validate_stage2_table(manifest, "acquisition_manifest", contract)
  summary <- jsonlite::fromJSON(file.path(directory, "run_summary.json"), simplifyVector = FALSE)
  if (!identical(summary$status, "complete") || nrow(manifest) != length(catalogue) ||
      !setequal(manifest$filename, file_names) ||
      !identical(summary$configuration_checksum_sha256, calculate_checksum(config_path)) ||
      !identical(summary$catalogue_checksum_sha256, calculate_checksum(cfg$catalogue_path))) {
    stop("Existing finalized DS06 run does not reconcile with frozen inputs.", call. = FALSE)
  }
  manifest
}

write_active_pin <- function(directory, manifest) {
  summary <- jsonlite::fromJSON(file.path(directory, "run_summary.json"), simplifyVector = FALSE)
  pin <- data.frame(
    work_item_id = cfg$work_item_id,
    run_relative_path = run_relative,
    completed_utc = summary$completed_utc,
    configuration_path = config_path,
    configuration_checksum_sha256 = summary$configuration_checksum_sha256,
    catalogue_checksum_sha256 = summary$catalogue_checksum_sha256,
    manifest_checksum_sha256 = calculate_checksum(file.path(directory, "manifest.csv")),
    run_summary_checksum_sha256 = calculate_checksum(file.path(directory, "run_summary.json")),
    package_count = nrow(manifest),
    total_size_bytes = sum(manifest$size_bytes),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  write_csv_atomic(manifest, "metadata/stage2/acquisition/ds06_smhi_shark_acquisition_manifest.csv")
  write_csv_atomic(pin, "metadata/stage2/acquisition/ds06_smhi_shark_active_run.csv")
}

if (dir.exists(final_dir)) {
  manifest <- validate_complete_run(final_dir)
  write_active_pin(final_dir, manifest)
  message(sprintf("Verified existing DS06 SHARK run with %d packages; no download required.", nrow(manifest)))
  quit(save = "no", status = 0L)
}
dir.create(staging_dir, recursive = TRUE, showWarnings = FALSE)
manifest <- if (file.exists(manifest_path)) {
  utils::read.csv(manifest_path, stringsAsFactors = FALSE, check.names = FALSE)
} else {
  stage2_empty_table(contract, "acquisition_manifest")
}
validate_stage2_table(manifest, "acquisition_manifest", contract)

test_zip <- function(path) {
  output <- system2("unzip", c("-t", shQuote(path)), stdout = TRUE, stderr = TRUE)
  status <- attr(output, "status")
  if (is.null(status)) status <- 0L
  if (status != 0L || !any(grepl("No errors detected", output, fixed = TRUE))) {
    stop(sprintf("Downloaded SHARK package failed ZIP integrity testing: %s", path), call. = FALSE)
  }
  invisible(TRUE)
}

for (i in seq_along(catalogue)) {
  row <- catalogue[[i]]
  destination <- file.path(staging_dir, row$dataset_file_name)
  existing <- match(row$dataset_file_name, manifest$filename)
  if (!is.na(existing)) {
    if (!file.exists(destination) ||
        !identical(calculate_checksum(destination), manifest$checksum_sha256[[existing]])) {
      stop(sprintf("Resumable DS06 file differs from its manifest: %s", row$dataset_file_name), call. = FALSE)
    }
    next
  }
  if (file.exists(destination)) {
    stop(sprintf("Unregistered file exists in DS06 staging run: %s", destination), call. = FALSE)
  }
  encoded_file <- utils::URLencode(row$dataset_file_name, reserved = TRUE)
  url <- sprintf(cfg$download_url_template, encoded_file)
  result <- download_with_retry(url, destination, max_tries = 4L, minimum_bytes = 100L,
                                timeout_seconds = 300L)
  test_zip(destination)
  new_row <- data.frame(
    ds_id = cfg$ds_id,
    acquisition_rank = as.integer(cfg$acquisition_rank),
    provider = cfg$provider,
    provider_dataset_id = row$dataset_name,
    canonical_provider_dataset_id = paste0("SHARK:", row$dataset_name),
    provider_version = row$version,
    source_role = cfg$source_role,
    request_method = "GET",
    request_url = url,
    request_parameters_sha256 = digest::digest(url, algo = "sha256", serialize = FALSE),
    retrieved_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    raw_relative_path = file.path(run_relative, row$dataset_file_name),
    filename = row$dataset_file_name,
    size_bytes = as.numeric(result$size),
    checksum_sha256 = result$checksum,
    content_type = result$content_type %||% "application/zip",
    file_validation_state = "verified",
    license_state = cfg$license_state,
    license_evidence = paste(cfg$license_evidence, cfg$license_url),
    redistribution_state = "allowed",
    citation = cfg$citation,
    doi_or_stable_url = sprintf(cfg$metadata_url_template,
                                utils::URLencode(row$dataset_name, reserved = TRUE)),
    manifest_status = "verified",
    status_detail = "Downloaded from canonical SHARK package endpoint and passed unzip -t CRC validation.",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  manifest <- rbind(manifest, new_row)
  manifest <- manifest[order(manifest$acquisition_rank, manifest$provider_dataset_id), , drop = FALSE]
  validate_stage2_table(manifest, "acquisition_manifest", contract)
  write_csv_atomic(manifest, manifest_path)
  message(sprintf("DS06 SHARK package %d/%d verified: %s", i, length(catalogue), row$dataset_file_name))
}

if (nrow(manifest) != length(catalogue) || !setequal(manifest$filename, file_names)) {
  stop("DS06 SHARK acquisition ended without all frozen catalogue packages.", call. = FALSE)
}
summary <- list(
  schema_version = cfg$schema_version,
  completed_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  status = "complete",
  work_item_id = cfg$work_item_id,
  package_count = nrow(manifest),
  total_size_bytes = sum(manifest$size_bytes),
  configuration_path = config_path,
  configuration_checksum_sha256 = calculate_checksum(config_path),
  catalogue_path = cfg$catalogue_path,
  catalogue_checksum_sha256 = calculate_checksum(cfg$catalogue_path),
  contract_checksum_sha256 = calculate_checksum(cfg$contract_path),
  software_version = R.version.string
)
jsonlite::write_json(summary, file.path(staging_dir, "run_summary.json"), pretty = TRUE, auto_unbox = TRUE)
writeLines(c(
  sprintf("completed_utc: %s", summary$completed_utc),
  sprintf("package_count: %d", summary$package_count),
  sprintf("total_size_bytes: %.0f", summary$total_size_bytes),
  sprintf("configuration_sha256: %s", summary$configuration_checksum_sha256),
  sprintf("catalogue_sha256: %s", summary$catalogue_checksum_sha256),
  sprintf("R: %s", R.version.string)
), file.path(staging_dir, "run.log"), useBytes = TRUE)
if (!file.rename(staging_dir, final_dir)) stop("Unable to atomically finalize DS06 SHARK acquisition.", call. = FALSE)
manifest <- validate_complete_run(final_dir)
write_active_pin(final_dir, manifest)
message(sprintf("DS06 SHARK acquisition complete: %d packages, %.2f GB.",
                nrow(manifest), sum(manifest$size_bytes) / 1024^3))
