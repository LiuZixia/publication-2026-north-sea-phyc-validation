# Resolve licence, canonical-provider family, and scientific role for the three domain survivors.

source("R/00_core_setup.R")
source("R/03_stage2_contract.R")

pin <- utils::read.csv("metadata/stage2_emodnet_wfs_metadata_active_run.csv",
                       stringsAsFactors = FALSE, check.names = FALSE)
if (nrow(pin) != 1L) stop("Exactly one official WFS survivor metadata run must be active.", call. = FALSE)
run_dir <- file.path("data", "raw", pin$run_relative_path[[1]])
if (!identical(calculate_checksum(file.path(run_dir, "manifest.csv")),
               pin$manifest_checksum_sha256[[1]]) ||
    !identical(calculate_checksum(file.path(run_dir, "run_summary.json")),
               pin$run_summary_checksum_sha256[[1]])) {
  stop("Official WFS survivor metadata differs from its active pin.", call. = FALSE)
}

manifest <- utils::read.csv(file.path(run_dir, "manifest.csv"), stringsAsFactors = FALSE,
                            check.names = FALSE, colClasses = c(dataset_id = "character"))
evidence <- utils::read.csv("metadata/stage2_emodnet_wfs_geometry_evidence.csv",
                            stringsAsFactors = FALSE, check.names = FALSE,
                            colClasses = c(wfs_dataset_id = "character"))
screened <- utils::read.csv("metadata/stage2_emodnet_wfs_screening.csv",
                            stringsAsFactors = FALSE, check.names = FALSE,
                            colClasses = c(wfs_dataset_id = "character"))
contract <- read_stage2_contract()
validate_stage2_wfs_queue(screened, contract, require_initial = FALSE)

extract_url <- function(page, pattern) {
  matches <- regmatches(page, gregexpr('https?://[^"< ]+', page, perl = TRUE))[[1]]
  value <- matches[grepl(pattern, matches, perl = TRUE)]
  if (!length(value)) "" else value[[1]]
}

resolution_rows <- lapply(c("2453", "5951", "6698"), function(dataset_id) {
  manifest_row <- manifest[manifest$dataset_id == dataset_id, , drop = FALSE]
  page_path <- file.path("data", "raw", manifest_row$raw_relative_path[[1]])
  page <- paste(readLines(page_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  licence_url <- extract_url(page, "spdx[.]org/licenses/")
  if (!nzchar(licence_url)) stop(sprintf("No licence found in official metadata for %s.", dataset_id), call. = FALSE)
  is_smhi <- dataset_id %in% c("2453", "6698")
  provider_url <- if (is_smhi) {
    extract_url(page, "gbif[.]se/ipt/(archive|archive[.]do)[?]r=smhi-phytoplankton-")
  } else {
    extract_url(page, "ipt[.]naturalsciences[.]be/resource[?]r=idod_ipms_phaeo")
  }
  if (!nzchar(provider_url)) stop(sprintf("No canonical provider archive found for %s.", dataset_id), call. = FALSE)
  geometry <- evidence[evidence$wfs_dataset_id == dataset_id, , drop = FALSE]
  data.frame(
    wfs_dataset_id = dataset_id,
    canonical_provider = if (is_smhi) "Swedish Meteorological and Hydrological Institute / SHARK" else "RBINS-OD Nature / Belgian Marine Data Centre",
    canonical_provider_url = provider_url,
    aggregator_relationship = "aggregator_copy",
    routed_work_item_id = if (is_smhi) "REGISTER:DS06" else "",
    licence_state = "open",
    licence_url = licence_url,
    provisional_tier = if (is_smhi) "B" else "F",
    analysis_role = if (is_smhi) "pending" else "discovery_sensitivity",
    screening_decision = if (is_smhi) "pending" else "exploratory",
    scientific_reason = if (is_smhi) {
      "Official metadata documents quantitative species counts and sometimes biovolume; acquire the canonical SHARK provider files under ranked DS06 before record deduplication."
    } else {
      "Official metadata documents a 1995-1996 weekly targeted Diatoma/Phaeocystis density series, not total-community biomass; two years cannot satisfy the prespecified recurrence rule, so retain only for exploratory Phaeocystis discovery sensitivity."
    },
    exact_domain_records = geometry$exact_domain_records,
    metadata_raw_relative_path = manifest_row$raw_relative_path,
    metadata_checksum_sha256 = manifest_row$checksum_sha256,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
})
resolution <- do.call(rbind, resolution_rows)
write_csv_atomic(resolution, "metadata/stage2_emodnet_wfs_survivor_resolution.csv")

for (i in seq_len(nrow(resolution))) {
  j <- match(resolution$wfs_dataset_id[[i]], screened$wfs_dataset_id)
  if (is.na(j)) stop("Resolved WFS survivor is absent from screening state.", call. = FALSE)
  screened$record_access_state[[j]] <- "resolved"
  screened$duplicate_resolution_state[[j]] <- "resolved"
  screened$screening_decision[[j]] <- resolution$screening_decision[[i]]
  screened$required_next_action[[j]] <- if (nzchar(resolution$routed_work_item_id[[i]])) {
    "route_aggregator_copy_to_REGISTER:DS06_canonical_provider_acquisition"
  } else {
    "retain_only_as_exploratory_Phaeocystis_discovery_sensitivity"
  }
  screened$decision_detail[[j]] <- paste(
    screened$decision_detail[[j]], resolution$scientific_reason[[i]],
    sprintf("Official licence: %s.", resolution$licence_url[[i]])
  )
}
validate_stage2_wfs_queue(screened, contract, require_initial = FALSE)
write_csv_atomic(screened, "metadata/stage2_emodnet_wfs_screening.csv")
message("Resolved all three exact-domain WFS survivors: two routed to DS06; one exploratory only.")
