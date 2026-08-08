# Common immutable acquisition and manifest helpers for Stage 1 catalogue searches.

source("R/00_core_setup.R")

stage1_now <- function() format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
stage1_stamp <- function() format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")

read_stage1_config <- function(path = "config/stage1_search_config.json") {
  required_namespace("jsonlite")
  if (!file.exists(path)) stop("Missing frozen Stage 1 search configuration.", call. = FALSE)
  cfg <- jsonlite::fromJSON(path, simplifyVector = FALSE)
  if (!identical(cfg$schema_version, "1.0.0")) stop("Unsupported Stage 1 configuration schema.", call. = FALSE)
  if (!cfg$review$status %in% c("pending_independent_review", "approved")) {
    stop("Stage 1 review status must be explicit.", call. = FALSE)
  }
  cfg
}

new_search_run <- function(prefix, required_gb = 0.1) {
  verify_raw_data_target(required_gb)
  id <- paste0("SEARCH-", prefix, "-", stage1_stamp())
  path <- file.path("data", "raw", "search_runs", id)
  if (dir.exists(path)) stop(sprintf("Search run already exists: %s", path), call. = FALSE)
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  list(id = id, path = path, started_utc = stage1_now())
}

stage1_query_hash <- function(method, endpoint, request) {
  required_namespace("digest")
  digest::digest(paste(method, endpoint, request, sep = "\n"), algo = "sha256", serialize = FALSE)
}

perform_request <- function(method, url, dest_file, body_json = NA_character_, max_tries = 4L,
                            minimum_bytes = 2L, request_headers = list(),
                            acceptable_status = 200:299) {
  required_namespace("httr2")
  if (file.exists(dest_file)) stop(sprintf("Refusing to overwrite %s", dest_file), call. = FALSE)
  dir.create(dirname(dest_file), recursive = TRUE, showWarnings = FALSE)
  partial <- paste0(dest_file, ".partial")
  if (file.exists(partial)) unlink(partial)
  on.exit(if (file.exists(partial)) unlink(partial), add = TRUE)

  req <- httr2::request(url) |>
    httr2::req_user_agent("north-sea-phyc-validation/Stage1") |>
    httr2::req_retry(max_tries = max_tries, max_seconds = 90) |>
    httr2::req_error(is_error = function(resp) FALSE)
  if (length(request_headers)) req <- do.call(httr2::req_headers, c(list(req), request_headers))
  if (identical(method, "POST")) {
    if (is.na(body_json) || !nzchar(body_json)) stop("POST body is required.", call. = FALSE)
    req <- req |>
      httr2::req_method("POST") |>
      httr2::req_headers(`Content-Type` = "application/json") |>
      httr2::req_body_raw(charToRaw(body_json), type = "application/json")
  }
  resp <- httr2::req_perform(req, path = partial)
  status <- httr2::resp_status(resp)
  size <- unname(file.info(partial)$size)
  if (!status %in% acceptable_status) stop(sprintf("HTTP %d for %s", status, url), call. = FALSE)
  if (is.na(size) || size < minimum_bytes) stop(sprintf("Response too small for %s", url), call. = FALSE)
  if (!isTRUE(file.rename(partial, dest_file))) stop("Atomic response rename failed.", call. = FALSE)
  list(
    status = status,
    size = size,
    content_type = httr2::resp_header(resp, "content-type") %||% "",
    response_cursor = httr2::resp_header(resp, "x-cursor") %||% "",
    checksum = calculate_checksum(dest_file)
  )
}

`%||%` <- function(x, y) if (is.null(x) || !length(x) || is.na(x)) y else x

artifact_row <- function(run, source_family, provider, api_version, license, method,
                         endpoint, request_text, page_or_cursor, dest_file, result,
                         records_returned, total_reported = NA_integer_, pagination_complete = TRUE,
                         query_label = "") {
  data.frame(
    search_run_id = run$id,
    source_family = source_family,
    provider = provider,
    endpoint = endpoint,
    api_version = api_version,
    license = license,
    method = method,
    request_text = request_text,
    query_hash_sha256 = stage1_query_hash(method, endpoint, request_text),
    query_label = query_label,
    geographic_bounds = "POLYGON ((-5 48, 13.06914 48, 13.06914 62, -5 62, -5 48))",
    page_or_cursor = as.character(page_or_cursor),
    retrieved_utc = stage1_now(),
    http_status = as.integer(result$status),
    retry_max_tries = 4L,
    raw_response_path = gsub("^data/raw/", "", dest_file),
    checksum_sha256 = result$checksum,
    size_bytes = as.numeric(result$size),
    content_type = result$content_type,
    records_returned = as.integer(records_returned),
    total_reported = as.integer(total_reported),
    pagination_complete = as.logical(pagination_complete),
    stringsAsFactors = FALSE
  )
}

write_search_manifest <- function(run, rows, provider_total, unique_provider_records,
                                  pagination_complete, notes = "") {
  required_namespace("jsonlite")
  if (!is.data.frame(rows) || !nrow(rows)) stop("Cannot write an empty search manifest.", call. = FALSE)
  manifest_path <- file.path(run$path, "manifest.csv")
  utils::write.csv(rows, manifest_path, row.names = FALSE, na = "")
  summary <- list(
    schema_version = "1.0.0",
    search_run_id = run$id,
    source_family = unique(rows$source_family),
    started_utc = run$started_utc,
    completed_utc = stage1_now(),
    configuration_path = "config/stage1_search_config.json",
    configuration_checksum_sha256 = calculate_checksum("config/stage1_search_config.json"),
    artifact_count = nrow(rows),
    records_identified_within_queries = sum(rows$records_returned),
    provider_total = as.integer(provider_total),
    unique_provider_records = as.integer(unique_provider_records),
    pagination_complete = isTRUE(pagination_complete),
    status = if (isTRUE(pagination_complete)) "complete" else "failed_incomplete",
    notes = notes,
    r_version = R.version.string
  )
  jsonlite::write_json(summary, file.path(run$path, "run_summary.json"), pretty = TRUE, auto_unbox = TRUE)
  
  log_path <- file.path(run$path, "human_readable_log.txt")
  log_content <- c(
    sprintf("Search Run ID: %s", run$id),
    sprintf("Source Family: %s", paste(unique(rows$source_family), collapse = ", ")),
    sprintf("Started UTC: %s", run$started_utc),
    sprintf("Completed UTC: %s", summary$completed_utc),
    sprintf("Artifact Count: %d", summary$artifact_count),
    sprintf("Records Identified: %d", summary$records_identified_within_queries),
    sprintf("Unique Provider Records: %d", summary$unique_provider_records),
    sprintf("Status: %s", summary$status),
    sprintf("Notes: %s", notes),
    "",
    "## Queries executed",
    paste(rows$method, rows$endpoint, rows$query_label, sep = " - "),
    "",
    "## Environment Session Info",
    capture.output(utils::sessionInfo())
  )
  writeLines(log_content, log_path)

  message(sprintf("%s complete: %d artifacts; %d unique provider records.", run$id, nrow(rows), unique_provider_records))
  invisible(summary)
}

json_record_count <- function(x, field = NULL) {
  if (!is.null(field)) x <- x[[field]]
  if (is.null(x)) return(0L)
  if (is.data.frame(x)) return(nrow(x))
  length(x)
}

assert_json_file <- function(path) {
  required_namespace("jsonlite")
  tryCatch(jsonlite::fromJSON(path, simplifyVector = FALSE), error = function(e) {
    stop(sprintf("Invalid JSON response %s: %s", path, e$message), call. = FALSE)
  })
}
