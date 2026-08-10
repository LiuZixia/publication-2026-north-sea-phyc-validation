# Freeze the Stage 2 work order and the unresolved EMODnet WFS routing queue.

source("R/00_core_setup.R")
source("R/03_stage2_contract.R")

contract_path <- "config/stage2_record_screening_contract.json"
shortlist_path <- "metadata/stage1/qualification/acquisition_shortlist.csv"
wfs_overlap_path <- "metadata/stage1/search/emodnet_wfs_overlap.csv"
registry_path <- "metadata/stage1/search/candidate_registry.csv"
work_order_path <- "metadata/stage2/control/acquisition_work_order.csv"
wfs_queue_path <- "metadata/stage2/control/wfs_geometry_queue.csv"
freeze_path <- "metadata/stage2/control/contract_freeze.json"

contract <- read_stage2_contract(contract_path)
storage <- verify_raw_data_target(required_gb = 0.01)
if (!identical(paste0(storage$path, "/"), contract$raw_storage$required_resolved_target)) {
  stop("Mounted raw-data target differs from the Stage 2 contract.", call. = FALSE)
}

# Preserve the Stage 1 ranking exactly; acquisition priority is not an eligibility decision.
shortlist <- utils::read.csv(shortlist_path, stringsAsFactors = FALSE, check.names = FALSE)
required_shortlist <- c("acquisition_rank", "ds_id", "name", "declared_tier", "declared_domain",
                        "planned_role", "licence_action")
if (!all(required_shortlist %in% names(shortlist))) {
  stop("Stage 1 shortlist lacks fields required by the Stage 2 work order.", call. = FALSE)
}
shortlist <- shortlist[order(shortlist$acquisition_rank), , drop = FALSE]
work_order <- data.frame(
  work_item_id = paste0("REGISTER:", shortlist$ds_id),
  acquisition_rank = as.integer(shortlist$acquisition_rank),
  ds_id = shortlist$ds_id,
  name = shortlist$name,
  declared_tier = shortlist$declared_tier,
  declared_domain = shortlist$declared_domain,
  planned_role = shortlist$planned_role,
  licence_action = shortlist$licence_action,
  required_next_action = "acquire_highest_resolution_canonical_provider_record_then_screen",
  work_state = "not_started",
  contract_version = contract$schema_version,
  stringsAsFactors = FALSE,
  check.names = FALSE
)
validate_stage2_work_order(work_order, contract)

# Join the title-level audit back to its immutable WFS catalogue page. Title geography is only a
# routing signal: every candidate remains pending until record geometry and provenance are queried.
overlap <- utils::read.csv(wfs_overlap_path, stringsAsFactors = FALSE, check.names = FALSE)
registry <- utils::read.csv(registry_path, stringsAsFactors = FALSE, check.names = FALSE)
wfs <- overlap[overlap$biological_title_match & !overlap$exact_title_match_existing, , drop = FALSE]
evidence <- registry[registry$source == "EMODnet Biology WFS",
                     c("provider_dataset_id", "geographic_screen_state", "raw_response_path",
                       "raw_response_checksum_sha256"), drop = FALSE]
if (anyDuplicated(evidence$provider_dataset_id)) stop("WFS registry IDs are not unique.", call. = FALSE)
match_index <- match(as.character(wfs$wfs_dataset_id), as.character(evidence$provider_dataset_id))
if (anyNA(match_index)) stop("An unmatched WFS candidate lacks immutable registry evidence.", call. = FALSE)
evidence <- evidence[match_index, , drop = FALSE]
title_signal <- ifelse(evidence$geographic_screen_state == "dataset_metadata_indicates_out_of_domain",
                       "out_of_domain", "unknown")
wfs_queue <- data.frame(
  work_item_id = paste0("EMODNET-WFS:", wfs$wfs_dataset_id),
  wfs_dataset_id = as.character(wfs$wfs_dataset_id),
  wfs_dataset_name = wfs$wfs_dataset_name,
  title_domain_signal = title_signal,
  record_geometry_state = "not_checked",
  record_access_state = "not_checked",
  duplicate_resolution_state = "not_checked",
  screening_decision = "pending",
  required_next_action = "query_record_geometry_and_canonical_provider_metadata",
  decision_detail = paste0(
    "Stage 1 title signal is ", title_signal,
    "; title evidence cannot set a final record-level decision under contract 1.0.0."
  ),
  stage1_raw_response_path = evidence$raw_response_path,
  stage1_raw_response_checksum_sha256 = evidence$raw_response_checksum_sha256,
  contract_version = contract$schema_version,
  stringsAsFactors = FALSE,
  check.names = FALSE
)
wfs_queue <- wfs_queue[order(as.integer(wfs_queue$wfs_dataset_id)), , drop = FALSE]
validate_stage2_wfs_queue(wfs_queue, contract)

write_csv_atomic(work_order, work_order_path)
write_csv_atomic(wfs_queue, wfs_queue_path)

# The freeze is deterministic: the prospective timestamp lives in the contract and every input and
# generated routing artifact is pinned by checksum. Re-running unchanged inputs yields identical bytes.
freeze_inputs <- c(
  contract = contract_path,
  stage1_shortlist = shortlist_path,
  stage1_wfs_overlap = wfs_overlap_path,
  stage1_candidate_registry = registry_path,
  access_and_licence_policy = "config/access_and_licence_policy.json",
  protocol_config = "config/protocol_config.json",
  greater_north_sea_geometry = "config/spatial/greater_north_sea.geojson",
  hydrographic_subregions = "config/spatial/hydrographic_subregions.geojson",
  generated_work_order = work_order_path,
  generated_wfs_queue = wfs_queue_path
)
freeze <- list(
  schema_version = contract$schema_version,
  frozen_at_utc = contract$frozen_at_utc,
  status = contract$status,
  raw_storage_target = contract$raw_storage$required_resolved_target,
  shortlist_rows = nrow(work_order),
  wfs_pending_rows = nrow(wfs_queue),
  wfs_title_out_of_domain_signals = sum(wfs_queue$title_domain_signal == "out_of_domain"),
  wfs_unknown_title_geography = sum(wfs_queue$title_domain_signal == "unknown"),
  artifacts = lapply(names(freeze_inputs), function(role) list(
    role = role,
    path = unname(freeze_inputs[[role]]),
    checksum_sha256 = calculate_checksum(unname(freeze_inputs[[role]]))
  ))
)
write_json_atomic(freeze, freeze_path)

message(sprintf("Stage 2 contract initialized: %d ranked datasets; %d WFS candidates pending.",
                nrow(work_order), nrow(wfs_queue)))
