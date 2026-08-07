# Validation and lookup helpers for immutable Stage 0 spatial acquisitions.

spatial_manifest_columns <- function() {
  c(
    "run_id", "source_id", "provider", "dataset", "artifact_id", "artifact_role",
    "page_number", "request_url", "api_version", "service_item_id", "license",
    "license_url", "access_time_utc", "http_status", "content_type", "size_bytes",
    "expected_feature_count", "returned_feature_count", "max_record_count",
    "pagination_complete", "transfer_limit_state", "filename", "checksum_sha256",
    "software_version"
  )
}

spatial_run_directories <- function(raw_root = file.path("data", "raw")) {
  run_root <- file.path(raw_root, "search_runs")
  if (!dir.exists(run_root)) return(character())
  sort(list.dirs(run_root, recursive = FALSE, full.names = TRUE)[
    grepl("^SPATIAL-ICES-[0-9]{8}T[0-9]{6}Z(?:-[0-9]+)?$", basename(list.dirs(run_root, recursive = FALSE, full.names = TRUE)))
  ])
}

validate_spatial_run <- function(run_dir, verify_checksums = TRUE) {
  manifest_file <- file.path(run_dir, "manifest.csv")
  if (!file.exists(manifest_file)) stop(sprintf("Spatial manifest is missing: %s", manifest_file), call. = FALSE)
  manifest <- read.csv(manifest_file, stringsAsFactors = FALSE, na.strings = c("", "NA"))
  missing_columns <- setdiff(spatial_manifest_columns(), names(manifest))
  if (length(missing_columns)) {
    stop(sprintf("Spatial manifest lacks columns: %s", paste(missing_columns, collapse = ", ")), call. = FALSE)
  }
  if (!nrow(manifest) || anyNA(manifest$artifact_id) || anyDuplicated(manifest$artifact_id)) {
    stop("Spatial manifest artifact IDs must be present and unique.", call. = FALSE)
  }
  if (length(unique(manifest$run_id)) != 1L || unique(manifest$run_id) != basename(run_dir)) {
    stop("Spatial manifest run_id does not match its immutable directory.", call. = FALSE)
  }

  artifact_paths <- file.path(run_dir, manifest$filename)
  missing_files <- artifact_paths[!file.exists(artifact_paths)]
  if (length(missing_files)) stop(sprintf("Manifest artifacts are missing: %s", paste(missing_files, collapse = ", ")), call. = FALSE)
  observed_sizes <- unname(file.info(artifact_paths)$size)
  if (anyNA(manifest$size_bytes) || any(observed_sizes != manifest$size_bytes)) {
    stop("Spatial artifact sizes do not match the manifest.", call. = FALSE)
  }
  if (anyNA(manifest$http_status) || any(manifest$http_status < 200L | manifest$http_status >= 300L)) {
    stop("Spatial manifest contains an unsuccessful HTTP status.", call. = FALSE)
  }
  if (verify_checksums) {
    observed_checksums <- vapply(artifact_paths, calculate_checksum, character(1))
    if (!identical(tolower(unname(observed_checksums)), tolower(unname(manifest$checksum_sha256)))) {
      stop("Spatial artifact checksums do not match the manifest.", call. = FALSE)
    }
  }

  feature_rows <- manifest$artifact_role == "features_page"
  if (!any(feature_rows)) stop("Spatial manifest contains no feature pages.", call. = FALSE)
  feature_manifest <- manifest[feature_rows, , drop = FALSE]
  for (source_id in unique(feature_manifest$source_id)) {
    source_rows <- feature_manifest[feature_manifest$source_id == source_id, , drop = FALSE]
    expected <- unique(source_rows$expected_feature_count)
    if (length(expected) != 1L || is.na(expected) || sum(source_rows$returned_feature_count) != expected) {
      stop(sprintf("Feature-count reconciliation failed for %s.", source_id), call. = FALSE)
    }
    if (any(is.na(source_rows$pagination_complete) | !source_rows$pagination_complete)) {
      stop(sprintf("Pagination is not complete for %s.", source_id), call. = FALSE)
    }
    if (any(tolower(source_rows$transfer_limit_state) == "true")) {
      stop(sprintf("Provider transfer limit was detected for %s.", source_id), call. = FALSE)
    }
  }

  license_rows <- manifest$artifact_role == "license_policy"
  if (sum(license_rows) != 1L || !nzchar(manifest$license_url[license_rows])) {
    stop("Exactly one archived license-policy artifact is required.", call. = FALSE)
  }
  manifest
}

latest_valid_spatial_run <- function(raw_root = file.path("data", "raw"), verify_checksums = TRUE) {
  candidates <- rev(spatial_run_directories(raw_root))
  for (candidate in candidates) {
    valid <- try(validate_spatial_run(candidate, verify_checksums = verify_checksums), silent = TRUE)
    if (!inherits(valid, "try-error")) return(candidate)
  }
  stop("No valid registered Stage 0 spatial acquisition is available.", call. = FALSE)
}

read_frozen_spatial_run <- function(pin_file = file.path("config", "spatial_raw_run.txt")) {
  if (!file.exists(pin_file)) stop(sprintf("Frozen spatial run file is missing: %s", pin_file), call. = FALSE)
  values <- trimws(readLines(pin_file, warn = FALSE))
  values <- values[nzchar(values) & !startsWith(values, "#")]
  if (length(values) != 1L || !grepl("^SPATIAL-ICES-[0-9]{8}T[0-9]{6}Z(?:-[0-9]+)?$", values)) {
    stop("Frozen spatial run file must contain exactly one valid run ID.", call. = FALSE)
  }
  values[[1]]
}
