# Acquire canonical ICES Figshare data for DS24: OSPAR COMP4 COMPEAT inputs
# Article ID: 22189111

source("R/00_core_setup.R")
source("R/03_stage2_contract.R")
required_namespace("httr")
required_namespace("jsonlite")

contract <- read_stage2_contract()
work_order <- utils::read.csv("metadata/stage2_acquisition_work_order.csv", stringsAsFactors = FALSE)
status <- utils::read.csv("metadata/stage2_acquisition_status.csv", stringsAsFactors = FALSE)

dataset_id <- "DS24"
work_item_id <- paste0("REGISTER:", dataset_id)
if (!work_item_id %in% work_order$work_item_id) {
  stop(sprintf("%s is not in the Stage 2 work order.", dataset_id), call. = FALSE)
}
if (status$acquisition_state[status$work_item_id == work_item_id] == "complete") {
  stop(sprintf("%s is already marked complete.", dataset_id), call. = FALSE)
}

timestamp <- strftime(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
run_name <- paste0("DS24_FIGSHARE_", timestamp)
run_dir <- file.path("data", "raw", "stage2", "ds24_figshare", run_name)
if (!dir.exists(run_dir)) dir.create(run_dir, recursive = TRUE)

log_path <- file.path(run_dir, "acquisition.log")
cat(sprintf("Beginning acquisition of %s from ICES Figshare\n", dataset_id), file = log_path)

article_id <- "22189111"
files_url <- sprintf("https://api.figshare.com/v2/articles/%s/files", article_id)

res <- httr::GET(files_url)
if (httr::status_code(res) != 200) {
  stop(sprintf("Failed to fetch Figshare files list: %d", httr::status_code(res)), call. = FALSE)
}

files_data <- jsonlite::fromJSON(httr::content(res, "text", encoding = "UTF-8"))
manifest_rows <- list()

for (i in seq_len(nrow(files_data))) {
  file_name <- files_data$name[i]
  download_url <- files_data$download_url[i]
  
  cat(sprintf("Downloading file: %s\n", file_name), file = log_path, append = TRUE)
  file_path <- file.path(run_dir, file_name)
  
  dl_res <- httr::GET(download_url, httr::write_disk(file_path, overwrite = TRUE), httr::timeout(3600))
  if (httr::status_code(dl_res) != 200) {
    warning(sprintf("Failed to download file %s. Status: %d", file_name, httr::status_code(dl_res)))
    next
  }
  
  checksum <- calculate_checksum(file_path)
  manifest_rows[[length(manifest_rows) + 1]] <- data.frame(
    file_name = file_name,
    checksum_sha256 = checksum,
    file_size_bytes = file.size(file_path),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

if (length(manifest_rows) == 0) {
  stop("No files were successfully downloaded.", call. = FALSE)
}

manifest <- do.call(rbind, manifest_rows)
manifest_path <- file.path(run_dir, "manifest.csv")
write_csv_atomic(manifest, manifest_path)

pin <- data.frame(
  work_item_id = work_item_id,
  run_name = run_name,
  run_relative_path = file.path("stage2", "ds24_figshare", run_name),
  manifest_checksum_sha256 = calculate_checksum(manifest_path),
  pinned_at_utc = timestamp,
  stringsAsFactors = FALSE,
  check.names = FALSE
)
write_csv_atomic(pin, "metadata/stage2_ds24_figshare_active_run.csv")

message("DS24 Figshare acquisition complete.")
