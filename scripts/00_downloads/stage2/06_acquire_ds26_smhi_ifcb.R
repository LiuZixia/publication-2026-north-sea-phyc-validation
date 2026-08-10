# Acquire rank-2 DS26 recurrent IFCB observations and diagnose the separate image reference item.

source("R/00_core_setup.R")
source("R/03_stage2_contract.R")
required_namespace("jsonlite")
required_namespace("digest")

config_path <- "config/stage2_ds26_smhi_ifcb_acquisition.json"
cfg <- jsonlite::fromJSON(config_path, simplifyVector = FALSE)
contract <- read_stage2_contract(cfg$contract_path)
if (!identical(cfg$classification, "stage2_ranked_canonical_provider_acquisition") ||
    !identical(cfg$work_item_id, "REGISTER:DS26") || cfg$acquisition_rank != 2L ||
    cfg$figshare_article_id != 25883455L) {
  stop("DS26 acquisition configuration is invalid.", call. = FALSE)
}

verify_raw_data_target(required_gb = cfg$required_free_gb)
run_relative <- file.path("stage2", "ds26_smhi_ifcb", cfg$acquisition_run_id)
final_dir <- file.path("data", "raw", run_relative)
staging_dir <- paste0(final_dir, ".partial")

validate_complete_run <- function(directory) {
  required <- file.path(directory, c("figshare_article_25883455.json", "shark_planktonimaging_eml.xml",
                                    "shark_planktonimaging_dwca.zip", "manifest.csv",
                                    "figshare_file_inventory.csv", "run_summary.json", "run.log"))
  if (any(!file.exists(required))) stop("Existing finalized DS26 run is incomplete.", call. = FALSE)
  manifest <- utils::read.csv(file.path(directory, "manifest.csv"), stringsAsFactors = FALSE,
                              check.names = FALSE)
  validate_stage2_table(manifest, "acquisition_manifest", contract)
  if (nrow(manifest) != 3L || any(vapply(seq_len(nrow(manifest)), function(i) {
    path <- file.path("data", "raw", manifest$raw_relative_path[[i]])
    !file.exists(path) || !identical(calculate_checksum(path), manifest$checksum_sha256[[i]])
  }, logical(1)))) {
    stop("Existing finalized DS26 manifest does not reconcile with raw artifacts.", call. = FALSE)
  }
  summary <- jsonlite::fromJSON(file.path(directory, "run_summary.json"), simplifyVector = FALSE)
  if (!identical(summary$status, "complete") ||
      !identical(summary$configuration_checksum_sha256, calculate_checksum(config_path))) {
    stop("Existing finalized DS26 summary differs from the frozen configuration.", call. = FALSE)
  }
  manifest
}

