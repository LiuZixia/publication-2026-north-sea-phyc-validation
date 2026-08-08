library(testthat)

root <- if (file.exists("README.md")) "." else ".."
at_root <- function(...) file.path(root, ...)
source(at_root("R", "00_core_setup.R"))
source(at_root("R", "01_registry_identity.R"))

test_that("the frozen strategy covers the full domain, terms, sources, and review state", {
  cfg <- jsonlite::fromJSON(at_root("config", "stage1_search_config.json"), simplifyVector = FALSE)
  expect_identical(cfg$schema_version, "1.0.0")
  expect_equal(unlist(cfg$geographic_scope$bbox_wgs84), c(-5, 48, 13.06914, 62))
  expect_setequal(unlist(cfg$geographic_scope$terms), c("North Sea", "Greater North Sea", "German Bight",
    "Dutch Continental Shelf", "Belgian Part of the North Sea", "Skagerrak", "Kattegat"))
  expect_true(all(c("phytoplankton", "Phaeocystis", "diatom", "dinoflagellate", "coccolithophore", "picoplankton", "nanophytoplankton") %in% unlist(cfg$biological_terms)))
  expect_true(all(c("abundance", "biomass", "biovolume", "carbon", "species composition", "bloom monitoring", "chlorophyll", "pigment", "flow cytometry") %in% unlist(cfg$measurement_terms)))
  expect_length(cfg$source_strategies, 10L)
  # The reviewer field frozen in this file is a superseded placeholder. It is deliberately not
  # corrected: the file's checksum is pinned into all ten archived run summaries, so editing it
  # would invalidate every executed search. The live record is config/scientific_review.json.
  expect_identical(cfg$review$second_scientific_reviewer, "Dr. Researcher")
})

test_that("scientific review is recorded honestly and does not overstate independence", {
  review <- jsonlite::fromJSON(at_root("config", "scientific_review.json"), simplifyVector = FALSE)
  strategy <- review$stage1_search_strategy
  expect_identical(review$supersedes$field, "review.second_scientific_reviewer")
  expect_identical(strategy$reviewer, "Dr. Zixia Liu")
  expect_identical(strategy$status, "reviewed")

  # Designer and reviewer are the same party, so Stage 1 action 2 is not satisfied. The record
  # must say so: a self-review reported as independent would be the most consequential possible
  # misstatement in this file, because every exclusion decision rests on it.
  expect_false(strategy$independent)
  expect_match(strategy$review_type, "self_review")
  expect_identical(strategy$independent_review$status, "deferred")
  expect_true(nzchar(strategy$independent_review$must_complete_before))
  expect_true(nzchar(strategy$independent_review$risk_if_not_completed))

  registry <- read.csv(at_root("metadata", "candidate_registry.csv"), stringsAsFactors = FALSE)
  expect_true(all(grepl("independent_second_review_deferred", registry$reviewer, fixed = TRUE)))
  expect_false(any(grepl("Dr. Researcher", registry$reviewer, fixed = TRUE)))

  # The requirements map must still carry the manual gate; automating it would be a false claim.
  map <- read.csv(at_root("tests", "requirements_map.csv"), stringsAsFactors = FALSE)
  reviewer_row <- map[map$stage == 1 & map$action == "2" &
    grepl("second scientific reviewer", map$requirement, ignore.case = TRUE), ]
  expect_equal(nrow(reviewer_row), 1L)
  expect_identical(reviewer_row$coverage, "manual_pending")
})

test_that("one complete active run is pinned for every required source family", {
  active <- read.csv(at_root("metadata", "stage1_active_runs.csv"), stringsAsFactors = FALSE)
  expected <- c("PLET", "ICES_DOME", "EMODNET_ERDDAP", "OBIS", "SMHI_SHARK", "PANGAEA", "GBIF",
                "MARINE_SCOTLAND", "CEFAS_DASSH", "ICES_FIGSHARE")
  expect_setequal(active$source_key, expected)
  expect_equal(anyDuplicated(active$source_key), 0L)
  config_checksum <- calculate_checksum(at_root("config", "stage1_search_config.json"))
  for (id in active$search_run_id) {
    run_dir <- at_root("data", "raw", "search_runs", id)
    expect_true(file.exists(file.path(run_dir, "manifest.csv")), info = id)
    summary <- jsonlite::fromJSON(file.path(run_dir, "run_summary.json"), simplifyVector = FALSE)
    manifest <- read.csv(file.path(run_dir, "manifest.csv"), stringsAsFactors = FALSE, check.names = FALSE)
    expect_identical(summary$status, "complete", info = id)
    expect_true(summary$pagination_complete, info = id)
    expect_equal(summary$artifact_count, nrow(manifest), info = id)
    expect_equal(summary$records_identified_within_queries, sum(manifest$records_returned), info = id)
    expect_identical(summary$configuration_checksum_sha256, config_checksum, info = id)
  }
})

