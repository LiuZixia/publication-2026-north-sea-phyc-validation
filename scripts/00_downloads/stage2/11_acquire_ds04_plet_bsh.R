#!/usr/bin/env Rscript
# Acquire the canonical DS04 PLET taxon-abundance export into an immutable Stage 2 run.

source("R/00_core_setup.R")
source("R/03_stage2_contract.R")
required_namespace("jsonlite")

verify_raw_data_target(required_gb = 1)
contract <- read_stage2_contract()
work <- utils::read.csv("metadata/stage2/control/acquisition_work_order.csv",
                        stringsAsFactors = FALSE, check.names = FALSE)
work_item_id <- "REGISTER:DS04"
if (!work_item_id %in% work$work_item_id) stop("DS04 is absent from the Stage 2 work order.", call. = FALSE)

config_path <- "config/stage2_ds04_plet_bsh_acquisition.json"
config <- jsonlite::fromJSON(config_path, simplifyVector = TRUE)
pin_path <- "metadata/stage2/acquisition/ds04_plet_bsh_active_run.csv"

valid_existing_pin <- function() {
  if (!file.exists(pin_path)) return(FALSE)
  pin <- utils::read.csv(pin_path, stringsAsFactors = FALSE, check.names = FALSE)
  if (nrow(pin) != 1L || !"run_relative_path" %in% names(pin)) return(FALSE)
  run_dir <- file.path("data", "raw", pin$run_relative_path[[1]])
  manifest_path <- file.path(run_dir, "manifest.csv")
  if (!file.exists(manifest_path) ||
      !identical(calculate_checksum(manifest_path), pin$manifest_checksum_sha256[[1]])) return(FALSE)
  manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE, check.names = FALSE)
  payload <- manifest$file_name[manifest$artifact_role == "observation_payload"]
  if (length(payload) != 1L) return(FALSE)
  paths <- file.path(run_dir, manifest$file_name)
  if (any(!file.exists(paths)) || any(file.size(paths) != manifest$file_size_bytes) ||
      !identical(unname(vapply(paths, calculate_checksum, character(1))), manifest$checksum_sha256)) return(FALSE)
  connection <- file(file.path(run_dir, payload), open = "r", encoding = "UTF-8")
  on.exit(close(connection), add = TRUE)
  lines <- readLines(connection, n = 2L, warn = FALSE)
  if (length(lines) != 2L) return(FALSE)
  probe <- tryCatch(utils::read.csv(text = paste(lines, collapse = "\n"), stringsAsFactors = FALSE,
                                    check.names = FALSE), error = function(error) NULL)
  !is.null(probe) && nrow(probe) == 1L && all(config$expected_columns %in% names(probe)) &&
    !"biomass_param_units" %in% names(probe) &&
    is.finite(suppressWarnings(as.numeric(probe$abundance[[1]])))
}

if (valid_existing_pin()) {
  message("Verified the existing canonical DS04 Stage 2 abundance acquisition; no download required.")
  quit(save = "no", status = 0L)
}

parameters <- c(
  startdate = config$start_date, enddate = config$end_date,
  north = config$north, south = config$south, east = config$east, west = config$west,
  abundance_dataset = config$dataset_parameter, format = config$format,
  raw = tolower(as.character(config$raw))
)
request_url <- build_query_url(config$endpoint, parameters)
stamp <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
run_name <- paste0("DS04_PLET_BSH_ABUNDANCE_", stamp)
run_relative_path <- file.path("stage2", "ds04_plet_bsh", run_name)
run_dir <- file.path("data", "raw", run_relative_path)
dir.create(run_dir, recursive = TRUE, showWarnings = FALSE)

request_path <- file.path(run_dir, "request_parameters.json")
html_path <- file.path(run_dir, "response.html")
csv_path <- file.path(run_dir, "bsh_phyto_zoo_abundance.csv")
log_path <- file.path(run_dir, "acquisition.log")
writeLines(jsonlite::toJSON(list(
  configuration_path = config_path,
  configuration_checksum_sha256 = calculate_checksum(config_path),
  request_url = request_url, parameters = as.list(parameters),
  requested_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
), auto_unbox = TRUE, pretty = TRUE), request_path, useBytes = TRUE)
writeLines(c(paste("run_name:", run_name), paste("request_url:", request_url)), log_path,
           useBytes = TRUE)

download_with_retry(request_url, html_path, max_tries = 4L, minimum_bytes = 50L,
                    timeout_seconds = 300L)
html <- paste(readLines(html_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
link <- regmatches(html, regexpr("[.][.]/output/raw/[^\"']+[.]csv", html, perl = TRUE))
if (!length(link) || !nzchar(link[[1]])) stop("DS04 PLET response lacks a raw CSV link.", call. = FALSE)
raw_url <- paste0("https://www.dassh.ac.uk/plet/", sub("^[.][.]/", "", link[[1]]))
write(paste("raw_url:", raw_url), log_path, append = TRUE)
download_with_retry(raw_url, csv_path, max_tries = 4L,
                    minimum_bytes = as.numeric(config$minimum_csv_bytes), timeout_seconds = 3600L)

connection <- file(csv_path, open = "r", encoding = "UTF-8")
lines <- readLines(connection, n = 2L, warn = FALSE)
close(connection)
probe <- utils::read.csv(text = paste(lines, collapse = "\n"), stringsAsFactors = FALSE,
                         check.names = FALSE)
if (nrow(probe) != 1L || !all(config$expected_columns %in% names(probe)) ||
    "biomass_param_units" %in% names(probe) ||
    !is.finite(suppressWarnings(as.numeric(probe$abundance[[1]])))) {
  stop("DS04 provider response is not the required taxon-abundance schema.", call. = FALSE)
}

manifest_files <- c(request_path, html_path, csv_path)
manifest <- data.frame(
  file_name = basename(manifest_files),
  checksum_sha256 = unname(vapply(manifest_files, calculate_checksum, character(1))),
  file_size_bytes = unname(file.size(manifest_files)),
  artifact_role = c("request_parameters", "provider_response", "observation_payload"),
  stringsAsFactors = FALSE, check.names = FALSE
)
manifest_path <- file.path(run_dir, "manifest.csv")
write_csv_atomic(manifest, manifest_path)
write(c(paste("completed_utc:", format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")),
        "validation_state: verified_taxon_abundance_schema"), log_path, append = TRUE)

previous_run <- if (file.exists(pin_path)) {
  old <- utils::read.csv(pin_path, stringsAsFactors = FALSE, check.names = FALSE)
  if (nrow(old) == 1L && "run_name" %in% names(old)) old$run_name[[1]] else ""
} else ""
pin <- data.frame(
  work_item_id = work_item_id, run_name = run_name, run_relative_path = run_relative_path,
  manifest_checksum_sha256 = calculate_checksum(manifest_path), pinned_at_utc = stamp,
  replaces_active_run = previous_run, stringsAsFactors = FALSE, check.names = FALSE
)
write_csv_atomic(pin, pin_path)
message(sprintf("DS04 canonical Stage 2 abundance acquisition complete: %s", run_relative_path))
