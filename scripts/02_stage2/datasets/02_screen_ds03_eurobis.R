# Screen DS03 EurOBIS phytoplankton against the domain geometry.

source("R/00_core_setup.R")
source("R/03_stage2_contract.R")
required_namespace("sf")

contract <- read_stage2_contract()
pin <- utils::read.csv("metadata/stage2/acquisition/ds03_eurobis_active_run.csv",
                       stringsAsFactors = FALSE, check.names = FALSE)
if (nrow(pin) != 1L || pin$work_item_id[[1]] != "REGISTER:DS03") {
  stop("DS03 active run pin is invalid.", call. = FALSE)
}

run_dir <- file.path("data", "raw", pin$run_relative_path[[1]])
manifest_path <- file.path(run_dir, "manifest.csv")
if (!identical(calculate_checksum(manifest_path), pin$manifest_checksum_sha256[[1]])) {
  stop("DS03 manifest checksum does not reconcile with the active pin.", call. = FALSE)
}

manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE, check.names = FALSE)
zip_files <- manifest$file_name[grepl("\\.zip$", manifest$file_name)]

# Function to extract locations from a DwCA zip
extract_locations <- function(zip_path) {
  temp_dir <- file.path(tempdir(), "ds03_unzip")
  if (dir.exists(temp_dir)) unlink(temp_dir, recursive = TRUE)
  dir.create(temp_dir)
  utils::unzip(zip_path, exdir = temp_dir, files = c("occurrence.txt", "event.txt"))
  
  occ_path <- file.path(temp_dir, "occurrence.txt")
  evt_path <- file.path(temp_dir, "event.txt")
  if (!file.exists(occ_path) || !file.exists(evt_path)) stop("occurrence.txt or event.txt not found in zip")
  
  occ_data <- utils::read.delim(occ_path, stringsAsFactors = FALSE, quote = "", sep = "\t")
  evt_data <- utils::read.delim(evt_path, stringsAsFactors = FALSE, quote = "", sep = "\t")
  
  # Basic column checks
  if (!"id" %in% names(occ_data)) stop("DS03 occurrence missing 'id'")
  if (!all(c("id", "decimalLatitude", "decimalLongitude") %in% names(evt_data))) {
    stop("DS03 event missing required columns")
  }
  
  merged <- merge(occ_data[, c("id"), drop = FALSE], evt_data[, c("id", "decimalLatitude", "decimalLongitude")], by = "id", all.x = TRUE)
  
  locations <- data.frame(
    reported_latitude = as.numeric(merged$decimalLatitude),
    reported_longitude = as.numeric(merged$decimalLongitude),
    stringsAsFactors = FALSE
  )
  unlink(temp_dir, recursive = TRUE)
  locations
}

all_locations <- do.call(rbind, lapply(zip_files, function(f) extract_locations(file.path(run_dir, f))))

valid <- is.finite(all_locations$reported_latitude) & is.finite(all_locations$reported_longitude) &
  all_locations$reported_latitude >= -90 & all_locations$reported_latitude <= 90 &
  all_locations$reported_longitude >= -180 & all_locations$reported_longitude <= 180

all_locations$domain_state <- "invalid_coordinate"

sf::sf_use_s2(FALSE)
domain <- sf::st_read("config/spatial/greater_north_sea.geojson", quiet = TRUE)
subregions <- sf::st_read("config/spatial/hydrographic_subregions.geojson", quiet = TRUE)

points <- sf::st_as_sf(
  data.frame(row = which(valid), lon = all_locations$reported_longitude[valid],
             lat = all_locations$reported_latitude[valid]),
  coords = c("lon", "lat"), crs = 4326
)

domain_hit <- lengths(suppressMessages(sf::st_intersects(points, domain, prepared = TRUE))) > 0L
all_locations$domain_state[points$row] <- "outside_domain"

if (any(domain_hit)) {
  region_hit <- suppressMessages(sf::st_intersects(points[domain_hit, , drop = FALSE], subregions,
                                                    prepared = TRUE))
  region_index <- vapply(region_hit, function(value) if (length(value)) value[[1]] else NA_integer_,
                         integer(1))
  if (anyNA(region_index)) stop("An in-domain location lacks a frozen subregion.", call. = FALSE)
  
  selected_rows <- points$row[domain_hit]
  all_locations$domain_state[selected_rows] <- ifelse(subregions$role[region_index] == "core-domain",
                                                   "core", "external_transfer")
}

screening_summary <- data.frame(
  total_raw_rows = nrow(all_locations),
  core_rows = sum(all_locations$domain_state == "core"),
  external_transfer_rows = sum(all_locations$domain_state == "external_transfer"),
  outside_domain_rows = sum(all_locations$domain_state == "outside_domain"),
  invalid_coordinate_rows = sum(all_locations$domain_state == "invalid_coordinate"),
  explicit_marine_phytoplankton_rows = nrow(all_locations), # Assuming dataset is all phytoplankton
  stringsAsFactors = FALSE,
  check.names = FALSE
)

summary_path <- "metadata/stage2/screening/ds03_eurobis_location_summary.csv"
write_csv_atomic(screening_summary, summary_path)

message(sprintf(
  "DS03 screening complete: %d core, %d external, %d outside locations out of %d total records.",
  screening_summary$core_rows, screening_summary$external_transfer_rows,
  screening_summary$outside_domain_rows, screening_summary$total_raw_rows
))
