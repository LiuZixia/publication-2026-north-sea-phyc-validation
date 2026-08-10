# Generate the Stage 2 access disposition register from frozen policy, existing request records,
# and checksum-pinned local payloads. This script never contacts a provider.

source("R/00_core_setup.R")
source("R/03_stage2_contract.R")

work_path <- "metadata/stage2/control/acquisition_work_order.csv"
request_path <- "metadata/stage1/qualification/provider_access_requests.csv"
output_path <- "metadata/stage2/control/access_dispositions.csv"

work <- utils::read.csv(work_path, stringsAsFactors = FALSE, check.names = FALSE)
requests <- utils::read.csv(request_path, stringsAsFactors = FALSE, check.names = FALSE)
contract <- read_stage2_contract()
validate_stage2_work_order(work, contract)

required_request_fields <- c(
  "ds_id", "provider", "contact_route", "request_type", "what_is_requested",
  "why_it_mattered", "consequence_applied_now", "draft_section", "revisit_trigger"
)
if (!all(required_request_fields %in% names(requests)) || anyDuplicated(requests$ds_id)) {
  stop("The provider request register is missing required fields or has duplicate DS IDs.", call. = FALSE)
}

verify_simple_pin <- function(active_run_path, expected_work_item_id) {
  pin <- utils::read.csv(active_run_path, stringsAsFactors = FALSE, check.names = FALSE)
  if (nrow(pin) != 1L || pin$work_item_id[[1]] != expected_work_item_id) {
    stop(sprintf("Invalid active-run pin: %s", active_run_path), call. = FALSE)
  }
  run_dir <- file.path("data", "raw", pin$run_relative_path[[1]])
  manifest_path <- file.path(run_dir, "manifest.csv")
  if (!file.exists(manifest_path) ||
      calculate_checksum(manifest_path) != pin$manifest_checksum_sha256[[1]]) {
    stop(sprintf("Active-run manifest checksum failed: %s", active_run_path), call. = FALSE)
  }
  manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE, check.names = FALSE)
  if (nrow(manifest) != 1L ||
      !all(c("file_name", "checksum_sha256", "file_size_bytes") %in% names(manifest))) {
    stop(sprintf("Expected a one-file simple manifest: %s", manifest_path), call. = FALSE)
  }
  payload <- file.path(run_dir, manifest$file_name[[1]])
  if (!file.exists(payload) || file.size(payload) != manifest$file_size_bytes[[1]] ||
      calculate_checksum(payload) != manifest$checksum_sha256[[1]]) {
    stop(sprintf("Pinned payload failed size or checksum validation: %s", payload), call. = FALSE)
  }
  list(pin = pin, manifest = manifest, payload = payload)
}

