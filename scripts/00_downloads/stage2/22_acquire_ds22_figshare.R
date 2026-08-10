# Acquire canonical ICES Figshare data for DS22: HELCOM PEG_BVOL
# Article ID: 27900237

source("R/00_core_setup.R")
source("R/03_stage2_contract.R")
required_namespace("httr")
required_namespace("jsonlite")

contract <- read_stage2_contract()
work_order <- utils::read.csv("metadata/stage2/control/acquisition_work_order.csv", stringsAsFactors = FALSE)
status <- utils::read.csv("metadata/stage2/control/acquisition_status.csv", stringsAsFactors = FALSE)

dataset_id <- "DS22"
work_item_id <- paste0("REGISTER:", dataset_id)
if (!work_item_id %in% work_order$work_item_id) {
  stop(sprintf("%s is not in the Stage 2 work order.", dataset_id), call. = FALSE)
}
if (status$acquisition_state[status$work_item_id == work_item_id] == "complete") {
  stop(sprintf("%s is already marked complete.", dataset_id), call. = FALSE)
}

timestamp <- strftime(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
run_name <- paste0("DS22_FIGSHARE_", timestamp)
run_dir <- file.path("data", "raw", "stage2", "ds22_figshare", run_name)
if (!dir.exists(run_dir)) dir.create(run_dir, recursive = TRUE)

log_path <- file.path(run_dir, "acquisition.log")
cat(sprintf("Beginning acquisition of %s from ICES Figshare\n", dataset_id), file = log_path)

article_id <- "27900237"
url <- sprintf("https://api.figshare.com/v2/articles/%s", article_id)

res <- httr::GET(url, httr::timeout(60))
if (httr::status_code(res) != 200) {
  stop(sprintf("Failed to get article metadata. HTTP status: %d", httr::status_code(res)), call. = FALSE)
}

article <- jsonlite::fromJSON(httr::content(res, "text", encoding = "UTF-8"))
metadata_path <- file.path(run_dir, "article_metadata.json")
write(jsonlite::toJSON(article, auto_unbox = TRUE, pretty = TRUE), metadata_path)

files <- article$files
if (is.null(files) || nrow(files) == 0) {
  stop("No files found attached to this Figshare article.", call. = FALSE)
}

manifest_rows <- list()

for (i in seq_len(nrow(files))) {
  file_url <- files$download_url[i]
  file_name <- files$name[i]
  file_size <- files$size[i]
  file_path <- file.path(run_dir, file_name)
  
  cat(sprintf("Downloading %s (%d bytes)...\n", file_name, file_size), file = log_path, append = TRUE)
  
  dl_res <- httr::GET(file_url, httr::write_disk(file_path, overwrite = TRUE), httr::timeout(300))
  if (httr::status_code(dl_res) == 200) {
    manifest_rows[[i]] <- data.frame(
      file_name = file_name,
      checksum_sha256 = calculate_checksum(file_path),
      file_size_bytes = file.size(file_path),
      figshare_id = files$id[i],
      figshare_computed_md5 = files$computed_md5[i],
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  } else {
    stop(sprintf("Failed to download %s", file_name), call. = FALSE)
  }
}

manifest <- do.call(rbind, manifest_rows)
manifest_path <- file.path(run_dir, "manifest.csv")
write_csv_atomic(manifest, manifest_path)

pin <- data.frame(
  work_item_id = work_item_id,
  run_name = run_name,
  run_relative_path = file.path("stage2", "ds22_figshare", run_name),
  manifest_checksum_sha256 = calculate_checksum(manifest_path),
  pinned_at_utc = timestamp,
  stringsAsFactors = FALSE,
  check.names = FALSE
)
write_csv_atomic(pin, "metadata/stage2/acquisition/ds22_figshare_active_run.csv")

message("DS22 ICES Figshare acquisition complete.")
