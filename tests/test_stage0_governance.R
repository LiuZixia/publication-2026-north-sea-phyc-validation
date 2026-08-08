suppressPackageStartupMessages({
  library(testthat)
  library(jsonlite)
  library(rprojroot)
})

project_root <- rprojroot::find_root(rprojroot::has_file("renv.lock"))

test_that("the frozen study configuration is complete and internally exact", {
  config <- jsonlite::fromJSON(file.path(project_root, "config", "protocol_config.json"), simplifyVector = FALSE)
  expect_identical(config$study_domain$name, "Greater North Sea")
  expect_identical(config$study_domain$crs, "EPSG:4326")
  expect_identical(config$study_domain$coastline_and_land_mask, "none_separate_ICES_marine_polygon_boundary_is_authoritative")
  expect_identical(config$study_domain$depth_convention, "positive_down_meters")
  expect_identical(config$study_domain$time_convention$timezone, "UTC")
  expect_identical(config$study_domain$time_convention$format, "%Y-%m-%dT%H:%M:%SZ")
  expect_identical(config$study_domain$station_assignment$maximum_distance_m, 5500L)
  expect_identical(config$study_domain$station_assignment$boundary_inclusion, "zero_distance_including_shared_boundaries")
  expect_identical(config$study_domain$station_assignment$distance_tie_tolerance_m, 0.000001)
  expect_identical(
    unlist(config$study_domain$station_assignment$multiple_candidate_tiebreak),
    c("minimum_distance_to_polygon", "minimum_distance_to_polygon_centroid", "lexicographic_subregion_id")
  )
  expect_identical(config$study_domain$regions$southern_and_central_north_sea, "core-domain")
  expect_identical(config$study_domain$regions$skagerrak_kattegat, "external-transfer")
})

test_that("protocol changes have accountable approval rather than role placeholders", {
  register <- read.csv(file.path(project_root, "config", "protocol_change_register.csv"), stringsAsFactors = FALSE)
  required <- c("date", "change", "rationale", "affected_stages", "decision_maker", "approval_status", "approval_reference", "classification")
  expect_identical(names(register), required)
  expect_true(nrow(register) >= 5L)
  expect_false(anyNA(register[required]))
  expect_true(all(register$approval_status %in% c("approved", "pending")))
  # The register carries proposals for later stages once Stage 0 is frozen. Anything that
  # touches a frozen Stage 0 decision must still be approved; a pending row may only
  # affect stages that have not yet passed their gate.
  stage_lists <- strsplit(register$affected_stages, "|", fixed = TRUE)
  touches_stage_zero <- vapply(stage_lists, function(x) "0" %in% trimws(x), logical(1))
  expect_true(all(register$approval_status[touches_stage_zero] == "approved"))
  # A pending row must still name its decision maker and its proposal source, so an
  # unapproved change can never be mistaken for a silently adopted one.
  expect_true(all(nzchar(trimws(register$approval_reference))))
  expect_true(all(nzchar(trimws(register$decision_maker))))
  placeholder_pattern <- "principal investigator|core team|protocol review|pending|unknown|tbd|placeholder"
  expect_false(any(grepl(placeholder_pattern, register$decision_maker, ignore.case = TRUE)))
  expect_true(all(register$classification %in% c("prospective amendment", "sensitivity analysis", "protocol deviation")))
})

test_that("the raw spatial source and immutable acquisition are frozen", {
  sources <- read.csv(file.path(project_root, "config", "spatial_sources.csv"), stringsAsFactors = FALSE)
  expect_setequal(sources$source_id, c("ices_ecoregions", "ices_areas"))
  expect_false(anyNA(sources))
  expect_true(all(grepl("^https://", sources$layer_url)))
  expect_true(all(sources$license == "CC BY 4.0"))
  pin <- trimws(readLines(file.path(project_root, "config", "spatial_raw_run.txt"), warn = FALSE))
  pin <- pin[nzchar(pin) & !startsWith(pin, "#")]
  expect_length(pin, 1L)
  expect_match(pin, "^SPATIAL-ICES-[0-9]{8}T[0-9]{6}Z(?:-[0-9]+)?$")
})

test_that("the Stage 0 environment and entry points are versioned", {
  expect_true(file.exists(file.path(project_root, "renv.lock")))
  expect_true(file.exists(file.path(project_root, "scripts", "00_setup.R")))
  expect_true(file.exists(file.path(project_root, "scripts", "00_derive_spatial.R")))
  lock <- jsonlite::fromJSON(file.path(project_root, "renv.lock"))
  expect_true(all(c("digest", "httr2", "jsonlite", "rprojroot", "sf", "testthat") %in% names(lock$Packages)))
})
