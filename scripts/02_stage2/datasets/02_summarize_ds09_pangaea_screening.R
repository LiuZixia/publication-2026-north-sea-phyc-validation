# Summarize DS09 PANGAEA Sylt screening results for Stage 2

source("R/00_core_setup.R")
source("R/03_stage2_contract.R")

contract <- read_stage2_contract()

loc_file <- "metadata/stage2/screening/ds09_pangaea_location_summary.csv"
if (!file.exists(loc_file)) stop("DS09 location summary not found.")

loc <- utils::read.csv(loc_file, stringsAsFactors = FALSE, check.names = FALSE)

summary <- data.frame(
  work_item_id = "REGISTER:DS09",
  record_count = as.integer(loc$total_raw_rows[[1]]),
  core_record_count = as.integer(loc$core_rows[[1]]),
  external_transfer_record_count = as.integer(loc$external_transfer_rows[[1]]),
  cmems_overlap_record_count = 0L,
  duplicate_record_count = 0L,
  provisional_tier = "D", # Hardcoded because work order says D/E
  analysis_role = "discovery_sensitivity", # Hardcoded because work order says core_margin
  screening_decision = "pending",
  exclusion_reason_code = "none",
  screening_detail = paste0(
    "DS09 PANGAEA Sylt acquisition and domain location screening complete. Final inclusion remains pending until ",
    "CMEMS temporal overlap is verified in Stage 5. ",
    loc$core_rows[[1]], " core records and ", loc$external_transfer_rows[[1]], 
    " external transfer records identified."
  ),
  stringsAsFactors = FALSE,
  check.names = FALSE
)

validate_stage2_table(summary, "dataset_screening_summary", contract)
write_csv_atomic(summary, "metadata/stage2/screening/ds09_pangaea_screening_summary.csv")
message("Summarized DS09 PANGAEA Sylt screening.")
