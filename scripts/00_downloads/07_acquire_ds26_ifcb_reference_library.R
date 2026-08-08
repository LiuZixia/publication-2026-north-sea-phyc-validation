# Archive the full DS26 manually annotated IFCB reference library as method evidence.

source("R/00_core_setup.R")
source("R/03_stage2_contract.R")
required_namespace("jsonlite")
required_namespace("digest")

config_path <- "config/stage2_ds26_ifcb_reference_library.json"
cfg <- jsonlite::fromJSON(config_path, simplifyVector = FALSE)
contract <- read_stage2_contract(cfg$contract_path)
if (!identical(cfg$classification, "stage2_method_reference_acquisition") ||
    !identical(cfg$work_item_id, "REGISTER:DS26") || cfg$acquisition_rank != 2L ||
    !identical(calculate_checksum(cfg$inventory_path), cfg$inventory_checksum_sha256) ||
    !identical(calculate_checksum(cfg$article_raw_path), cfg$article_raw_checksum_sha256)) {
  stop("DS26 IFCB reference-library configuration or pinned inputs are invalid.", call. = FALSE)
}
inventory <- utils::read.csv(cfg$inventory_path, stringsAsFactors = FALSE, check.names = FALSE,
                             colClasses = c(file_id = "character"))
if (nrow(inventory) != cfg$expected_file_count ||
    sum(inventory$size_bytes) != cfg$expected_total_size_bytes ||
    any(!nzchar(inventory$download_url)) || anyDuplicated(inventory$file_id) ||
    anyDuplicated(inventory$filename)) {
  stop("Pinned Figshare file inventory differs from the frozen reference acquisition.", call. = FALSE)
}

verify_raw_data_target(required_gb = cfg$required_free_gb)
run_relative <- file.path("stage2", "ds26_ifcb_reference", cfg$acquisition_run_id)
final_dir <- file.path("data", "raw", run_relative)
staging_dir <- paste0(final_dir, ".partial")
manifest_path <- file.path(staging_dir, "manifest.csv")

