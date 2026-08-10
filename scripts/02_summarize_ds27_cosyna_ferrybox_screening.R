# 02_summarize_ds27_cosyna_ferrybox_screening.R
# Summarize DS27 (COSYNA/Hereon FerryBox)

source("R/00_core_setup.R")
source("R/03_stage2_contract.R")

message("Summarizing DS27...")

df <- data.frame(
  work_item_id = "DS27",
  record_count = 0L,
  core_record_count = 0L,
  external_transfer_record_count = 0L,
  cmems_overlap_record_count = 0L,
  duplicate_record_count = 0L,
  provisional_tier = "E",
  analysis_role = "pending",
  screening_decision = "pending",
  exclusion_reason_code = "none",
  screening_detail = "NetCDF files unparsed due to missing ncdf4 package. Requires future parsing.",
  stringsAsFactors = FALSE
)

# Validate
validate_stage2_table(df, "dataset_screening_summary")

out_path <- "data/interim/stage2/ds27_dataset_screening_summary.csv"
dir.create(dirname(out_path), recursive = TRUE, showWarnings = FALSE)
utils::write.csv(df, out_path, row.names = FALSE, na = "")
message("Wrote ", out_path)
