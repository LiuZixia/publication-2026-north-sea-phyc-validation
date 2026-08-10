# Summarize PLET screening results for Stage 2

source("R/00_core_setup.R")
source("R/03_stage2_contract.R")

contract <- read_stage2_contract()

plet_datasets <- list(
  list(id = "DS04", file = "metadata/stage2/screening/ds04_plet_bsh_location_summary.csv",
       out = "metadata/stage2/screening/ds04_plet_bsh_screening_summary.csv", tier = "A", role = "primary_reference"),
  list(id = "DS05", file = "metadata/stage2/screening/ds05_plet_novana_location_summary.csv",
       out = "metadata/stage2/screening/ds05_plet_novana_screening_summary.csv", tier = "A", role = "primary_reference"),
  list(id = "DS07", file = "metadata/stage2/screening/ds07_plet_cefas_location_summary.csv",
       out = "metadata/stage2/screening/ds07_plet_cefas_screening_summary.csv", tier = "A", role = "primary_reference"),
  list(id = "DS10", file = "metadata/stage2/screening/ds10_plet_vliz_location_summary.csv",
       out = "metadata/stage2/screening/ds10_plet_vliz_screening_summary.csv", tier = "C", role = "lifeform_only"),
  list(id = "DS11", file = "metadata/stage2/screening/ds11_plet_chlorophyll_location_summary.csv",
       out = "metadata/stage2/screening/ds11_plet_chlorophyll_screening_summary.csv", tier = "E", role = "comparator"),
  list(id = "DS16", file = "metadata/stage2/screening/ds16_plet_stonehaven_location_summary.csv",
       out = "metadata/stage2/screening/ds16_plet_stonehaven_screening_summary.csv", tier = "C", role = "primary_reference")
)

for (ds in plet_datasets) {
  if (file.exists(ds$file)) {
    loc <- utils::read.csv(ds$file, stringsAsFactors = FALSE, check.names = FALSE)
    
    summary <- data.frame(
      work_item_id = paste0("REGISTER:", ds$id),
      record_count = as.integer(loc$total_raw_rows[[1]]),
      core_record_count = as.integer(loc$core_rows[[1]]),
      external_transfer_record_count = as.integer(loc$external_transfer_rows[[1]]),
      cmems_overlap_record_count = 0L,
      duplicate_record_count = 0L,
      provisional_tier = ds$tier,
      analysis_role = ds$role,
      screening_decision = "pending",
      exclusion_reason_code = "none",
      screening_detail = paste0(
        "PLET acquisition and domain location screening complete. Final inclusion remains pending until ",
        "CMEMS temporal overlap is verified in Stage 5. ",
        loc$core_rows[[1]], " core records and ", loc$external_transfer_rows[[1]], 
        " external transfer records identified."
      ),
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
    
    validate_stage2_table(summary, "dataset_screening_summary", contract)
    write_csv_atomic(summary, ds$out)
    message(sprintf("Summarized PLET dataset %s screening.", ds$id))
  }
}
