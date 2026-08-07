suppressPackageStartupMessages({
  library(testthat)
  library(jsonlite)
  library(rprojroot)
})

project_root <- rprojroot::find_root(rprojroot::has_file("renv.lock"))
source(file.path(project_root, "R", "00_identifiers.R"))

test_that("all frozen identifier generators are deterministic and correctly prefixed", {
  config <- jsonlite::fromJSON(file.path(project_root, "config", "protocol_config.json"))
  prefixes <- config$provenance_rules$identifier_prefixes
  dataset_id <- generate_dataset_id("EMODNET", "Biology", "2026")
  station_id <- generate_station_id(dataset_id, "Station 1", 54.1234, 2.1234)
  sample_id <- generate_sample_id(station_id, "2026-08-07T12:00:00Z", 10.1)
  generated <- c(
    dataset = dataset_id,
    search_run = generate_search_run_id("EMODNET", "20260807T120000Z"),
    source_record = generate_source_record_id(dataset_id, "record-1", 1),
    sample = sample_id,
    station = station_id,
    taxon_record = generate_taxon_record_id(sample_id, "Phaeocystis", "colonial"),
    observation_window = generate_observation_window_id(station_id, "2026-04-01", "2026-04-07"),
    event = generate_event_id("REG-1", 2026, 1),
    year = generate_year_id("REG-1", 2026),
    network = generate_network_id("EMODNET"),
    subregion = generate_subregion_id("southern_and_central_north_sea"),
    model_file = generate_model_file_id("phyc.nc", "abcdef")
  )
  expect_setequal(names(generated), names(prefixes))
  for (identifier_type in names(generated)) {
    expect_match(generated[[identifier_type]], paste0("^", prefixes[[identifier_type]], "-[a-f0-9]{16}$"))
  }
  expect_identical(generate_dataset_id("EMODNET", "Biology", "2026"), dataset_id)
})

test_that("identifier collision inputs and canonical rounding behave as specified", {
  dataset_id <- generate_dataset_id("EMODNET", "Biology", "2026")
  expect_identical(
    generate_dataset_id("EMODNET", NA_character_, ""),
    generate_dataset_id("EMODNET", "NA", "NA")
  )
  expect_identical(
    generate_station_id(dataset_id, "Station 1", 54.12340, 2.12340),
    generate_station_id(dataset_id, "Station 1", 54.12341, 2.12342)
  )
  expect_false(identical(
    generate_station_id(dataset_id, "Station 1", 54.12340, 2.12340),
    generate_station_id(dataset_id, "Station 1", 54.12349, 2.12349)
  ))
  expect_false(identical(
    generate_source_record_id(dataset_id, "record-1", 1),
    generate_source_record_id(dataset_id, "record-1", 2)
  ))
  expect_false(identical(
    generate_sample_id("STN-1", "2026-08-07T12:00:00Z", 10),
    generate_sample_id("STN-1", "2026-08-07T12:00:01Z", 10)
  ))
})

test_that("the data dictionary covers every frozen identifier entity", {
  dictionary <- read.csv(file.path(project_root, "config", "data_dictionary.csv"), stringsAsFactors = FALSE)
  config <- jsonlite::fromJSON(file.path(project_root, "config", "protocol_config.json"))
  expect_setequal(unique(dictionary$entity), names(config$provenance_rules$identifier_prefixes))
  expect_equal(anyDuplicated(dictionary[c("entity", "field")]), 0L)
})
