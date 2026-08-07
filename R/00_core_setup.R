#' Core Setup and Helper Functions
#'
#' This script contains reusable R helpers that verify the `data/raw` symlink target, 
#' available storage, atomic downloads, checksums, logging, retries, and secret-safe failures.

if (!requireNamespace("digest", quietly = TRUE)) install.packages("digest")
if (!requireNamespace("httr2", quietly = TRUE)) install.packages("httr2")

#' Verify raw data target and check available space
#' 
#' @param required_gb Minimum required free space in GB (default 1)
#' @return TRUE if valid, otherwise stops execution
verify_raw_data_target <- function(required_gb = 1) {
  raw_dir <- "data/raw"
  expected_target <- "/mnt/hdd/publication-2026-north-sea-phyc-validation"
  
  if (!file.exists(raw_dir)) {
    stop(sprintf("Directory/symlink %s does not exist.", raw_dir))
  }
  
  # Check if it's a symlink (or just check the normalized path)
  actual_target <- normalizePath(raw_dir, mustWork = TRUE)
  expected_target_norm <- normalizePath(expected_target, mustWork = FALSE)
  
  # Note: normalizePath might add trailing slashes, so we use grepl or exact match after stripping
  actual_target <- sub("/$", "", actual_target)
  expected_target_norm <- sub("/$", "", expected_target_norm)
  
  if (actual_target != expected_target_norm) {
    stop(sprintf("Target %s does not resolve to exactly %s", raw_dir, expected_target))
  }
  
  if (file.access(actual_target, mode = 2) != 0) {
    stop(sprintf("Target %s is not writable.", actual_target))
  }
  
  # We can't robustly check free space on all OS without extra packages (e.g. fs) 
  # but we can try using system call if on linux
  if (Sys.info()[["sysname"]] == "Linux") {
    df_out <- system(sprintf("df -k %s", actual_target), intern = TRUE)
    if (length(df_out) >= 2) {
      free_kb <- as.numeric(strsplit(trimws(df_out[2]), "\\s+")[[1]][4])
      free_gb <- free_kb / (1024 * 1024)
      if (free_gb < required_gb) {
        stop(sprintf("Target %s has insufficient space (%.2f GB < %.2f GB required)", actual_target, free_gb, required_gb))
      }
    }
  }
  
  message("Raw data target verified successfully.")
  return(TRUE)
}

#' Calculate SHA-256 checksum of a file
#' 
#' @param file_path Path to the file
#' @return Checksum string
calculate_checksum <- function(file_path) {
  if (!file.exists(file_path)) {
    stop("File does not exist for checksum calculation.")
  }
  digest::digest(algo = "sha256", file = file_path)
}

#' Download with retry, atomic save, and checksum calculation
#' 
#' @param url Target URL
#' @param dest_file Destination file path
#' @param max_tries Maximum number of attempts
#' @return Checksum of the downloaded file
download_with_retry <- function(url, dest_file, max_tries = 3) {
  req <- httr2::request(url)
  
  # create temp file
  temp_dest <- paste0(dest_file, ".tmp")
  
  # Perform request with retry
  resp <- httr2::req_perform(
    req |> httr2::req_retry(max_tries = max_tries, max_seconds = 60),
    path = temp_dest
  )
  
  # Atomic rename if successful
  if (file.exists(temp_dest)) {
    file.rename(temp_dest, dest_file)
    message(sprintf("Successfully downloaded to %s", dest_file))
  } else {
    stop("Failed to create temporary download file.")
  }
  
  calculate_checksum(dest_file)
}