# The archived DS08 response is checksum-valid as a response, but it is a PANGAEA login page rather
# than the requested observation ZIP. Preserve that distinction: it is evidence of unavailable
# access, not a zero-row biological dataset.
ds08 <- verify_simple_pin(
  "metadata/stage2/acquisition/ds08_pangaea_abundance_active_run.csv", "REGISTER:DS08"
)
ds08_head <- paste(readLines(ds08$payload, n = 40L, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
if (!grepl("<title>Log in", ds08_head, fixed = TRUE)) {
  stop("The pinned DS08 response is no longer recognisable as the archived login page.", call. = FALSE)
}

# DS12 is a valid public DwC-A. Its provider email is useful only for richer effort metadata; it is
# not an access requirement and must not make the open archive unavailable.
ds12 <- verify_simple_pin(
  "metadata/stage2/acquisition/ds12_dassh_ipt_active_run.csv", "REGISTER:DS12"
)
con <- file(ds12$payload, open = "rb")
on.exit(close(con), add = TRUE)
ds12_magic <- rawToChar(readBin(con, what = "raw", n = 2L))
close(con)
on.exit(NULL, add = FALSE)
if (!identical(ds12_magic, "PK")) stop("The pinned DS12 payload is not a ZIP archive.", call. = FALSE)

request_rows <- requests[, required_request_fields, drop = FALSE]
request_rows$email_requirement <- "required"
request_rows$availability_state <- ifelse(
  request_rows$request_type == "release_status_enquiry",
  "temporarily_unavailable_unreleased",
  ifelse(request_rows$request_type == "existence_and_access_enquiry",
         "temporarily_unavailable_no_identified_data_route",
         "temporarily_unavailable_contact_required")
)
request_rows$archived_payload_state <- "no_stage2_observation_payload"
request_rows$current_stage_action <- "proceed_without_dataset"

additional <- data.frame(
  ds_id = c("DS08", "DS12", "DS28"),
  provider = c("AWI / PANGAEA", "Continuous Plankton Recorder Survey / MBA",
               "VLIZ LifeWatch Belgium"),
  contact_route = c(
    "Principal investigators named on PANGAEA.960407 and PANGAEA.862910",
    "CPR Survey data team",
    "LifeWatch Belgium data support"
  ),
  request_type = c("licence_and_moratorium_enquiry", "optional_metadata_request",
                   "dataset_identity_and_access_enquiry"),
  what_is_requested = c(
    "Licence and moratorium terms for carbon- and biovolume-resolved Helgoland Roads children",
    "Route-level counts, PCI, tow identity, sampled volume, retention guidance, and usage terms",
    "Exact HPLC series identity, DOI or API/IPT route, licence, pigment methods, and coordinates"
  ),
  why_it_mattered = c(
    "The restricted carbon and biovolume children are the only identified direct route to lifeform carbon shares; the attempted parent-series abundance ZIP returned a login page.",
    "The public DASSH DwC-A is usable at Tier D/E, but richer effort metadata would improve interpretation of the only basin-scale offshore evidence.",
    "The narrative candidate lacks an exact machine-actionable identity, so no observation payload or legal terms can be tied specifically to the claimed HPLC/CHEMTAX series."
  ),
  consequence_applied_now = c(
    "DS08 is unavailable in the current Stage 2 pass. No login HTML is parsed as observations and no carbon-share evidence is claimed.",
    "Proceed with the existing public DASSH DwC-A at Tier D/E; the optional email does not block Stage 2.",
    "DS28 is unavailable in the current Stage 2 pass and contributes no pigment or haptophyte evidence."
  ),
  draft_section = c("docs/access_requests/DRAFT_EMAILS.md#ds08",
                    "docs/access_requests/DRAFT_EMAILS.md#ds12",
                    "docs/access_requests/DRAFT_EMAILS.md#ds28"),
  revisit_trigger = c(
    "Written licence terms plus an accessible observation payload",
    "A provider response supplying richer effort metadata",
    "A provider response identifying an exact accessible series with usable terms"
  ),
  email_requirement = c("required", "optional_enhancement", "required"),
  availability_state = c(
    "temporarily_unavailable_no_valid_archived_payload",
    "available_open_evidence_email_optional",
    "temporarily_unavailable_no_identified_data_route"
  ),
  archived_payload_state = c("login_html_not_observation_data", "valid_public_dwca",
                             "no_stage2_observation_payload"),
  current_stage_action = c("proceed_without_dataset", "continue_existing_open_evidence",
                           "proceed_without_dataset"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)

dispositions <- rbind(request_rows, additional)
dispositions$work_item_id <- ifelse(
  dispositions$ds_id %in% work$ds_id, paste0("REGISTER:", dispositions$ds_id), ""
)
dispositions$in_ranked_work_order <- dispositions$ds_id %in% work$ds_id
dispositions$reason_email_needed <- paste0(
  dispositions$what_is_requested, ". Reason: ", dispositions$why_it_mattered
)
dispositions$evidence_path <- ifelse(
  dispositions$ds_id == "DS08",
  "metadata/stage2/acquisition/ds08_pangaea_abundance_active_run.csv",
  ifelse(dispositions$ds_id == "DS12",
         "metadata/stage2/acquisition/ds12_dassh_ipt_active_run.csv",
         ifelse(dispositions$ds_id == "DS28",
                "metadata/stage1/qualification/ds_crosswalk.csv", request_path))
)

dispositions <- dispositions[order(dispositions$ds_id), c(
  "ds_id", "work_item_id", "in_ranked_work_order", "provider", "contact_route",
  "request_type", "email_requirement", "availability_state", "archived_payload_state",
  "current_stage_action", "reason_email_needed", "consequence_applied_now", "evidence_path",
  "draft_section", "revisit_trigger"
)]
if (nrow(dispositions) != 9L || anyDuplicated(dispositions$ds_id) ||
    !setequal(dispositions$ds_id, c("DS08", "DS12", "DS17", "DS18", "DS19", "DS20",
                                   "DS21", "DS23", "DS28"))) {
  stop("Stage 2 access dispositions do not cover the nine declared request cases.", call. = FALSE)
}
unavailable <- dispositions$email_requirement == "required"
if (any(dispositions$current_stage_action[unavailable] != "proceed_without_dataset") ||
    dispositions$current_stage_action[dispositions$ds_id == "DS12"] !=
      "continue_existing_open_evidence") {
  stop("Email-required and optional-email cases are not separated correctly.", call. = FALSE)
}

write_csv_atomic(dispositions, output_path)
message(sprintf(
  "Stage 2 access dispositions generated: %d temporarily unavailable; %d optional enhancement.",
  sum(unavailable), sum(dispositions$email_requirement == "optional_enhancement")
))
