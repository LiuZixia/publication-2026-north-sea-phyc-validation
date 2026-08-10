# Traceability helpers for Stage 1 through Stage 3 file inventories.

normalize_repo_path <- function(path) {
  path <- gsub("\\\\", "/", path)
  path <- sub("^\\./", "", path)
  path <- sub("^/mnt/hdd/publication-2026-north-sea-phyc-validation/", "data/raw/", path)
  path
}

inventory_stage <- function(path) {
  p <- normalize_repo_path(path)
  b <- basename(p)

  if (grepl("^data/raw/search_runs/SEARCH-", p) ||
      grepl("^metadata/stage1/", p) ||
      grepl("^config/(stage1_|ds_register_crosswalk|screening_rules|scientific_review|access_and_licence_policy)", p) ||
      grepl("^scripts/01_stage1/", p) || grepl("^scripts/00_downloads/stage1/", p) ||
      grepl("^R/(01_|02_stage1)", p) || grepl("stage1", b, ignore.case = TRUE)) {
    return("stage1")
  }

  if (grepl("^data/raw/stage2/", p) || grepl("^metadata/stage2/", p) ||
      grepl("^config/stage2_", p) || grepl("^scripts/02_stage2/", p) ||
      grepl("^scripts/00_downloads/stage2/", p) ||
      identical(p, "scripts/02_stage2/control/98_legacy_raw_inventory.R") ||
      identical(p, "R/03_stage2_contract.R") || grepl("stage2", b, ignore.case = TRUE)) {
    return("stage2")
  }

  if (grepl("^metadata/stage3/", p) || grepl("^scripts/03_stage3/", p) ||
      grepl("^data/interim/stage3", p) || grepl("^config/stage3_", p) ||
      identical(p, "R/05_stage3_contract.R") || identical(p, "tests/test_stage3_coverage.R") ||
      grepl("^outputs/(figures/stage3_|logs/stage3_)", p)) {
    return("stage3")
  }

  if (grepl("^metadata/stage4/", p) || grepl("^scripts/04_stage4/", p) ||
      grepl("^config/stage4_", p) || identical(p, "R/06_stage4_contract.R") ||
      identical(p, "tests/test_stage4_feasibility.R") || identical(p, "docs/stages/STAGE4.md") ||
      grepl("^outputs/(reports/stage4_|logs/stage4_)", p)) {
    return("stage4")
  }

  NA_character_
}

inventory_category <- function(path) {
  p <- normalize_repo_path(path)
  if (grepl("^data/raw/", p)) return("raw_evidence")
  if (grepl("^data/(interim|processed)/", p)) return("generated_data")
  if (grepl("^scripts/", p)) return("script")
  if (grepl("^R/", p)) return("reusable_code")
  if (grepl("^config/", p)) return("configuration")
  if (grepl("^tests/", p)) return("test")
  if (grepl("^outputs/logs/", p)) return("validation_log")
  if (grepl("^outputs/", p)) return("generated_report")
  if (grepl("^metadata/", p)) return("generated_metadata")
  if (grepl("^docs/", p) || grepl("(README|PROGRESS|PENDING|AGENTS)\\.md$", p)) return("description")
  "other"
}

is_source_category <- function(category) {
  category %in% c("script", "reusable_code", "configuration", "test", "description", "other")
}

script_files_for_inventory <- function() {
  sort(c(
    list.files("scripts", pattern = "\\.R$", recursive = TRUE, full.names = TRUE),
    list.files("R", pattern = "\\.R$", recursive = TRUE, full.names = TRUE)
  ))
}

script_references <- function(path, scripts = script_files_for_inventory()) {
  target <- normalize_repo_path(path)
  target_base <- basename(target)
  keep <- vapply(scripts, function(script) {
    lines <- readLines(script, warn = FALSE, encoding = "UTF-8")
    any(grepl(target, lines, fixed = TRUE)) || any(grepl(target_base, lines, fixed = TRUE))
  }, logical(1))
  paste(normalize_repo_path(scripts[keep]), collapse = ";")
}

