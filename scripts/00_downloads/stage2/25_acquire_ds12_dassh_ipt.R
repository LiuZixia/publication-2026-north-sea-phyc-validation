# Acquire DS12: CPR Survey (Direct Download from DASSH IPT)
# Replaces previous custom request route

source("R/00_core_setup.R")
source("R/03_stage2_contract.R")
required_namespace("httr")

contract <- read_stage2_contract()
work_order <- utils::read.csv("metadata/stage2/control/acquisition_work_order.csv", stringsAsFactors = FALSE)
status <- utils::read.csv("metadata/stage2/control/acquisition_status.csv", stringsAsFactors = FALSE)

dataset_id <- "DS12"
work_item_id <- paste0("REGISTER:", dataset_id)
if (!work_item_id %in% work_order$work_item_id) {
  stop("DS12 is not in the Stage 2 work order.", call. = FALSE)
}
if (status$acquisition_state[status$work_item_id == work_item_id] == "complete") {
  stop("DS12 is already marked complete.", call. = FALSE)
}

timestamp <- strftime(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
run_name <- paste0("DS12_DASSH_IPT_", timestamp)
run_dir <- file.path("data", "raw", "stage2", "ds12_dassh_ipt", run_name)
if (!dir.exists(run_dir)) dir.create(run_dir, recursive = TRUE)

download_url <- "https://www.dassh.ac.uk/ipt/archive.do?r=cpr_public"
zip_path <- file.path(run_dir, "cpr_public_dwca.zip")

message("Downloading DS12 CPR Survey DwC-A directly from DASSH IPT...")
res <- httr::GET(download_url, httr::write_disk(zip_path, overwrite = TRUE), httr::timeout(3600))
if (httr::status_code(res) != 200) {
  stop(sprintf("Failed to download DS12 with status code: %d", httr::status_code(res)), call. = FALSE)
}

checksum <- calculate_checksum(zip_path)
manifest <- data.frame(
  file_name = "cpr_public_dwca.zip",
  checksum_sha256 = checksum,
  file_size_bytes = file.size(zip_path),
  stringsAsFactors = FALSE,
  check.names = FALSE
)

manifest_path <- file.path(run_dir, "manifest.csv")
write_csv_atomic(manifest, manifest_path)

pin <- data.frame(
  work_item_id = work_item_id,
  run_name = run_name,
  run_relative_path = file.path("stage2", "ds12_dassh_ipt", run_name),
  manifest_checksum_sha256 = calculate_checksum(manifest_path),
  pinned_at_utc = timestamp,
  stringsAsFactors = FALSE,
  check.names = FALSE
)
write_csv_atomic(pin, "metadata/stage2/acquisition/ds12_dassh_ipt_active_run.csv")

message("DS12 DASSH IPT direct acquisition complete.")
