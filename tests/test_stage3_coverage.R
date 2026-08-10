library(testthat)

root <- if (file.exists("README.md")) "." else ".."
at_root <- function(...) file.path(root, ...)
read_project_csv <- function(path) read.csv(at_root(path), stringsAsFactors = FALSE)

test_that("mixed datetime quality cannot erase valid time of day", {
  source(at_root("R/05_stage3_contract.R"), local = TRUE)
  value <- stage3_parse_datetime(c("2020-10-22 05:48:00", "2020-10-22 99:99:00", "2020-10-23"))
  expect_equal(format(value[[1]], "%H:%M:%S", tz = "UTC"), "05:48:00")
  expect_true(is.na(value[[2]]))
  expect_equal(format(value[[3]], "%H:%M:%S", tz = "UTC"), "00:00:00")
})

test_that("Stage 3 freezes the complete Stage 2 handoff", {
  manifest <- read_project_csv("metadata/stage3/input/stage3_input_manifest.csv")
  expect_equal(nrow(manifest), 19L)
  expect_equal(anyDuplicated(manifest$work_item_id), 0L)
  expect_equal(sum(manifest$work_state == "complete"), 16L)
  expect_equal(sum(manifest$work_state == "unavailable"), 3L)
  expect_setequal(manifest$ds_id[manifest$work_state == "unavailable"], c("DS08", "DS23", "DS28"))
  expect_setequal(manifest$ds_id[manifest$stage3_scope %in% c("primary_candidate",
    "primary_candidate_duplicate_audit")], c("DS02", "DS03", "DS04", "DS05", "DS06", "DS07", "DS16"))
  expect_true(all(file.exists(at_root(manifest$status_evidence_path))))
})

test_that("sample support uses defensible dataset/sample keys and all observation adapters", {
  samples <- read_project_csv("data/interim/stage3_sample_support.csv")
  expect_gt(nrow(samples), 0L)
  expect_equal(anyDuplicated(paste(samples$ds_id, samples$sample_id, sep = "|")), 0L)
  expect_setequal(unique(samples$ds_id), c("DS02", "DS03", "DS04", "DS05", "DS06", "DS07",
    "DS09", "DS10", "DS11", "DS12", "DS16", "DS24", "DS26", "DS27"))
  valid_time_by_dataset <- tapply(!is.na(samples$datetime_utc) & nzchar(samples$datetime_utc),
                                  samples$ds_id, sum)
  expect_true(all(valid_time_by_dataset > 0L))
  expect_true(all(c("station_id", "datetime_precision", "subregion_id", "method_epoch") %in% names(samples)))
})

test_that("known biological roles survive the Stage 3 audit", {
  value <- read_project_csv("metadata/stage3/method/method_biological_coverage.csv")
  row <- function(id) value[value$ds_id == id, , drop = FALSE]
  expect_true(all(row("DS06")[c("has_carbon", "has_biovolume", "has_abundance", "has_taxonomy")]))
  expect_true(all(row("DS26")[c("has_carbon", "has_biovolume", "has_abundance", "has_taxonomy")]))
  expect_true(all(row("DS02")[c("has_abundance", "has_taxonomy")]))
  expect_true(row("DS11")$has_chlorophyll)
  expect_false(row("DS11")$has_abundance)
  expect_true(row("DS27")$has_chlorophyll)
  expect_false(row("DS27")$has_carbon)
  expect_true(all(!value[value$work_state == "unavailable", grep("^has_", names(value))]))
  expect_equal(sum(value$cross_lifeform_dominance_permitted_now), 1L)
  expect_true(row("DS06")$cross_lifeform_dominance_permitted_now)
})

test_that("coverage outputs have stable keys and do not overstate stations", {
  temporal <- read_project_csv("metadata/stage3/coverage/temporal_cadence_by_year.csv")
  station_temporal <- read_project_csv("metadata/stage3/coverage/temporal_cadence_by_station_year.csv")
  station_availability <- read_project_csv("metadata/stage3/coverage/station_temporal_availability.csv")
  time_coverage <- read_project_csv("metadata/stage3/coverage/time_of_day_coverage.csv")
  spatial <- read_project_csv("metadata/stage3/coverage/spatial_support.csv")
  expect_equal(anyDuplicated(temporal[c("ds_id", "monitoring_network", "subregion_id", "method_epoch", "year")]), 0L)
  expect_equal(anyDuplicated(station_temporal[c("ds_id", "monitoring_network", "station_id",
    "subregion_id", "method_epoch", "year")]), 0L)
  expect_equal(anyDuplicated(time_coverage[c("ds_id", "monitoring_network", "subregion_id", "year")]), 0L)
  expect_setequal(time_coverage$ds_id, temporal$ds_id)
  expect_true(all(temporal$adequacy_state == "not_assessed_until_target_season_is_frozen"))
  expect_true(all(!spatial$spatial_interpolation_permitted))
  expect_true(any(spatial$station_identity_state == "coordinate_or_transect_proxy_not_station"))
  expect_true(all(station_temporal$station_identity_state == "provider_station"))
  expect_setequal(station_availability$ds_id, unique(temporal$ds_id))
  expect_true(any(station_availability$station_temporal_support_state ==
                    "unavailable_only_coordinate_or_transect_proxy"))
  expect_true(all(time_coverage$tidal_phase_support_state == "unknown_no_frozen_tide_source"))
})

test_that("role gate is region-period-window-tier resolved and PhyC blind", {
  gate <- read_project_csv("metadata/stage3/gate/dataset_region_period_role_gate.csv")
  key <- c("ds_id", "monitoring_network", "subregion_id", "method_epoch", "year", "period_start", "period_end",
           "analysis_window", "reference_tier")
  expect_equal(anyDuplicated(gate[key]), 0L)
  expect_true(all(gate$stage3_role %in% c("eligible", "secondary", "exploratory", "unusable")))
  expect_true(all(!gate$phy_c_inspected))
  expect_true(any(gate$stage3_role == "eligible"))
  expect_false(any(gate$ds_id == "DS03" & gate$stage3_role == "eligible"))
  expect_true(all(c("DS08", "DS23", "DS28") %in% gate$ds_id[gate$stage3_role == "unusable"]))
  overlap <- read_project_csv("metadata/stage3/gate/cmems_metadata_overlap.csv")
  expect_true(all(overlap$candidate_cmems_product_id == "not_prospectively_frozen"))
  expect_true(all(overlap$temporal_overlap_state == "unknown_until_product_metadata_is_frozen"))
  expect_true(all(!overlap$phy_c_values_accessed))
})

test_that("required Stage 3 outputs and figures exist", {
  paths <- c(
    "metadata/stage3/coverage/temporal_cadence_by_year.csv",
    "metadata/stage3/coverage/temporal_cadence_by_station_year.csv",
    "metadata/stage3/coverage/station_temporal_availability.csv",
    "metadata/stage3/coverage/time_of_day_coverage.csv",
    "metadata/stage3/coverage/seasonal_effort.csv",
    "metadata/stage3/coverage/spatial_support.csv",
    "metadata/stage3/coverage/vertical_support.csv",
    "metadata/stage3/method/method_epoch_register.csv",
    "metadata/stage3/method/network_year_variable_matrix.csv",
    "metadata/stage3/gate/coverage_gaps.csv",
    "outputs/figures/stage3_temporal_coverage.png",
    "outputs/figures/stage3_spatial_support.png"
  )
  full_paths <- at_root(paths)
  expect_true(all(file.exists(full_paths)))
  expect_true(all(file.info(full_paths)$size > 0))
})
