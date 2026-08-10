# Pin and checksum-verify one official-metadata run for the exact-domain WFS survivors.

source("R/00_core_setup.R")
source("R/03_stage2_contract.R")
required_namespace("jsonlite")

arguments <- commandArgs(trailingOnly = TRUE)
if (length(arguments) != 1L) {
  stop("Usage: Rscript scripts/02_stage2/wfs/02_register_metadata_run.R data/raw/stage2/emodnet_wfs_survivor_metadata/<UTC>", call. = FALSE)
}
run_dir <- normalizePath(arguments[[1]], mustWork = TRUE)
raw <- verify_raw_data_target(required_gb = 0.01)
raw_prefix <- paste0(raw$path, .Platform$file.sep)
if (!startsWith(run_dir, raw_prefix) || grepl("\\.partial$", run_dir)) {
  stop("Metadata run must be finalized beneath the required raw target.", call. = FALSE)
}
summary <- jsonlite::fromJSON(file.path(run_dir, "run_summary.json"), simplifyVector = FALSE)
manifest <- utils::read.csv(file.path(run_dir, "manifest.csv"), stringsAsFactors = FALSE,
                            check.names = FALSE, colClasses = c(dataset_id = "character"))
if (!identical(summary$status, "complete") || !identical(summary$dataset_count, 3L) ||
    nrow(manifest) != 3L || !setequal(manifest$dataset_id, c("2453", "5951", "6698")) ||
    !identical(summary$configuration_checksum_sha256, calculate_checksum(summary$configuration_path))) {
  stop("Official WFS survivor metadata run does not reconcile.", call. = FALSE)
}
for (i in seq_len(nrow(manifest))) {
  path <- file.path("data", "raw", manifest$raw_relative_path[[i]])
  if (!file.exists(path) || !identical(calculate_checksum(path), manifest$checksum_sha256[[i]])) {
    stop(sprintf("Official metadata checksum failed: %s", manifest$raw_relative_path[[i]]), call. = FALSE)
  }
}
pin <- data.frame(
  run_relative_path = substring(run_dir, nchar(raw_prefix) + 1L),
  completed_utc = summary$completed_utc,
  configuration_path = summary$configuration_path,
  configuration_checksum_sha256 = summary$configuration_checksum_sha256,
  geometry_evidence_checksum_sha256 = summary$geometry_evidence_checksum_sha256,
  manifest_checksum_sha256 = calculate_checksum(file.path(run_dir, "manifest.csv")),
  run_summary_checksum_sha256 = calculate_checksum(file.path(run_dir, "run_summary.json")),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
write_csv_atomic(pin, "metadata/stage2/acquisition/emodnet_wfs_metadata_active_run.csv")
message(sprintf("Pinned official WFS survivor metadata: %s", pin$run_relative_path))
