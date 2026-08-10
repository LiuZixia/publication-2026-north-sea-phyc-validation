# Summarize DS24 Figshare screening results for Stage 2

source("R/00_core_setup.R")
source("R/03_stage2_contract.R")

contract <- read_stage2_contract()

loc_file <- "metadata/stage2_ds24_figshare_location_summary.csv"
if (!file.exists(loc_file)) stop("DS24 location summary not found.")

loc <- utils::read.csv(loc_file, stringsAsFactors = FALSE, check.names = FALSE)

summary <- data.frame(
  work_item_id = "REGISTER:DS24",
  record_count = as.integer(loc$total_raw_rows[[1]]),
  core_record_count = as.integer(loc$core_rows[[1]]),
  external_transfer_record_count = as.integer(loc$external_transfer_rows[[1]]),
  cmems_overlap_record_count = 0L,
  duplicate_record_count = 0L,
  provisional_tier = "E", # Hardcoded from work order
  analysis_role = "comparator", # Hardcoded from work order
  screening_decision = "pending",
  exclusion_reason_code = "none",
  screening_detail = paste0(
    "DS24 Figshare OSPAR COMPEAT acquisition and domain location screening complete. Final inclusion remains pending until ",
    "CMEMS temporal overlap is verified in Stage 5. ",
    loc$core_rows[[1]], " core records and ", loc$external_transfer_rows[[1]], 
    " external transfer records identified."
  ),
  stringsAsFactors = FALSE,
  check.names = FALSE
)

validate_stage2_table(summary, "dataset_screening_summary", contract)
write_csv_atomic(summary, "metadata/stage2_ds24_figshare_screening_summary.csv")
message("Summarized DS24 Figshare screening.")
