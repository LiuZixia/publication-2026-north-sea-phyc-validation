# Acquire canonical PLET export for DS16: MSS Stonehaven Phytoplankton
# PLET dataset ID: "MSS Stonehaven Phytoplankton"
# Target period: 2000-01-01 to 2019-12-31

source("R/00_core_setup.R")
source("R/03_stage2_contract.R")
required_namespace("httr")
required_namespace("sf")

contract <- read_stage2_contract()
work_order <- utils::read.csv("metadata/stage2/control/acquisition_work_order.csv", stringsAsFactors = FALSE)
status <- utils::read.csv("metadata/stage2/control/acquisition_status.csv", stringsAsFactors = FALSE)

dataset_id <- "DS16"
work_item_id <- paste0("REGISTER:", dataset_id)
if (!work_item_id %in% work_order$work_item_id) {
  stop("DS16 is not in the Stage 2 work order.", call. = FALSE)
}
if (status$acquisition_state[status$work_item_id == work_item_id] == "complete") {
  stop("DS16 is already marked complete.", call. = FALSE)
}

# The bounding box of the frozen Greater North Sea domain
sf::sf_use_s2(FALSE)
domain <- sf::st_read("config/spatial/greater_north_sea.geojson", quiet = TRUE)
bbox <- sf::st_bbox(domain)
north <- as.character(ceiling(bbox[["ymax"]]))
south <- as.character(floor(bbox[["ymin"]]))
east <- as.character(ceiling(bbox[["xmax"]]))
west <- as.character(floor(bbox[["xmin"]]))

plet_base_url <- "https://www.dassh.ac.uk/plet/cgi-bin/get_form.py"
dataset_name <- "MSS Stonehaven Phytoplankton"
start_date <- "2000-01-01"
end_date <- "2019-12-31"

url <- sprintf(
  "%s?startdate=%s&enddate=%s&north=%s&south=%s&east=%s&west=%s&abundance_dataset=%s&format=csv&raw=true",
  plet_base_url, start_date, end_date, north, south, east, west, URLencode(dataset_name, reserved = TRUE)
)

timestamp <- strftime(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
run_name <- paste0("DS16_PLET_STONEHAVEN_", timestamp)
run_dir <- file.path("data", "raw", "stage2", "ds16_plet_stonehaven", run_name)
if (!dir.exists(run_dir)) dir.create(run_dir, recursive = TRUE)

html_path <- file.path(run_dir, "response.html")
csv_path <- file.path(run_dir, "mss_stonehaven_phyto.csv")
log_path <- file.path(run_dir, "acquisition.log")

cat(sprintf("Beginning acquisition of DS16 from PLET: %s\n", url), file = log_path)

# Download the HTML response containing the links
res <- httr::GET(url, httr::write_disk(html_path, overwrite = TRUE), httr::timeout(3600))

if (httr::status_code(res) != 200) {
  stop(sprintf("PLET acquisition failed with status code: %d", httr::status_code(res)), call. = FALSE)
}

html_text <- paste(readLines(html_path, warn = FALSE), collapse = "\n")
match <- regmatches(html_text, regexpr("\\.\\./output/raw/[^\"']+\\.csv", html_text))
if (length(match) == 0) {
  stop("Could not find the raw data link in the PLET response.", call. = FALSE)
}

raw_url <- paste0("https://www.dassh.ac.uk/plet/", sub("^\\.\\./", "", match[[1]]))
cat(sprintf("Parsed raw URL: %s\n", raw_url), file = log_path, append = TRUE)

res_csv <- httr::GET(raw_url, httr::write_disk(csv_path, overwrite = TRUE), httr::timeout(3600))
if (httr::status_code(res_csv) != 200) {
  stop(sprintf("PLET raw CSV download failed with status code: %d", httr::status_code(res_csv)), call. = FALSE)
}

cat("Acquisition complete.\n", file = log_path, append = TRUE)
cat(sprintf("Saved to: %s\n", csv_path), file = log_path, append = TRUE)

checksum <- calculate_checksum(csv_path)

manifest <- data.frame(
  file_name = "mss_stonehaven_phyto.csv",
  checksum_sha256 = checksum,
  file_size_bytes = file.size(csv_path),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
manifest_path <- file.path(run_dir, "manifest.csv")
write_csv_atomic(manifest, manifest_path)

pin <- data.frame(
  work_item_id = work_item_id,
  run_name = run_name,
  run_relative_path = file.path("stage2", "ds16_plet_stonehaven", run_name),
  manifest_checksum_sha256 = calculate_checksum(manifest_path),
  pinned_at_utc = timestamp,
  stringsAsFactors = FALSE,
  check.names = FALSE
)
write_csv_atomic(pin, "metadata/stage2/acquisition/ds16_plet_stonehaven_active_run.csv")

message("DS16 PLET acquisition complete.")
