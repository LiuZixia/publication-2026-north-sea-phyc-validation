# Screen DS04 BSH phytoplankton against the domain geometry.

source("R/00_core_setup.R")
source("R/03_stage2_contract.R")
required_namespace("sf")

contract <- read_stage2_contract()
pin <- utils::read.csv("metadata/stage2/acquisition/ds04_plet_bsh_active_run.csv",
                       stringsAsFactors = FALSE, check.names = FALSE)
if (nrow(pin) != 1L || pin$work_item_id[[1]] != "REGISTER:DS04") {
  stop("DS04 active run pin is invalid.", call. = FALSE)
}

run_dir <- file.path("data", "raw", pin$run_relative_path[[1]])
manifest_path <- file.path(run_dir, "manifest.csv")
if (!identical(calculate_checksum(manifest_path), pin$manifest_checksum_sha256[[1]])) {
  stop("DS04 manifest checksum does not reconcile with the active pin.", call. = FALSE)
}

manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE, check.names = FALSE)
if (!all(c("file_name", "checksum_sha256", "file_size_bytes", "artifact_role") %in% names(manifest)) ||
    nrow(manifest) != 3L || sum(manifest$artifact_role == "observation_payload") != 1L) {
  stop("DS04 manifest does not identify one canonical observation payload.", call. = FALSE)
}

payload <- which(manifest$artifact_role == "observation_payload")
csv_path <- file.path(run_dir, manifest$file_name[[payload]])
if (!identical(calculate_checksum(csv_path), manifest$checksum_sha256[[payload]]) ||
    file.size(csv_path) != manifest$file_size_bytes[[payload]]) {
  stop("DS04 raw CSV checksum does not match manifest.", call. = FALSE)
}

# Read the raw PLET CSV
raw_data <- utils::read.csv(csv_path, stringsAsFactors = FALSE, check.names = FALSE)

# Basic column checks
required_cols <- c("dataset_name", "latitude", "longitude", "date", "aphia_id", "taxon",
                   "abundance", "lifeforms", "plankton_type")
missing_cols <- setdiff(required_cols, names(raw_data))
if (length(missing_cols) > 0) {
  stop(sprintf("DS04 missing required columns: %s", paste(missing_cols, collapse = ", ")), call. = FALSE)
}

locations <- data.frame(
  row_id = seq_len(nrow(raw_data)),
  reported_latitude = as.numeric(raw_data$latitude),
  reported_longitude = as.numeric(raw_data$longitude),
  stringsAsFactors = FALSE,
  check.names = FALSE
)

valid <- is.finite(locations$reported_latitude) & is.finite(locations$reported_longitude) &
  locations$reported_latitude >= -90 & locations$reported_latitude <= 90 &
  locations$reported_longitude >= -180 & locations$reported_longitude <= 180

locations$domain_state <- "invalid_coordinate"
locations$subregion_id <- NA_character_

sf::sf_use_s2(FALSE)
domain <- sf::st_read("config/spatial/greater_north_sea.geojson", quiet = TRUE)
subregions <- sf::st_read("config/spatial/hydrographic_subregions.geojson", quiet = TRUE)

points <- sf::st_as_sf(
  data.frame(row = which(valid), lon = locations$reported_longitude[valid],
             lat = locations$reported_latitude[valid]),
  coords = c("lon", "lat"), crs = 4326
)

domain_hit <- lengths(suppressMessages(sf::st_intersects(points, domain, prepared = TRUE))) > 0L
locations$domain_state[points$row] <- "outside_domain"

if (any(domain_hit)) {
  region_hit <- suppressMessages(sf::st_intersects(points[domain_hit, , drop = FALSE], subregions,
                                                    prepared = TRUE))
  region_index <- vapply(region_hit, function(value) if (length(value)) value[[1]] else NA_integer_,
                         integer(1))
  if (anyNA(region_index)) stop("An in-domain location lacks a frozen subregion.", call. = FALSE)
  
  selected_rows <- points$row[domain_hit]
  locations$domain_state[selected_rows] <- ifelse(subregions$role[region_index] == "core-domain",
                                                   "core", "external_transfer")
  locations$subregion_id[selected_rows] <- subregions$subregion_id[region_index]
}

explicit_marine_phytoplankton_signal <-
  grepl("phytoplankton|dinoflagellate|diatom", raw_data$lifeforms, ignore.case = TRUE) |
  grepl("phytoplankton", raw_data$plankton_type, ignore.case = TRUE)

screening_summary <- data.frame(
  total_raw_rows = nrow(raw_data),
  core_rows = sum(locations$domain_state == "core"),
  external_transfer_rows = sum(locations$domain_state == "external_transfer"),
  outside_domain_rows = sum(locations$domain_state == "outside_domain"),
  invalid_coordinate_rows = sum(locations$domain_state == "invalid_coordinate"),
  explicit_marine_phytoplankton_rows = sum(explicit_marine_phytoplankton_signal),
  stringsAsFactors = FALSE,
  check.names = FALSE
)

summary_path <- "metadata/stage2/screening/ds04_plet_bsh_location_summary.csv"
write_csv_atomic(screening_summary, summary_path)

message(sprintf(
  "DS04 screening complete: %d core, %d external, %d outside locations out of %d total records.",
  screening_summary$core_rows, screening_summary$external_transfer_rows,
  screening_summary$outside_domain_rows, screening_summary$total_raw_rows
))