test_that("the direct EMODnet Biology WFS update is append-only and complete", {
  append <- read.csv(at_root("metadata", "stage1_append_runs.csv"), stringsAsFactors = FALSE)
  expect_identical(names(append), c("source_key", "search_run_id", "configuration_path"))
  expect_true(nrow(append) >= 1L)
  expect_true(all(append$source_key == "EMODNET_BIOLOGY_WFS"))
  expect_equal(anyDuplicated(append$search_run_id), 0L)

  for (i in seq_len(nrow(append))) {
    id <- append$search_run_id[[i]]
    config_path <- at_root(append$configuration_path[[i]])
    config <- jsonlite::fromJSON(config_path, simplifyVector = FALSE)
    expect_identical(config$classification, "append_only_stage1_search_update", info = id)
    expect_identical(config$inventory_layer, "Dataportal:eurobis_datasets", info = id)
    expect_identical(config$occurrence_layer, "Dataportal:eurobis", info = id)

    run_dir <- at_root("data", "raw", "search_runs", id)
    summary <- jsonlite::fromJSON(file.path(run_dir, "run_summary.json"), simplifyVector = FALSE)
    manifest <- read.csv(file.path(run_dir, "manifest.csv"), stringsAsFactors = FALSE, check.names = FALSE)
    pages <- manifest[grepl("dataset_catalogue_page_", manifest$raw_response_path), ]
    expect_identical(summary$status, "complete", info = id)
    expect_true(summary$pagination_complete, info = id)
    expect_identical(summary$configuration_path, append$configuration_path[[i]], info = id)
    expect_identical(summary$configuration_checksum_sha256, calculate_checksum(config_path), info = id)
    expect_equal(summary$provider_total, 1517L, info = id)
    expect_equal(summary$unique_provider_records, 1517L, info = id)
    expect_equal(sum(pages$records_returned), 1517L, info = id)
    expect_equal(unique(pages$total_reported), 1517L, info = id)
    expect_true(tail(pages$records_returned, 1L) < config$page_size, info = id)
  }
})

test_that("query log has exact scalar requests and checksum-verified raw evidence", {
  log <- read.csv(at_root("metadata", "stage1_query_log.csv"), stringsAsFactors = FALSE, check.names = FALSE)
  required <- c("search_run_id", "source_family", "provider", "endpoint", "api_version", "license", "method",
    "request_text", "query_hash_sha256", "query_label", "geographic_bounds", "page_or_cursor", "retrieved_utc",
    "http_status", "retry_max_tries", "raw_response_path", "checksum_sha256", "size_bytes", "content_type",
    "records_returned", "total_reported", "pagination_complete")
  expect_identical(names(log), required)
  expect_true(all(nzchar(log$request_text)))
  expect_true(all(grepl("^[0-9a-f]{64}$", log$query_hash_sha256)))
  expect_true(all(grepl("^[0-9a-f]{64}$", log$checksum_sha256)))
  expect_true(all(log$pagination_complete))
  expect_true(all(log$http_status %in% c(200L, 404L)))
  expect_true(all(log$http_status[log$source_family != "EMODnet ERDDAP"] == 200L))
  paths <- unique(log[, c("raw_response_path", "checksum_sha256")])
  for (i in seq_len(nrow(paths))) {
    path <- at_root("data", "raw", paths$raw_response_path[[i]])
    expect_true(file.exists(path), info = path)
    expect_identical(calculate_checksum(path), paths$checksum_sha256[[i]], info = path)
  }
})

