# Acquire canonical PANGAEA data for DS27: COSYNA/Hereon FerryBox series
# Targets: PANGAEA.883824 (2002-2005) and PANGAEA.930383 (2007-2012)

source("R/00_core_setup.R")
source("R/03_stage2_contract.R")
required_namespace("httr")

contract <- read_stage2_contract()
work_order <- utils::read.csv("metadata/stage2_acquisition_work_order.csv", stringsAsFactors = FALSE)
status <- utils::read.csv("metadata/stage2_acquisition_status.csv", stringsAsFactors = FALSE)

dataset_id <- "DS27"
work_item_id <- paste0("REGISTER:", dataset_id)
if (!work_item_id %in% work_order$work_item_id) {
  stop(sprintf("%s is not in the Stage 2 work order.", dataset_id), call. = FALSE)
}
if (status$acquisition_state[status$work_item_id == work_item_id] == "complete") {
  stop(sprintf("%s is already marked complete.", dataset_id), call. = FALSE)
}

timestamp <- strftime(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
run_name <- paste0("DS27_PANGAEA_", timestamp)
run_dir <- file.path("data", "raw", "stage2", "ds27_pangaea_ferrybox", run_name)
if (!dir.exists(run_dir)) dir.create(run_dir, recursive = TRUE)

log_path <- file.path(run_dir, "acquisition.log")
cat(sprintf("Beginning acquisition of %s from PANGAEA\n", dataset_id), file = log_path)

manifest_rows <- list()

# 1. Dataset 883824 (Text file with NetCDF links)
cat("Processing 883824...\n", file = log_path, append = TRUE)
url_883824 <- "https://doi.pangaea.de/10.1594/PANGAEA.883824?format=textfile"
file_883824 <- file.path(run_dir, "PANGAEA_883824.txt")

res <- httr::GET(url_883824, httr::write_disk(file_883824, overwrite = TRUE), httr::timeout(60))
if (httr::status_code(res) == 200) {
  content_883824 <- readLines(file_883824, warn = FALSE)
  # Extract links to NetCDF files
  links <- regmatches(content_883824, gregexpr("https://store\\.pangaea\\.de/.*\\.nc", content_883824))
  links <- unique(unlist(links))
  
  cat(sprintf("Found %d NetCDF files for 883824. Downloading...\n", length(links)), file = log_path, append = TRUE)
  for (link in links) {
    file_name <- basename(link)
    file_path <- file.path(run_dir, file_name)
    dl_res <- httr::GET(link, httr::write_disk(file_path, overwrite = TRUE), httr::timeout(300))
    if (httr::status_code(dl_res) == 200) {
      manifest_rows[[length(manifest_rows) + 1]] <- data.frame(
        file_name = file_name,
        checksum_sha256 = calculate_checksum(file_path),
        file_size_bytes = file.size(file_path),
        stringsAsFactors = FALSE,
        check.names = FALSE
      )
    } else {
      warning(sprintf("Failed to download %s", link))
    }
  }
} else {
  warning("Failed to fetch 883824 textfile")
}

# 2. Dataset 930383 (Zip collection)
cat("Processing 930383...\n", file = log_path, append = TRUE)
url_930383 <- "https://doi.pangaea.de/10.1594/PANGAEA.930383?format=zip"
file_930383 <- file.path(run_dir, "PANGAEA_930383.zip")

res_zip <- httr::GET(url_930383, httr::write_disk(file_930383, overwrite = TRUE), httr::timeout(3600))
if (httr::status_code(res_zip) == 200) {
  manifest_rows[[length(manifest_rows) + 1]] <- data.frame(
    file_name = basename(file_930383),
    checksum_sha256 = calculate_checksum(file_930383),
    file_size_bytes = file.size(file_930383),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
} else {
  warning(sprintf("Failed to fetch 930383 zip, status: %d", httr::status_code(res_zip)))
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
  run_relative_path = file.path("stage2", "ds27_pangaea_ferrybox", run_name),
  manifest_checksum_sha256 = calculate_checksum(manifest_path),
  pinned_at_utc = timestamp,
  stringsAsFactors = FALSE,
  check.names = FALSE
)
write_csv_atomic(pin, "metadata/stage2_ds27_pangaea_ferrybox_active_run.csv")

message("DS27 PANGAEA Ferrybox acquisition complete.")
