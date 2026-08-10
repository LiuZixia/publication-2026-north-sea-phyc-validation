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

test_that("the live Stage 2 status overlay distinguishes progress from the frozen baseline", {
  work <- read.csv(at_root("metadata", "stage2_acquisition_work_order.csv"),
                   stringsAsFactors = FALSE, check.names = FALSE)
  status <- read.csv(at_root("metadata", "stage2_acquisition_status.csv"),
                     stringsAsFactors = FALSE, check.names = FALSE)
  expect_equal(nrow(work), 19L)
  expect_true(all(work$work_state == "not_started"))
  expect_identical(status$work_item_id, work$work_item_id)
  expect_identical(status$frozen_work_state, work$work_state)
  expect_identical(status$current_work_state[status$ds_id == "DS06"], "in_progress")
  expect_identical(status$current_work_state[status$ds_id == "DS26"], "complete")
  expect_identical(status$current_work_state[status$ds_id == "DS02"], "in_progress")
  expect_identical(status$acquisition_state[status$ds_id == "DS02"],
                   "observations_acquired_pending_record_screening")
  expect_true(all(status$current_work_state[status$acquisition_rank >= 4L] == "not_started"))
  expect_equal(sum(status$current_work_state == "complete"), 1L)
  expect_equal(sum(status$current_work_state == "in_progress"), 2L)
  expect_equal(sum(status$current_work_state == "not_started"), 16L)
  expect_false(all(status$current_work_state == "complete"))
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

test_that("rank-2 DS26 recurrent SMHI IFCB observations are acquired and pinned", {
  contract <- read_stage2_contract(at_root("config", "stage2_record_screening_contract.json"))
  pin <- read.csv(at_root("metadata", "stage2_ds26_smhi_ifcb_active_run.csv"),
                  stringsAsFactors = FALSE, check.names = FALSE)
  manifest <- read.csv(at_root("metadata", "stage2_ds26_smhi_ifcb_acquisition_manifest.csv"),
                       stringsAsFactors = FALSE, check.names = FALSE)
  files <- read.csv(at_root("metadata", "stage2_ds26_smhi_ifcb_figshare_file_inventory.csv"),
                    stringsAsFactors = FALSE, check.names = FALSE,
                    colClasses = c(file_id = "character"))
  expect_equal(nrow(pin), 1L)
  expect_identical(pin$work_item_id, "REGISTER:DS26")
  expect_equal(pin$artifact_count, 3L)
  expect_equal(pin$total_size_bytes, 18376897)
  expect_equal(nrow(manifest), 3L)
  expect_silent(validate_stage2_table(manifest, "acquisition_manifest", contract))
  expect_equal(sum(manifest$source_role == "canonical_provider"), 2L)
  expect_equal(sum(manifest$source_role == "comparator"), 1L)
  expect_true(all(manifest$file_validation_state == "verified"))
  expect_true(all(manifest$license_state == "open"))
  expect_equal(nrow(files), 4L)
  expect_equal(sum(files$size_bytes), 8104707049)
  expect_true(all(files$acquisition_state == "metadata_only_pending_role_and_size_review"))

  run_dir <- at_root("data", "raw", pin$run_relative_path[[1]])
  expect_identical(calculate_checksum(file.path(run_dir, "manifest.csv")),
                   pin$manifest_checksum_sha256[[1]])
  expect_identical(calculate_checksum(file.path(run_dir, "figshare_file_inventory.csv")),
                   pin$figshare_inventory_checksum_sha256[[1]])
})

test_that("DS26 exact screening supports only the prespecified secondary IFCB role", {
  contract <- read_stage2_contract(at_root("config", "stage2_record_screening_contract.json"))
  tables <- read.csv(at_root("metadata", "stage2_ds26_smhi_ifcb_table_summary.csv"),
                     stringsAsFactors = FALSE, check.names = FALSE)
  measurements <- read.csv(at_root("metadata", "stage2_ds26_smhi_ifcb_measurement_summary.csv"),
                           stringsAsFactors = FALSE, check.names = FALSE)
  events <- read.csv(at_root("metadata", "stage2_ds26_smhi_ifcb_event_summary.csv"),
                     stringsAsFactors = FALSE, check.names = FALSE)
  linkage <- read.csv(at_root("metadata", "stage2_ds26_smhi_ifcb_event_linkage_audit.csv"),
                      stringsAsFactors = FALSE, check.names = FALSE)
  inventory <- read.csv(at_root("metadata", "stage2_ds26_smhi_ifcb_variable_inventory.csv"),
                        stringsAsFactors = FALSE, check.names = FALSE)
  summary <- read.csv(at_root("metadata", "stage2_ds26_smhi_ifcb_screening_summary.csv"),
                      stringsAsFactors = FALSE, check.names = FALSE)
  registry <- read.csv(at_root("metadata", "stage2_ds26_smhi_ifcb_output_registry.csv"),
                       stringsAsFactors = FALSE, check.names = FALSE)
  expect_identical(tables$row_count, c(17731L, 121103L, 1111062L))
  expect_equal(nrow(inventory), 85L)
  expect_silent(validate_stage2_table(inventory, "variable_inventory", contract))
  expect_equal(nrow(events), 3L)
  expect_equal(sum(events$core_occurrence_rows), 3212L)
  expect_equal(sum(events$external_transfer_occurrence_rows), 57844L)
  expect_equal(sum(events$outside_domain_occurrence_rows), 60047L)
  expect_equal(sum(events$invalid_coordinate_occurrence_rows), 0L)
  expect_setequal(events$source_dataset, c(
    "SHARK_PlanktonImaging_2016_SMHI_Tangesund",
    "SHARK_PlanktonImaging_2022_2024_SMHI_Baltic",
    "SHARK_PlanktonImaging_2022_2024_SMHI_Skagerrak_Kattegat"
  ))
  expect_true(all(c("Carbon content", "Biovolume concentration", "Abundance",
                    "Classifier F1 score model accuracy", "Classifier used", "Trophic type") %in%
                    measurements$measurement_type))
  expect_identical(linkage$event_type,
                   c("dataset_event", "sampling_event", "sample", "all_event_table_rows"))
  expect_identical(linkage$event_table_rows, c(1L, 8865L, 8865L, 17731L))
  expect_identical(linkage$occurrence_linked_event_rows, c(0L, 0L, 8864L, 8864L))
  expect_identical(linkage$occurrence_unlinked_event_rows, c(1L, 8865L, 1L, 8867L))
  expect_identical(linkage$event_measurement_linked_event_rows, c(1L, 8865L, 8865L, 17731L))
  expect_identical(linkage$occurrence_unlinked_with_event_measurement_rows,
                   c(1L, 8865L, 1L, 8867L))
  expect_silent(validate_stage2_table(summary, "dataset_screening_summary", contract))
  expect_identical(summary$provisional_tier, "B")
  expect_identical(summary$analysis_role, "lifeform_only")
  expect_identical(summary$screening_decision, "secondary")
  expect_equal(summary$core_record_count, 3212L)
  expect_equal(summary$external_transfer_record_count, 57844L)
  expect_match(summary$screening_detail, "17731 event-table rows")
  expect_match(summary$screening_detail, "8864 sample leaves")
  expect_match(summary$screening_detail, "remains unknown rather than a negative")
  expect_match(summary$screening_detail, "Only four calendar years")
  expect_match(summary$screening_detail, "machine-predicted")
  expect_equal(nrow(registry), 7L)
  expect_true(all(registry$output_schema_version == "1.1.0"))
  expect_identical(registry$row_count[registry$artifact_role == "event_linkage_audit"], 4L)
  expect_true(all(file.exists(at_root(registry$path))))
  expect_true(all(vapply(seq_len(nrow(registry)), function(i) {
    identical(calculate_checksum(at_root(registry$path[[i]])), registry$checksum_sha256[[i]])
  }, logical(1))))
})

test_that("the DS26 annotated image library is method evidence not a second network", {
  contract <- read_stage2_contract(at_root("config", "stage2_record_screening_contract.json"))
  pin <- read.csv(at_root("metadata", "stage2_ds26_ifcb_reference_active_run.csv"),
                  stringsAsFactors = FALSE, check.names = FALSE)
  manifest <- read.csv(at_root("metadata", "stage2_ds26_ifcb_reference_acquisition_manifest.csv"),
                       stringsAsFactors = FALSE, check.names = FALSE)
  summary <- read.csv(at_root("metadata", "stage2_ds26_ifcb_reference_summary.csv"),
                      stringsAsFactors = FALSE, check.names = FALSE)
  expect_equal(nrow(pin), 1L)
  expect_equal(pin$file_count, 4L)
  expect_equal(pin$total_size_bytes, 8104707049)
  expect_equal(nrow(manifest), 4L)
  expect_silent(validate_stage2_table(manifest, "acquisition_manifest", contract))
  expect_true(all(manifest$provider_dataset_id == "FIGSHARE:25883455"))
  expect_true(all(manifest$source_role == "comparator"))
  expect_true(all(manifest$license_state == "open"))
  expect_true(all(manifest$redistribution_state == "allowed"))
  expect_true(all(grepl("not an independent monitoring network", manifest$status_detail, fixed = TRUE)))
  expect_equal(summary$annotated_image_count, 86232L)
  expect_equal(summary$class_count, 146L)
  expect_false(summary$independent_monitoring_network)
  expect_false(summary$observation_record_source)
})

test_that("rank-3 DS02 starts from the canonical RWS catalogue without substituting PLET", {
  contract <- read_stage2_contract(at_root("config", "stage2_record_screening_contract.json"))
  pin <- read.csv(at_root("metadata", "stage2_ds02_rws_catalogue_active_run.csv"),
                  stringsAsFactors = FALSE, check.names = FALSE)
  manifest <- read.csv(at_root("metadata", "stage2_ds02_rws_catalogue_acquisition_manifest.csv"),
                       stringsAsFactors = FALSE, check.names = FALSE)
  expect_equal(nrow(pin), 1L)
  expect_identical(pin$work_item_id, "REGISTER:DS02")
  expect_equal(pin$artifact_count, 3L)
  expect_equal(nrow(manifest), 3L)
  expect_silent(validate_stage2_table(manifest, "acquisition_manifest", contract))
  expect_true(all(manifest$provider == "Rijkswaterstaat (RWS)"))
  expect_true(all(manifest$source_role == "canonical_provider"))
  expect_true(all(manifest$license_state == "open"))
  expect_true(all(manifest$redistribution_state == "allowed"))
  expect_false(any(grepl("PLET", manifest$provider)))

  run_dir <- at_root("data", "raw", pin$run_relative_path[[1]])
  expect_identical(calculate_checksum(file.path(run_dir, "manifest.csv")),
                   pin$manifest_checksum_sha256[[1]])
  expect_identical(calculate_checksum(file.path(run_dir, "rws_extended_catalogue.json")),
                   pin$catalogue_checksum_sha256[[1]])
})

test_that("DS02 observation screening supersedes catalogue-only checkpoint", {
  contract <- read_stage2_contract(at_root("config", "stage2_record_screening_contract.json"))
  links <- read.csv(at_root("metadata", "stage2_ds02_rws_catalogue_link_summary.csv"),
                    stringsAsFactors = FALSE, check.names = FALSE)
  summary <- read.csv(at_root("metadata", "stage2_ds02_rws_screening_summary.csv"),
                      stringsAsFactors = FALSE, check.names = FALSE)
  registry <- read.csv(at_root("metadata", "stage2_ds02_rws_catalogue_output_registry.csv"),
                       stringsAsFactors = FALSE, check.names = FALSE)
  access <- read.csv(at_root("metadata", "stage2_ds02_rws_v3_access_diagnosis.csv"),
                     stringsAsFactors = FALSE, check.names = FALSE)
  access_pin <- read.csv(at_root("metadata", "stage2_ds02_rws_v3_access_active_run.csv"),
                         stringsAsFactors = FALSE, check.names = FALSE)
  expect_equal(links$catalogue_metadata_rows, 2757L)
  expect_equal(links$catalogue_location_rows, 2635L)
  expect_equal(links$catalogue_metadata_location_links, 104679L)
  expect_equal(links$core_locations, 1092L)
  expect_equal(links$external_transfer_locations, 0L)
  expect_equal(links$outside_domain_locations, 1543L)
  expect_equal(links$invalid_coordinate_locations, 0L)
  expect_equal(links$domain_linked_metadata_rows, 2158L)
  expect_equal(links$count_or_biovolume_metadata_rows, 21L)
  expect_equal(links$explicit_marine_phytoplankton_metadata_rows, 0L)
  expect_equal(links$observation_rows_acquired, 0L)
  expect_silent(validate_stage2_table(summary, "dataset_screening_summary", contract))
  expect_identical(summary$screening_decision, "pending")
  expect_identical(summary$provisional_tier, "A")
  expect_equal(summary$record_count, 505452L)
  expect_match(summary$screening_detail, "Manual temporal exports from RWS Waterinfo API V3 are complete and record-screened")
  expect_match(summary$screening_detail, "194411 records intersect the core region")
  expect_match(summary$screening_detail, "not-yet-assessed")
  expect_equal(nrow(registry), 3L)
  expect_true(all(file.exists(at_root(registry$path))))
  expect_true(all(vapply(seq_len(nrow(registry)), function(i) {
    identical(calculate_checksum(at_root(registry$path[[i]])), registry$checksum_sha256[[i]])
  }, logical(1))))
  expect_equal(nrow(access), 1L)
  expect_equal(access$http_status, 401L)
  expect_false(access$authentication_sent)
  expect_equal(access$observation_rows_acquired, 0L)
  expect_identical(access$access_state, "credential_or_provider_export_required")
  expect_identical(calculate_checksum(at_root("data", "raw", access$evidence_relative_path)),
                   access$evidence_checksum_sha256)
  expect_identical(access_pin$response_headers_checksum_sha256,
                   access$evidence_checksum_sha256)
})

test_that("DS02 manual Waterinfo export is pinned and supports record screening", {
  contract <- read_stage2_contract(at_root("config", "stage2_record_screening_contract.json"))
  cfg <- jsonlite::fromJSON(
    at_root("config", "stage2_ds02_rws_manual_export_intake.json"),
    simplifyVector = FALSE
  )
  pin <- read.csv(at_root("metadata", "stage2_ds02_rws_manual_export_active_run.csv"),
                  stringsAsFactors = FALSE, check.names = FALSE)
  manifest <- read.csv(
    at_root("metadata", "stage2_ds02_rws_manual_export_acquisition_manifest.csv"),
    stringsAsFactors = FALSE, check.names = FALSE
  )
  inventory <- read.csv(
    at_root("metadata", "stage2_ds02_rws_manual_export_file_inventory.csv"),
    stringsAsFactors = FALSE, check.names = FALSE
  )
  intake <- read.csv(
    at_root("metadata", "stage2_ds02_rws_manual_export_intake_summary.csv"),
    stringsAsFactors = FALSE, check.names = FALSE
  )

  expect_identical(cfg$portal_category, "Overige biologische data")
  expect_setequal(unlist(cfg$portal_filters$taxon_type), c("FYTPT", "DIATM"))
  expect_identical(cfg$portal_filters$period, "not_reported")
  expect_equal(nrow(manifest), 4L)
  expect_silent(validate_stage2_table(manifest, "acquisition_manifest", contract))
  expect_true(all(manifest$provider == "Rijkswaterstaat (RWS)"))
  expect_true(all(manifest$source_role == "canonical_provider"))
  expect_true(all(manifest$request_method == "MANUAL_BROWSER_EXPORT"))
  expect_true(all(manifest$file_validation_state == "verified"))
  expect_true(all(vapply(seq_len(nrow(manifest)), function(i) {
    path <- at_root("data", "raw", manifest$raw_relative_path[[i]])
    file.exists(path) && identical(calculate_checksum(path), manifest$checksum_sha256[[i]])
  }, logical(1))))

  expect_equal(inventory$observation_rows, c(210900L, 60723L, 47758L, 186071L))
  expect_equal(inventory$meetobject_count, c(40L, 21L, 37L, 41L))
  expect_equal(sum(inventory$extra_location_description_rows), 105L)
  expect_equal(intake$source_file_count, 4L)
  expect_equal(intake$total_size_bytes, 76933080)
  expect_equal(intake$observation_rows, 505452L)
  expect_equal(intake$target_2000_2019_rows, 432532L)
  expect_equal(intake$outside_target_period_rows, 72920L)
  expect_identical(intake$date_min_utc, "2000-01-09T23:00:00Z")
  expect_identical(intake$date_max_utc, "2025-09-02T10:00:00Z")
  expect_equal(intake$meetobject_count, 139L)
  expect_equal(intake$pairwise_station_overlap_count, 0L)
  expect_equal(intake$raw_exact_duplicate_rows, 1574L)
  expect_equal(intake$extra_location_description_rows, 105L)
  expect_identical(intake$acquisition_state,
                   "canonical_observations_acquired_pending_record_screening")
  expect_identical(intake$screening_decision, "pending")

  run_dir <- at_root("data", "raw", pin$run_relative_path[[1]])
  expect_identical(calculate_checksum(file.path(run_dir, "manifest.csv")),
                   pin$manifest_checksum_sha256[[1]])
  expect_identical(calculate_checksum(file.path(run_dir, "file_inventory.csv")),
                   pin$file_inventory_checksum_sha256[[1]])
  expect_identical(calculate_checksum(file.path(run_dir, "intake_summary.csv")),
                   pin$intake_summary_checksum_sha256[[1]])
})
