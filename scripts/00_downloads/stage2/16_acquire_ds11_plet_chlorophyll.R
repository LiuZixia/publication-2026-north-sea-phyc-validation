# Acquire canonical PLET export for DS11: PLET chlorophyll companions
# Target period: 2000-01-01 to 2019-12-31

source("R/00_core_setup.R")
source("R/03_stage2_contract.R")
required_namespace("httr")
required_namespace("sf")

contract <- read_stage2_contract()
work_order <- utils::read.csv("metadata/stage2/control/acquisition_work_order.csv", stringsAsFactors = FALSE)
status <- utils::read.csv("metadata/stage2/control/acquisition_status.csv", stringsAsFactors = FALSE)

dataset_id <- "DS11"
work_item_id <- paste0("REGISTER:", dataset_id)
if (!work_item_id %in% work_order$work_item_id) {
  stop("DS11 is not in the Stage 2 work order.", call. = FALSE)
}
if (status$acquisition_state[status$work_item_id == work_item_id] == "complete") {
  stop("DS11 is already marked complete.", call. = FALSE)
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
start_date <- "2000-01-01"
end_date <- "2019-12-31"

timestamp <- strftime(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
run_name <- paste0("DS11_PLET_CHLOROPHYLL_", timestamp)
run_dir <- file.path("data", "raw", "stage2", "ds11_plet_chlorophyll", run_name)
if (!dir.exists(run_dir)) dir.create(run_dir, recursive = TRUE)
log_path <- file.path(run_dir, "acquisition.log")

cat(sprintf("Beginning acquisition of DS11 from PLET\n"), file = log_path)

datasets <- c(
  "LW_VLIZ_chla",
  "MSS Stonehaven Chlorophyll data",
  "NOVANA chlorophyl data",
  "Chlorofyl_data_noordzee_NL",
  "National data_SMHI_Kattegat-Dnr: S/Gbg-2021_116/Chl",
  "National data_SMHI_skagerrak-Dnr: S/Gbg-2021_116/Chl",
  "BSH_Phyto_Zoo"
)

manifest_rows <- list()

for (i in seq_along(datasets)) {
  ds_name <- datasets[i]
  cat(sprintf("\nProcessing dataset: %s\n", ds_name), file = log_path, append = TRUE)
  
  # Chlorophyll is under biomass_dataset
  url <- sprintf(
    "%s?startdate=%s&enddate=%s&north=%s&south=%s&east=%s&west=%s&biomass_dataset=%s&format=csv&raw=true",
    plet_base_url, start_date, end_date, north, south, east, west, URLencode(ds_name, reserved = TRUE)
  )
  
  html_path <- file.path(run_dir, sprintf("response_%02d.html", i))
  safe_name <- gsub("[^A-Za-z0-9]", "_", tolower(ds_name))
  csv_filename <- sprintf("%s.csv", safe_name)
  csv_path <- file.path(run_dir, csv_filename)
  
  res <- httr::GET(url, httr::write_disk(html_path, overwrite = TRUE), httr::timeout(3600))
  if (httr::status_code(res) != 200) {
    stop(sprintf("PLET HTML acquisition failed for %s with status code: %d", ds_name, httr::status_code(res)), call. = FALSE)
  }
  
  html_text <- paste(readLines(html_path, warn = FALSE), collapse = "\n")
  match <- regmatches(html_text, regexpr("\\.\\./output/raw/[^\"']+\\.csv", html_text))
  if (length(match) == 0) {
    cat(sprintf("No CSV link found for %s, skipping.\n", ds_name), file = log_path, append = TRUE)
    next
  }
  
  raw_url <- paste0("https://www.dassh.ac.uk/plet/", sub("^\\.\\./", "", match[[1]]))
  cat(sprintf("Parsed raw URL: %s\n", raw_url), file = log_path, append = TRUE)
  
  res_csv <- httr::GET(raw_url, httr::write_disk(csv_path, overwrite = TRUE), httr::timeout(3600))
  if (httr::status_code(res_csv) != 200) {
    stop(sprintf("PLET raw CSV download failed for %s with status code: %d", ds_name, httr::status_code(res_csv)), call. = FALSE)
  }
  
  checksum <- calculate_checksum(csv_path)
  manifest_rows[[length(manifest_rows) + 1]] <- data.frame(
    file_name = csv_filename,
    checksum_sha256 = checksum,
    file_size_bytes = file.size(csv_path),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

if (length(manifest_rows) == 0) {
  stop("No datasets were successfully downloaded.", call. = FALSE)
}

manifest <- do.call(rbind, manifest_rows)
manifest_path <- file.path(run_dir, "manifest.csv")
write_csv_atomic(manifest, manifest_path)

pin <- data.frame(
  work_item_id = work_item_id,
  run_name = run_name,
  run_relative_path = file.path("stage2", "ds11_plet_chlorophyll", run_name),
  manifest_checksum_sha256 = calculate_checksum(manifest_path),
  pinned_at_utc = timestamp,
  stringsAsFactors = FALSE,
  check.names = FALSE
)
write_csv_atomic(pin, "metadata/stage2/acquisition/ds11_plet_chlorophyll_active_run.csv")

message("DS11 PLET acquisition complete.")
