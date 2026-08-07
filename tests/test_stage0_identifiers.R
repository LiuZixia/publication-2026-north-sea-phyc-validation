library(testthat)
library(jsonlite)
library(sf)
library(rprojroot)

proj_root <- rprojroot::find_root(rprojroot::has_file("renv.lock"))
source(file.path(proj_root, "R", "00_identifiers.R"))
source(file.path(proj_root, "R", "00_spatial_assignment.R"))

test_that("Configuration contains required elements and strict formatting", {
  config <- fromJSON(file.path(proj_root, "config", "protocol_config.json"))
  expect_true(!is.null(config$study_domain$crs))
  expect_true(is.null(config$study_domain$coastline_mask)) # Should be removed
  expect_true(!is.null(config$study_domain$depth_convention))
  expect_equal(config$study_domain$time_convention$format, "%Y-%m-%dT%H:%M:%SZ")
  expect_true(!is.null(config$provenance_rules$identifier_prefixes))
})

test_that("Deterministic spatial assignments", {
  sub_file <- file.path(proj_root, "config", "spatial", "hydrographic_subregions.geojson")
  expect_true(file.exists(sub_file))
  
  # Assert topological validity
  old_s2 <- sf_use_s2(FALSE)
  on.exit(sf_use_s2(old_s2), add = TRUE)
  regions <- st_read(sub_file, quiet = TRUE)
  expect_true(all(st_is_valid(regions)))
  
  # Southern and Central North Sea point (approx 2E, 54N)
  # Skagerrak/Kattegat point (approx 11E, 57.5N)
  # Outside point (0E, 65N)
  
  lats <- c(54.0, 57.5, 65.0)
  lons <- c(2.0, 11.0, 0.0)
  
  assigned <- assign_station(lats, lons, subregions_file = sub_file)
  
  # Assertions
  expect_equal(assigned[1], "southern_and_central_north_sea")
  expect_equal(assigned[2], "skagerrak_kattegat")
  expect_true(is.na(assigned[3]))
  
  # Tie-breaking/coastal buffer point
  # A point well outside the marine boundary, e.g. 52.0 N, 5.0 E (Netherlands land)
  assigned_coastal <- assign_station(c(52.0), c(5.0), subregions_file = sub_file, max_dist_m = 500000)
  expect_true(!is.na(assigned_coastal))
})

test_that("Deterministic identifiers with canonical rules", {
  
  # Test dataset ID
  ds1 <- generate_dataset_id("EMODNET", "Biology", "2026")
  ds2 <- generate_dataset_id("EMODNET", "Biology", "2026")
  expect_equal(ds1, ds2)
  expect_match(ds1, "^DS-[a-f0-9]{16}$")
  
  # Test missing values are handled identically to "NA"
  ds_na <- generate_dataset_id("EMODNET", NA, "")
  ds_na_explicit <- generate_dataset_id("EMODNET", "NA", "NA")
  expect_equal(ds_na, ds_na_explicit)
  
  # Test station ID (rounding coordinates)
  st1 <- generate_station_id(ds1, "Stn1", 54.12341, 2.12342)
  st2 <- generate_station_id(ds1, "Stn1", 54.12349, 2.12349) # Different, should hash differently
  st3 <- generate_station_id(ds1, "Stn1", 54.12340, 2.12340) # Same when rounded to 4 decimals (54.1234, 2.1234)
  expect_true(st1 != st2)
  expect_equal(st1, st3)
  expect_match(st1, "^STN-")
  
  # Test record ID collision indexing
  rec1 <- generate_source_record_id(ds1, "REC1", collision_index = 1)
  rec2 <- generate_source_record_id(ds1, "REC1", collision_index = 2)
  expect_true(rec1 != rec2)
  
  # Verify other generators do not error and use correct prefixes
  expect_match(generate_sample_id(st1, "2026-08-07T12:00:00Z", 10.12), "^SMP-")
  expect_match(generate_source_record_id(ds1, "REC1"), "^REC-")
  expect_match(generate_taxon_record_id("SMP-XXX", "Phaeocystis", "adult"), "^TAX-")
  expect_match(generate_event_id("REG-1", 2026, 1), "^EVT-")
  expect_match(generate_year_id("REG-1", 2026), "^YR-")
  expect_match(generate_subregion_id("Core"), "^REG-")
  expect_match(generate_network_id("EMODNET"), "^NET-")
  expect_match(generate_search_run_id("EMODNET", "20260807T120000Z"), "^SEARCH-")
  expect_match(generate_observation_window_id(st1, "2026-01-01", "2026-12-31"), "^WIN-")
  expect_match(generate_model_file_id("file.nc", "abcd"), "^MOD-")
})
