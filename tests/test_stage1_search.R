library(testthat)

root <- if (file.exists("README.md")) "." else ".."
at_root <- function(...) file.path(root, ...)
source(at_root("R", "00_core_setup.R"))

test_that("the frozen strategy covers the full domain, terms, sources, and review state", {
  cfg <- jsonlite::fromJSON(at_root("config", "stage1_search_config.json"), simplifyVector = FALSE)
  expect_identical(cfg$schema_version, "1.0.0")
  expect_equal(unlist(cfg$geographic_scope$bbox_wgs84), c(-5, 48, 13.06914, 62))
  expect_setequal(unlist(cfg$geographic_scope$terms), c("North Sea", "Greater North Sea", "German Bight",
    "Dutch Continental Shelf", "Belgian Part of the North Sea", "Skagerrak", "Kattegat"))
  expect_true(all(c("phytoplankton", "Phaeocystis", "diatom", "dinoflagellate", "coccolithophore", "picoplankton", "nanophytoplankton") %in% unlist(cfg$biological_terms)))
  expect_true(all(c("abundance", "biomass", "biovolume", "carbon", "species composition", "bloom monitoring", "chlorophyll", "pigment", "flow cytometry") %in% unlist(cfg$measurement_terms)))
  expect_length(cfg$source_strategies, 10L)
  expect_identical(cfg$review$status, "approved")
  expect_identical(cfg$review$second_scientific_reviewer, "Dr. Researcher")
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

  figshare <- log[log$source_family == "ICES Figshare" & grepl("ices_library_page_", log$raw_response_path), ]
  expect_true(tail(figshare$records_returned, 1) < 1000L)
  expect_equal(anyDuplicated(figshare$query_hash_sha256), 0L)
})

test_that("candidate registry has every essential field and points to raw evidence", {
  registry <- read.csv(at_root("metadata", "candidate_registry.csv"), stringsAsFactors = FALSE, check.names = FALSE)
  required <- c("search_run_id", "source", "endpoint", "api_version", "query_hash_sha256", "execution_time_utc",
    "raw_response_path", "raw_response_checksum_sha256", "provider_dataset_id", "catalogue_id", "title",
    "doi_or_stable_url", "version", "geographic_metadata", "temporal_metadata", "measurement_types", "taxonomic_content",
    "method_metadata", "access_status", "license", "screening_status", "exclusion_reason", "reviewer", "decision_date",
    "duplicate_catalogue_ids", "canonical_provider_dataset_id", "related_identifier")
  expect_identical(names(registry), required)
  expect_equal(nrow(registry), 26557L)
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
  expect_equal(value[["records_identified"]], 28247L)
  expect_equal(value[["duplicate_catalogue_or_query_records"]], value[["records_identified"]] - nrow(registry))
  expect_equal(value[["unique_catalogue_records"]], nrow(registry))
  expect_equal(value[["unique_dataset_families"]], length(unique(registry$canonical_provider_dataset_id)))
  expect_equal(value[["screened"]], nrow(registry))
  expect_equal(value[["excluded"]], sum(registry$screening_status == "excluded"))
  expect_equal(value[["pending"]], sum(registry$screening_status == "pending"))
  expect_equal(value[["advanced_to_acquisition"]], sum(registry$screening_status == "advanced_to_acquisition"))
  expect_equal(value[["screened"]], value[["excluded"]] + value[["pending"]] + value[["advanced_to_acquisition"]])
})

test_that("all prespecified known items are recalled from archived evidence", {
  recall <- read.csv(at_root("metadata", "stage1_known_item_recall.csv"), stringsAsFactors = FALSE)
  expect_setequal(recall$benchmark_id, c("DS02", "DS04", "DS05", "DS06", "DS07", "DS08", "DS10", "DS16", "DS24"))
  expect_true(all(recall$found))
  expect_true(all(nzchar(recall$raw_response_path)))
  expect_true(all(grepl("^[0-9a-f]{64}$", recall$raw_response_checksum_sha256)))
  expect_match(recall$matched_provider_dataset_id[recall$benchmark_id == "DS16"], "Stonehaven", ignore.case = TRUE)
  expect_identical(recall$matched_provider_dataset_id[recall$benchmark_id == "DS24"], "22189111")
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