producer_for_inventory <- function(path, category, scripts = script_files_for_inventory()) {
  p <- normalize_repo_path(path)
  b <- basename(p)

  if (is_source_category(category)) return("not_applicable_source_or_input")
  if (identical(p, "metadata/stage1/input/manual_discovery_log.csv")) return("historical_curated_input")
  if (identical(p, "metadata/stage1/qualification/provider_access_requests.csv")) return("historical_curated_input")
  if (grepl("^outputs/logs/stage1_validation_", p)) return("scripts/01_stage1/99_validate_stage1.R")
  if (grepl("^outputs/logs/stage2_contract_validation_", p)) return("scripts/02_stage2/control/99_validate_stage2.R")
  if (grepl("^outputs/logs/stage3_validation_", p)) return("scripts/03_stage3/00_run_stage3.R")
  if (grepl("^outputs/logs/stage4_validation_", p)) return("scripts/04_stage4/00_run_stage4.R")
  if (grepl("^data/interim/stage3_support/ds[0-9]{2}_sample_support[.]csv$", p)) {
    return("scripts/03_stage3/01_build_coverage.R")
  }
  if (p %in% c("metadata/stage1/inventory/file_inventory.csv",
               "metadata/stage2/inventory/file_inventory.csv",
               "metadata/stage3/inventory/file_inventory.csv",
               "metadata/stage4/inventory/file_inventory.csv")) {
    return("scripts/00_traceability/01_build_stage_file_inventory.R")
  }

  if (grepl("^data/raw/search_runs/SEARCH-", p)) {
    run <- sub("^data/raw/search_runs/(SEARCH-[A-Z0-9]+)-.*$", "\\1", p)
    key <- sub("^SEARCH-", "", run)
    map <- c(
      PLET = "scripts/00_downloads/stage1/01_search_plet.R",
      ICESDOME = "scripts/00_downloads/stage1/01_search_ices_dome.R",
      EMODNET = "scripts/00_downloads/stage1/01_search_emodnet_erddap.R",
      OBIS = "scripts/00_downloads/stage1/01_search_obis.R",
      SMHISHARK = "scripts/00_downloads/stage1/01_search_smhi_shark.R",
      PANGAEA = "scripts/00_downloads/stage1/01_search_pangaea.R",
      GBIF = "scripts/00_downloads/stage1/01_search_gbif.R",
      SCOTMARINE = "scripts/00_downloads/stage1/01_search_scot_marine.R",
      CEFASDASSH = "scripts/00_downloads/stage1/01_search_cefas_dassh.R",
      FIGSHARE = "scripts/00_downloads/stage1/01_search_ices_figshare.R",
      EMODNETBIOWFS = "scripts/00_downloads/stage1/02_search_emodnet_biology_wfs.R"
    )
    if (key %in% names(map)) return(unname(map[[key]]))
  }

  if (grepl("^data/raw/stage2/", p)) {
    folder <- strsplit(sub("^data/raw/stage2/", "", p), "/", fixed = TRUE)[[1]][1]
    map <- c(
      emodnet_wfs_geometry = "scripts/00_downloads/stage2/01_acquire_emodnet_wfs_geometry.R",
      emodnet_wfs_survivor_metadata = "scripts/00_downloads/stage2/02_acquire_emodnet_wfs_survivor_metadata.R",
      ds06_smhi_shark = "scripts/00_downloads/stage2/05_acquire_ds06_smhi_shark.R",
      ds26_smhi_ifcb = "scripts/00_downloads/stage2/06_acquire_ds26_smhi_ifcb.R",
      ds26_ifcb_reference = "scripts/00_downloads/stage2/07_acquire_ds26_ifcb_reference_library.R",
      ds02_rws = "scripts/00_downloads/stage2/10_intake_ds02_rws_manual_export.R",
      ds02_rws_access = "scripts/00_downloads/stage2/09_diagnose_ds02_rws_v3_access.R",
      ds04_plet_bsh = "scripts/00_downloads/stage2/11_acquire_ds04_plet_bsh.R",
      ds05_plet_novana = "scripts/00_downloads/stage2/12_acquire_ds05_plet_novana.R",
      ds07_plet_cefas = "scripts/00_downloads/stage2/13_acquire_ds07_plet_cefas.R",
      ds16_plet_stonehaven = "scripts/00_downloads/stage2/14_acquire_ds16_plet_stonehaven.R",
      ds10_plet_vliz = "scripts/00_downloads/stage2/15_register_ds10_plet_vliz_legacy.R",
      ds11_plet_chlorophyll = "scripts/00_downloads/stage2/16_acquire_ds11_plet_chlorophyll.R",
      ds03_eurobis = "scripts/00_downloads/stage2/17_acquire_ds03_eurobis.R",
      ds24_figshare = "scripts/00_downloads/stage2/18_acquire_ds24_figshare.R",
      ds09_pangaea = "scripts/00_downloads/stage2/19_acquire_ds09_pangaea_sylt.R",
      ds27_pangaea_ferrybox = "scripts/00_downloads/stage2/20_acquire_ds27_pangaea_ferrybox.R",
      ds22_figshare = "scripts/00_downloads/stage2/22_acquire_ds22_figshare.R",
      ds15_emodnet_presence = "scripts/00_downloads/stage2/23_acquire_ds15_emodnet_presence.R",
      ds10_vliz_imis = "scripts/00_downloads/stage2/24_acquire_ds10_vliz_imis.R",
      ds12_dassh_ipt = "scripts/00_downloads/stage2/25_acquire_ds12_dassh_ipt.R",
      ds08_pangaea_abundance = "scripts/00_downloads/stage2/26_acquire_ds08_pangaea_abundance.R"
    )
    if (folder %in% names(map)) return(unname(map[[folder]]))
  }

  exact <- c(
    "active_runs.csv" = "scripts/00_downloads/stage1/00_run_searches.R",
    "append_runs.csv" = "scripts/00_downloads/stage1/02_search_emodnet_biology_wfs.R",
    "candidate_registry.csv" = "scripts/01_stage1/01_compile_candidate_registry.R",
    "query_log.csv" = "scripts/01_stage1/01_compile_candidate_registry.R",
    "search_flow.csv" = "scripts/01_stage1/01_compile_candidate_registry.R",
    "known_item_recall.csv" = "scripts/01_stage1/01_compile_candidate_registry.R",
    "emodnet_wfs_overlap.csv" = "scripts/01_stage1/01_compile_candidate_registry.R",
    "emodnet_wfs_overlap_summary.csv" = "scripts/01_stage1/01_compile_candidate_registry.R",
    "ds_crosswalk.csv" = "scripts/01_stage1/02_build_ds_crosswalk.R",
    "acquisition_shortlist.csv" = "scripts/01_stage1/02_build_ds_crosswalk.R",
    "unavailable_candidates.csv" = "scripts/01_stage1/02_build_ds_crosswalk.R",
    "acquisition_work_order.csv" = "scripts/02_stage2/control/00_initialize_contract.R",
    "wfs_geometry_queue.csv" = "scripts/02_stage2/control/00_initialize_contract.R",
    "contract_freeze.json" = "scripts/02_stage2/control/00_initialize_contract.R",
    "acquisition_status.csv" = "scripts/02_stage2/control/01_refresh_acquisition_status.R",
    "access_dispositions.csv" = "scripts/02_stage2/control/02_build_access_dispositions.R",
    "emodnet_wfs_active_run.csv" = "scripts/02_stage2/wfs/00_register_geometry_run.R",
    "emodnet_wfs_metadata_active_run.csv" = "scripts/02_stage2/wfs/02_register_metadata_run.R",
    "emodnet_wfs_geometry_evidence.csv" = "scripts/02_stage2/wfs/01_screen_geometry.R",
    "emodnet_wfs_screening.csv" = "scripts/02_stage2/wfs/03_resolve_survivors.R",
    "emodnet_wfs_survivor_resolution.csv" = "scripts/02_stage2/wfs/03_resolve_survivors.R",
    "stage3_input_manifest.csv" = "scripts/03_stage3/00_build_input_manifest.R",
    "input_manifest_checksums.csv" = "scripts/03_stage3/00_build_input_manifest.R",
    "temporal_cadence_by_year.csv" = "scripts/03_stage3/01_build_coverage.R",
    "temporal_cadence_by_station_year.csv" = "scripts/03_stage3/01_build_coverage.R",
    "station_temporal_availability.csv" = "scripts/03_stage3/01_build_coverage.R",
    "time_of_day_coverage.csv" = "scripts/03_stage3/01_build_coverage.R",
    "seasonal_effort.csv" = "scripts/03_stage3/01_build_coverage.R",
    "spatial_support.csv" = "scripts/03_stage3/01_build_coverage.R",
    "vertical_support.csv" = "scripts/03_stage3/01_build_coverage.R",
    "stage3_sample_support.csv" = "scripts/03_stage3/01_build_coverage.R",
    "method_biological_coverage.csv" = "scripts/03_stage3/02_build_method_biology.R",
    "method_epoch_register.csv" = "scripts/03_stage3/02_build_method_biology.R",
    "network_year_variable_matrix.csv" = "scripts/03_stage3/02_build_method_biology.R",
    "dataset_region_period_role_gate.csv" = "scripts/03_stage3/03_apply_role_gate.R",
    "cmems_metadata_overlap.csv" = "scripts/03_stage3/03_apply_role_gate.R",
    "coverage_gaps.csv" = "scripts/03_stage3/03_apply_role_gate.R",
    "stage3_gate_status.csv" = "scripts/03_stage3/99_validate_stage3.R",
    "stage3_output_registry.csv" = "scripts/03_stage3/98_build_output_registry.R",
    "stage3_temporal_coverage.png" = "scripts/03_stage3/04_make_coverage_figures.R",
    "stage3_spatial_support.png" = "scripts/03_stage3/04_make_coverage_figures.R",
    "provisional_dataset_manifest.csv" = "scripts/04_stage4/00_build_feasibility.R",
    "subregion_window_feasibility.csv" = "scripts/04_stage4/00_build_feasibility.R",
    "window_candidate_register.csv" = "scripts/04_stage4/00_build_feasibility.R",
    "lifeform_feasibility.csv" = "scripts/04_stage4/00_build_feasibility.R",
    "scope_limitations.csv" = "scripts/04_stage4/00_build_feasibility.R",
    "question_feasibility.csv" = "scripts/04_stage4/00_build_feasibility.R",
    "stage4_gate_status.csv" = "scripts/04_stage4/99_validate_stage4.R",
    "stage4_output_registry.csv" = "scripts/04_stage4/98_build_output_registry.R",
    "stage4_feasibility.md" = "scripts/04_stage4/01_build_report.R",
    "stage_status.md" = "scripts/99_stage_status.R",
    "downloaded_files_inventory.md" = "scripts/02_stage2/control/98_legacy_raw_inventory.R"
  )
  if (b %in% names(exact)) return(unname(exact[[b]]))

  refs <- strsplit(script_references(p, scripts), ";", fixed = TRUE)[[1]]
  refs <- refs[nzchar(refs)]
  if (length(refs) == 1L) return(refs)

  # Generated dataset artifacts use stable verb prefixes that identify their stage script.
  candidates <- refs
  if (grepl("(_active_run|_acquisition_manifest|_file_inventory|_intake_summary|_access_diagnosis)\\.", b)) {
    download_refs <- refs[grepl("scripts/00_downloads/", refs)]
    if (length(download_refs)) candidates <- download_refs
  } else if (grepl("_location_summary\\.", b)) {
    screen_refs <- refs[grepl("/02_screen_", refs)]
    if (length(screen_refs)) candidates <- screen_refs
  } else if (grepl("_duplicate_resolution|_sample_overlap", b)) {
    resolve_refs <- refs[grepl("/02_resolve_", refs)]
    if (length(resolve_refs)) candidates <- resolve_refs
  } else if (grepl("_screening_summary\\.", b)) {
    summary_refs <- refs[grepl("/02_(summarize|inventory)_", refs)]
    if (length(summary_refs)) candidates <- summary_refs
  } else if (grepl("_(variable_inventory|package_summary|table_summary|event_summary|event_linkage_audit|output_registry)\\.", b)) {
    inventory_refs <- refs[grepl("/02_(inventory|screen)_", refs)]
    if (length(inventory_refs)) candidates <- inventory_refs
  }
  if (length(candidates)) return(paste(unique(candidates), collapse = ";"))

  NA_character_
}

