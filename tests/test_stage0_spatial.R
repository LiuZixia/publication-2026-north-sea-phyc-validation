suppressPackageStartupMessages({
  library(testthat)
  library(sf)
  library(jsonlite)
  library(rprojroot)
})

project_root <- rprojroot::find_root(rprojroot::has_file("renv.lock"))
source(file.path(project_root, "R", "00_core_setup.R"))
source(file.path(project_root, "R", "00_spatial_provenance.R"))
source(file.path(project_root, "R", "00_spatial_assignment.R"))

square_polygon <- function(xmin, ymin, xmax, ymax) {
  sf::st_polygon(list(matrix(
    c(xmin, ymin, xmax, ymin, xmax, ymax, xmin, ymax, xmin, ymin),
    ncol = 2,
    byrow = TRUE
  )))
}

write_test_regions <- function(ids, geometries) {
  path <- tempfile(fileext = ".geojson")
  value <- sf::st_sf(subregion_id = ids, geometry = sf::st_sfc(geometries, crs = 4326))
  sf::st_write(value, path, quiet = TRUE)
  path
}

test_that("frozen domain and subregions are valid and form one partition", {
  domain <- sf::st_read(file.path(project_root, "config", "spatial", "greater_north_sea.geojson"), quiet = TRUE)
  regions <- sf::st_read(file.path(project_root, "config", "spatial", "hydrographic_subregions.geojson"), quiet = TRUE)
  expect_equal(nrow(domain), 1L)
  expect_equal(nrow(regions), 2L)
  expect_identical(sf::st_crs(domain)$epsg, 4326L)
  expect_identical(sf::st_crs(regions)$epsg, 4326L)
  expect_true(all(sf::st_is_valid(domain)))
  expect_true(all(sf::st_is_valid(regions)))
  expect_equal(anyDuplicated(regions$subregion_id), 0L)
  expect_setequal(regions$subregion_id, c("southern_and_central_north_sea", "skagerrak_kattegat"))
  expect_setequal(regions$role, c("core-domain", "external-transfer"))
  bounds <- sf::st_bbox(regions)
  expect_true(bounds[["xmin"]] > -20 && bounds[["xmax"]] < 30)
  expect_true(bounds[["ymin"]] > 45 && bounds[["ymax"]] < 70)
  overlap_area <- as.numeric(sum(sf::st_area(sf::st_intersection(sf::st_geometry(regions[1, ]), sf::st_geometry(regions[2, ])))))
  domain_area <- as.numeric(sum(sf::st_area(domain)))
  partition_error <- abs(domain_area - as.numeric(sum(sf::st_area(regions)))) / domain_area
  expect_lte(overlap_area, 1)
  expect_lte(partition_error, 1e-7)
})

test_that("station assignment handles core, transfer, outside, missing, and invalid coordinates", {
  subregion_file <- file.path(project_root, "config", "spatial", "hydrographic_subregions.geojson")
  assigned <- assign_station(c(54, 57.5, 65, NA), c(2, 11, 0, 2), subregions_file = subregion_file)
  expect_identical(
    assigned,
    c("southern_and_central_north_sea", "skagerrak_kattegat", NA_character_, NA_character_)
  )
  expect_error(assign_station(91, 0, subregions_file = subregion_file), "Invalid WGS84")
  expect_error(assign_station(0, 181, subregions_file = subregion_file), "Invalid WGS84")
  expect_error(assign_station("54", 2, subregions_file = subregion_file), "must be numeric")
})

test_that("the exact 5,500 m default includes and excludes the correct coastal points", {
  path <- write_test_regions("region", list(square_polygon(0, 0, 1, 1)))
  on.exit(unlink(path), add = TRUE)
  expect_identical(formals(assign_station)$max_dist_m, 5500)
  expect_identical(formals(assign_station)$distance_tie_tolerance_m, 0.000001)
  expect_identical(assign_station(0.5, -0.04, path), "region")
  expect_true(is.na(assign_station(0.5, -0.06, path)))
})

test_that("boundary, overlap, centroid, and lexical tie-breaks are deterministic", {
  adjacent <- write_test_regions(
    c("alpha", "beta"),
    list(square_polygon(0, 0, 1, 1), square_polygon(1, 0, 2, 1))
  )
  overlap <- write_test_regions(
    c("alpha", "beta"),
    list(square_polygon(0, 0, 2, 1), square_polygon(1, 0, 4, 1))
  )
  on.exit(unlink(c(adjacent, overlap)), add = TRUE)
  expect_identical(assign_station(0.5, 1, adjacent), "alpha")
  expect_identical(assign_station(0.5, 1.8, overlap), "beta")
  expect_identical(assign_station(c(0.5, 0.5), c(1.8, 1.8), overlap), c("beta", "beta"))
})

test_that("raw spatial acquisition and derived provenance reconcile", {
  run_id <- read_frozen_spatial_run(file.path(project_root, "config", "spatial_raw_run.txt"))
  run_dir <- file.path(project_root, "data", "raw", "search_runs", run_id)
  manifest <- validate_spatial_run(run_dir, verify_checksums = TRUE)
  feature_rows <- manifest$artifact_role == "features_page"
  returned <- tapply(manifest$returned_feature_count[feature_rows], manifest$source_id[feature_rows], sum)
  expected <- tapply(manifest$expected_feature_count[feature_rows], manifest$source_id[feature_rows], unique)
  expect_identical(as.integer(returned[names(expected)]), as.integer(expected))
  expect_true(all(manifest$pagination_complete[feature_rows]))
  expect_false(any(tolower(manifest$transfer_limit_state[feature_rows]) == "true"))

  provenance_file <- file.path(project_root, "metadata", "stage0_spatial_provenance.csv")
  provenance <- read.csv(provenance_file, stringsAsFactors = FALSE)
  expect_equal(nrow(provenance), 2L)
  expect_true(all(provenance$source_run_id == run_id))
  expect_true(all(provenance$source_manifest_checksum_sha256 == calculate_checksum(file.path(run_dir, "manifest.csv"))))
  expect_identical(
    unname(provenance$output_checksum_sha256),
    unname(vapply(file.path(project_root, provenance$output_file), calculate_checksum, character(1)))
  )
  expect_true(all(provenance$derivation_script_checksum_sha256 == calculate_checksum(file.path(project_root, "scripts", "00_derive_spatial.R"))))
  expect_true(all(provenance$protocol_config_checksum_sha256 == calculate_checksum(file.path(project_root, "config", "protocol_config.json"))))
})