test_that("provider totals and terminal pages reconcile", {
  log <- read.csv(at_root("metadata", "stage1_query_log.csv"), stringsAsFactors = FALSE, check.names = FALSE)

  pangaea <- log[log$source_family == "PANGAEA", ]
  expect_equal(sum(pangaea$records_returned), unique(pangaea$total_reported))
  expect_equal(unique(pangaea$total_reported), 966L)
  expect_equal(tail(pangaea$records_returned, 1), 0L)

  obis <- log[log$source_family == "OBIS", ]
  expect_equal(obis$records_returned, obis$total_reported)

  gbif <- log[log$source_family == "GBIF", ]
  for (label in unique(gbif$query_label)) {
    x <- gbif[gbif$query_label == label, ]
    expect_equal(sum(x$records_returned), unique(x$total_reported), info = label)
  }

  cefas <- log[log$source_family == "Cefas Data Hub/DASSH" & grepl("query_", log$raw_response_path), ]
  for (label in unique(cefas$query_label)) {
    x <- cefas[cefas$query_label == label, ]
    expect_equal(sum(x$records_returned), unique(x$total_reported), info = label)
  }

  scot <- log[log$source_family == "Marine Scotland", ]
  expect_equal(tail(scot$records_returned, 1), 0L)

  emodnet <- log[log$source_family == "EMODnet ERDDAP", ]
  expect_true(all(emodnet$records_returned < 1000L))

  emodnet_wfs <- log[log$source_family == "EMODnet Biology WFS" &
    grepl("dataset_catalogue_page_", log$raw_response_path), ]
  expect_equal(sum(emodnet_wfs$records_returned), unique(emodnet_wfs$total_reported))
  expect_equal(unique(emodnet_wfs$total_reported), 1517L)
  expect_true(tail(emodnet_wfs$records_returned, 1L) < 1000L)

  figshare <- log[log$source_family == "ICES Figshare" & grepl("ices_library_page_", log$raw_response_path), ]
  expect_true(tail(figshare$records_returned, 1) < 1000L)
  expect_equal(anyDuplicated(figshare$query_hash_sha256), 0L)
})

test_that("candidate registry has every essential field and points to raw evidence", {
  registry <- read.csv(at_root("metadata", "candidate_registry.csv"), stringsAsFactors = FALSE, check.names = FALSE)
  required <- c("search_run_id", "source", "endpoint", "api_version", "query_hash_sha256", "execution_time_utc",
    "raw_response_path", "raw_response_checksum_sha256", "provider_dataset_id", "catalogue_id", "title",
    "doi_or_stable_url", "version", "geographic_metadata", "temporal_metadata", "measurement_types", "taxonomic_content",
    "method_metadata", "access_status", "license", "screening_status", "exclusion_reason", "geographic_screen_state",
    "reviewer", "decision_date", "duplicate_catalogue_ids", "canonical_provider_dataset_id", "related_identifier")
  expect_identical(names(registry), required)
  expect_equal(nrow(registry), 28081L)
  expect_false(any(!nzchar(registry$search_run_id)))
  expect_false(any(!nzchar(registry$source)))
  expect_false(any(!nzchar(registry$provider_dataset_id)))
  expect_false(any(!nzchar(registry$title)))
  expect_false(any(!nzchar(registry$raw_response_path)))
  expect_true(all(grepl("^[0-9a-f]{64}$", registry$raw_response_checksum_sha256)))
  expect_equal(anyDuplicated(paste(registry$source, registry$provider_dataset_id)), 0L)
  expect_setequal(unique(registry$screening_status), c("pending", "excluded", "advanced_to_acquisition"))
  expect_true(all(nzchar(registry$exclusion_reason[registry$screening_status == "excluded"])))
  expect_true(all(!nzchar(registry$exclusion_reason[registry$screening_status != "excluded"])))
  expect_false("phyc_performance" %in% names(registry))
  expect_false(any(grepl("PhyC", apply(registry, 1, paste, collapse = " "), fixed = TRUE)))
})

test_that("search-flow counts are generated and exactly reproducible", {
  registry <- read.csv(at_root("metadata", "candidate_registry.csv"), stringsAsFactors = FALSE)
  flow <- read.csv(at_root("metadata", "stage1_search_flow.csv"), stringsAsFactors = FALSE)
  value <- setNames(flow$count, flow$stage)
  expect_equal(value[["records_identified"]], 29771L)
  expect_equal(value[["duplicate_catalogue_or_query_records"]], value[["records_identified"]] - nrow(registry))
  expect_equal(value[["unique_catalogue_records"]], nrow(registry))
  expect_equal(value[["unique_dataset_families"]], length(unique(registry$canonical_provider_dataset_id)))
  expect_equal(value[["screened"]], nrow(registry))
  expect_equal(value[["excluded"]], sum(registry$screening_status == "excluded"))
  expect_equal(value[["pending"]], sum(registry$screening_status == "pending"))
  expect_equal(value[["advanced_to_acquisition"]], sum(registry$screening_status == "advanced_to_acquisition"))
  expect_equal(value[["screened"]], value[["excluded"]] + value[["pending"]] + value[["advanced_to_acquisition"]])
})

