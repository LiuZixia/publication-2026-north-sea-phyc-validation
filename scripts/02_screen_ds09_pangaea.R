# Screen DS09 PANGAEA Sylt phytoplankton against the domain geometry.

source("R/00_core_setup.R")
source("R/03_stage2_contract.R")
required_namespace("sf")

contract <- read_stage2_contract()
pin <- utils::read.csv("metadata/stage2_ds09_pangaea_active_run.csv",
                       stringsAsFactors = FALSE, check.names = FALSE)
if (nrow(pin) != 1L || pin$work_item_id[[1]] != "REGISTER:DS09") {
  stop("DS09 active run pin is invalid.", call. = FALSE)
}

run_dir <- file.path("data", "raw", pin$run_relative_path[[1]])

# Read all PANGAEA txt files in the run directory
txt_files <- list.files(run_dir, pattern = "\\.txt$", recursive = TRUE, full.names = TRUE)

extract_locations <- function(txt_path) {
  # Find where data starts (after */)
  lines <- readLines(txt_path, warn = FALSE)
  data_start <- grep("^\\*/", lines)[1]
  if (is.na(data_start)) stop(sprintf("Could not find data start in %s", txt_path))
  
  # Read data skipping metadata
  raw_data <- utils::read.delim(txt_path, skip = data_start, stringsAsFactors = FALSE, quote = "", sep = "\t", check.names = FALSE)
  
  # Basic column checks
  if (!all(c("Latitude", "Longitude") %in% names(raw_data))) {
    # Fallback to LATITUDE from metadata
    meta_lines <- lines[1:data_start]
    cov_line <- grep("^Coverage:", meta_lines, value = TRUE)
    if (length(cov_line) == 0) stop(sprintf("DS09 file missing Latitude/Longitude and Coverage metadata: %s", txt_path), call. = FALSE)
    
    lat_match <- regexpr("(?:MEDIAN )?LATITUDE: [0-9.]+", cov_line)
    lon_match <- regexpr("(?:MEDIAN )?LONGITUDE: [0-9.]+", cov_line)
    
    if (lat_match == -1 || lon_match == -1) stop("DS09 file missing coords in Coverage: ", txt_path)
    
    lat_str <- regmatches(cov_line, lat_match)
    lon_str <- regmatches(cov_line, lon_match)
    
    lat <- as.numeric(sub(".*LATITUDE: ", "", lat_str))
    lon <- as.numeric(sub(".*LONGITUDE: ", "", lon_str))
    
    locations <- data.frame(
      reported_latitude = rep(lat, nrow(raw_data)),
      reported_longitude = rep(lon, nrow(raw_data)),
      stringsAsFactors = FALSE
    )
  } else {
    locations <- data.frame(
      reported_latitude = as.numeric(raw_data$Latitude),
      reported_longitude = as.numeric(raw_data$Longitude),
      stringsAsFactors = FALSE
    )
  }
  
  locations
}

all_locations <- do.call(rbind, lapply(txt_files, extract_locations))

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
  explicit_marine_phytoplankton_rows = nrow(all_locations),
  stringsAsFactors = FALSE,
  check.names = FALSE
)

summary_path <- "metadata/stage2_ds09_pangaea_location_summary.csv"
write_csv_atomic(screening_summary, summary_path)

message(sprintf(
  "DS09 screening complete: %d core, %d external, %d outside locations out of %d total records.",
  screening_summary$core_rows, screening_summary$external_transfer_rows,
  screening_summary$outside_domain_rows, screening_summary$total_raw_rows
))