validate_complete_run <- function(directory) {
  required <- file.path(directory, c(inventory$filename, "manifest.csv", "run_summary.json", "run.log"))
  if (any(!file.exists(required))) stop("Existing finalized IFCB reference run is incomplete.", call. = FALSE)
  manifest <- utils::read.csv(file.path(directory, "manifest.csv"), stringsAsFactors = FALSE,
                              check.names = FALSE)
  validate_stage2_table(manifest, "acquisition_manifest", contract)
  if (nrow(manifest) != nrow(inventory) || !setequal(manifest$filename, inventory$filename) ||
      any(vapply(seq_len(nrow(manifest)), function(i) {
        path <- file.path("data", "raw", manifest$raw_relative_path[[i]])
        !file.exists(path) || !identical(calculate_checksum(path), manifest$checksum_sha256[[i]])
      }, logical(1)))) {
    stop("Finalized IFCB reference manifest does not reconcile.", call. = FALSE)
  }
  summary <- jsonlite::fromJSON(file.path(directory, "run_summary.json"), simplifyVector = FALSE)
  if (!identical(summary$status, "complete") ||
      !identical(summary$configuration_checksum_sha256, calculate_checksum(config_path))) {
    stop("Finalized IFCB reference summary differs from its configuration.", call. = FALSE)
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
    source_inventory_checksum_sha256 = cfg$inventory_checksum_sha256,
    manifest_checksum_sha256 = calculate_checksum(file.path(directory, "manifest.csv")),
    run_summary_checksum_sha256 = calculate_checksum(file.path(directory, "run_summary.json")),
    file_count = nrow(manifest),
    total_size_bytes = sum(manifest$size_bytes),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  write_csv_atomic(manifest, "metadata/stage2_ds26_ifcb_reference_acquisition_manifest.csv")
  write_csv_atomic(pin, "metadata/stage2_ds26_ifcb_reference_active_run.csv")
}

if (dir.exists(final_dir)) {
  manifest <- validate_complete_run(final_dir)
  write_tracked_pins(final_dir, manifest)
  message("Verified existing DS26 IFCB reference-library run; no download required.")
  quit(save = "no", status = 0L)
}
dir.create(staging_dir, recursive = TRUE, showWarnings = FALSE)
manifest <- if (file.exists(manifest_path)) {
  utils::read.csv(manifest_path, stringsAsFactors = FALSE, check.names = FALSE)
} else {
  stage2_empty_table(contract, "acquisition_manifest")
}
validate_stage2_table(manifest, "acquisition_manifest", contract)

for (i in seq_len(nrow(inventory))) {
  row <- inventory[i, , drop = FALSE]
  destination <- file.path(staging_dir, row$filename[[1]])
  existing <- match(row$filename[[1]], manifest$filename)
  if (!is.na(existing)) {
    if (!file.exists(destination) || file.info(destination)$size != row$size_bytes[[1]] ||
        !identical(digest::digest(destination, algo = "md5", file = TRUE), row$computed_md5[[1]])) {
      stop(sprintf("Resumable IFCB reference file differs from its manifest: %s", row$filename[[1]]),
           call. = FALSE)
    }
    next
  }
  if (file.exists(destination)) stop(sprintf("Unregistered partial file exists: %s", destination), call. = FALSE)
  result <- download_with_retry(row$download_url[[1]], destination, max_tries = 4L,
                                minimum_bytes = max(1L, min(row$size_bytes[[1]], 1000L)),
                                timeout_seconds = 1800L)
  if (result$size != row$size_bytes[[1]] ||
      !identical(digest::digest(destination, algo = "md5", file = TRUE), row$computed_md5[[1]])) {
    stop(sprintf("Figshare size or MD5 validation failed: %s", row$filename[[1]]), call. = FALSE)
  }
  if (grepl("[.]zip$", row$filename[[1]], ignore.case = TRUE)) {
    zip_test <- system2("unzip", c("-t", shQuote(destination)), stdout = TRUE, stderr = TRUE)
    status <- attr(zip_test, "status") %||% 0L
    if (status != 0L || !any(grepl("No errors detected", zip_test, fixed = TRUE))) {
      stop(sprintf("Figshare ZIP integrity failed: %s", row$filename[[1]]), call. = FALSE)
    }
  }
  new_row <- data.frame(
    ds_id = cfg$ds_id,
    acquisition_rank = as.integer(cfg$acquisition_rank),
    provider = cfg$provider,
    provider_dataset_id = cfg$provider_dataset_id,
    canonical_provider_dataset_id = cfg$provider_dataset_id,
    provider_version = cfg$provider_version,
    source_role = "comparator",
    request_method = "GET",
    request_url = row$download_url[[1]],
    request_parameters_sha256 = digest::digest(row$download_url[[1]], algo = "sha256", serialize = FALSE),
    retrieved_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    raw_relative_path = file.path(run_relative, row$filename[[1]]),
    filename = row$filename[[1]],
    size_bytes = as.numeric(result$size),
    checksum_sha256 = result$checksum,
    content_type = result$content_type %||% "application/octet-stream",
    file_validation_state = "verified",
    license_state = "open",
    license_evidence = paste(cfg$license, cfg$license_url),
    redistribution_state = "allowed",
    citation = paste0("Torstensson et al. (2024). SMHI IFCB Plankton Image Reference Library. ",
                      "https://doi.org/", cfg$doi),
    doi_or_stable_url = paste0("https://doi.org/", cfg$doi),
    manifest_status = "verified",
    status_detail = paste("Full reference-library file archived for", cfg$scientific_role),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  manifest <- rbind(manifest, new_row)
  validate_stage2_table(manifest, "acquisition_manifest", contract)
  write_csv_atomic(manifest, manifest_path)
  message(sprintf("DS26 reference file %d/%d verified: %s", i, nrow(inventory), row$filename[[1]]))
}

if (nrow(manifest) != nrow(inventory) || sum(manifest$size_bytes) != cfg$expected_total_size_bytes) {
  stop("DS26 IFCB reference acquisition does not reconcile with the pinned inventory.", call. = FALSE)
}
summary <- list(
  schema_version = cfg$schema_version,
  completed_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  status = "complete",
  work_item_id = cfg$work_item_id,
  file_count = nrow(manifest),
  total_size_bytes = sum(manifest$size_bytes),
  scientific_role = cfg$scientific_role,
  configuration_checksum_sha256 = calculate_checksum(config_path),
  source_inventory_checksum_sha256 = cfg$inventory_checksum_sha256,
  contract_checksum_sha256 = calculate_checksum(cfg$contract_path),
  software_version = R.version.string
)
jsonlite::write_json(summary, file.path(staging_dir, "run_summary.json"), pretty = TRUE, auto_unbox = TRUE)
writeLines(c(
  sprintf("completed_utc: %s", summary$completed_utc),
  sprintf("file_count: %d", summary$file_count),
  sprintf("total_size_bytes: %.0f", summary$total_size_bytes),
  paste("scientific_role:", summary$scientific_role),
  sprintf("R: %s", R.version.string)
), file.path(staging_dir, "run.log"), useBytes = TRUE)
if (!file.rename(staging_dir, final_dir)) stop("Unable to atomically finalize IFCB reference run.", call. = FALSE)
manifest <- validate_complete_run(final_dir)
write_tracked_pins(final_dir, manifest)
message(sprintf("DS26 IFCB reference library complete: %d files, %.2f GB.",
                nrow(manifest), sum(manifest$size_bytes) / 1024^3))