write_tracked_pins <- function(directory, manifest) {
  summary <- jsonlite::fromJSON(file.path(directory, "run_summary.json"), simplifyVector = FALSE)
  pin <- data.frame(
    work_item_id = cfg$work_item_id,
    run_relative_path = run_relative,
    completed_utc = summary$completed_utc,
    configuration_path = config_path,
    configuration_checksum_sha256 = summary$configuration_checksum_sha256,
    manifest_checksum_sha256 = calculate_checksum(file.path(directory, "manifest.csv")),
    figshare_inventory_checksum_sha256 = calculate_checksum(file.path(directory, "figshare_file_inventory.csv")),
    run_summary_checksum_sha256 = calculate_checksum(file.path(directory, "run_summary.json")),
    artifact_count = nrow(manifest),
    total_size_bytes = sum(manifest$size_bytes),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  write_csv_atomic(manifest, "metadata/stage2/acquisition/ds26_smhi_ifcb_acquisition_manifest.csv")
  write_csv_atomic(pin, "metadata/stage2/acquisition/ds26_smhi_ifcb_active_run.csv")
  figshare_inventory <- utils::read.csv(file.path(directory, "figshare_file_inventory.csv"),
                                        stringsAsFactors = FALSE, check.names = FALSE)
  write_csv_atomic(figshare_inventory, "metadata/stage2/acquisition/ds26_smhi_ifcb_figshare_file_inventory.csv")
}

if (dir.exists(final_dir)) {
  manifest <- validate_complete_run(final_dir)
  write_tracked_pins(final_dir, manifest)
  message("Verified existing DS26 SMHI IFCB run; no download required.")
  quit(save = "no", status = 0L)
}
dir.create(staging_dir, recursive = TRUE, showWarnings = FALSE)

requests <- list(
  list(filename = "figshare_article_25883455.json", url = cfg$figshare_article_api_url,
       role = "comparator", content = "application/json", minimum = 100L),
  list(filename = "shark_planktonimaging_eml.xml", url = cfg$ipt_eml_url,
       role = "canonical_provider", content = "application/xml", minimum = 1000L),
  list(filename = "shark_planktonimaging_dwca.zip", url = cfg$ipt_archive_url,
       role = "canonical_provider", content = "application/zip", minimum = 10000L)
)
download_results <- lapply(requests, function(request) {
  destination <- file.path(staging_dir, request$filename)
  result <- if (file.exists(destination)) {
    size <- file.info(destination)$size
    if (!is.finite(size) || size < request$minimum) {
      stop(sprintf("Existing DS26 partial artifact is too small: %s", destination), call. = FALSE)
    }
    list(checksum = calculate_checksum(destination), status = 200L, size = unname(size),
         content_type = request$content, url = request$url)
  } else {
    download_with_retry(request$url, destination, max_tries = 4L,
                        minimum_bytes = request$minimum, timeout_seconds = 300L)
  }
  c(request, result)
})

article_path <- file.path(staging_dir, "figshare_article_25883455.json")
article <- jsonlite::fromJSON(article_path, simplifyVector = FALSE)
if (article$id != cfg$figshare_article_id ||
    !grepl(cfg$expected_title_pattern, article$title, ignore.case = TRUE) ||
    is.null(article$files) || !length(article$files)) {
  stop("Official Figshare response does not identify the expected DS26 reference library.", call. = FALSE)
}
figshare_files <- do.call(rbind, lapply(article$files, function(file) data.frame(
  article_id = as.integer(article$id),
  file_id = as.character(file$id),
  filename = as.character(file$name),
  size_bytes = as.numeric(file$size),
  download_url = as.character(file$download_url),
  supplied_md5 = as.character(file$supplied_md5 %||% ""),
  computed_md5 = as.character(file$computed_md5 %||% ""),
  acquisition_state = "metadata_only_pending_role_and_size_review",
  stringsAsFactors = FALSE,
  check.names = FALSE
)))
if (any(!nzchar(figshare_files$filename)) || anyDuplicated(figshare_files$file_id) ||
    any(!is.finite(figshare_files$size_bytes) | figshare_files$size_bytes < 0)) {
  stop("Figshare file inventory contains invalid file identifiers or sizes.", call. = FALSE)
}
write_csv_atomic(figshare_files, file.path(staging_dir, "figshare_file_inventory.csv"))

eml_text <- paste(readLines(file.path(staging_dir, "shark_planktonimaging_eml.xml"),
                            warn = FALSE, encoding = "UTF-8"), collapse = "\n")
if (!grepl("Imaging FlowCytobots", eml_text, fixed = TRUE) ||
    !grepl("CC0", eml_text, fixed = TRUE) ||
    !grepl("2016-08-10", eml_text, fixed = TRUE)) {
  stop("SMHI IFCB EML lacks the expected identity, licence, or temporal evidence.", call. = FALSE)
}
zip_path <- file.path(staging_dir, "shark_planktonimaging_dwca.zip")
zip_test <- system2("unzip", c("-t", shQuote(zip_path)), stdout = TRUE, stderr = TRUE)
zip_status <- attr(zip_test, "status") %||% 0L
zip_members <- utils::unzip(zip_path, list = TRUE)
if (zip_status != 0L || !any(grepl("No errors detected", zip_test, fixed = TRUE)) ||
    !all(c("meta.xml", "eml.xml") %in% zip_members$Name) ||
    !any(grepl("event", zip_members$Name, ignore.case = TRUE)) ||
    !any(grepl("occurrence", zip_members$Name, ignore.case = TRUE))) {
  stop("SMHI IFCB Darwin Core archive failed integrity or member checks.", call. = FALSE)
}

figshare_license <- article$license$name %||% "unverified"
figshare_license_url <- article$license$url %||% ""
manifest_rows <- lapply(seq_along(requests), function(i) {
  request <- requests[[i]]
  result <- download_results[[i]]
  is_figshare <- request$filename == "figshare_article_25883455.json"
  data.frame(
    ds_id = cfg$ds_id,
    acquisition_rank = as.integer(cfg$acquisition_rank),
    provider = if (is_figshare) "SciLifeLab Data Centre / Figshare" else cfg$provider,
    provider_dataset_id = if (is_figshare) paste0("FIGSHARE:", cfg$figshare_article_id) else
      paste0("IPT:", cfg$ipt_resource_key),
    canonical_provider_dataset_id = if (is_figshare) paste0("FIGSHARE:", cfg$figshare_article_id) else
      paste0("SMHI:", cfg$ipt_resource_key),
    provider_version = if (is_figshare) as.character(article$modified_date) else cfg$ipt_provider_version,
    source_role = request$role,
    request_method = "GET",
    request_url = request$url,
    request_parameters_sha256 = digest::digest(request$url, algo = "sha256", serialize = FALSE),
    retrieved_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    raw_relative_path = file.path(run_relative, request$filename),
    filename = request$filename,
    size_bytes = as.numeric(result$size),
    checksum_sha256 = result$checksum,
    content_type = result$content_type %||% request$content,
    file_validation_state = "verified",
    license_state = if (is_figshare && !grepl("creativecommons|CC", figshare_license,
                                             ignore.case = TRUE)) "unverified" else "open",
    license_evidence = if (is_figshare) paste(figshare_license, figshare_license_url) else
      "Publisher-managed SMHI EML states CC0 1.0.",
    redistribution_state = if (is_figshare && !nzchar(figshare_license_url)) "unknown" else "allowed",
    citation = if (is_figshare) as.character(article$citation) else
      "Swedish Meteorological and Hydrological Institute. SHARK - Phyto- and Microzooplankton Data Collected by Imaging FlowCytobots (IFCB) in Swedish and Adjacent Waters.",
    doi_or_stable_url = if (is_figshare) as.character(article$url_public_html) else
      paste0("https://www.gbif.se/ipt/resource?r=", cfg$ipt_resource_key),
    manifest_status = "verified",
    status_detail = if (is_figshare)
      "Official article metadata archived; listed image-library files were not downloaded pending role and size review." else
      "Publisher-managed SMHI IPT artifact archived; EML identity/licence evidence and Darwin Core ZIP integrity verified.",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
})
manifest <- do.call(rbind, manifest_rows)
validate_stage2_table(manifest, "acquisition_manifest", contract)
write_csv_atomic(manifest, file.path(staging_dir, "manifest.csv"))
summary <- list(
  schema_version = cfg$schema_version,
  completed_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  status = "complete",
  work_item_id = cfg$work_item_id,
  artifact_count = nrow(manifest),
  total_size_bytes = sum(manifest$size_bytes),
  figshare_listed_file_count = nrow(figshare_files),
  figshare_listed_total_size_bytes = sum(figshare_files$size_bytes),
  configuration_checksum_sha256 = calculate_checksum(config_path),
  contract_checksum_sha256 = calculate_checksum(cfg$contract_path),
  software_version = R.version.string
)
jsonlite::write_json(summary, file.path(staging_dir, "run_summary.json"), pretty = TRUE, auto_unbox = TRUE)
writeLines(c(
  sprintf("completed_utc: %s", summary$completed_utc),
  sprintf("artifact_count: %d", summary$artifact_count),
  sprintf("total_size_bytes: %.0f", summary$total_size_bytes),
  sprintf("figshare_listed_file_count: %d", summary$figshare_listed_file_count),
  sprintf("figshare_listed_total_size_bytes: %.0f", summary$figshare_listed_total_size_bytes),
  sprintf("R: %s", R.version.string)
), file.path(staging_dir, "run.log"), useBytes = TRUE)
if (!file.rename(staging_dir, final_dir)) stop("Unable to atomically finalize DS26 acquisition.", call. = FALSE)
manifest <- validate_complete_run(final_dir)
write_tracked_pins(final_dir, manifest)
message(sprintf("DS26 acquisition complete: %d artifacts; Figshare lists %d files (%.2f GB) not downloaded.",
                nrow(manifest), nrow(figshare_files), sum(figshare_files$size_bytes) / 1024^3))