test_that("the direct EMODnet WFS inventory has an explicit overlap diagnosis", {
  overlap <- read.csv(at_root("metadata", "stage1_emodnet_wfs_overlap.csv"), stringsAsFactors = FALSE)
  summary <- read.csv(at_root("metadata", "stage1_emodnet_wfs_overlap_summary.csv"), stringsAsFactors = FALSE)
  value <- setNames(summary$count, summary$metric)
  registry <- read.csv(at_root("metadata", "candidate_registry.csv"), stringsAsFactors = FALSE)

  expect_equal(nrow(overlap), 1517L)
  expect_equal(anyDuplicated(overlap$wfs_dataset_id), 0L)
  expect_equal(value[["wfs_dataset_inventory_rows"]], nrow(overlap))
  expect_equal(value[["exact_title_matches_any_archived_catalogue"]], sum(overlap$exact_title_match_existing))
  expect_equal(value[["exact_title_matches_obis"]], sum(overlap$exact_title_match_obis))
  expect_equal(value[["biological_title_candidates"]], sum(overlap$biological_title_match))
  expect_equal(value[["unmatched_biological_title_candidates"]],
    sum(overlap$biological_title_match & !overlap$exact_title_match_existing))
  expect_equal(value[["unmatched_biological_title_candidates"]], 40L)

  # The complete inventory disproves a blanket same-title assumption, but none of the unmatched
  # biological titles supplies dataset-level North Sea evidence. They remain explicit candidates
  # for record-level geometry screening instead of being silently promoted or discarded.
  unmatched_ids <- overlap$wfs_dataset_id[overlap$biological_title_match & !overlap$exact_title_match_existing]
  unmatched <- registry[registry$source == "EMODnet Biology WFS" &
    registry$provider_dataset_id %in% unmatched_ids, ]
  expect_equal(nrow(unmatched), 40L)
  expect_false(any(unmatched$geographic_screen_state == "dataset_metadata_matches_frozen_domain_terms"))
  expect_true(all(unmatched$screening_status == "pending"))
})

test_that("all prespecified known items are recalled from archived evidence", {
  recall <- read.csv(at_root("metadata", "stage1_known_item_recall.csv"), stringsAsFactors = FALSE)
  # The set deliberately includes candidates the search modules were not built around: the
  # offshore evidence base (DS12), the restricted German series (DS17, DS18), the second Wadden
  # Sea sentinel (DS09), the Dutch historical extension (DS03), the GBIF-only record (DS23), and
  # the external-transfer imaging series (DS26).
  expect_setequal(recall$benchmark_id, c("DS02", "DS03", "DS04", "DS05", "DS06", "DS07", "DS08",
    "DS09", "DS10", "DS12", "DS16", "DS17", "DS18", "DS23", "DS24", "DS26"))
  expect_true(all(recall$found))
  expect_true(all(nzchar(recall$raw_response_path)))
  expect_true(all(grepl("^[0-9a-f]{64}$", recall$raw_response_checksum_sha256)))
  expect_match(recall$matched_provider_dataset_id[recall$benchmark_id == "DS16"], "Stonehaven", ignore.case = TRUE)
  expect_identical(recall$matched_provider_dataset_id[recall$benchmark_id == "DS24"], "22189111")
})

test_that("no prespecified benchmark is discarded by the dataset-metadata screen", {
  # Recall proves only that a benchmark reached the registry. A benchmark that is present but
  # screened out never reaches Stage 2, so presence and retention must be asserted separately.
  recall <- read.csv(at_root("metadata", "stage1_known_item_recall.csv"), stringsAsFactors = FALSE)
  expect_true(all(recall$screening_status != "excluded"))
  expect_true(all(nzchar(recall$canonical_provider_dataset_id)))

  registry <- read.csv(at_root("metadata", "candidate_registry.csv"), stringsAsFactors = FALSE)
  # Provider titles abbreviate "phytoplankton"; matching only the full word discarded the Dutch
  # (RWS) and German (BSH) national series while known-item recall still reported them found.
  for (id in c("RWS_Fpzout_2000-2019_phyto", "BSH_Phyto_Zoo")) {
    row <- registry[registry$provider_dataset_id == id, ]
    expect_equal(nrow(row), 1L, info = id)
    expect_false(row$screening_status == "excluded", info = id)
  }
})

