# Generate the stage-status report from the artefacts themselves.
#
# PROGRESS.md previously carried counts, checksums, and gate verdicts in prose, and drifted out of
# agreement with the files it described: one session recorded Stage 1 as accepted four lines below
# the audit that had rejected it. Narrative status duplicated from data will always be able to
# contradict it. This script derives the status, so PROGRESS.md can hold decisions and rationale
# only, and cannot disagree with the registry.

source("R/00_core_setup.R")
required_namespace("jsonlite")

fmt <- function(x) formatC(x, format = "d", big.mark = ",")
lines <- c("# Stage Status (generated)", "",
  sprintf("Generated (UTC): %s", format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")),
  "",
  "Do not edit. Regenerate with `Rscript scripts/99_stage_status.R`.", "")

section <- function(title) c("", paste("##", title), "")
kv <- function(k, v) sprintf("- **%s:** %s", k, v)

# ---- Stage 0 -----------------------------------------------------------------
register <- utils::read.csv("config/protocol_change_register.csv", stringsAsFactors = FALSE)
lines <- c(lines, section("Stage 0 — Governance"),
  kv("Protocol-change rows", nrow(register)),
  kv("Approved", sum(register$approval_status == "approved")),
  kv("Pending approval", sum(register$approval_status == "pending")),
  kv("Frozen domain files", paste(basename(list.files("config/spatial", pattern = "geojson$")), collapse = ", ")))

if (any(register$approval_status == "pending")) {
  lines <- c(lines, "", "Pending protocol changes (require principal-investigator decision):", "")
  pending <- register[register$approval_status == "pending", ]
  lines <- c(lines, sprintf("- %s — %s", pending$date, substr(pending$change, 1, 150)))
}

# ---- Stage 1 -----------------------------------------------------------------
registry <- utils::read.csv("metadata/stage1/search/candidate_registry.csv", stringsAsFactors = FALSE, check.names = FALSE)
flow <- utils::read.csv("metadata/stage1/search/search_flow.csv", stringsAsFactors = FALSE)
recall <- utils::read.csv("metadata/stage1/search/known_item_recall.csv", stringsAsFactors = FALSE)
qlog <- utils::read.csv("metadata/stage1/search/query_log.csv", stringsAsFactors = FALSE, check.names = FALSE)
active <- utils::read.csv("metadata/stage1/search/active_runs.csv", stringsAsFactors = FALSE)
append <- if (file.exists("metadata/stage1/search/append_runs.csv")) {
  utils::read.csv("metadata/stage1/search/append_runs.csv", stringsAsFactors = FALSE)
} else data.frame()
value <- stats::setNames(flow$count, flow$stage)

lines <- c(lines, section("Stage 1 — Reproducible Systematic Search"),
  kv("Pinned complete search runs", nrow(active) + nrow(append)),
  kv("Initial source families", nrow(active)),
  kv("Append-only update runs", nrow(append)),
  kv("Query-log rows", nrow(qlog)),
  kv("Pagination complete for every query", all(qlog$pagination_complete)),
  kv("Registry SHA-256", calculate_checksum("metadata/stage1/search/candidate_registry.csv")),
  kv("Initial search-config SHA-256", calculate_checksum("config/stage1_search_config.json")),
  kv("Screening-rules SHA-256 (versioned, not pinned)", calculate_checksum("config/screening_rules.json")),
  "")

if (nrow(append) && file.exists("metadata/stage1/search/emodnet_wfs_overlap_summary.csv")) {
  wfs <- utils::read.csv("metadata/stage1/search/emodnet_wfs_overlap_summary.csv", stringsAsFactors = FALSE)
  wfs_value <- stats::setNames(wfs$count, wfs$metric)
  lines <- c(lines, section("Stage 1 — EMODnet Biology WFS Append Audit"),
    kv("Direct WFS inventory rows", wfs_value[["wfs_dataset_inventory_rows"]]),
    kv("Exact title matches to any archived catalogue", wfs_value[["exact_title_matches_any_archived_catalogue"]]),
    kv("Exact title matches to OBIS", wfs_value[["exact_title_matches_obis"]]),
    kv("Biological-title candidates", wfs_value[["biological_title_candidates"]]),
    kv("Unmatched biological-title candidates retained", wfs_value[["unmatched_biological_title_candidates"]]),
    "",
    "No unmatched biological title contains dataset-level evidence for the frozen North Sea domain;",
    "those rows remain pending for Stage 2 record-level geometry screening.", "")
}

lines <- c(lines, "| Search flow | Count |", "|---|---|",
  sprintf("| %s | %s |", flow$stage, fmt(flow$count)), "")

lines <- c(lines,
  kv("Known-item benchmarks", nrow(recall)),
  kv("Recalled from archived evidence", sum(recall$found)),
  kv("Recalled and retained through screening", sum(recall$screening_status != "excluded")),
  "")

geo <- table(registry$geographic_screen_state)
lines <- c(lines, "| Dataset-level geographic screen | Rows |", "|---|---|",
  sprintf("| %s | %s |", names(geo), fmt(as.integer(geo))),
  "", "Geography is recorded, not enforced, at dataset level; Stage 2 performs the record-level intersection.", "")

# ---- Register crosswalk and acquisition shortlist -----------------------------
if (file.exists("metadata/stage1/qualification/ds_crosswalk.csv")) {
  cw <- utils::read.csv("metadata/stage1/qualification/ds_crosswalk.csv", stringsAsFactors = FALSE)
  sl <- utils::read.csv("metadata/stage1/qualification/acquisition_shortlist.csv", stringsAsFactors = FALSE)
  diagnosed_absence <- !cw$resolved & (cw$availability == "no_route" | cw$entry_type == "excluded_decision")
  undiagnosed <- cw$ds_id[!cw$resolved & !diagnosed_absence]
  diagnosed <- cw$ds_id[diagnosed_absence]
  empty <- cw$ds_id[cw$resolved & cw$retained_rows == 0L]
  lines <- c(lines, section("Stage 1 — Register Crosswalk and Acquisition Shortlist"),
    kv("Register entries resolved against archived evidence", sprintf("%d of %d", sum(cw$resolved), nrow(cw))),
    kv("Diagnosed without retained registry evidence", if (length(diagnosed)) paste(diagnosed, collapse = ", ") else "none"),
    kv("Undiagnosed search failures requiring query/API review", if (length(undiagnosed)) paste(undiagnosed, collapse = ", ") else "none"),
    kv("Resolved but retaining no rows after screening", if (length(empty)) paste(empty, collapse = ", ") else "none"),
    kv("Datasets shortlisted for Stage 2 acquisition", nrow(sl)),
    kv("Shortlisted with an open subset only", sum(sl$availability == "partially_open")),
    kv("Shortlisted needing a licence resolved before Stage 7",
       sum(sl$licence_action == "resolve_licence_before_stage7_manifest_freeze")),
    "")
  if (file.exists("metadata/stage1/qualification/unavailable_candidates.csv")) {
    un <- utils::read.csv("metadata/stage1/qualification/unavailable_candidates.csv", stringsAsFactors = FALSE)
    lines <- c(lines,
      kv("Datasets the study proceeds without", if (nrow(un)) paste(un$ds_id, collapse = ", ") else "none"),
      "", "| DS | Name | Availability | Tier | Domain |", "|---|---|---|---|---|",
      sprintf("| %s | %s | %s | %s | %s |", un$ds_id, un$name, un$availability,
        un$declared_tier, un$declared_domain), "")
  }
  top <- utils::head(sl, 10)
  lines <- c(lines, "Top of the acquisition work order:", "",
    "| Rank | DS | Name | Tier | Domain | Status |", "|---|---|---|---|---|---|",
    sprintf("| %d | %s | %s | %s | %s | %s |", top$acquisition_rank, top$ds_id, top$name,
      top$declared_tier, top$declared_domain, top$acquisition_status), "")
}

# ---- Provider access ---------------------------------------------------------
stage2_access_path <- "metadata/stage2/control/access_dispositions.csv"
if (file.exists(stage2_access_path)) {
  access <- utils::read.csv(stage2_access_path, stringsAsFactors = FALSE, check.names = FALSE)
  legacy_requests <- utils::read.csv("metadata/stage1/qualification/provider_access_requests.csv",
                                    stringsAsFactors = FALSE, check.names = FALSE)
  sent <- !is.na(legacy_requests$sent_utc) & nzchar(trimws(legacy_requests$sent_utc))
  required <- access$email_requirement == "required"
  ranked_unavailable <- access$in_ranked_work_order &
    access$current_stage_action == "proceed_without_dataset"
  lines <- c(lines, section("Provider Access Requests"),
    kv("Documented email dispositions", nrow(access)),
    kv("Required and temporarily unavailable", sum(required)),
    kv("Optional metadata enhancements", sum(access$email_requirement == "optional_enhancement")),
    kv("Ranked Stage 2 items unavailable", sum(ranked_unavailable)),
    kv("Sent", sum(sent)),
    kv("Drafted, awaiting a human to send", sum(!sent)),
    kv("Drafts", "docs/access_requests/DRAFT_EMAILS.md"),
    "",
    "No request carries a deadline. Required-email datasets are unavailable under the frozen policy",
    "and contribute no observations in the current pass. A dated provider response can trigger",
    "reassessment; optional requests do not block use of already archived open evidence.",
    "",
    "| DS | Provider | Requirement | Current action | Why email is needed |", "|---|---|---|---|---|",
    sprintf("| %s | %s | %s | %s | %s |", access$ds_id, substr(access$provider, 1, 40),
      access$email_requirement, access$current_stage_action,
      substr(gsub("[|]", "/", access$reason_email_needed), 1, 110)), "")
} else if (file.exists("metadata/stage1/qualification/provider_access_requests.csv")) {
  req <- utils::read.csv("metadata/stage1/qualification/provider_access_requests.csv", stringsAsFactors = FALSE)
  sent <- !is.na(req$sent_utc) & nzchar(trimws(req$sent_utc))
  lines <- c(lines, section("Provider Access Requests"),
    kv("Registered requests", nrow(req)),
    kv("Sent", sum(sent)),
    kv("Drafted, awaiting a human to send", sum(!sent)),
    kv("Drafts", "docs/access_requests/DRAFT_EMAILS.md"),
    "",
    "No request carries a deadline. Under `config/access_and_licence_policy.json` a contact-required",
    "dataset is unavailable from the moment the search establishes that, and the consequence below is",
    "already applied. A reply re-admits the dataset as a dated addition to the change register.",
    "",
    "| DS | Provider | Treatment | Consequence already applied |", "|---|---|---|---|",
    sprintf("| %s | %s | %s | %s |", req$ds_id, substr(req$provider, 1, 40),
      substr(req$availability_treatment, 1, 46), substr(req$consequence_applied_now, 1, 90)), "")
}

# ---- Stage 2 -----------------------------------------------------------------
stage2_status_path <- "metadata/stage2/control/acquisition_status.csv"
if (file.exists(stage2_status_path)) {
  stage2 <- utils::read.csv(stage2_status_path, stringsAsFactors = FALSE, check.names = FALSE)
  state <- table(factor(stage2$current_work_state,
                        levels = c("complete", "unavailable", "in_progress", "not_started")))
  decision <- table(stage2$screening_decision)
  inventory_path <- "metadata/stage2/inventory/file_inventory.csv"
  unresolved_path <- "metadata/stage_file_inventory_unresolved.csv"
  inventory <- if (file.exists(inventory_path)) {
    utils::read.csv(inventory_path, stringsAsFactors = FALSE, check.names = FALSE)
  } else data.frame()
  unresolved <- if (file.exists(unresolved_path)) {
    utils::read.csv(unresolved_path, stringsAsFactors = FALSE, check.names = FALSE)
  } else data.frame(stage = character())
  lines <- c(lines, section("Stage 2 — Acquisition Evidence and Record Screening"),
    kv("Frozen work items", nrow(stage2)),
    kv("Current complete", unname(state[["complete"]])),
    kv("Current temporarily unavailable", unname(state[["unavailable"]])),
    kv("Current in progress", unname(state[["in_progress"]])),
    kv("Current not started", unname(state[["not_started"]])),
    kv("Screening decisions", paste(names(decision), as.integer(decision), sep = "=", collapse = ", ")),
    kv("Inventoried Stage 2 files", nrow(inventory)),
    kv("Unresolved Stage 2 artifacts", sum(unresolved$stage == "stage2")),
    kv("Operational description", "docs/stages/STAGE2.md"),
    "", "The prospective work order remains unchanged; current state is a generated overlay.",
    "A pending scientific decision or an unavailable dataset is not an ecological negative.", "")
}

# ---- Stage 3 and downstream stages -------------------------------------------
stage3_gate_path <- "metadata/stage3/gate/stage3_gate_status.csv"
if (file.exists(stage3_gate_path)) {
  stage3 <- utils::read.csv(stage3_gate_path, stringsAsFactors = FALSE, check.names = FALSE)
  if (nrow(stage3) == 1L && identical(stage3$gate_state, "passed")) {
    role_gate <- utils::read.csv("metadata/stage3/gate/dataset_region_period_role_gate.csv",
                                 stringsAsFactors = FALSE, check.names = FALSE)
    eligible_ds <- sort(unique(role_gate$ds_id[role_gate$stage3_role == "eligible"]))
    lines <- c(lines, section("Stage 3 — Coverage Audit and Scientific-Use Gate"),
      kv("Gate state", stage3$gate_state),
      kv("Stage 2 work items retained", stage3$stage2_work_items),
      kv("Complete / unavailable", paste(stage3$complete_work_items,
                                          stage3$unavailable_work_items, sep = " / ")),
      kv("Observation datasets parsed", stage3$observation_datasets_parsed),
      kv("Defensible sample/support units", fmt(stage3$sample_support_units)),
      kv("Datasets with at least one eligible combination", paste(eligible_ds, collapse = ", ")),
      kv("Deterministic replay", stage3$deterministic_replay),
      kv("PhyC values accessed", stage3$phy_c_values_accessed),
      kv("Operational description", "docs/stages/STAGE3.md"),
      "", "Eligibility is combination-specific and still requires Stage 4 feasibility and Stage 5 compatibility.",
      "Unavailable access remains unknown, never an ecological zero.", "")
  } else {
    lines <- c(lines, section("Stage 3 — Coverage Audit and Scientific-Use Gate"),
      "In progress. A unique generated `passed` gate is not present.", "")
  }
} else {
  lines <- c(lines, section("Stage 3 — Coverage Audit and Scientific-Use Gate"),
    "In progress. A generated validation gate is not yet present.", "")
}

# ---- Stage 4 and downstream stages -------------------------------------------
stage4_gate_path <- "metadata/stage4/gate/stage4_gate_status.csv"
if (file.exists(stage4_gate_path)) {
  stage4 <- utils::read.csv(stage4_gate_path, stringsAsFactors = FALSE, check.names = FALSE)
  if (nrow(stage4) == 1L && stage4$gate_state == "conditional_proceed_to_stage5_harmonization") {
    lines <- c(lines, section("Stage 4 — Feasibility and Confirmatory Design"),
      kv("Gate state", stage4$gate_state),
      kv("Primary validation feasibility", stage4$primary_validation_feasibility),
      kv("Independent primary candidate networks", stage4$independent_primary_candidate_networks),
      kv("Direct-carbon anchor networks", stage4$direct_carbon_anchor_networks),
      kv("Conversion candidate networks", stage4$conversion_candidate_networks),
      kv("Primary-window candidates", stage4$primary_window_candidates),
      kv("Stage 5 harmonization authorized", stage4$stage5_harmonization_authorized),
      kv("Stage 6 outcomes authorized", stage4$stage6_outcome_authorized),
      kv("CMEMS acquisition authorized", stage4$cmems_acquisition_authorized),
      kv("Operational description", "docs/stages/STAGE4.md"),
      "", "The handoff is conditional: adequacy, conversion, events, recurrence, spatial scope,",
      "and exact product overlap remain unresolved without PhyC inspection.", "")
  } else {
    lines <- c(lines, section("Stage 4 — Feasibility and Confirmatory Design"),
      "Not passed. A unique conditional Stage 5 handoff is not present.", "")
  }
} else {
  lines <- c(lines, section("Stage 4 — Feasibility and Confirmatory Design"),
    "In progress. A generated Stage 4 gate is not yet present.", "")
}

lines <- c(lines, section("Stages 5-12"),
  "Stage 5 may proceed only for the roles named by Stage 4; later stages remain unauthorized.",
  "", "No CMEMS PhyC value has been acquired or inspected.", "")

dir.create("outputs", showWarnings = FALSE)
writeLines(lines, "outputs/stage_status.md", useBytes = TRUE)
message("Wrote outputs/stage_status.md")
