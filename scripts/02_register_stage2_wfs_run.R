# Pin one successfully finalized Stage 2 EMODnet WFS geometry run after verifying every response.

source("R/00_core_setup.R")
source("R/03_stage2_contract.R")
required_namespace("jsonlite")

arguments <- commandArgs(trailingOnly = TRUE)
if (length(arguments) != 1L) {
  stop("Usage: Rscript scripts/02_register_stage2_wfs_run.R data/raw/stage2/emodnet_wfs_geometry/<UTC>", call. = FALSE)
}
run_dir <- normalizePath(arguments[[1]], mustWork = TRUE)
raw <- verify_raw_data_target(required_gb = 0.01)
raw_prefix <- paste0(raw$path, .Platform$file.sep)
if (!startsWith(run_dir, raw_prefix) || grepl("\\.partial$", run_dir)) {
  stop("The WFS run must be a finalized directory beneath the required raw target.", call. = FALSE)
}
required_files <- file.path(run_dir, c("manifest.csv", "dataset_hit_summary.csv", "run_summary.json", "run.log"))
if (any(!file.exists(required_files))) stop("Finalized WFS run is incomplete.", call. = FALSE)

summary <- jsonlite::fromJSON(file.path(run_dir, "run_summary.json"), simplifyVector = FALSE)
if (!identical(summary$status, "complete") || !identical(summary$queued_datasets, 40L) ||
    !identical(summary$queried_datasets, 40L)) {
  stop("WFS run summary does not document a complete 40-dataset run.", call. = FALSE)
}
if (!identical(summary$configuration_checksum_sha256,
               calculate_checksum(summary$configuration_path))) {
  stop("WFS run configuration checksum no longer matches.", call. = FALSE)
}

manifest <- utils::read.csv(file.path(run_dir, "manifest.csv"), stringsAsFactors = FALSE,
                            check.names = FALSE)
if (nrow(manifest) != summary$manifest_rows || anyDuplicated(manifest$raw_relative_path)) {
  stop("WFS manifest row count or raw paths do not reconcile.", call. = FALSE)
}
for (i in seq_len(nrow(manifest))) {
  path <- file.path("data", "raw", manifest$raw_relative_path[[i]])
  if (!file.exists(path) || !identical(calculate_checksum(path), manifest$checksum_sha256[[i]])) {
    stop(sprintf("WFS response checksum failed: %s", manifest$raw_relative_path[[i]]), call. = FALSE)
  }
}

relative_run <- substring(run_dir, nchar(raw_prefix) + 1L)
pin <- data.frame(
  run_relative_path = relative_run,
  completed_utc = summary$completed_utc,
  configuration_path = summary$configuration_path,
  configuration_checksum_sha256 = summary$configuration_checksum_sha256,
  contract_checksum_sha256 = summary$contract_checksum_sha256,
  queue_checksum_sha256 = summary$queue_checksum_sha256,
  domain_geometry_checksum_sha256 = summary$domain_geometry_checksum_sha256,
  manifest_checksum_sha256 = calculate_checksum(file.path(run_dir, "manifest.csv")),
  dataset_hit_summary_checksum_sha256 = calculate_checksum(file.path(run_dir, "dataset_hit_summary.csv")),
  run_summary_checksum_sha256 = calculate_checksum(file.path(run_dir, "run_summary.json")),
  manifest_rows = as.integer(summary$manifest_rows),
  bbox_records_archived = as.integer(summary$bbox_records_archived),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
write_csv_atomic(pin, "metadata/stage2_emodnet_wfs_active_run.csv")
message(sprintf("Pinned and checksum-verified Stage 2 WFS run: %s", relative_run))