test_that("a shared provider DOI does not merge distinct observatories into one family", {
  registry <- read.csv(at_root("metadata", "candidate_registry.csv"), stringsAsFactors = FALSE)
  # PLET publishes eight distinct Marine Scotland series under the single DOI 10.17031/1637.
  mss <- registry[grepl("^MSS ", registry$title), ]
  expect_gte(nrow(mss), 8L)
  expect_equal(anyDuplicated(mss$canonical_provider_dataset_id), 0L)
  expect_true(all(mss$canonical_provider_dataset_id == paste(mss$source, mss$provider_dataset_id, sep = ":")))

  stonehaven <- registry[registry$provider_dataset_id == "MSS Stonehaven Chlorophyll data", ]
  expect_equal(nrow(stonehaven), 1L)
  expect_false(grepl("Loch Ewe", stonehaven$canonical_provider_dataset_id))
  expect_false(grepl("Loch Ewe", stonehaven$duplicate_catalogue_ids))
})

test_that("registry identity rules fold case and reject collection DOIs", {
  # "[^a-z0-9]" deletes uppercase letters, so folding must happen before the class is applied.
  expect_identical(stage1_norm_title("MSS Stonehaven Phytoplankton"), "mssstonehavenphytoplankton")
  expect_identical(stage1_norm_title("Cefas SmartBuoy - UK"), stage1_norm_title("CEFAS smartbuoy uk"))
  expect_identical(stage1_norm_doi("https://doi.org/10.17031/1637"), "10.17031/1637")
  expect_identical(stage1_norm_doi("https://data-api.cefas.co.uk/api/holdings/19624"), "")

  source <- c("PLET", "PLET", "PLET", "OBIS")
  doi <- c("10.1/collection", "10.1/collection", "10.2/dataset", "10.2/dataset")
  title <- c("stationa", "stationb", "seriesx", "seriesx")
  expect_identical(stage1_collection_dois(source, doi, title), "10.1/collection")

  identity <- ifelse(doi %in% stage1_collection_dois(source, doi, title), "", doi)
  groups <- stage1_identity_groups(identity, title)
  expect_equal(length(unique(groups)), 3L)
  expect_false(groups[[1]] == groups[[2]])
  expect_true(groups[[3]] == groups[[4]])
  # Grouping is transitive across the DOI and title passes.
  expect_equal(length(unique(stage1_identity_groups(c("d", "d", ""), c("", "t", "t")))), 1L)
})

test_that("dataset-level geography is recorded for every row and never silently enforced", {
  registry <- read.csv(at_root("metadata", "candidate_registry.csv"), stringsAsFactors = FALSE)
  states <- c("in_domain_by_server_side_query_geometry", "dataset_metadata_matches_frozen_domain_terms",
              "dataset_metadata_indicates_out_of_domain", "dataset_metadata_lacks_domain_evidence")
  expect_true(all(registry$geographic_screen_state %in% states))
  expect_true(all(nzchar(registry$geographic_screen_state)))

  # Only OBIS applied the frozen polygon server-side.
  expect_true(all(registry$geographic_screen_state[registry$source == "OBIS"] == "in_domain_by_server_side_query_geometry"))

  # GBIF exposes no dataset-level spatial filter. Out-of-domain holdings must therefore be
  # labelled and carried into Stage 2 record-level screening, not dropped on metadata alone,
  # and the label must not be mistaken for an exclusion that has already happened.
  gbif <- registry[registry$source == "GBIF", ]
  out_of_domain <- gbif[gbif$geographic_screen_state == "dataset_metadata_indicates_out_of_domain", ]
  expect_gt(nrow(out_of_domain), 0L)
  expect_true(all(out_of_domain$screening_status == "pending"))
  expect_true(any(grepl("Adriatic", out_of_domain$title, ignore.case = TRUE)))
  expect_false(any(grepl("geograph", registry$exclusion_reason, ignore.case = TRUE)))
})

