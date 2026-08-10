# Summarize DS03 EurOBIS screening results for Stage 2

source("R/00_core_setup.R")
source("R/03_stage2_contract.R")

contract <- read_stage2_contract()

loc_file <- "metadata/stage2_ds03_eurobis_location_summary.csv"
if (!file.exists(loc_file)) stop("DS03 location summary not found.")

loc <- utils::read.csv(loc_file, stringsAsFactors = FALSE, check.names = FALSE)

summary <- data.frame(
  work_item_id = "REGISTER:DS03",
  record_count = as.integer(loc$total_raw_rows[[1]]),
  core_record_count = as.integer(loc$core_rows[[1]]),
  external_transfer_record_count = as.integer(loc$external_transfer_rows[[1]]),
  cmems_overlap_record_count = 0L,
  duplicate_record_count = 0L,
  provisional_tier = "A", # Assuming tier A for now based on work order
  analysis_role = "primary_reference",
  screening_decision = "pending",
  exclusion_reason_code = "none",
  screening_detail = paste0(
    "DS03 EurOBIS DwCA acquisition and domain location screening complete. Final inclusion remains pending until ",
    "CMEMS temporal overlap is verified in Stage 5. ",
    loc$core_rows[[1]], " core records and ", loc$external_transfer_rows[[1]], 
    " external transfer records identified."
  ),
  stringsAsFactors = FALSE,
  check.names = FALSE
)

# Overwrite tier from work order if needed
work_order <- utils::read.csv("metadata/stage2_acquisition_work_order.csv", stringsAsFactors = FALSE)
wo_row <- work_order[work_order$work_item_id == "REGISTER:DS03", ]
if (nrow(wo_row) == 1) {
  summary$provisional_tier <- wo_row$declared_tier
}

validate_stage2_table(summary, "dataset_screening_summary", contract)
write_csv_atomic(summary, "metadata/stage2_ds03_eurobis_screening_summary.csv")
message("Summarized DS03 EurOBIS screening.")
