# Core setup and acquisition helpers used by scripted pipeline stages.

required_namespace <- function(package) {
  if (!requireNamespace(package, quietly = TRUE)) {
    stop(
      sprintf("Required package '%s' is unavailable; restore the locked environment with renv::restore().", package),
      call. = FALSE
    )
  }
}

# Verify that raw artifacts can only be written to the declared external mount.
verify_raw_data_target <- function(required_gb = 1) {
  raw_dir <- file.path("data", "raw")
  expected_target <- "/mnt/hdd/publication-2026-north-sea-phyc-validation"

  if (!nzchar(Sys.readlink(raw_dir))) {
    stop("data/raw must exist and must be a symbolic link.", call. = FALSE)
  }

  actual_target <- normalizePath(raw_dir, mustWork = TRUE)
  expected_target <- normalizePath(expected_target, mustWork = TRUE)
  if (!identical(actual_target, expected_target)) {
    stop(sprintf("data/raw resolves to '%s', not the required target '%s'.", actual_target, expected_target), call. = FALSE)
  }

  mount_info <- system2(
    "findmnt",
    c("-T", shQuote(actual_target), "-n", "-o", "TARGET,SOURCE,FSTYPE,OPTIONS"),
    stdout = TRUE,
    stderr = TRUE
  )
  if (!length(mount_info) || !nzchar(trimws(mount_info[[1]]))) {
    stop(sprintf("No mounted filesystem contains raw-data target '%s'.", actual_target), call. = FALSE)
  }
  if (file.access(actual_target, mode = 2) != 0) {
    stop(sprintf("Raw-data target '%s' is not writable.", actual_target), call. = FALSE)
  }

  df_out <- system2("df", c("-Pk", shQuote(actual_target)), stdout = TRUE, stderr = TRUE)
  if (length(df_out) < 2L) {
    stop("Unable to determine free space for the raw-data target.", call. = FALSE)
  }
  free_kb <- suppressWarnings(as.numeric(strsplit(trimws(df_out[[2]]), "[[:space:]]+")[[1]][4]))
  if (is.na(free_kb)) {
    stop("Unable to parse free space for the raw-data target.", call. = FALSE)
  }
  free_gb <- free_kb / (1024^2)
  if (free_gb < required_gb) {
    stop(sprintf("Raw-data target has %.2f GB free; %.2f GB is required.", free_gb, required_gb), call. = FALSE)
  }

  invisible(list(path = actual_target, mount = mount_info[[1]], free_gb = free_gb))
}

# Calculate the required SHA-256 checksum without loading the file into memory.
calculate_checksum <- function(file_path) {
  required_namespace("digest")
  if (!file.exists(file_path) || dir.exists(file_path)) {
    stop(sprintf("Checksum input is not a file: %s", file_path), call. = FALSE)
  }
  digest::digest(algo = "sha256", file = file_path)
}

# Download to a same-directory partial file, validate the response, and rename atomically.
download_with_retry <- function(url, dest_file, max_tries = 3, minimum_bytes = 1) {
  required_namespace("httr2")
  if (file.exists(dest_file)) {
    stop(sprintf("Refusing to overwrite immutable raw artifact: %s", dest_file), call. = FALSE)
  }
  dir.create(dirname(dest_file), recursive = TRUE, showWarnings = FALSE)

  partial_file <- paste0(dest_file, ".partial")
  if (file.exists(partial_file)) unlink(partial_file)
  on.exit(if (file.exists(partial_file)) unlink(partial_file), add = TRUE)

  request <- httr2::request(url) |>
    httr2::req_user_agent("north-sea-phyc-validation/Stage0") |>
    httr2::req_retry(max_tries = max_tries, max_seconds = 60)
  response <- httr2::req_perform(request, path = partial_file)
  status <- httr2::resp_status(response)
  size_bytes <- file.info(partial_file)$size
  content_type <- httr2::resp_header(response, "content-type")

  if (status < 200L || status >= 300L) {
    stop(sprintf("Download returned HTTP status %d for %s", status, url), call. = FALSE)
  }
  if (is.na(size_bytes) || size_bytes < minimum_bytes) {
    stop(sprintf("Downloaded response is smaller than %d bytes: %s", minimum_bytes, url), call. = FALSE)
  }
  if (!isTRUE(file.rename(partial_file, dest_file))) {
    stop(sprintf("Atomic rename failed for %s", dest_file), call. = FALSE)
  }

  list(
    checksum = calculate_checksum(dest_file),
    status = status,
    size = unname(size_bytes),
    content_type = if (is.null(content_type)) NA_character_ else content_type,
    url = url
  )
}

# Build a stable query URL with explicit, percent-encoded parameter values.
build_query_url <- function(base_url, parameters) {
  if (is.null(names(parameters)) || any(!nzchar(names(parameters)))) {
    stop("Every query parameter must be named.", call. = FALSE)
  }
  encoded <- vapply(parameters, function(value) utils::URLencode(as.character(value), reserved = TRUE), character(1))
  paste0(base_url, "?", paste0(names(encoded), "=", encoded, collapse = "&"))
}