test_that("DS22 is the actual validated and pinned PEG_BVOL file", {
  registry <- read.csv(at_root("metadata", "candidate_registry.csv"), stringsAsFactors = FALSE)
  ds22 <- registry[registry$provider_dataset_id == "PEG_BVOL_2025", ]
  expect_equal(nrow(ds22), 1L)
  expect_identical(ds22$screening_status, "advanced_to_acquisition")
  path <- at_root("data", "raw", ds22$raw_response_path)
  expect_true(file.exists(path))
  expect_gt(file.info(path)$size, 1000)
  expect_gt(nrow(utils::unzip(path, list = TRUE)), 0L)
  expect_identical(calculate_checksum(path), ds22$raw_response_checksum_sha256)
})

test_that("search modules contain no stubs, artificial page truncation, or PhyC lookup", {
  scripts <- list.files(at_root("scripts", "00_downloads"), pattern = "01_.*\\.R$", full.names = TRUE)
  expect_gte(length(scripts), 11L)
  text <- paste(vapply(c(scripts, at_root("R", "02_stage1_search_modules.R")), function(path) paste(readLines(path, warn = FALSE), collapse = "\n"), character(1)), collapse = "\n")
  expect_false(grepl("not fully implemented|creating stub|max_pages", text, ignore.case = TRUE))
  expect_false(grepl("CMEMS|PhyC", text, ignore.case = TRUE))
})

test_that("DS08 contact-only access state remains separately logged", {
  log_df <- read.csv(at_root("metadata", "manual_discovery_log.csv"), stringsAsFactors = FALSE)
  expect_true(any(log_df$identifier == "DS08" & log_df$verification_status == "manual_contact"))
})

test_that("every archived PLET catalogue row reaches the registry", {
  # A parser that skips records it cannot fully populate biases discovery in a direction no count
  # reveals. Requiring a DOI cell dropped seven real datasets, including the restricted German
  # coastal series DS17, because restricted holdings are the least likely to carry a DOI.
  active <- read.csv(at_root("metadata", "stage1_active_runs.csv"), stringsAsFactors = FALSE)
  run <- active$search_run_id[active$source_key == "PLET"]
  html <- paste(readLines(at_root("data", "raw", "search_runs", run, "catalogue.html"), warn = FALSE), collapse = "\n")
  trs <- regmatches(html, gregexpr("(?s)<tr[^>]*>.*?</tr>", html, perl = TRUE))[[1]]
  data_rows <- sum(vapply(trs, function(tr) {
    length(regmatches(tr, gregexpr("(?s)<td[^>]*>.*?</td>", tr, perl = TRUE))[[1]]) == 5L
  }, logical(1)))

  registry <- read.csv(at_root("metadata", "candidate_registry.csv"), stringsAsFactors = FALSE)
  expect_equal(sum(registry$source == "PLET"), data_rows)
  expect_true(any(registry$provider_dataset_id == "OSPAR_LLUR-SH_2010-2020"))
  no_doi <- registry[registry$source == "PLET" & !nzchar(registry$doi_or_stable_url), ]
  expect_gt(nrow(no_doi), 0L)
})

test_that("screening rules are versioned separately from the pinned search configuration", {
  # Correcting a screen must never invalidate a pinned search response and force a re-run.
  rules <- stage1_screening_rules(at_root("config", "screening_rules.json"))
  expect_gt(length(rules$biological_scope$terms), 0L)
  expect_gt(length(rules$geographic_screen$out_of_domain_terms), 0L)
  expect_true("PLET" %in% vapply(rules$biological_scope$scope_guaranteed_sources, `[[`, character(1), "source"))
  expect_true(all(nzchar(vapply(rules$biological_scope$scope_guaranteed_sources, `[[`, character(1), "reason"))))

  active <- read.csv(at_root("metadata", "stage1_active_runs.csv"), stringsAsFactors = FALSE)
  search_config <- calculate_checksum(at_root("config", "stage1_search_config.json"))
  for (id in active$search_run_id) {
    summary <- jsonlite::fromJSON(at_root("data", "raw", "search_runs", id, "run_summary.json"), simplifyVector = FALSE)
    expect_identical(summary$configuration_checksum_sha256, search_config, info = id)
  }
  # The screening rules must NOT be what the runs are pinned to.
  expect_false(identical(search_config, calculate_checksum(at_root("config", "screening_rules.json"))))
})

