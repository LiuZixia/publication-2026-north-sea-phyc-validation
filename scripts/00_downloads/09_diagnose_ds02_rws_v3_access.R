# Archive the unauthenticated access response from the current canonical RWS biological API.

source("R/00_core_setup.R")
source("R/03_stage2_contract.R")
required_namespace("httr2")
required_namespace("jsonlite")

config_path <- "config/stage2_ds02_rws_v3_access_diagnosis.json"
cfg <- jsonlite::fromJSON(config_path, simplifyVector = FALSE)
if (!identical(cfg$classification, "stage2_canonical_provider_access_diagnosis") ||
    !identical(cfg$work_item_id, "REGISTER:DS02") || cfg$acquisition_rank != 3L ||
    !identical(cfg$request_method, "GET") || isTRUE(cfg$authentication_sent)) {
  stop("DS02 RWS V3 access-diagnosis configuration is invalid.", call. = FALSE)
}

verify_raw_data_target(required_gb = cfg$required_free_gb)
run_relative <- file.path("stage2", "ds02_rws_access", cfg$diagnostic_run_id)
final_dir <- file.path("data", "raw", run_relative)
staging_dir <- paste0(final_dir, ".partial")

write_tracked <- function(directory) {
  summary <- jsonlite::fromJSON(file.path(directory, "run_summary.json"), simplifyVector = FALSE)
  diagnosis <- data.frame(
    work_item_id = cfg$work_item_id,
    provider = cfg$provider,
    route = cfg$route,
    endpoint = cfg$endpoint,
    request_method = cfg$request_method,
    authentication_sent = FALSE,
    http_status = as.integer(summary$http_status),
    response_body_size_bytes = as.numeric(summary$response_body_size_bytes),
    access_state = "credential_or_provider_export_required",
    observation_rows_acquired = 0L,
    evidence_relative_path = file.path(run_relative, "response_headers.json"),
    evidence_checksum_sha256 = calculate_checksum(file.path(directory, "response_headers.json")),
    decision_detail = cfg$decision_rule,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  pin <- data.frame(
    work_item_id = cfg$work_item_id,
    run_relative_path = run_relative,
    completed_utc = summary$completed_utc,
    configuration_path = config_path,
    configuration_checksum_sha256 = summary$configuration_checksum_sha256,
    response_headers_checksum_sha256 = calculate_checksum(file.path(directory, "response_headers.json")),
    response_body_checksum_sha256 = calculate_checksum(file.path(directory, "response_body.bin")),
    run_summary_checksum_sha256 = calculate_checksum(file.path(directory, "run_summary.json")),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  write_csv_atomic(diagnosis, "metadata/stage2_ds02_rws_v3_access_diagnosis.csv")
  write_csv_atomic(pin, "metadata/stage2_ds02_rws_v3_access_active_run.csv")
}

if (dir.exists(final_dir)) {
  required <- file.path(final_dir, c("response_headers.json", "response_body.bin",
                                    "run_summary.json", "run.log"))
  if (any(!file.exists(required))) stop("Existing DS02 V3 access run is incomplete.", call. = FALSE)
  summary <- jsonlite::fromJSON(file.path(final_dir, "run_summary.json"), simplifyVector = FALSE)
  if (summary$http_status != cfg$expected_http_status ||
      !identical(summary$configuration_checksum_sha256, calculate_checksum(config_path))) {
    stop("Existing DS02 V3 access run differs from its frozen configuration.", call. = FALSE)
  }
  write_tracked(final_dir)
  message("Verified existing DS02 RWS V3 access diagnosis; no request required.")
  quit(save = "no", status = 0L)
}
dir.create(staging_dir, recursive = TRUE, showWarnings = FALSE)
body_path <- file.path(staging_dir, "response_body.bin")
if (file.exists(body_path) && unlink(body_path) != 0L) {
  stop("Unable to replace the incomplete DS02 V3 response body.", call. = FALSE)
}
request <- httr2::request(cfg$endpoint) |>
  httr2::req_user_agent("north-sea-phyc-validation/Stage2-DS02-access-diagnosis") |>
  httr2::req_timeout(seconds = 60) |>
  httr2::req_error(is_error = function(response) FALSE)
response <- httr2::req_perform(request, path = body_path)
status <- httr2::resp_status(response)
if (status != cfg$expected_http_status) {
  stop(sprintf("RWS V3 access response changed: expected HTTP %d, received %d.",
               cfg$expected_http_status, status), call. = FALSE)
}
headers <- unclass(as.list(httr2::resp_headers(response)))
jsonlite::write_json(list(
  endpoint = cfg$endpoint,
  request_method = cfg$request_method,
  authentication_sent = FALSE,
  http_status = status,
  response_headers = headers
), file.path(staging_dir, "response_headers.json"), pretty = TRUE, auto_unbox = TRUE)
summary <- list(
  schema_version = cfg$schema_version,
  completed_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  status = "complete",
  work_item_id = cfg$work_item_id,
  http_status = status,
  response_body_size_bytes = unname(file.info(body_path)$size),
  authentication_sent = FALSE,
  access_state = "credential_or_provider_export_required",
  configuration_checksum_sha256 = calculate_checksum(config_path),
  software_version = R.version.string
)
jsonlite::write_json(summary, file.path(staging_dir, "run_summary.json"),
                     pretty = TRUE, auto_unbox = TRUE)
writeLines(c(
  sprintf("completed_utc: %s", summary$completed_utc),
  sprintf("http_status: %d", summary$http_status),
  sprintf("response_body_size_bytes: %.0f", summary$response_body_size_bytes),
  "authentication_sent: false",
  sprintf("access_state: %s", summary$access_state),
  sprintf("R: %s", R.version.string)
), file.path(staging_dir, "run.log"), useBytes = TRUE)
if (!file.rename(staging_dir, final_dir)) {
  stop("Unable to atomically finalize the DS02 RWS V3 access diagnosis.", call. = FALSE)
}
write_tracked(final_dir)
message(sprintf("DS02 RWS V3 unauthenticated access diagnosed: HTTP %d; observations pending.", status))
