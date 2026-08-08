# Append a direct EMODnet Biology Dataportal WFS inventory to the completed Stage 1 search.

source("R/01_search_helpers.R")
required_namespace("jsonlite")

config_path <- "config/stage1_emodnet_biology_wfs_append.json"
cfg <- jsonlite::fromJSON(config_path, simplifyVector = FALSE)
if (!identical(cfg$schema_version, "1.0.0") ||
    !identical(cfg$classification, "append_only_stage1_search_update")) {
  stop("Unsupported EMODnet Biology WFS append configuration.", call. = FALSE)
}
if (!identical(cfg$inventory_layer, "Dataportal:eurobis_datasets") ||
    !identical(cfg$occurrence_layer, "Dataportal:eurobis")) {
  stop("The frozen EMODnet Biology layer names have changed.", call. = FALSE)
}

run_emodnet_biology_wfs_search <- function() {
  run <- new_search_run("EMODNETBIOWFS", required_gb = 0.01)
  rows <- list()
  endpoint <- cfg$endpoint

  fixed_requests <- list(
    capabilities = list(
      params = c(service = cfg$service, version = cfg$version, request = "GetCapabilities"),
      extension = ".xml", label = "WFS capabilities"
    ),
    occurrence_schema = list(
      params = c(service = cfg$service, version = cfg$version, request = "DescribeFeatureType",
                 typeNames = cfg$occurrence_layer, outputFormat = "application/json"),
      extension = ".json", label = "Dataportal:eurobis occurrence schema"
    ),
    dataset_schema = list(
      params = c(service = cfg$service, version = cfg$version, request = "DescribeFeatureType",
                 typeNames = cfg$inventory_layer, outputFormat = "application/json"),
      extension = ".json", label = "Dataportal:eurobis_datasets inventory schema"
    )
  )

  for (name in names(fixed_requests)) {
    request <- fixed_requests[[name]]
    url <- build_query_url(endpoint, request$params)
    dest <- file.path(run$path, paste0(name, request$extension))
    ans <- perform_request("GET", url, dest)
    if (identical(request$extension, ".json")) assert_json_file(dest)
    rows[[length(rows) + 1L]] <- artifact_row(
      run, "EMODnet Biology WFS", "EMODnet Biology / EurOBIS", "OGC WFS 2.0.0",
      cfg$license, "GET", endpoint, url, name, dest, ans, 1L,
      query_label = request$label
    )
  }

  # The inventory layer is provider-defined dataset metadata. Exhausting it avoids relying on
  # keywords at the network boundary and keeps all screening decisions reproducible and local.
  page_size <- as.integer(cfg$page_size)
  start_index <- 0L
  page <- 1L
  provider_total <- NA_integer_
  all_ids <- character()
  repeat {
    params <- c(
      service = cfg$service, version = cfg$version, request = "GetFeature",
      typeNames = cfg$inventory_layer, outputFormat = "application/json",
      count = page_size, startIndex = start_index, sortBy = "id"
    )
    url <- build_query_url(endpoint, params)
    dest <- file.path(run$path, sprintf("dataset_catalogue_page_%04d.json", page))
    ans <- perform_request("GET", url, dest, minimum_bytes = 20L)
    x <- jsonlite::fromJSON(dest, simplifyVector = FALSE)
    if (is.null(x$features) || is.null(x$numberMatched) || is.null(x$numberReturned)) {
      stop("Malformed EMODnet Biology WFS dataset inventory response.", call. = FALSE)
    }
    n <- length(x$features)
    reported_page <- as.integer(x$numberReturned)
    total <- as.integer(x$numberMatched)
    if (n != reported_page) stop("EMODnet WFS numberReturned does not match the feature array.", call. = FALSE)
    if (is.na(provider_total)) provider_total <- total
    if (total != provider_total) stop("EMODnet WFS numberMatched changed during pagination.", call. = FALSE)

    if (n) {
      ids <- vapply(x$features, function(feature) as.character(feature$properties$id), character(1))
      dataset_names <- vapply(x$features, function(feature) as.character(feature$properties$name %||% ""), character(1))
      if (any(!nzchar(ids)) || any(!nzchar(dataset_names))) stop("EMODnet WFS inventory has a blank id or name.", call. = FALSE)
      if (length(intersect(ids, all_ids))) stop("EMODnet WFS pagination returned duplicate dataset IDs.", call. = FALSE)
      all_ids <- c(all_ids, ids)
    }

    rows[[length(rows) + 1L]] <- artifact_row(
      run, "EMODnet Biology WFS", "EMODnet Biology / EurOBIS", "OGC WFS 2.0.0",
      cfg$license, "GET", endpoint, url, page, dest, ans, n, provider_total,
      query_label = "complete Dataportal:eurobis_datasets inventory"
    )
    if (length(all_ids) >= provider_total) break
    if (n == 0L) stop("EMODnet WFS returned an empty page before the reported total.", call. = FALSE)
    start_index <- start_index + n
    page <- page + 1L
    if (page > 10000L) stop("EMODnet WFS pagination safety limit reached.", call. = FALSE)
  }
  if (length(all_ids) != provider_total || anyDuplicated(all_ids)) {
    stop(sprintf("EMODnet WFS inventory mismatch: %d unique IDs versus %d reported.",
      length(unique(all_ids)), provider_total), call. = FALSE)
  }

  write_search_manifest(
    run, do.call(rbind, rows), provider_total, length(unique(all_ids)), TRUE,
    notes = "Direct EMODnet Biology Dataportal WFS audit: capabilities and both schemas archived; complete eurobis_datasets inventory exhausted without a server-side keyword filter.",
    configuration_path = config_path
  )
  run$id
}

run_id <- run_emodnet_biology_wfs_search()

# Pin append runs separately so the ten-run initial execution and its frozen configuration remain
# intact. Re-running this script adds a dated row; it never replaces a prior raw response or pin.
append_path <- "metadata/stage1_append_runs.csv"
append <- if (file.exists(append_path)) {
  utils::read.csv(append_path, stringsAsFactors = FALSE, check.names = FALSE)
} else {
  data.frame(source_key = character(), search_run_id = character(), configuration_path = character(),
             stringsAsFactors = FALSE)
}
new_row <- data.frame(source_key = "EMODNET_BIOLOGY_WFS", search_run_id = run_id,
                      configuration_path = config_path, stringsAsFactors = FALSE)
append <- rbind(append, new_row)
utils::write.csv(append, append_path, row.names = FALSE)
message(sprintf("Pinned append-only EMODnet Biology WFS run %s in %s.", run_id, append_path))
