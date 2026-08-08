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

test_that("rank-1 DS06 canonical SHARK acquisition is complete and pinned", {
  contract <- read_stage2_contract(at_root("config", "stage2_record_screening_contract.json"))
  pin <- read.csv(at_root("metadata", "stage2_ds06_smhi_shark_active_run.csv"),
                  stringsAsFactors = FALSE, check.names = FALSE)
  manifest <- read.csv(at_root("metadata", "stage2_ds06_smhi_shark_acquisition_manifest.csv"),
                       stringsAsFactors = FALSE, check.names = FALSE)
  expect_equal(nrow(pin), 1L)
  expect_identical(pin$work_item_id, "REGISTER:DS06")
  expect_equal(pin$package_count, 219L)
  expect_equal(pin$total_size_bytes, 27700519)
  expect_equal(nrow(manifest), 219L)
  expect_silent(validate_stage2_table(manifest, "acquisition_manifest", contract))
  expect_true(all(manifest$provider == "SMHI SHARK"))
  expect_true(all(manifest$source_role == "canonical_provider"))
  version_counts <- sort(table(manifest$provider_version), decreasing = TRUE)
  expect_identical(as.integer(version_counts), c(208L, 8L, 1L, 1L, 1L))
  expect_identical(names(version_counts),
                   c("2025-03-09", "2025-03-11", "2025-03-07", "2025-03-13", "2025-03-17"))
  expect_true(all(manifest$file_validation_state == "verified"))
  expect_true(all(manifest$license_state == "open"))
  expect_equal(sum(manifest$size_bytes), pin$total_size_bytes)

  run_dir <- at_root("data", "raw", pin$run_relative_path[[1]])
  expect_identical(calculate_checksum(file.path(run_dir, "manifest.csv")),
                   pin$manifest_checksum_sha256[[1]])
  expect_identical(calculate_checksum(file.path(run_dir, "run_summary.json")),
                   pin$run_summary_checksum_sha256[[1]])
  expect_true(all(file.exists(at_root("data", "raw", manifest$raw_relative_path))))
})

test_that("DS06 variable inventory and exact spatial screen reconcile every source row", {
  contract <- read_stage2_contract(at_root("config", "stage2_record_screening_contract.json"))
  registry <- read.csv(at_root("metadata", "stage2_ds06_smhi_shark_output_registry.csv"),
                       stringsAsFactors = FALSE, check.names = FALSE)
  packages <- read.csv(at_root("metadata", "stage2_ds06_smhi_shark_package_summary.csv"),
                       stringsAsFactors = FALSE, check.names = FALSE)
  inventory <- read.csv(at_root("metadata", "stage2_ds06_smhi_shark_variable_inventory.csv"),
                        stringsAsFactors = FALSE, check.names = FALSE)
  expect_equal(nrow(registry), 4L)
  expect_equal(registry$row_count[registry$artifact_role == "record_screening"], 909693L)
  expect_equal(registry$row_count[registry$artifact_role == "duplicate_identity"], 909693L)
  expect_equal(nrow(packages), 219L)
  expect_equal(sum(packages$source_rows), 909693L)
  expect_equal(sum(packages$core_rows), 7948L)
  expect_equal(sum(packages$external_transfer_rows), 478860L)
  expect_equal(sum(packages$outside_domain_rows), 422885L)
  expect_equal(sum(packages$carbon_rows), 209656L)
  expect_equal(sum(packages$biovolume_rows), 186334L)
  expect_equal(sum(packages$abundance_or_count_rows), 513703L)
  expect_equal(sum(packages$method_metadata_rows), 494671L)
  expect_true(all(packages$source_rows == packages$core_rows +
                    packages$external_transfer_rows + packages$outside_domain_rows))
  expect_equal(nrow(inventory), 21390L)
  expect_silent(validate_stage2_table(inventory, "variable_inventory", contract))
})

test_that("DS06 cross-package duplicate evidence preserves distinct scientific rows", {
  contract <- read_stage2_contract(at_root("config", "stage2_record_screening_contract.json"))
  summary <- read.csv(
    at_root("metadata", "stage2_ds06_smhi_shark_duplicate_resolution_summary.csv"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  overlap <- read.csv(at_root("metadata", "stage2_ds06_smhi_shark_sample_overlap.csv"),
                      stringsAsFactors = FALSE, check.names = FALSE)
  duplicate_map <- read.csv(at_root("data", "interim", "stage2_ds06_smhi_shark_duplicate_map.csv"),
                            stringsAsFactors = FALSE, check.names = FALSE,
                            colClasses = "character")
  registry <- read.csv(
    at_root("metadata", "stage2_ds06_smhi_shark_duplicate_resolution_registry.csv"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  expect_equal(summary$source_record_count, 909693L)
  expect_equal(summary$unique_provider_sample_count, 8102L)
  expect_equal(summary$cross_package_sample_count, 4L)
  expect_equal(summary$cross_package_sample_membership_count, 8L)
  expect_equal(summary$scientific_fingerprint_field_count, 51L)
  expect_equal(summary$exact_duplicate_fingerprint_count, 0L)
  expect_equal(summary$duplicate_record_count, 0L)
  expect_equal(nrow(overlap), 8L)
  expect_equal(length(unique(overlap$shark_sample_id_md5)), 4L)
  expect_true(all(overlap$exact_cross_package_duplicate_rows == 0L))
  expect_equal(nrow(duplicate_map), 0L)
  expect_silent(validate_stage2_table(duplicate_map, "duplicate_map", contract))
  expect_equal(nrow(registry), 4L)
  expect_true(all(file.exists(at_root(registry$path))))
})

test_that("DS06 remains pending despite its provisional direct-carbon tier", {
  contract <- read_stage2_contract(at_root("config", "stage2_record_screening_contract.json"))
  summary <- read.csv(at_root("metadata", "stage2_ds06_smhi_shark_screening_summary.csv"),
                      stringsAsFactors = FALSE, check.names = FALSE)
  expect_silent(validate_stage2_table(summary, "dataset_screening_summary", contract))
  expect_identical(summary$work_item_id, "REGISTER:DS06")
  expect_identical(summary$provisional_tier, "A")
  expect_identical(summary$analysis_role, "primary_reference")
  expect_identical(summary$screening_decision, "pending")
  expect_equal(summary$core_record_count, 7948L)
  expect_equal(summary$external_transfer_record_count, 478860L)
  expect_equal(summary$duplicate_record_count, 0L)
  expect_match(summary$screening_detail, "not-yet-assessed")
})
