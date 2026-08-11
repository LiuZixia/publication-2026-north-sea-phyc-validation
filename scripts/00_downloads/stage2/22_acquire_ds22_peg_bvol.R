#!/usr/bin/env Rscript
# Acquire the canonical provider PEG_BVOL archive for DS22 into an immutable Stage 2 run.

source("R/00_core_setup.R")
source("R/03_stage2_contract.R")
required_namespace("jsonlite")

verify_raw_data_target(required_gb = 0.1)
work <- utils::read.csv("metadata/stage2/control/acquisition_work_order.csv",
                        stringsAsFactors = FALSE, check.names = FALSE)
work_item_id <- "REGISTER:DS22"
if (!work_item_id %in% work$work_item_id) stop("DS22 is absent from the Stage 2 work order.", call. = FALSE)

config_path <- "config/stage2_ds22_peg_bvol_acquisition.json"
config <- jsonlite::fromJSON(config_path, simplifyVector = TRUE)
pin_path <- "metadata/stage2/acquisition/ds22_peg_bvol_active_run.csv"

valid_existing_pin <- function() {
  if (!file.exists(pin_path)) return(FALSE)
  pin <- utils::read.csv(pin_path, stringsAsFactors = FALSE, check.names = FALSE)
  if (nrow(pin) != 1L || !"run_relative_path" %in% names(pin)) return(FALSE)
  run_dir <- file.path("data", "raw", pin$run_relative_path[[1]])
  manifest_path <- file.path(run_dir, "manifest.csv")
  if (!file.exists(manifest_path) ||
      !identical(calculate_checksum(manifest_path), pin$manifest_checksum_sha256[[1]])) return(FALSE)
  manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE, check.names = FALSE)
  archive <- manifest$file_name[manifest$artifact_role == "conversion_authority_archive"]
  if (length(archive) != 1L) return(FALSE)
  paths <- file.path(run_dir, manifest$file_name)
  if (any(!file.exists(paths)) || any(file.size(paths) != manifest$file_size_bytes) ||
      !identical(unname(vapply(paths, calculate_checksum, character(1))), manifest$checksum_sha256)) return(FALSE)
  listing <- tryCatch(utils::unzip(file.path(run_dir, archive), list = TRUE), error = function(error) NULL)
  !is.null(listing) && config$expected_inner_workbook %in% listing$Name
}

if (valid_existing_pin()) {
  message("Verified the existing canonical DS22 Stage 2 PEG_BVOL acquisition; no download required.")
  quit(save = "no", status = 0L)
}

stamp <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
run_name <- paste0("DS22_PEG_BVOL_", stamp)
run_relative_path <- file.path("stage2", "ds22_peg_bvol", run_name)
run_dir <- file.path("data", "raw", run_relative_path)
dir.create(run_dir, recursive = TRUE, showWarnings = FALSE)
request_path <- file.path(run_dir, "request_parameters.json")
archive_path <- file.path(run_dir, "PEG_BVOL.zip")
log_path <- file.path(run_dir, "acquisition.log")
writeLines(jsonlite::toJSON(list(
  configuration_path = config_path,
  configuration_checksum_sha256 = calculate_checksum(config_path), endpoint = config$endpoint,
  requested_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
), auto_unbox = TRUE, pretty = TRUE), request_path, useBytes = TRUE)
writeLines(c(paste("run_name:", run_name), paste("endpoint:", config$endpoint)), log_path,
           useBytes = TRUE)
download_with_retry(config$endpoint, archive_path, max_tries = 4L,
                    minimum_bytes = as.numeric(config$minimum_zip_bytes), timeout_seconds = 600L)
listing <- utils::unzip(archive_path, list = TRUE)
if (!config$expected_inner_workbook %in% listing$Name) {
  stop(sprintf("DS22 archive lacks %s.", config$expected_inner_workbook), call. = FALSE)
}

manifest_files <- c(request_path, archive_path)
manifest <- data.frame(
  file_name = basename(manifest_files),
  checksum_sha256 = unname(vapply(manifest_files, calculate_checksum, character(1))),
  file_size_bytes = unname(file.size(manifest_files)),
  artifact_role = c("request_parameters", "conversion_authority_archive"),
  provider_endpoint = config$endpoint, provider_version_state = config$provider_version_state,
  stringsAsFactors = FALSE, check.names = FALSE
)
manifest_path <- file.path(run_dir, "manifest.csv")
write_csv_atomic(manifest, manifest_path)
write(c(paste("completed_utc:", format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")),
        paste("inner_workbook:", config$expected_inner_workbook),
        "validation_state: verified_provider_conversion_archive"), log_path, append = TRUE)
pin <- data.frame(
  work_item_id = work_item_id, run_name = run_name, run_relative_path = run_relative_path,
  manifest_checksum_sha256 = calculate_checksum(manifest_path), pinned_at_utc = stamp,
  stringsAsFactors = FALSE, check.names = FALSE
)
write_csv_atomic(pin, pin_path)
message(sprintf("DS22 canonical Stage 2 PEG_BVOL acquisition complete: %s", run_relative_path))
