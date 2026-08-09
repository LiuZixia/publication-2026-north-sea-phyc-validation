# Build a current operational-status overlay without mutating the checksum-frozen work order.

source("R/00_core_setup.R")
source("R/03_stage2_contract.R")

contract <- read_stage2_contract()
work_order_path <- "metadata/stage2_acquisition_work_order.csv"
status_path <- "metadata/stage2_acquisition_status.csv"
work <- utils::read.csv(work_order_path, stringsAsFactors = FALSE, check.names = FALSE)
validate_stage2_work_order(work, contract)

# The work order is the prospective baseline and intentionally remains all not_started. Current
# state is derived from per-dataset screening summaries so readers do not mistake that freeze for
# the live acquisition state.
summary_paths <- list.files(
  "metadata",
  pattern = "^stage2_ds[0-9]{2}_.+_screening_summary\\.csv$",
  full.names = TRUE
)
summaries <- lapply(summary_paths, function(path) {
  value <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
  validate_stage2_table(value, "dataset_screening_summary", contract)
  if (nrow(value) != 1L) stop(sprintf("Expected one dataset summary row in %s.", path), call. = FALSE)
  value$status_evidence_path <- path
  value
})
summary <- if (length(summaries)) do.call(rbind, summaries) else NULL
if (!is.null(summary) && anyDuplicated(summary$work_item_id)) {
  stop("Multiple per-dataset screening summaries claim the same work item.", call. = FALSE)
}

status <- data.frame(
  work_item_id = work$work_item_id,
  acquisition_rank = work$acquisition_rank,
  ds_id = work$ds_id,
  frozen_work_state = work$work_state,
  current_work_state = "not_started",
  acquisition_state = "not_started",
  screening_decision = "not_assessed",
  provisional_tier = "not_assessed",
  status_evidence_path = "",
  status_detail = paste0(
    "No per-dataset screening summary exists; canonical acquisition has not started under the ",
    "tracked Stage 2 workflow."
  ),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
if (!is.null(summary)) {
  matched <- match(status$work_item_id, summary$work_item_id)
  has_summary <- !is.na(matched)
  decision <- summary$screening_decision[matched[has_summary]]
  record_count <- summary$record_count[matched[has_summary]]
  status$current_work_state[has_summary] <- ifelse(decision == "pending", "in_progress", "complete")
  status$acquisition_state[has_summary] <- ifelse(
    record_count > 0L, "acquired_and_record_screened", "catalogue_archived_observations_pending"
  )
  status$screening_decision[has_summary] <- decision
  status$provisional_tier[has_summary] <- summary$provisional_tier[matched[has_summary]]
  status$status_evidence_path[has_summary] <- summary$status_evidence_path[matched[has_summary]]
  status$status_detail[has_summary] <- ifelse(
    decision == "pending",
    ifelse(
      record_count > 0L,
      paste0("Acquisition and initial record screening exist, but the per-dataset decision remains ",
             "pending; this ranked item is not complete."),
      paste0("The canonical provider catalogue is archived and screened, but no observation records ",
             "are acquired; this ranked item is in progress and not complete.")
    ),
    paste0("Acquisition and record screening are complete at the dataset level with decision '",
           decision, "'.")
  )
}

allowed_states <- unlist(contract$controlled_vocabularies$work_state, use.names = FALSE)
if (nrow(status) != 19L || anyDuplicated(status$work_item_id) ||
    !identical(status$acquisition_rank, seq_len(nrow(status))) ||
    any(!status$current_work_state %in% allowed_states) ||
    !all(status$frozen_work_state == "not_started")) {
  stop("Stage 2 acquisition-status overlay failed its ordering or state assertions.", call. = FALSE)
}
write_csv_atomic(status, status_path)
message(sprintf(
  "Stage 2 status refreshed: %d complete, %d in progress, %d not started (Stage 2 gate remains open).",
  sum(status$current_work_state == "complete"),
  sum(status$current_work_state == "in_progress"),
  sum(status$current_work_state == "not_started")
))
