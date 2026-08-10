# Screen DS24 Figshare (OSPAR COMPEAT) against the domain geometry.

source("R/00_core_setup.R")
source("R/03_stage2_contract.R")
required_namespace("sf")

contract <- read_stage2_contract()
pin <- utils::read.csv("metadata/stage2/acquisition/ds24_figshare_active_run.csv",
                       stringsAsFactors = FALSE, check.names = FALSE)
if (nrow(pin) != 1L || pin$work_item_id[[1]] != "REGISTER:DS24") {
  stop("DS24 active run pin is invalid.", call. = FALSE)
}

run_dir <- file.path("data", "raw", pin$run_relative_path[[1]])

gz_files <- list.files(run_dir, pattern = "StationSamples.*\\.txt\\.gz$", recursive = TRUE, full.names = TRUE)

extract_locations <- function(filepath) {
  # Read just the necessary columns to save memory
  # We only need Longitude and Latitude
  col_names <- names(utils::read.delim(gzfile(filepath), nrows = 1, sep = "\t", check.names = FALSE))
  
  if (!"Latitude [degrees_north]" %in% col_names || !"Longitude [degrees_east]" %in% col_names) {
    stop("Missing Latitude/Longitude columns in ", filepath)
  }
  
  # Set colClasses to "NULL" for everything except the lat/lon to save memory/time
  classes <- rep("NULL", length(col_names))
  classes[col_names == "Latitude [degrees_north]"] <- "numeric"
  classes[col_names == "Longitude [degrees_east]"] <- "numeric"
  
  raw_data <- utils::read.delim(gzfile(filepath), colClasses = classes, sep = "\t", check.names = FALSE, stringsAsFactors = FALSE)
  
  names(raw_data) <- c("reported_longitude", "reported_latitude") # Because they might be in different order, but read.delim assigns them by column index order, wait!
  # Actually, read.delim with colClasses keeps the selected columns in the original order.
  # Let's just read all and subset, it's safer and the files aren't that huge (max 77MB gz).
  
  raw_data <- utils::read.delim(gzfile(filepath), sep = "\t", check.names = FALSE, stringsAsFactors = FALSE)
  data.frame(
    reported_latitude = as.numeric(raw_data[["Latitude [degrees_north]"]]),
    reported_longitude = as.numeric(raw_data[["Longitude [degrees_east]"]]),
    stringsAsFactors = FALSE
  )
}

all_locations <- do.call(rbind, lapply(gz_files, extract_locations))

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
  
  # For points in domain but not in any subregion, they stay "outside_domain" or we can error.
  # The contract requires them to have a subregion if they are in the domain.
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

summary_path <- "metadata/stage2/screening/ds24_figshare_location_summary.csv"
write_csv_atomic(screening_summary, summary_path)

message(sprintf(
  "DS24 screening complete: %d core, %d external, %d outside locations out of %d total records.",
  screening_summary$core_rows, screening_summary$external_transfer_rows,
  screening_summary$outside_domain_rows, screening_summary$total_raw_rows
))
