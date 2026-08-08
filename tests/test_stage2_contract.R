library(testthat)

root <- if (file.exists("README.md")) "." else ".."
at_root <- function(...) file.path(root, ...)
source(at_root("R", "00_core_setup.R"))
source(at_root("R", "00_identifiers.R"))
source(at_root("R", "03_stage2_contract.R"))

test_that("the Stage 2 contract is prospective and preserves the scientific boundary", {
  contract <- read_stage2_contract(at_root("config", "stage2_record_screening_contract.json"))
  expect_identical(contract$schema_version, "1.0.0")
  expect_identical(contract$frozen_at_utc, "2026-08-08T18:10:24Z")
  expect_true(contract$raw_storage$immutable)
  expect_identical(contract$raw_storage$required_resolved_target,
                   "/mnt/hdd/publication-2026-north-sea-phyc-validation/")
  expect_false(contract$decision_rules$title_only_geography_can_set_final_decision)
  expect_true(contract$decision_rules$unknown_is_never_negative)
  expect_false(contract$decision_rules$aggregator_copy_counts_as_independent_network)

  all_fields <- unlist(lapply(contract$tables, function(spec) {
    vapply(spec$fields, function(field) field$name, character(1))
  }), use.names = FALSE)
  expect_false(any(tolower(all_fields) %in% unlist(contract$phy_c_boundary$prohibited_fields)))
  expect_false(any(grepl("phyc|phy_c", all_fields, ignore.case = TRUE)))
})

test_that("every Stage 2 table schema can be instantiated and rejects drift", {
  contract <- read_stage2_contract(at_root("config", "stage2_record_screening_contract.json"))
  for (table_name in names(contract$tables)) {
    empty <- stage2_empty_table(contract, table_name)
    expect_silent(validate_stage2_table(empty, table_name, contract))
    expect_identical(names(empty), stage2_field_names(contract, table_name), info = table_name)
  }

  work <- read.csv(at_root("metadata", "stage2_acquisition_work_order.csv"),
                   stringsAsFactors = FALSE, check.names = FALSE)
  expect_error(validate_stage2_table(work[-1], "acquisition_work_order", contract),
               "columns differ")
  work$work_state[[1]] <- "invented_state"
  expect_error(validate_stage2_table(work, "acquisition_work_order", contract),
               "outside vocabulary")
})

test_that("the Stage 1 shortlist is frozen into the exact Stage 2 rank order", {
  contract <- read_stage2_contract(at_root("config", "stage2_record_screening_contract.json"))
  shortlist <- read.csv(at_root("metadata", "stage1_acquisition_shortlist.csv"), stringsAsFactors = FALSE)
  work <- read.csv(at_root("metadata", "stage2_acquisition_work_order.csv"),
                   stringsAsFactors = FALSE, check.names = FALSE)
  expect_silent(validate_stage2_work_order(work, contract))
  expect_identical(work$ds_id, shortlist$ds_id[order(shortlist$acquisition_rank)])
  expect_identical(work$name, shortlist$name[order(shortlist$acquisition_rank)])
  expect_true(all(work$required_next_action ==
                  "acquire_highest_resolution_canonical_provider_record_then_screen"))
})

test_that("all unmatched WFS candidates remain pending for record-level evidence", {
  contract <- read_stage2_contract(at_root("config", "stage2_record_screening_contract.json"))
  queue <- read.csv(
    at_root("metadata", "stage2_wfs_geometry_queue.csv"),
    stringsAsFactors = FALSE,
    check.names = FALSE,
    colClasses = c(wfs_dataset_id = "character")
  )
  expect_silent(validate_stage2_wfs_queue(queue, contract))
  expect_equal(nrow(queue), 40L)
  expect_equal(sum(queue$title_domain_signal == "out_of_domain"), 18L)
  expect_equal(sum(queue$title_domain_signal == "unknown"), 22L)
  expect_true(all(queue$screening_decision == "pending"))
  expect_true(all(grepl("title evidence cannot set a final record-level decision",
                        queue$decision_detail, fixed = TRUE)))

  title_only_exclusion <- queue
  title_only_exclusion$screening_decision[[1]] <- "excluded"
  title_only_exclusion$record_geometry_state[[1]] <- "not_checked"
  expect_error(validate_stage2_wfs_queue(title_only_exclusion, contract),
               "No WFS candidate may receive a final decision")
})

test_that("the Stage 2 freeze pins every contract input and routing artifact", {
  freeze <- jsonlite::fromJSON(at_root("metadata", "stage2_contract_freeze.json"), simplifyVector = FALSE)
  expect_identical(freeze$status, "prospectively_frozen_before_observation_acquisition")
  expect_identical(freeze$shortlist_rows, 19L)
  expect_identical(freeze$wfs_pending_rows, 40L)
  expect_identical(freeze$wfs_title_out_of_domain_signals, 18L)
  expect_identical(freeze$wfs_unknown_title_geography, 22L)
  expect_equal(length(freeze$artifacts), 10L)
  roles <- vapply(freeze$artifacts, function(artifact) artifact$role, character(1))
  expect_equal(anyDuplicated(roles), 0L)
  for (artifact in freeze$artifacts) {
    path <- at_root(artifact$path)
    expect_true(file.exists(path), info = artifact$role)
    expect_identical(calculate_checksum(path), artifact$checksum_sha256, info = artifact$role)
  }
})

