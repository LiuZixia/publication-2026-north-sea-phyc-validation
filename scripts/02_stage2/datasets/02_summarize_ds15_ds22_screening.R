# Summarize screening results for reference datasets DS15 and DS22

source("R/00_core_setup.R")
source("R/03_stage2_contract.R")

contract <- read_stage2_contract()

ds15 <- data.frame(
  work_item_id = "REGISTER:DS15",
  record_count = 1L,
  core_record_count = 0L,
  external_transfer_record_count = 0L,
  cmems_overlap_record_count = 0L,
  duplicate_record_count = 0L,
  provisional_tier = "not_applicable",
  analysis_role = "discovery_sensitivity",
  screening_decision = "secondary",
  exclusion_reason_code = "none",
  screening_detail = "EMODnet gridded presence/absence product acquired and documented as a secondary exploratory sensitivity reference, not primary independent event truth.",
  stringsAsFactors = FALSE,
  check.names = FALSE
)

validate_stage2_table(ds15, "dataset_screening_summary", contract)
write_csv_atomic(ds15, "metadata/stage2/screening/ds15_emodnet_erddap_screening_summary.csv")

ds22 <- data.frame(
  work_item_id = "REGISTER:DS22",
  record_count = 1L,
  core_record_count = 0L,
  external_transfer_record_count = 0L,
  cmems_overlap_record_count = 0L,
  duplicate_record_count = 0L,
  provisional_tier = "not_applicable",
  analysis_role = "comparator",
  screening_decision = "secondary",
  exclusion_reason_code = "none",
  screening_detail = "HELCOM PEG_BVOL conversion authority acquired and documented as a secondary reference for converting biovolume to carbon.",
  stringsAsFactors = FALSE,
  check.names = FALSE
)

validate_stage2_table(ds22, "dataset_screening_summary", contract)
write_csv_atomic(ds22, "metadata/stage2/screening/ds22_ices_figshare_screening_summary.csv")

message("Screening summaries for DS15 and DS22 written.")
