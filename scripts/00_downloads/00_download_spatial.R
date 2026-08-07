#!/usr/bin/env Rscript
#' Download Spatial Boundaries
#'
#' Downloads the authoritative ICES Ecoregions and ICES Areas layers,
#' generates checksums and manifests in the raw data store,
#' repairs geometries, and extracts the core Greater North Sea domain 
#' and the external Skagerrak/Kattegat (Area 27.3.a) subregion.

library(httr2)
library(jsonlite)
library(sf)

source("R/00_core_setup.R")

# 1. Verify Raw Target
verify_raw_data_target()

# 2. Define endpoints
ecoregions_url <- "https://gis.ices.dk/gis/rest/services/ICES_reference_layers/ICES_Ecoregions/MapServer/0/query?where=1%3D1&outFields=*&f=json"
areas_url <- "https://gis.ices.dk/gis/rest/services/ICES_reference_layers/ICES_Areas/MapServer/0/query?where=1%3D1&outFields=*&f=json"

# Run identifiers and paths
run_time <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
search_dir <- file.path("data", "raw", "search_runs", paste0("SPATIAL-ICES-", run_time))
if (!dir.exists(search_dir)) dir.create(search_dir, recursive = TRUE)

ecoregions_dest <- file.path(search_dir, "ices_ecoregions_raw.geojson")
areas_dest <- file.path(search_dir, "ices_areas_raw.geojson")

# 3. Download and checksum
message("Downloading ICES Ecoregions...")
eco_checksum <- download_with_retry(ecoregions_url, ecoregions_dest)

message("Downloading ICES Areas...")
area_checksum <- download_with_retry(areas_url, areas_dest)

# 4. Generate manifest
manifest <- data.frame(
  provider = c("ICES", "ICES"),
  dataset = c("ICES Ecoregions", "ICES Areas"),
  version = c("MapServer_0", "MapServer_0"),
  access_date = c(run_time, run_time),
  url = c(ecoregions_url, areas_url),
  filename = c(basename(ecoregions_dest), basename(areas_dest)),
  checksum_sha256 = c(eco_checksum, area_checksum)
)
write.csv(manifest, file.path(search_dir, "manifest.csv"), row.names = FALSE)

# Write human-readable log
log_lines <- c(
  sprintf("Spatial Download Run: %s", run_time),
  "Provider: ICES GIS REST API",
  "Datasets: ICES Ecoregions and ICES Statistical Areas",
  sprintf("Ecoregions Checksum: %s", eco_checksum),
  sprintf("Areas Checksum: %s", area_checksum)
)
writeLines(log_lines, file.path(search_dir, "acquisition.log"))

# 5. Process geometries
message("Processing Geometries...")

eco_raw <- sf::st_read(ecoregions_dest, quiet = TRUE)
area_raw <- sf::st_read(areas_dest, quiet = TRUE)

# Make valid to fix degenerate vertices
eco_valid <- sf::st_make_valid(eco_raw)
area_valid <- sf::st_make_valid(area_raw)

# Extract Greater North Sea
gns <- eco_valid[eco_valid$Ecoregion == "Greater North Sea", ]
if (nrow(gns) == 0) stop("Greater North Sea ecoregion not found.")

# Extract Area 27.3.a (Skagerrak and Kattegat) including its subdivisions (27.3.a.20, 27.3.a.21)
sk_area <- area_valid[grepl("^27\\.3\\.a", area_valid$Area_Full), ]
if (nrow(sk_area) == 0) stop("Area 27.3.a not found.")

# 6. Intersect 27.3.a with Greater North Sea to ensure we only get the marine part within the domain
skagerrak_kattegat <- sf::st_intersection(sk_area, gns)
skagerrak_kattegat <- sf::st_make_valid(skagerrak_kattegat)

# 7. Core domain is Greater North Sea minus Skagerrak/Kattegat
core_domain <- sf::st_difference(gns, sf::st_union(skagerrak_kattegat))
core_domain <- sf::st_make_valid(core_domain)

# Validate s2 topologies
if (!all(sf::st_is_valid(core_domain)) || !all(sf::st_is_valid(skagerrak_kattegat))) {
  stop("Generated geometries are topologically invalid after processing.")
}

# 8. Format for output
gns_out <- gns[, "Ecoregion"]
names(gns_out)[names(gns_out) == "Ecoregion"] <- "domain_name"

subregions <- rbind(
  data.frame(
    subregion_id = "southern_and_central_north_sea",
    role = "core-domain",
    geometry = sf::st_geometry(core_domain)
  ),
  data.frame(
    subregion_id = "skagerrak_kattegat",
    role = "external-transfer",
    geometry = sf::st_geometry(skagerrak_kattegat)
  )
)
subregions_sf <- sf::st_as_sf(subregions, crs = 4326)

# Write spatial files
sf::st_write(gns_out, "config/spatial/greater_north_sea.geojson", delete_dsn = TRUE, quiet = TRUE)
sf::st_write(subregions_sf, "config/spatial/hydrographic_subregions.geojson", delete_dsn = TRUE, quiet = TRUE)

message("Successfully generated authoritative spatial definitions.")
