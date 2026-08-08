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
registry <- utils::read.csv("metadata/candidate_registry.csv", stringsAsFactors = FALSE, check.names = FALSE)
flow <- utils::read.csv("metadata/stage1_search_flow.csv", stringsAsFactors = FALSE)
recall <- utils::read.csv("metadata/stage1_known_item_recall.csv", stringsAsFactors = FALSE)
qlog <- utils::read.csv("metadata/stage1_query_log.csv", stringsAsFactors = FALSE, check.names = FALSE)
active <- utils::read.csv("metadata/stage1_active_runs.csv", stringsAsFactors = FALSE)
value <- stats::setNames(flow$count, flow$stage)

lines <- c(lines, section("Stage 1 — Reproducible Systematic Search"),
  kv("Source families with a pinned complete run", nrow(active)),
  kv("Query-log rows", nrow(qlog)),
  kv("Pagination complete for every query", all(qlog$pagination_complete)),
  kv("Registry SHA-256", calculate_checksum("metadata/candidate_registry.csv")),
  kv("Search-config SHA-256 (pinned into every run summary)", calculate_checksum("config/stage1_search_config.json")),
  kv("Screening-rules SHA-256 (versioned, not pinned)", calculate_checksum("config/screening_rules.json")),
  "")

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
if (file.exists("metadata/stage1_ds_crosswalk.csv")) {
  cw <- utils::read.csv("metadata/stage1_ds_crosswalk.csv", stringsAsFactors = FALSE)
  sl <- utils::read.csv("metadata/stage1_acquisition_shortlist.csv", stringsAsFactors = FALSE)
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
  if (file.exists("metadata/stage1_unavailable_candidates.csv")) {
    un <- utils::read.csv("metadata/stage1_unavailable_candidates.csv", stringsAsFactors = FALSE)
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
if (file.exists("metadata/provider_access_requests.csv")) {
  req <- utils::read.csv("metadata/provider_access_requests.csv", stringsAsFactors = FALSE)
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

# ---- Downstream stages -------------------------------------------------------
lines <- c(lines, section("Stages 2-12"),
  "Not started. No observation records, coverage audit, recurrence labels, validation splits, or CMEMS data exist.",
  "", "No CMEMS PhyC value has been acquired or inspected.", "")

dir.create("outputs", showWarnings = FALSE)
writeLines(lines, "outputs/stage_status.md", useBytes = TRUE)
message("Wrote outputs/stage_status.md")
