# Build a current operational-status overlay without mutating the checksum-frozen work order.

source("R/00_core_setup.R")
source("R/03_stage2_contract.R")

contract <- read_stage2_contract()
work_order_path <- "metadata/stage2/control/acquisition_work_order.csv"
status_path <- "metadata/stage2/control/acquisition_status.csv"
work <- utils::read.csv(work_order_path, stringsAsFactors = FALSE, check.names = FALSE)
validate_stage2_work_order(work, contract)

# The work order is the prospective baseline and intentionally remains all not_started. Current
# state is derived from per-dataset screening summaries so readers do not mistake that freeze for
# the live acquisition state.
summary_paths <- list.files(
  "metadata/stage2/screening",
  pattern = "^ds[0-9]{2}_.+_screening_summary\\.csv$",
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
  # A pending scientific inclusion decision can depend on Stage 3-5 coverage, method, or biomass
  # audits even though Stage 2 acquisition and record screening are finished. Do not conflate that
  # later-stage uncertainty with unfinished Stage 2 work when actual records were screened.
  status$current_work_state[has_summary] <- ifelse(
    decision != "pending" | record_count > 0L, "complete", "in_progress"
  )
  status$acquisition_state[has_summary] <- ifelse(
    record_count > 0L, "acquired_and_record_screened", "catalogue_archived_observations_pending"
  )
  status$screening_decision[has_summary] <- decision
  status$provisional_tier[has_summary] <- summary$provisional_tier[matched[has_summary]]
  status$status_evidence_path[has_summary] <- summary$status_evidence_path[matched[has_summary]]
  status$status_detail[has_summary] <- ifelse(
    decision == "pending" & record_count > 0L,
    paste0(
      "Stage 2 acquisition and record screening are complete. Scientific inclusion remains pending ",
      "for the later observation-only audits stated in the dataset summary."
    ),
    ifelse(
      decision == "pending",
      paste0("The canonical provider catalogue is archived and screened, but no observation records ",
             "are acquired; this ranked item is in progress and not complete."),
      paste0("Acquisition and record screening are complete at the dataset level with decision '",
             decision, "'.")
    )
  )
}

# Acquisition can advance beyond an older catalogue-only screening summary. Keep that distinction
# visible without rewriting the prospectively frozen work order or claiming record screening.
ds02_intake_path <- "metadata/stage2/acquisition/ds02_rws_manual_export_intake_summary.csv"
if (file.exists(ds02_intake_path)) {
  intake <- utils::read.csv(ds02_intake_path, stringsAsFactors = FALSE, check.names = FALSE)
  if (nrow(intake) != 1L || intake$work_item_id[[1]] != "REGISTER:DS02" ||
      intake$observation_rows[[1]] <= 0L ||
      intake$screening_decision[[1]] != "pending") {
    stop("DS02 manual-export intake summary is invalid.", call. = FALSE)
  }
  row <- match("REGISTER:DS02", status$work_item_id)
  if (status$current_work_state[[row]] != "complete") {
    status$current_work_state[[row]] <- "in_progress"
    status$acquisition_state[[row]] <- "observations_acquired_pending_record_screening"
    status$status_evidence_path[[row]] <- ds02_intake_path
    status$status_detail[[row]] <- paste0(
      "Canonical Waterinfo observation exports are acquired and checksum-pinned, but record-level ",
      "geometry, duplicates, methods, and eligibility have not yet been screened; this ranked item ",
      "remains in progress."
    )
  }
}

# Email-required datasets are unavailable now under the frozen access policy. Keep this as a work
# state rather than manufacturing a zero-row screening summary or turning missing access into a
# scientific exclusion.
access_path <- "metadata/stage2/control/access_dispositions.csv"
if (!file.exists(access_path)) {
  stop("Generate the Stage 2 access dispositions before refreshing status.", call. = FALSE)
}
access <- utils::read.csv(access_path, stringsAsFactors = FALSE, check.names = FALSE)
unavailable <- access$in_ranked_work_order &
  access$current_stage_action == "proceed_without_dataset"
for (i in which(unavailable)) {
  row <- match(access$work_item_id[[i]], status$work_item_id)
  if (is.na(row)) stop("An unavailable disposition is absent from the work order.", call. = FALSE)
  status$current_work_state[[row]] <- "unavailable"
  status$acquisition_state[[row]] <- "temporarily_unavailable"
  status$screening_decision[[row]] <- "not_assessed"
  status$provisional_tier[[row]] <- work$declared_tier[[row]]
  status$status_evidence_path[[row]] <- access_path
  status$status_detail[[row]] <- paste0(
    access$consequence_applied_now[[i]], " Email is required because: ",
    access$reason_email_needed[[i]]
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
gate_open <- any(status$current_work_state %in% c("not_started", "in_progress", "failed"))
message(sprintf(
  "Stage 2 status refreshed: %d complete, %d unavailable, %d in progress, %d not started (%s).",
  sum(status$current_work_state == "complete"),
  sum(status$current_work_state == "unavailable"),
  sum(status$current_work_state == "in_progress"),
  sum(status$current_work_state == "not_started"),
  ifelse(gate_open, "Stage 2 gate remains open", "Stage 2 work order is fully dispositioned")
))
