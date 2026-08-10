library(testthat)

root <- if (file.exists("README.md")) "." else ".."
at_root <- function(...) file.path(root, ...)
read_project_csv <- function(path) read.csv(at_root(path), stringsAsFactors = FALSE)

test_that("Stage 4 retains all datasets and authorizes only explicit Stage 5 roles", {
  x <- read_project_csv("metadata/stage4/feasibility/provisional_dataset_manifest.csv")
  expect_equal(nrow(x), 19L)
  expect_equal(anyDuplicated(x$ds_id), 0L)
  expect_setequal(x$ds_id[x$independent_primary_network], c("DS02", "DS04", "DS05", "DS06", "DS07", "DS16"))
  expect_equal(x$stage4_role[x$ds_id == "DS06"], "primary_direct_carbon_anchor")
  expect_setequal(x$ds_id[x$stage4_role == "unavailable"], c("DS08", "DS23", "DS28"))
  expect_true(all(!x$phy_c_inspected))
})

test_that("feasibility covers every frozen subregion and candidate window", {
  x <- read_project_csv("metadata/stage4/feasibility/subregion_window_feasibility.csv")
  expect_equal(nrow(x), 8L)
  expect_equal(anyDuplicated(x[c("subregion_id", "analysis_window")]), 0L)
  expect_setequal(x$subregion_id, c("southern_and_central_north_sea", "skagerrak_kattegat"))
  expect_setequal(x$analysis_window, c("daily", "3_day", "7_day", "cadence_matched"))
  expect_true(all(x$adequately_sampled_year_state == "unknown_pending_prespecified_adequacy_rules"))
  expect_true(all(x$bloom_event_count_state == "unknown_until_stage6_observation_only_outcomes"))
  expect_true(all(!x$phy_c_inspected))
})

test_that("window conclusions do not promote daily timing or freeze the final window", {
  x <- read_project_csv("metadata/stage4/feasibility/window_candidate_register.csv")
  expect_setequal(x$analysis_window[x$window_design_role == "primary_window_candidate"],
                  c("7_day", "cadence_matched"))
  expect_equal(x$window_design_role[x$analysis_window == "daily"], "not_confirmatory")
  expect_true(all(!x$final_primary_window_frozen))
})

test_that("lifeforms and scope limitations remain observation-only and conservative", {
  life <- read_project_csv("metadata/stage4/feasibility/lifeform_feasibility.csv")
  limits <- read_project_csv("metadata/stage4/feasibility/scope_limitations.csv")
  expect_true(all(!life$confirmatory_now))
  expect_true(all(life$recurrence_state == "not_calculated_before_stage6"))
  expect_true(all(!life$phy_c_inspected))
  expect_true(all(c("tier_a_base", "offshore_central_northern", "target_season_adequacy",
                    "event_counts", "cmems_overlap", "contact_required_inputs") %in% limits$limitation_id))
  expect_true(all(!limits$phy_c_inspected))
})

test_that("Stage 4 gate permits Stage 5 only", {
  x <- read_project_csv("metadata/stage4/gate/stage4_gate_status.csv")
  expect_equal(nrow(x), 1L)
  expect_equal(x$gate_state, "conditional_proceed_to_stage5_harmonization")
  expect_true(x$stage5_harmonization_authorized)
  expect_false(x$stage6_outcome_authorized)
  expect_false(x$cmems_acquisition_authorized)
  expect_false(x$phy_c_values_accessed)
  expect_equal(x$independent_primary_candidate_networks, 6L)
  expect_equal(x$direct_carbon_anchor_networks, 1L)
})
