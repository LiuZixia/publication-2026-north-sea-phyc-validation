# Verify and register the existing DS10 PLET/VLIZ acquisition without contacting the provider.
#
# This run predates the ordered Stage 2 acquisition scripts. The exact submitted request and the
# returned raw-file URL are retained below and checked against the archived acquisition log. This
# script never downloads or rewrites raw evidence; it only validates the immutable run and rebuilds
# its tracked active-run pin.

source("R/00_core_setup.R")
source("R/03_stage2_contract.R")

request_url <- paste0(
  "https://www.dassh.ac.uk/plet/cgi-bin/get_form.py?",
  "startdate=2000-01-01&enddate=2019-12-31&north=63&south=48&east=14&west=-6&",
  "abundance_dataset=LW_VLIZ_phyto&format=csv&raw=true"
)
returned_raw_url <-
  "https://www.dassh.ac.uk/plet/output/raw/2026-08-09T11:51:29.093034.csv"
run_name <- "DS10_PLET_VLIZ_20260809T105128Z"
run_relative_path <- file.path("stage2", "ds10_plet_vliz", run_name)
run_dir <- file.path("data", "raw", run_relative_path)

verify_raw_data_target(required_gb = 0)
required <- file.path(run_dir, c("response.html", "acquisition.log", "manifest.csv",
                                "lw_vliz_phyto.csv"))
if (!dir.exists(run_dir) || any(!file.exists(required))) {
  stop("The archived DS10 PLET/VLIZ run is incomplete; no download was attempted.", call. = FALSE)
}

log_lines <- readLines(file.path(run_dir, "acquisition.log"), warn = FALSE, encoding = "UTF-8")
if (!any(grepl(request_url, log_lines, fixed = TRUE)) ||
    !any(grepl(returned_raw_url, log_lines, fixed = TRUE))) {
  stop("The archived DS10 request log differs from the exact registered requests.", call. = FALSE)
}

manifest_path <- file.path(run_dir, "manifest.csv")
manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE, check.names = FALSE)
if (!identical(names(manifest), c("file_name", "checksum_sha256", "file_size_bytes")) ||
    nrow(manifest) != 1L || manifest$file_name[[1]] != "lw_vliz_phyto.csv") {
  stop("The archived DS10 manifest has an unexpected schema or payload.", call. = FALSE)
}
payload_path <- file.path(run_dir, manifest$file_name[[1]])
if (!identical(unname(file.info(payload_path)$size), as.numeric(manifest$file_size_bytes[[1]])) ||
    !identical(calculate_checksum(payload_path), manifest$checksum_sha256[[1]])) {
  stop("The archived DS10 payload differs from its manifest.", call. = FALSE)
}

pin <- data.frame(
  work_item_id = "REGISTER:DS10",
  run_name = run_name,
  run_relative_path = run_relative_path,
  manifest_checksum_sha256 = calculate_checksum(manifest_path),
  pinned_at_utc = "20260809T105128Z",
  stringsAsFactors = FALSE,
  check.names = FALSE
)
write_csv_atomic(pin, "metadata/stage2/acquisition/ds10_plet_vliz_active_run.csv")
message("Verified and registered the existing DS10 PLET/VLIZ run; no download attempted.")
