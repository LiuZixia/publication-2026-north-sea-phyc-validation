#' Search EMODnet ERDDAP for Phytoplankton Data
#'
#' This script performs a systematic API search on the EMODnet ERDDAP server.
#' It meets the Stage 0 governance requirements for reproducible API queries.

source("R/00_core_setup.R")
library(jsonlite)

# Verify storage is accessible
verify_raw_data_target()

# Set up metadata
search_date <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
search_id <- paste0("SEARCH-EMODNET-", search_date)
base_url <- "https://erddap.emodnet.eu/erddap/search/index.json"
query_term <- "phytoplankton"

# Output directory within data/raw
out_dir <- file.path("data/raw/search_runs", search_id)
if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

# Construct URL (using page 1, max items 1000 for this search)
query_url <- paste0(base_url, "?page=1&itemsPerPage=1000&searchFor=", utils::URLencode(query_term))
dest_file <- file.path(out_dir, "response.json")

# Execute atomic download with retry
message("Downloading search results from EMODnet ERDDAP...")
checksum <- download_with_retry(query_url, dest_file)

# Basic validation of the response
response_data <- jsonlite::fromJSON(dest_file)
if (!"table" %in% names(response_data)) {
  stop("Invalid response format: 'table' object not found in JSON.")
}
record_count <- nrow(response_data$table$rows)
message(sprintf("Search complete. Retrieved %d records.", record_count))

# Save acquisition manifest
manifest <- list(
  search_id = search_id,
  provider = "EMODnet ERDDAP",
  endpoint = base_url,
  query = query_term,
  execution_time_utc = search_date,
  records_returned = record_count,
  files = list(
    list(
      filename = basename(dest_file),
      checksum_sha256 = checksum
    )
  )
)
manifest_file <- file.path(out_dir, "manifest.json")
write_json(manifest, manifest_file, pretty = TRUE, auto_unbox = TRUE)

message(sprintf("Manifest saved to %s", manifest_file))
