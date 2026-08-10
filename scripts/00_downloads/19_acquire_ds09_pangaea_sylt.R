# Acquire canonical PANGAEA data for DS09: Sylt Roads microplankton
# Primary target: PANGAEA.150033 (quantitative series 1992-2013)

source("R/00_core_setup.R")
source("R/03_stage2_contract.R")
required_namespace("httr")

contract <- read_stage2_contract()
work_order <- utils::read.csv("metadata/stage2_acquisition_work_order.csv", stringsAsFactors = FALSE)
status <- utils::read.csv("metadata/stage2_acquisition_status.csv", stringsAsFactors = FALSE)

dataset_id <- "DS09"
work_item_id <- paste0("REGISTER:", dataset_id)
if (!work_item_id %in% work_order$work_item_id) {
  stop(sprintf("%s is not in the Stage 2 work order.", dataset_id), call. = FALSE)
}
if (status$acquisition_state[status$work_item_id == work_item_id] == "complete") {
  stop(sprintf("%s is already marked complete.", dataset_id), call. = FALSE)
}

timestamp <- strftime(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
run_name <- paste0("DS09_PANGAEA_", timestamp)
run_dir <- file.path("data", "raw", "stage2", "ds09_pangaea", run_name)
if (!dir.exists(run_dir)) dir.create(run_dir, recursive = TRUE)

log_path <- file.path(run_dir, "acquisition.log")
cat(sprintf("Beginning acquisition of %s from PANGAEA\n", dataset_id), file = log_path)

# Download the parent dataset file
parent_doi <- "10.1594/PANGAEA.150033"
parent_url <- sprintf("https://doi.pangaea.de/%s?format=textfile", parent_doi)
parent_file <- file.path(run_dir, "parent_150033.txt")

cat(sprintf("Fetching parent dataset %s\n", parent_doi), file = log_path, append = TRUE)
res <- httr::GET(parent_url, httr::write_disk(parent_file, overwrite = TRUE), httr::timeout(60))
if (httr::status_code(res) != 200) {
  stop(sprintf("Failed to fetch PANGAEA parent dataset. Status: %d", httr::status_code(res)), call. = FALSE)
}

# Parse parent to extract child PANGAEA DOIs
parent_content <- paste(readLines(parent_file, warn = FALSE), collapse = " ")
matches <- regmatches(parent_content, gregexpr("10\\.1594/PANGAEA\\.\\d+", parent_content))
child_dois <- unique(unlist(matches))
child_dois <- setdiff(child_dois, parent_doi)

if (length(child_dois) == 0) {
  stop("No child DOIs found in the parent dataset.", call. = FALSE)
}

cat(sprintf("Found %d child DOIs to download.\n", length(child_dois)), file = log_path, append = TRUE)

manifest_rows <- list()
for (doi in child_dois) {
  ds_id_clean <- gsub("10.1594/", "", doi)
  file_name <- paste0(ds_id_clean, ".txt")
  file_path <- file.path(run_dir, file_name)
  download_url <- sprintf("https://doi.pangaea.de/%s?format=textfile", doi)
  
  cat(sprintf("Downloading %s\n", doi), file = log_path, append = TRUE)
  dl_res <- httr::GET(download_url, httr::write_disk(file_path, overwrite = TRUE), httr::timeout(60))
  if (httr::status_code(dl_res) != 200) {
    warning(sprintf("Failed to download %s. Status: %d", doi, httr::status_code(dl_res)))
    next
  }
  
  Sys.sleep(1) # Be nice to PANGAEA
  
  checksum <- calculate_checksum(file_path)
  manifest_rows[[length(manifest_rows) + 1]] <- data.frame(
    file_name = file_name,
    checksum_sha256 = checksum,
    file_size_bytes = file.size(file_path),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

# Add parent to manifest
manifest_rows[[length(manifest_rows) + 1]] <- data.frame(
  file_name = basename(parent_file),
  checksum_sha256 = calculate_checksum(parent_file),
  file_size_bytes = file.size(parent_file),
  stringsAsFactors = FALSE,
  check.names = FALSE
)

if (length(manifest_rows) == 1) {
  stop("No child files were successfully downloaded.", call. = FALSE)
}

manifest <- do.call(rbind, manifest_rows)
manifest_path <- file.path(run_dir, "manifest.csv")
write_csv_atomic(manifest, manifest_path)

pin <- data.frame(
  work_item_id = work_item_id,
  run_name = run_name,
  run_relative_path = file.path("stage2", "ds09_pangaea", run_name),
  manifest_checksum_sha256 = calculate_checksum(manifest_path),
  pinned_at_utc = timestamp,
  stringsAsFactors = FALSE,
  check.names = FALSE
)
write_csv_atomic(pin, "metadata/stage2_ds09_pangaea_active_run.csv")

message("DS09 PANGAEA acquisition complete.")