test_that("every register entry resolves to archived evidence or is diagnosed", {
  crosswalk <- read.csv(at_root("metadata", "stage1_ds_crosswalk.csv"), stringsAsFactors = FALSE)
  spec <- jsonlite::fromJSON(at_root("config", "ds_register_crosswalk.json"), simplifyVector = FALSE)
  expect_equal(nrow(crosswalk), length(spec$entries))
  expect_true(all(nzchar(crosswalk$register_section)))

  # Every observational candidate must either be located in archived evidence or be recorded as a
  # dataset the study proceeds without. An entry that is neither has simply gone missing.
  observational <- crosswalk[crosswalk$entry_type %in% c("dataset", "dataset_group", "conversion_reference"), ]
  unresolved <- observational$ds_id[!observational$resolved]
  unavailable <- read.csv(at_root("metadata", "stage1_unavailable_candidates.csv"), stringsAsFactors = FALSE)
  expect_true(all(unresolved %in% unavailable$ds_id),
    info = paste(setdiff(unresolved, unavailable$ds_id), collapse = ", "))

  shortlist <- read.csv(at_root("metadata", "stage1_acquisition_shortlist.csv"), stringsAsFactors = FALSE)
  expect_gt(nrow(shortlist), 15L)
  expect_equal(nrow(shortlist), 19L)
  expect_equal(shortlist$acquisition_rank, seq_len(nrow(shortlist)))
  expect_true(all(diff(shortlist$priority_score) <= 0))
  expect_false(any(shortlist$declared_domain == "out_of_domain"))
  # The benchmarks that carry the primary outcome must all be queued.
  expect_true(all(c("DS02", "DS04", "DS06", "DS07", "DS08") %in% shortlist$ds_id))
})

test_that("access classes are read from archived evidence and handle the empty case", {
  # paste0(character(0), "") returns a length-one "", so an entry that resolved to no retained
  # record would otherwise be classified as openly available. Two register entries were.
  expect_length(stage1_access_class(character(0), character(0)), 0L)
  expect_identical(stage1_availability(stage1_access_class(character(0), character(0))), "no_route")

  expect_identical(stage1_access_class("CC-BY-4.0 Creative Commons Attribution 4.0", "PANGAEA data status 4"), "open")
  expect_identical(stage1_access_class("UNKNOWN Licensing unknown: Please contact principal investigator", "PANGAEA data status 4"), "contact_required")
  # A provider marking a record restricted overrides a generic collection-level licence string.
  expect_identical(stage1_access_class("per underlying PLET dataset", "restricted"), "contact_required")
  expect_identical(stage1_access_class("", "public OBIS/EurOBIS metadata and archive"), "unverified")

  expect_identical(stage1_availability(c("open", "unverified")), "open_route_archived")
  expect_identical(stage1_availability(c("open", "contact_required")), "partially_open")
  expect_identical(stage1_availability(c("contact_required", "contact_required")), "contact_required")
})

test_that("contact-required datasets are excluded from acquisition and their consequence is recorded", {
  shortlist <- read.csv(at_root("metadata", "stage1_acquisition_shortlist.csv"), stringsAsFactors = FALSE)
  unavailable <- read.csv(at_root("metadata", "stage1_unavailable_candidates.csv"), stringsAsFactors = FALSE)
  requests <- read.csv(at_root("metadata", "provider_access_requests.csv"), stringsAsFactors = FALSE)
  policy <- jsonlite::fromJSON(at_root("config", "access_and_licence_policy.json"), simplifyVector = FALSE)

  expect_true(nzchar(policy$availability_rule$no_deadlines))
  expect_true(all(shortlist$availability %in% c("open_route_archived", "partially_open")))
  expect_false(any(unavailable$availability %in% c("open_route_archived", "partially_open")))
  expect_equal(length(intersect(shortlist$ds_id, unavailable$ds_id)), 0L)

  # Every dataset the study proceeds without must have its consequence written down now. A scope
  # limit that arises from access and is not recorded becomes indistinguishable, after results
  # exist, from an exclusion made because the result was inconvenient.
  expect_true(all(unavailable$ds_id %in% requests$ds_id),
    info = paste(setdiff(unavailable$ds_id, requests$ds_id), collapse = ", "))
  expect_true(all(nzchar(requests$consequence_applied_now)))
  expect_true(all(nzchar(requests$availability_treatment)))
  expect_true(all(nzchar(requests$revisit_trigger)))
  expect_false("decision_deadline" %in% names(requests))

  # DS08's carbon and biovolume children are contact-required; its abundance children are not.
  ds08 <- shortlist[shortlist$ds_id == "DS08", ]
  expect_equal(nrow(ds08), 1L)
  expect_identical(ds08$availability, "partially_open")
  expect_gt(ds08$rows_contact_required, 0L)
  expect_gt(ds08$rows_open_licence, 0L)

  # DS12 is reachable through its open OBIS route, so the offshore arm is not blocked.
  expect_true("DS12" %in% shortlist$ds_id)
  expect_true(all(c("DS17", "DS18", "DS19", "DS20", "DS21") %in% unavailable$ds_id))

  # Licence-unverified datasets must be flagged, never silently promoted.
  flagged <- shortlist$licence_action[shortlist$rows_licence_unverified > 0L]
  expect_true(all(flagged == "resolve_licence_before_stage7_manifest_freeze"))
})

