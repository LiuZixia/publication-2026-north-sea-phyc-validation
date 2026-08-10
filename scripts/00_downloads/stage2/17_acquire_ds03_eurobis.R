# Acquire canonical EurOBIS IPT archives for DS03: Dutch long term monitoring
# Target period: 1990-2018 (split across two datasets in IPT)

source("R/00_core_setup.R")
source("R/03_stage2_contract.R")
required_namespace("httr")

contract <- read_stage2_contract()
work_order <- utils::read.csv("metadata/stage2/control/acquisition_work_order.csv", stringsAsFactors = FALSE)
status <- utils::read.csv("metadata/stage2/control/acquisition_status.csv", stringsAsFactors = FALSE)

dataset_id <- "DS03"
work_item_id <- paste0("REGISTER:", dataset_id)
if (!work_item_id %in% work_order$work_item_id) {
  stop("DS03 is not in the Stage 2 work order.", call. = FALSE)
}
if (status$acquisition_state[status$work_item_id == work_item_id] == "complete") {
  stop("DS03 is already marked complete.", call. = FALSE)
}

timestamp <- strftime(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
run_name <- paste0("DS03_EUROBIS_IPT_", timestamp)
run_dir <- file.path("data", "raw", "stage2", "ds03_eurobis", run_name)
if (!dir.exists(run_dir)) dir.create(run_dir, recursive = TRUE)

log_path <- file.path(run_dir, "acquisition.log")
cat(sprintf("Beginning acquisition of DS03 from EurOBIS IPT\n"), file = log_path)

datasets <- list(
  list(name = "mwtl_phytoplankton", url = "https://ipt.vliz.be/eurobis/archive.do?r=mwtl_phytoplankton"),
  list(name = "mwtl_phytoplankton2", url = "https://ipt.vliz.be/eurobis/archive.do?r=mwtl_phytoplankton2")
)

manifest_rows <- list()

for (ds in datasets) {
  cat(sprintf("\nProcessing IPT dataset: %s\n", ds$name), file = log_path, append = TRUE)
  cat(sprintf("URL: %s\n", ds$url), file = log_path, append = TRUE)
  
  zip_filename <- sprintf("%s.zip", ds$name)
  zip_path <- file.path(run_dir, zip_filename)
  
  res <- httr::GET(ds$url, httr::write_disk(zip_path, overwrite = TRUE), httr::timeout(3600))
  if (httr::status_code(res) != 200) {
    stop(sprintf("EurOBIS IPT download failed for %s with status code: %d", ds$name, httr::status_code(res)), call. = FALSE)
  }
  
  cat("Download complete.\n", file = log_path, append = TRUE)
  
  checksum <- calculate_checksum(zip_path)
  manifest_rows[[length(manifest_rows) + 1]] <- data.frame(
    file_name = zip_filename,
    checksum_sha256 = checksum,
    file_size_bytes = file.size(zip_path),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

manifest <- do.call(rbind, manifest_rows)
manifest_path <- file.path(run_dir, "manifest.csv")
write_csv_atomic(manifest, manifest_path)

pin <- data.frame(
  work_item_id = work_item_id,
  run_name = run_name,
  run_relative_path = file.path("stage2", "ds03_eurobis", run_name),
  manifest_checksum_sha256 = calculate_checksum(manifest_path),
  pinned_at_utc = timestamp,
  stringsAsFactors = FALSE,
  check.names = FALSE
)
write_csv_atomic(pin, "metadata/stage2/acquisition/ds03_eurobis_active_run.csv")

message("DS03 EurOBIS IPT acquisition complete.")
