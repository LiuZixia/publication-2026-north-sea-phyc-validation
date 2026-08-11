#!/usr/bin/env Rscript
# Cache batched WoRMS records for reported AphiaIDs and unresolved DS02 names.

source("R/00_core_setup.R")
source("R/03_stage2_contract.R")
required_namespace("jsonlite")

verify_raw_data_target(required_gb = 0.1)
config_path <- "config/stage5_worms_acquisition.json"
config <- jsonlite::fromJSON(config_path, simplifyVector = TRUE)
pin_path <- "metadata/stage5/taxonomy/worms_active_run.csv"

if (file.exists(pin_path)) {
  pin <- utils::read.csv(pin_path, stringsAsFactors = FALSE, check.names = FALSE)
  manifest_path <- file.path("data", "raw", pin$run_relative_path[[1]], "manifest.csv")
  if (nrow(pin) != 1L || !file.exists(manifest_path) ||
      !"input_profile_checksum_sha256" %in% names(pin) ||
      !file.exists(config$input_profile) ||
      !identical(calculate_checksum(config$input_profile), pin$input_profile_checksum_sha256[[1]]) ||
      !identical(calculate_checksum(manifest_path), pin$manifest_checksum_sha256[[1]]))
    stop("Existing WoRMS cache pin, source-profile checksum, or manifest is invalid.", call. = FALSE)
  manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE, check.names = FALSE)
  files <- file.path(dirname(manifest_path), manifest$file_name)
  if (any(!file.exists(files)) || any(file.size(files) != manifest$file_size_bytes) ||
      !identical(unname(vapply(files, calculate_checksum, character(1))), manifest$checksum_sha256))
    stop("Existing WoRMS cache files fail checksum validation.", call. = FALSE)
  message("Verified existing WoRMS taxonomy cache; no API requests required.")
  quit(save = "no", status = 0L)
}

profile_path <- config$input_profile
profile <- utils::read.csv(profile_path, stringsAsFactors = FALSE, check.names = FALSE)
aphia_ids <- sort(unique(suppressWarnings(as.integer(profile$reported_aphia_id))))
aphia_ids <- aphia_ids[!is.na(aphia_ids)]
reported_names <- sort(unique(trimws(profile$reported_taxon_name[profile$ds_id == config$name_source_dataset])))
reported_names <- reported_names[nzchar(reported_names)]
if (!length(aphia_ids) || !length(reported_names)) stop("WoRMS request terms are empty.", call. = FALSE)

batch_terms <- function(values, route, size) {
  batch <- ceiling(seq_along(values) / size)
  data.frame(route = route, batch = batch,
             position = ave(seq_along(values), batch, FUN = seq_along),
             input_term = as.character(values), stringsAsFactors = FALSE, check.names = FALSE)
}
terms <- rbind(batch_terms(aphia_ids, "reported_aphia_id", config$maximum_terms_per_request),
               batch_terms(reported_names, "ds02_taxamatch_name", config$maximum_terms_per_request))

stamp <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
run_name <- paste0("WORMS_TAXONOMY_", stamp)
run_relative_path <- file.path("stage5", "worms_taxonomy", run_name)
run_dir <- file.path("data", "raw", run_relative_path)
dir.create(run_dir, recursive = TRUE, showWarnings = FALSE)
terms_path <- file.path(run_dir, "request_terms.csv")
log_path <- file.path(run_dir, "acquisition.log")
write_csv_atomic(terms, terms_path)
writeLines(c(paste("run_name:", run_name), paste("configuration:", config_path),
             paste("reported_aphia_ids:", length(aphia_ids)),
             paste("ds02_reported_names:", length(reported_names))), log_path, useBytes = TRUE)

query_rows <- list()
response_paths <- character()
query_index <- 0L
for (route in unique(terms$route)) {
  route_terms <- terms[terms$route == route, , drop = FALSE]
  for (batch in sort(unique(route_terms$batch))) {
    values <- route_terms$input_term[route_terms$batch == batch]
    if (route == "reported_aphia_id") {
      parameters <- stats::setNames(values, rep("aphiaids[]", length(values)))
      endpoint <- config$id_endpoint
      prefix <- "aphia"
    } else {
      parameters <- c(stats::setNames(values, rep("scientificnames[]", length(values))),
                      marine_only = tolower(as.character(config$marine_only)))
      endpoint <- config$name_endpoint
      prefix <- "name"
    }
    url <- build_query_url(endpoint, parameters)
    response_path <- file.path(run_dir, sprintf("%s_batch_%03d.json", prefix, batch))
    response <- download_with_retry(url, response_path, max_tries = config$maximum_tries,
                                    minimum_bytes = 2L, timeout_seconds = config$timeout_seconds)
    parsed <- tryCatch(jsonlite::fromJSON(response_path, simplifyVector = FALSE),
                       error = function(error) stop(sprintf("Invalid WoRMS JSON: %s", response_path), call. = FALSE))
    if (!is.list(parsed)) stop(sprintf("WoRMS response is not an array: %s", response_path), call. = FALSE)
    query_index <- query_index + 1L
    query_rows[[query_index]] <- data.frame(
      route = route, batch = batch, request_count = length(values), response_count = length(parsed),
      endpoint = endpoint, request_url_sha256 = digest::digest(url, algo = "sha256", serialize = FALSE),
      raw_response_path = file.path(run_relative_path, basename(response_path)),
      response_checksum_sha256 = response$checksum, response_size_bytes = response$size,
      http_status = response$status, completed_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
      stringsAsFactors = FALSE, check.names = FALSE
    )
    response_paths <- c(response_paths, response_path)
    write(sprintf("completed route=%s batch=%d terms=%d", route, batch, length(values)),
          log_path, append = TRUE)
    Sys.sleep(config$request_delay_seconds)
  }
}

query_log <- do.call(rbind, query_rows)
query_log_path <- "metadata/stage5/taxonomy/worms_query_log.csv"
dir.create(dirname(query_log_path), recursive = TRUE, showWarnings = FALSE)
write_csv_atomic(query_log, query_log_path)
manifest_files <- c(terms_path, response_paths)
manifest <- data.frame(
  file_name = basename(manifest_files),
  checksum_sha256 = unname(vapply(manifest_files, calculate_checksum, character(1))),
  file_size_bytes = unname(file.size(manifest_files)),
  artifact_role = c("request_terms", rep("unmodified_api_response", length(response_paths))),
  stringsAsFactors = FALSE, check.names = FALSE
)
manifest_path <- file.path(run_dir, "manifest.csv")
write_csv_atomic(manifest, manifest_path)
write(c(paste("completed_utc:", format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")),
        paste("request_batches:", nrow(query_log)), "pagination_state: complete_not_applicable_batched_terms"),
      log_path, append = TRUE)
pin <- data.frame(
  run_name = run_name, run_relative_path = run_relative_path,
  manifest_checksum_sha256 = calculate_checksum(manifest_path),
  request_terms_checksum_sha256 = calculate_checksum(terms_path),
  input_profile_checksum_sha256 = calculate_checksum(profile_path), pinned_at_utc = stamp,
  stringsAsFactors = FALSE, check.names = FALSE
)
write_csv_atomic(pin, pin_path)
message(sprintf("WoRMS cache complete: %d AphiaIDs and %d DS02 names in %d batches.",
                length(aphia_ids), length(reported_names), nrow(query_log)))