read_manifest_checksum_map <- function(raw_root = "data/raw") {
  manifests <- list.files(raw_root, pattern = "^manifest\\.csv$", recursive = TRUE,
                          full.names = TRUE, include.dirs = FALSE)
  rows <- list()
  idx <- 0L
  for (manifest_path in manifests) {
    tab <- tryCatch(utils::read.csv(manifest_path, stringsAsFactors = FALSE, check.names = FALSE),
                    error = function(e) NULL)
    if (is.null(tab) || !nrow(tab)) next
    checksum_col <- intersect(c("checksum_sha256", "sha256"), names(tab))
    if (!length(checksum_col)) next
    path_col <- intersect(c("raw_response_path", "raw_relative_path", "file_name", "filename"), names(tab))
    if (!length(path_col)) next
    for (i in seq_len(nrow(tab))) {
      raw_value <- as.character(tab[[path_col[[1]]]][[i]])
      if (is.na(raw_value) || !nzchar(raw_value)) next
      if (path_col[[1]] %in% c("file_name", "filename") && !grepl("/", raw_value, fixed = TRUE)) {
        file_path <- file.path(dirname(manifest_path), raw_value)
      } else {
        file_path <- file.path(raw_root, sub("^(data/raw/)?", "", raw_value))
      }
      idx <- idx + 1L
      rows[[idx]] <- data.frame(
        path = normalize_repo_path(file_path),
        recorded_sha256 = as.character(tab[[checksum_col[[1]]]][[i]]),
        checksum_manifest = normalize_repo_path(manifest_path),
        stringsAsFactors = FALSE
      )
    }
  }
  # Large generated datasets are checksum-pinned by their stage-owned output registries. Reading
  # those checksums avoids rehashing multi-gigabyte interim tables on every inventory refresh while
  # still keeping every derived file visible and traceable.
  registries <- list.files("metadata", pattern = "registry\\.csv$", recursive = TRUE,
                           full.names = TRUE, include.dirs = FALSE)
  for (registry_path in registries) {
    tab <- tryCatch(utils::read.csv(registry_path, stringsAsFactors = FALSE, check.names = FALSE),
                    error = function(e) NULL)
    if (is.null(tab) || !nrow(tab) ||
        !all(c("path", "checksum_sha256") %in% names(tab))) next
    for (i in seq_len(nrow(tab))) {
      value <- normalize_repo_path(as.character(tab$path[[i]]))
      checksum <- as.character(tab$checksum_sha256[[i]])
      if (!nzchar(value) || !grepl("^[0-9a-f]{64}$", checksum)) next
      idx <- idx + 1L
      rows[[idx]] <- data.frame(
        path = value,
        recorded_sha256 = checksum,
        checksum_manifest = normalize_repo_path(registry_path),
        stringsAsFactors = FALSE
      )
    }
  }
  if (!length(rows)) return(data.frame(path = character(), recorded_sha256 = character(),
                                       checksum_manifest = character()))
  out <- do.call(rbind, rows)
  out <- out[!duplicated(out$path), , drop = FALSE]
  rownames(out) <- NULL
  out
}

