# Summarize the archived DS26 classifier reference without treating images as observation records.

source("R/00_core_setup.R")
source("R/03_stage2_contract.R")

pin <- utils::read.csv("metadata/stage2/acquisition/ds26_ifcb_reference_active_run.csv",
                       stringsAsFactors = FALSE, check.names = FALSE)
manifest <- utils::read.csv("metadata/stage2/acquisition/ds26_ifcb_reference_acquisition_manifest.csv",
                            stringsAsFactors = FALSE, check.names = FALSE)
contract <- read_stage2_contract()
validate_stage2_table(manifest, "acquisition_manifest", contract)
if (nrow(pin) != 1L || nrow(manifest) != 4L ||
    !identical(calculate_checksum(file.path("data", "raw", pin$run_relative_path[[1]], "manifest.csv")),
               pin$manifest_checksum_sha256[[1]]) ||
    any(vapply(seq_len(nrow(manifest)), function(i) {
      !identical(calculate_checksum(file.path("data", "raw", manifest$raw_relative_path[[i]])),
                 manifest$checksum_sha256[[i]])
    }, logical(1)))) {
  stop("DS26 reference-library run or checksums do not reconcile.", call. = FALSE)
}
readme_path <- file.path("data", "raw", manifest$raw_relative_path[manifest$filename == "README.md"])
readme <- paste(readLines(readme_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
required_text <- c("86,232 annotated images", "146 different classes", "from 2016 to 2026",
                   "training classifiers", "CC BY 4.0")
if (any(!vapply(required_text, grepl, logical(1), x = readme, fixed = TRUE))) {
  stop("Archived DS26 reference README lacks expected scope or licence statements.", call. = FALSE)
}
summary <- data.frame(
  work_item_id = "REGISTER:DS26",
  provider_dataset_id = "FIGSHARE:25883455",
  doi = "10.17044/scilifelab.25883455.v6",
  provider_version = "6",
  annotated_image_count = 86232L,
  class_count = 146L,
  coverage_start_year = 2016L,
  coverage_end_year = 2026L,
  archived_file_count = nrow(manifest),
  archived_size_bytes = sum(manifest$size_bytes),
  license = "CC BY 4.0",
  scientific_role = "classifier_taxonomy_size_range_and_method_evidence",
  independent_monitoring_network = FALSE,
  observation_record_source = FALSE,
  resolution_detail = paste0(
    "The full v6 image/MATLAB library is archived to audit classifier classes, image features, ",
    "size and method assumptions for DS26. Its manually annotated images train or assess the ",
    "classifier; they are not a second monitoring network, sampling series, or bloom reference."
  ),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
write_csv_atomic(summary, "metadata/stage2/screening/ds26_ifcb_reference_summary.csv")
message("DS26 IFCB reference summary complete: 86,232 images, 146 classes, method evidence only.")
