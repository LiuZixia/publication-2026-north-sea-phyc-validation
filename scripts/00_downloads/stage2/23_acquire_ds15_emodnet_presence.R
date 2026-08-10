# Acquire canonical EMODnet Greater North Sea presence/absence product (DS15)
# Target: biology_6587_phyto_north_sea_4bd1_a08c_0019 from ERDDAP

source("R/00_core_setup.R")
source("R/03_stage2_contract.R")
required_namespace("httr")

contract <- read_stage2_contract()
work_order <- utils::read.csv("metadata/stage2/control/acquisition_work_order.csv", stringsAsFactors = FALSE)
status <- utils::read.csv("metadata/stage2/control/acquisition_status.csv", stringsAsFactors = FALSE)

dataset_id <- "DS15"
work_item_id <- paste0("REGISTER:", dataset_id)
if (!work_item_id %in% work_order$work_item_id) {
  stop(sprintf("%s is not in the Stage 2 work order.", dataset_id), call. = FALSE)
}
if (status$acquisition_state[status$work_item_id == work_item_id] == "complete") {
  stop(sprintf("%s is already marked complete.", dataset_id), call. = FALSE)
}

timestamp <- strftime(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
run_name <- paste0("DS15_EMODNET_", timestamp)
run_dir <- file.path("data", "raw", "stage2", "ds15_emodnet_presence", run_name)
if (!dir.exists(run_dir)) dir.create(run_dir, recursive = TRUE)

log_path <- file.path(run_dir, "acquisition.log")
cat(sprintf("Beginning acquisition of %s from EMODnet ERDDAP\n", dataset_id), file = log_path)

# 1. Download CSV data
url_csv <- "https://erddap.emodnet.eu/erddap/tabledap/biology_6587_phyto_north_sea_4bd1_a08c_0019.csv"
file_csv <- file.path(run_dir, "biology_6587_phyto_north_sea_4bd1_a08c_0019.csv")

cat("Downloading CSV data...\n", file = log_path, append = TRUE)
res_csv <- httr::GET(url_csv, httr::write_disk(file_csv, overwrite = TRUE), httr::timeout(600))

if (httr::status_code(res_csv) != 200) {
  stop(sprintf("Failed to fetch ERDDAP CSV, status: %d", httr::status_code(res_csv)), call. = FALSE)
}

# 2. Download nc data for completeness
url_nc <- "https://erddap.emodnet.eu/erddap/tabledap/biology_6587_phyto_north_sea_4bd1_a08c_0019.nc"
file_nc <- file.path(run_dir, "biology_6587_phyto_north_sea_4bd1_a08c_0019.nc")

cat("Downloading NetCDF data...\n", file = log_path, append = TRUE)
res_nc <- httr::GET(url_nc, httr::write_disk(file_nc, overwrite = TRUE), httr::timeout(600))

if (httr::status_code(res_nc) != 200) {
  warning(sprintf("Failed to fetch ERDDAP NetCDF, status: %d", httr::status_code(res_nc)))
}

manifest_rows <- list()
manifest_rows[[1]] <- data.frame(
  file_name = basename(file_csv),
  checksum_sha256 = calculate_checksum(file_csv),
  file_size_bytes = file.size(file_csv),
  stringsAsFactors = FALSE,
  check.names = FALSE
)

if (file.exists(file_nc)) {
  manifest_rows[[2]] <- data.frame(
    file_name = basename(file_nc),
    checksum_sha256 = calculate_checksum(file_nc),
    file_size_bytes = file.size(file_nc),
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
  run_relative_path = file.path("stage2", "ds15_emodnet_presence", run_name),
  manifest_checksum_sha256 = calculate_checksum(manifest_path),
  pinned_at_utc = timestamp,
  stringsAsFactors = FALSE,
  check.names = FALSE
)
write_csv_atomic(pin, "metadata/stage2/acquisition/ds15_emodnet_presence_active_run.csv")

message("DS15 EMODnet ERDDAP acquisition complete.")