test_that("source-record identity follows the frozen Stage 0 generator", {
  id <- generate_source_record_id("DS06", "provider-row-1", collision_index = 1L)
  expect_match(id, "^REC-[0-9a-f]{16}$")
  expect_identical(id, generate_source_record_id("DS06", "provider-row-1", collision_index = 1L))
  expect_false(identical(id, generate_source_record_id("DS06", "provider-row-1", collision_index = 2L)))
})

test_that("the complete WFS geometry run is pinned and reconciled", {
  pin <- read.csv(at_root("metadata", "stage2_emodnet_wfs_active_run.csv"),
                  stringsAsFactors = FALSE, check.names = FALSE)
  expect_equal(nrow(pin), 1L)
  run_dir <- at_root("data", "raw", pin$run_relative_path[[1]])
  expect_identical(calculate_checksum(file.path(run_dir, "manifest.csv")),
                   pin$manifest_checksum_sha256[[1]])
  expect_identical(calculate_checksum(file.path(run_dir, "dataset_hit_summary.csv")),
                   pin$dataset_hit_summary_checksum_sha256[[1]])
  expect_identical(calculate_checksum(file.path(run_dir, "run_summary.json")),
                   pin$run_summary_checksum_sha256[[1]])
  summary <- jsonlite::fromJSON(file.path(run_dir, "run_summary.json"), simplifyVector = FALSE)
  expect_identical(summary$status, "complete")
  expect_identical(summary$queried_datasets, 40L)
  expect_identical(summary$manifest_rows, 81L)
  expect_identical(summary$bbox_records_archived, 384548L)
})

test_that("record geometry resolves every unmatched WFS candidate without title-only exclusion", {
  contract <- read_stage2_contract(at_root("config", "stage2_record_screening_contract.json"))
  screened <- read.csv(at_root("metadata", "stage2_emodnet_wfs_screening.csv"),
                       stringsAsFactors = FALSE, check.names = FALSE,
                       colClasses = c(wfs_dataset_id = "character"))
  evidence <- read.csv(at_root("metadata", "stage2_emodnet_wfs_geometry_evidence.csv"),
                       stringsAsFactors = FALSE, check.names = FALSE,
                       colClasses = c(wfs_dataset_id = "character"))
  expect_silent(validate_stage2_wfs_queue(screened, contract, require_initial = FALSE))
  expect_true(all(screened$record_geometry_state == "resolved"))
  expect_equal(sum(screened$screening_decision == "excluded"), 37L)
  expect_setequal(evidence$wfs_dataset_id[evidence$exact_domain_records > 0L],
                  c("2453", "5951", "6698"))
  expect_equal(sum(evidence$domain_bbox_records), 384548L)
  expect_equal(sum(evidence$exact_domain_records), 371618L)
  expect_true(all(evidence$boundary_touch_records == 0L))
  expect_true(all(screened$screening_decision[screened$title_domain_signal == "out_of_domain"] == "excluded"))
})

test_that("official metadata routes WFS survivors to canonical scientific roles", {
  resolution <- read.csv(at_root("metadata", "stage2_emodnet_wfs_survivor_resolution.csv"),
                         stringsAsFactors = FALSE, check.names = FALSE,
                         colClasses = c(wfs_dataset_id = "character"))
  expect_setequal(resolution$wfs_dataset_id, c("2453", "5951", "6698"))
  smhi <- resolution[resolution$wfs_dataset_id %in% c("2453", "6698"), ]
  expect_true(all(smhi$aggregator_relationship == "aggregator_copy"))
  expect_true(all(smhi$routed_work_item_id == "REGISTER:DS06"))
  expect_true(all(smhi$licence_state == "open"))
  expect_true(all(smhi$licence_url == "https://spdx.org/licenses/CC0-1.0.html"))
  expect_true(all(smhi$screening_decision == "pending"))

  belgian <- resolution[resolution$wfs_dataset_id == "5951", ]
  expect_identical(belgian$licence_url, "https://spdx.org/licenses/CC-BY-4.0.html")
  expect_identical(belgian$provisional_tier, "F")
  expect_identical(belgian$analysis_role, "discovery_sensitivity")
  expect_identical(belgian$screening_decision, "exploratory")
  expect_match(belgian$scientific_reason, "two years cannot satisfy")

  work <- read.csv(at_root("metadata", "stage2_acquisition_work_order.csv"), stringsAsFactors = FALSE)
  expect_equal(sum(work$work_item_id == "REGISTER:DS06"), 1L)
  expect_false(any(grepl("EMODNET-WFS", work$work_item_id)))
})