test_that("every plan requirement maps to a test or a declared manual gate", {
  # The suite once passed while two benchmarks were excluded, four observatories were merged into
  # one family, and the geographic screen was inert. "The tests pass" is only a meaningful claim
  # when the requirements each test covers are enumerated.
  map <- read.csv(at_root("tests", "requirements_map.csv"), stringsAsFactors = FALSE)
  expect_identical(names(map), c("stage", "action", "requirement", "test_file", "test_name", "coverage"))
  expect_true(all(map$coverage %in% c("automated", "manual_pending")))
  expect_true(all(nzchar(map$requirement)))

  automated <- map[map$coverage == "automated", ]
  expect_true(all(nzchar(automated$test_file)))
  expect_true(all(nzchar(automated$test_name)))

  # Named tests in this file must actually exist.
  own <- automated[automated$test_file == "tests/test_stage1_search.R", ]
  source_text <- paste(readLines(at_root("tests", "test_stage1_search.R"), warn = FALSE), collapse = "\n")
  declared <- unique(gsub("[^a-z0-9]+", " ", tolower(own$test_name)))
  present <- unique(gsub("[^a-z0-9]+", " ", tolower(
    regmatches(source_text, gregexpr('(?<=test_that\\(")[^"]+', source_text, perl = TRUE))[[1]])))
  expect_true(all(declared %in% present), info = paste(setdiff(declared, present), collapse = " | "))

  # Every numbered Stage 1 action in the plan must appear in the map.
  plan <- readLines(at_root("docs", "STAGED_WORK_PLAN.md"), warn = FALSE)
  start <- grep("^## 4\\. Stage 1", plan)[[1]]
  end <- grep("^## 5\\. Stage 2", plan)[[1]]
  actions <- grep("^[0-9]+\\. ", plan[start:end], value = TRUE)
  numbers <- as.integer(sub("^([0-9]+)\\..*$", "\\1", actions))
  expect_true(all(seq_len(max(numbers)) %in% as.integer(map$action[map$stage == 1 & map$action != "quality"])))
})

test_that("generated status distinguishes diagnosed absence and unsent requests", {
  # Blank CSV cells are read as NA. Passing them directly to nzchar reports them as non-empty on
  # this R version, which previously made seven draft emails appear sent. Diagnosed no-route and
  # excluded-by-decision entries must likewise not be described as undiagnosed search failures.
  root_dir <- normalizePath(root, mustWork = TRUE)
  original_dir <- setwd(root_dir)
  on.exit(setwd(original_dir), add = TRUE)
  output <- system2("Rscript", file.path("scripts", "99_stage_status.R"), stdout = TRUE, stderr = TRUE)
  status <- attr(output, "status")
  if (is.null(status)) status <- 0L
  expect_equal(status, 0L, info = paste(output, collapse = "\n"))

  report <- paste(readLines(file.path(root_dir, "outputs", "stage_status.md"), warn = FALSE), collapse = "\n")
  expect_match(report, "\\*\\*Sent:\\*\\* 0")
  expect_match(report, "\\*\\*Drafted, awaiting a human to send:\\*\\* 7")
  expect_match(report, "\\*\\*Diagnosed without retained registry evidence:\\*\\* DS20, DS21, DS31, DS33")
  expect_match(report, "\\*\\*Undiagnosed search failures requiring query/API review:\\*\\* none")
})