git_tracked_paths <- function() {
  out <- system2("git", "ls-files", stdout = TRUE, stderr = TRUE)
  status <- attr(out, "status")
  if (!is.null(status) && status != 0L) stop("Unable to list Git-tracked files.", call. = FALSE)
  normalize_repo_path(out)
}

build_stage_inventory <- function(stage, raw_checksum_map, scripts = script_files_for_inventory()) {
  stopifnot(stage %in% c("stage1", "stage2", "stage3", "stage4"))
  repo_files <- c(
    list.files("metadata", recursive = TRUE, full.names = TRUE, all.files = FALSE),
    list.files("config", recursive = TRUE, full.names = TRUE, all.files = FALSE),
    list.files("scripts", recursive = TRUE, full.names = TRUE, all.files = FALSE),
    list.files("R", recursive = TRUE, full.names = TRUE, all.files = FALSE),
    list.files("tests", recursive = TRUE, full.names = TRUE, all.files = FALSE),
    list.files("docs", recursive = TRUE, full.names = TRUE, all.files = FALSE),
    list.files("outputs", recursive = TRUE, full.names = TRUE, all.files = FALSE),
    list.files("data/interim", recursive = TRUE, full.names = TRUE, all.files = FALSE),
    list.files("data/processed", recursive = TRUE, full.names = TRUE, all.files = FALSE),
    list.files(if (stage == "stage1") "data/raw/search_runs" else "data/raw/stage2",
               recursive = TRUE, full.names = TRUE, all.files = FALSE)
  )
  repo_files <- sort(unique(normalize_repo_path(repo_files[file.exists(repo_files) & !dir.exists(repo_files)])))
  assigned <- vapply(repo_files, inventory_stage, character(1))
  paths <- repo_files[assigned == stage & !is.na(assigned)]
  info <- file.info(paths)
  categories <- vapply(paths, inventory_category, character(1))
  producers <- vapply(seq_along(paths), function(i) producer_for_inventory(paths[[i]], categories[[i]], scripts),
                      character(1))
  refs <- rep("", length(paths))
  needs_refs <- categories %in% c("generated_metadata", "generated_report")
  refs[needs_refs] <- vapply(paths[needs_refs], script_references, character(1), scripts = scripts)

  sha <- rep(NA_character_, length(paths))
  checksum_source <- rep("not_registered", length(paths))
  map_idx <- match(paths, raw_checksum_map$path)
  mapped <- !is.na(map_idx) & nzchar(raw_checksum_map$recorded_sha256[map_idx])
  sha[mapped] <- raw_checksum_map$recorded_sha256[map_idx[mapped]]
  checksum_source[mapped] <- raw_checksum_map$checksum_manifest[map_idx[mapped]]

  safe_to_hash <- is.na(sha) & categories != "raw_evidence"
  self_inventory <- paths %in% c("metadata/stage1/inventory/file_inventory.csv",
                                 "metadata/stage2/inventory/file_inventory.csv",
                                 "metadata/stage3/inventory/file_inventory.csv",
                                 "metadata/stage4/inventory/file_inventory.csv")
  safe_to_hash[self_inventory] <- FALSE
  sha[safe_to_hash] <- vapply(paths[safe_to_hash], calculate_checksum, character(1))
  checksum_source[safe_to_hash] <- "calculated_by_inventory_script"

  raw_small <- is.na(sha) & categories == "raw_evidence" & !is.na(info$size) & info$size <= 25 * 1024^2
  sha[raw_small] <- vapply(paths[raw_small], calculate_checksum, character(1))
  checksum_source[raw_small] <- "calculated_by_inventory_script_small_unregistered_raw"

  # An inventory cannot contain its own final byte size or checksum deterministically.
  info$size[self_inventory] <- NA_real_
  checksum_source[self_inventory] <- "self_referential_inventory_not_hashed"

  tracked <- git_tracked_paths()
  data.frame(
    stage = stage,
    category = categories,
    path = paths,
    producer_script = producers,
    script_reference_candidates = refs,
    exists = TRUE,
    size_bytes = unname(info$size),
    sha256 = sha,
    checksum_source = checksum_source,
    git_tracked = paths %in% tracked,
    immutable = categories == "raw_evidence",
    traceability_state = ifelse(
      is_source_category(categories) | producers %in% c("historical_curated_input", "not_applicable_source_or_input"),
      "source_or_input",
      ifelse(
        self_inventory | (!is.na(producers) & nzchar(producers) & !is.na(sha) & nzchar(sha)),
        "traceable", "unresolved"
      )
    ),
    stringsAsFactors = FALSE
  )
}
