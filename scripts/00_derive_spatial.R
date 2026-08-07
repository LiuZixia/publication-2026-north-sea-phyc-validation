#!/usr/bin/env Rscript
# Derive frozen Stage 0 domain files from one explicitly registered immutable raw run.

suppressPackageStartupMessages(library(sf))
source("R/00_core_setup.R")
source("R/00_spatial_provenance.R")

verify_raw_data_target(required_gb = 0)
run_id <- read_frozen_spatial_run()
run_dir <- file.path("data", "raw", "search_runs", run_id)
manifest <- validate_spatial_run(run_dir, verify_checksums = TRUE)
source_config <- read.csv("config/spatial_sources.csv", stringsAsFactors = FALSE)

read_feature_pages <- function(source_id) {
  rows <- manifest$artifact_role == "features_page" & manifest$source_id == source_id
  pages <- manifest[rows, , drop = FALSE]
  pages <- pages[order(pages$page_number), , drop = FALSE]
  # Suppress GDAL's performance-only multipart warning; schema and geometry are validated below.
  values <- lapply(file.path(run_dir, pages$filename), function(path) suppressWarnings(sf::st_read(path, quiet = TRUE)))
  output <- do.call(rbind, values)
  if (nrow(output) != unique(pages$expected_feature_count)) {
    stop(sprintf("Derived input count changed for %s.", source_id), call. = FALSE)
  }
  output
}

ecoregions <- read_feature_pages("ices_ecoregions")
areas <- read_feature_pages("ices_areas")
if (!identical(sf::st_crs(ecoregions)$epsg, 3857L) || !identical(sf::st_crs(areas)$epsg, 3857L)) {
  stop("ICES raw spatial layers must resolve to EPSG:3857 before transformation.", call. = FALSE)
}

ecoregions <- sf::st_make_valid(ecoregions)
areas <- sf::st_make_valid(areas)

select_frozen_features <- function(value, source_id) {
  specification <- source_config[source_config$source_id == source_id, , drop = FALSE]
  if (nrow(specification) != 1L) stop(sprintf("Expected one source specification for %s.", source_id), call. = FALSE)
  field <- specification$selection_field[[1]]
  selector <- specification$selection_value[[1]]
  if (!field %in% names(value)) stop(sprintf("Selection field '%s' is absent from %s.", field, source_id), call. = FALSE)
  matches <- if (startsWith(selector, "^")) grepl(selector, value[[field]]) else value[[field]] == selector
  value[!is.na(matches) & matches, , drop = FALSE]
}

greater_north_sea <- select_frozen_features(ecoregions, "ices_ecoregions")
if (nrow(greater_north_sea) != 1L) stop("Expected exactly one Greater North Sea ecoregion.", call. = FALSE)
greater_north_sea <- sf::st_union(greater_north_sea)

skagerrak_kattegat_parts <- select_frozen_features(areas, "ices_areas")
if (!nrow(skagerrak_kattegat_parts)) stop("No ICES Area 27.3.a features were found.", call. = FALSE)
skagerrak_kattegat <- sf::st_make_valid(sf::st_intersection(sf::st_union(skagerrak_kattegat_parts), greater_north_sea))
core_domain <- sf::st_make_valid(sf::st_difference(greater_north_sea, skagerrak_kattegat))

greater_north_sea <- sf::st_transform(greater_north_sea, 4326)
core_domain <- sf::st_transform(core_domain, 4326)
skagerrak_kattegat <- sf::st_transform(skagerrak_kattegat, 4326)
domain_sf <- sf::st_sf(domain_name = "Greater North Sea", geometry = greater_north_sea)
subregions_sf <- sf::st_sf(
  subregion_id = c("southern_and_central_north_sea", "skagerrak_kattegat"),
  role = c("core-domain", "external-transfer"),
  geometry = sf::st_sfc(core_domain[[1]], skagerrak_kattegat[[1]], crs = 4326)
)

if (!all(sf::st_is_valid(domain_sf)) || !all(sf::st_is_valid(subregions_sf))) stop("Derived spatial geometries are invalid.", call. = FALSE)
if (anyDuplicated(subregions_sf$subregion_id)) stop("Derived subregion IDs are not unique.", call. = FALSE)
overlap_area <- as.numeric(sum(sf::st_area(sf::st_intersection(sf::st_geometry(subregions_sf[1, ]), sf::st_geometry(subregions_sf[2, ])))))
partition_relative_error <- abs(as.numeric(sum(sf::st_area(domain_sf))) - as.numeric(sum(sf::st_area(subregions_sf)))) / as.numeric(sum(sf::st_area(domain_sf)))
if (overlap_area > 1 || partition_relative_error > 1e-7) stop("Derived regions do not form the frozen non-overlapping domain partition.", call. = FALSE)

write_geojson_atomic <- function(value, destination) {
  partial <- paste0(destination, ".partial.geojson")
  if (file.exists(partial)) unlink(partial)
  sf::st_write(value, partial, driver = "GeoJSON", quiet = TRUE)
  check <- sf::st_read(partial, quiet = TRUE)
  if (!all(sf::st_is_valid(check)) || !identical(sf::st_crs(check)$epsg, 4326L)) stop("Atomic spatial output validation failed.", call. = FALSE)
  if (!isTRUE(file.rename(partial, destination))) stop(sprintf("Unable to replace derived output: %s", destination), call. = FALSE)
}

dir.create("config/spatial", recursive = TRUE, showWarnings = FALSE)
write_geojson_atomic(domain_sf, "config/spatial/greater_north_sea.geojson")
write_geojson_atomic(subregions_sf, "config/spatial/hydrographic_subregions.geojson")

dir.create("metadata", recursive = TRUE, showWarnings = FALSE)
raw_manifest_checksum <- calculate_checksum(file.path(run_dir, "manifest.csv"))
feature_checksums <- manifest$checksum_sha256[manifest$artifact_role == "features_page"]
provenance <- data.frame(
  output_file = c("config/spatial/greater_north_sea.geojson", "config/spatial/hydrographic_subregions.geojson"),
  output_checksum_sha256 = vapply(c("config/spatial/greater_north_sea.geojson", "config/spatial/hydrographic_subregions.geojson"), calculate_checksum, character(1)),
  source_run_id = run_id,
  source_manifest_checksum_sha256 = raw_manifest_checksum,
  source_feature_checksums_sha256 = paste(feature_checksums, collapse = "|"),
  derivation_script_checksum_sha256 = calculate_checksum("scripts/00_derive_spatial.R"),
  spatial_source_config_checksum_sha256 = calculate_checksum("config/spatial_sources.csv"),
  protocol_config_checksum_sha256 = calculate_checksum("config/protocol_config.json"),
  source_access_time_utc = max(manifest$access_time_utc),
  row_count = c(nrow(domain_sf), nrow(subregions_sf)),
  crs_epsg = 4326L,
  stringsAsFactors = FALSE
)
provenance_file <- "metadata/stage0_spatial_provenance.csv"
provenance_partial <- paste0(provenance_file, ".partial")
write.csv(provenance, provenance_partial, row.names = FALSE)
if (!isTRUE(file.rename(provenance_partial, provenance_file))) stop("Unable to finalize derived spatial provenance.", call. = FALSE)

message(sprintf("Derived Stage 0 spatial files from frozen run %s.", run_id))
