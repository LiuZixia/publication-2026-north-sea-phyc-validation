#!/usr/bin/env Rscript
# Resolve reported taxonomy to accepted WoRMS identifiers and audit PEG_BVOL conversion readiness.

source("R/00_core_setup.R")
source("R/03_stage2_contract.R")
source("R/07_stage5_contract.R")

profile_path <- "metadata/stage5/harmonization/taxon_conversion_coverage.csv"
taxonomy_path <- "metadata/stage5/taxonomy/worms_taxonomy_crosswalk.csv"
peg_path <- "data/interim/stage5/reference/peg_bvol_2026.csv"
if (any(!file.exists(c(profile_path, taxonomy_path, peg_path)))) {
  stop("Stage 5 taxonomy, taxon profile, or PEG_BVOL input is missing.", call. = FALSE)
}

profile <- utils::read.csv(profile_path, stringsAsFactors = FALSE, check.names = FALSE)
taxonomy <- utils::read.csv(taxonomy_path, stringsAsFactors = FALSE, check.names = FALSE)
peg <- utils::read.csv(peg_path, stringsAsFactors = FALSE, check.names = FALSE)

# A provider AphiaID is accepted only after WoRMS validation. A reported name is accepted only when
# TAXAMATCH returned one exact valid identifier; fuzzy candidates remain unresolved for review.
valid_ids <- taxonomy[taxonomy$input_route == "reported_aphia_id" &
                        taxonomy$match_type == "provider_aphia_id_validated", , drop = FALSE]
valid_ids$accepted_aphia_id <- ifelse(nzchar(valid_ids$valid_AphiaID),
                                      valid_ids$valid_AphiaID, valid_ids$AphiaID)
valid_ids <- valid_ids[!duplicated(valid_ids$input_term),
                       c("input_term", "accepted_aphia_id", "valid_name", "rank", "status")]

exact <- taxonomy[taxonomy$input_route == "ds02_taxamatch_name" &
                    taxonomy$match_type == "exact_name_match", , drop = FALSE]
exact$accepted_aphia_id <- ifelse(nzchar(exact$valid_AphiaID), exact$valid_AphiaID, exact$AphiaID)
exact_key <- split(seq_len(nrow(exact)), exact$input_term)
exact_rows <- lapply(exact_key, function(index) {
  candidates <- unique(exact$accepted_aphia_id[index][nzchar(exact$accepted_aphia_id[index])])
  if (length(candidates) != 1L) return(NULL)
  chosen <- index[match(candidates[[1]], exact$accepted_aphia_id[index])]
  data.frame(input_term = exact$input_term[[chosen]], accepted_aphia_id = candidates[[1]],
             valid_name = exact$valid_name[[chosen]], rank = exact$rank[[chosen]],
             status = exact$status[[chosen]], stringsAsFactors = FALSE, check.names = FALSE)
})
exact_names <- do.call(rbind, exact_rows[!vapply(exact_rows, is.null, logical(1))])
row.names(exact_names) <- NULL

profile$accepted_aphia_id <- ""
profile$accepted_name <- ""
profile$accepted_rank <- ""
profile$taxonomy_resolution_state <- ""
has_text <- function(value) !is.na(value) & nzchar(trimws(as.character(value)))
for (i in seq_len(nrow(profile))) {
  if (has_text(profile$reported_aphia_id[[i]])) {
    position <- match(profile$reported_aphia_id[[i]], valid_ids$input_term)
    if (!is.na(position)) {
      profile$accepted_aphia_id[[i]] <- valid_ids$accepted_aphia_id[[position]]
      profile$accepted_name[[i]] <- valid_ids$valid_name[[position]]
      profile$accepted_rank[[i]] <- valid_ids$rank[[position]]
      profile$taxonomy_resolution_state[[i]] <- "provider_aphia_id_validated_by_worms"
    } else {
      profile$taxonomy_resolution_state[[i]] <- "provider_aphia_id_unresolved"
    }
  } else {
    position <- match(profile$reported_taxon_name[[i]], exact_names$input_term)
    if (!is.na(position)) {
      profile$accepted_aphia_id[[i]] <- exact_names$accepted_aphia_id[[position]]
      profile$accepted_name[[i]] <- exact_names$valid_name[[position]]
      profile$accepted_rank[[i]] <- exact_names$rank[[position]]
      profile$taxonomy_resolution_state[[i]] <- "reported_name_exactly_resolved_by_worms"
    } else if (profile$reported_taxon_name[[i]] %in%
               taxonomy$input_term[taxonomy$match_type == "taxamatch_fuzzy_candidate_requires_review"]) {
      profile$taxonomy_resolution_state[[i]] <- "worms_fuzzy_candidate_requires_review"
    } else {
      profile$taxonomy_resolution_state[[i]] <- "reported_name_unresolved"
    }
  }
}

peg$accepted_aphia_id <- trimws(as.character(peg$AphiaID))
peg$authority_size_class <- trimws(as.character(peg$SizeClassNo))
peg$authority_carbon_pg <- suppressWarnings(as.numeric(peg$`Calculated_Carbon_pg/counting_unit`))
profile$authority_candidate_rows <- 0L
profile$authority_match_route <- ""
profile$candidate_carbon_pg_lower <- NA_real_
profile$candidate_carbon_pg_central <- NA_real_
profile$candidate_carbon_pg_upper <- NA_real_
profile$conversion_readiness_state <- ""

for (i in seq_len(nrow(profile))) {
  accepted <- profile$accepted_aphia_id[[i]]
  if (!has_text(accepted)) {
    profile$authority_match_route[[i]] <- "no_accepted_taxonomy"
    profile$conversion_readiness_state[[i]] <- "not_ready_taxonomy_unresolved"
    next
  }
  candidate <- which(peg$accepted_aphia_id == accepted)
  route <- "accepted_aphia_id"
  size <- trimws(profile$reported_size_class[[i]])
  if (length(candidate) && has_text(size)) {
    sized <- candidate[peg$authority_size_class[candidate] == size]
    if (length(sized)) {
      candidate <- sized
      route <- "accepted_aphia_id_and_reported_size_class"
    }
  }
  profile$authority_match_route[[i]] <- route
  profile$authority_candidate_rows[[i]] <- length(candidate)
  carbon <- peg$authority_carbon_pg[candidate]
  carbon <- carbon[is.finite(carbon)]
  if (length(carbon)) {
    profile$candidate_carbon_pg_lower[[i]] <- min(carbon)
    profile$candidate_carbon_pg_upper[[i]] <- max(carbon)
    if (length(candidate) == 1L) profile$candidate_carbon_pg_central[[i]] <- carbon[[1]]
  }
  if (!length(candidate)) {
    state <- "not_ready_no_peg_authority_row"
  } else if (length(candidate) > 1L) {
    state <- "not_ready_multiple_size_or_stage_authority_rows"
  } else if (profile$ds_id[[i]] %in% c("DS04", "DS05", "DS07", "DS16")) {
    state <- "candidate_only_plet_unit_and_method_unresolved"
  } else if (profile$ds_id[[i]] == "DS02") {
    state <- "candidate_only_measurement_size_method_and_uncertainty_unresolved"
  } else if (profile$ds_id[[i]] == "DS06" &&
             grepl("carbon", profile$reported_measurement[[i]], ignore.case = TRUE)) {
    state <- "provider_carbon_route_conversion_not_required"
  } else if (profile$ds_id[[i]] == "DS06" &&
             grepl("biovolume", profile$reported_measurement[[i]], ignore.case = TRUE)) {
    state <- "provider_biovolume_route_requires_registered_carbon_equation"
  } else {
    state <- "candidate_only_method_and_uncertainty_unresolved"
  }
  profile$conversion_readiness_state[[i]] <- state
}

contract <- stage5_read_source_contract()
summary <- do.call(rbind, lapply(stage5_required_ids()[stage5_required_ids() != "DS22"], function(ds_id) {
  x <- profile[profile$ds_id == ds_id, , drop = FALSE]
  accepted <- has_text(x$accepted_aphia_id)
  unique_authority <- x$authority_candidate_rows == 1L
  data.frame(
    ds_id = ds_id, monitoring_network = contract$monitoring_network[match(ds_id, contract$ds_id)],
    source_rows_profiled = sum(x$source_row_count),
    rows_with_accepted_taxonomy = sum(x$source_row_count[accepted]),
    rows_with_unique_authority_row = sum(x$source_row_count[accepted & unique_authority]),
    rows_with_ambiguous_authority_rows = sum(x$source_row_count[accepted & x$authority_candidate_rows > 1L]),
    rows_without_authority_row = sum(x$source_row_count[accepted & x$authority_candidate_rows == 0L]),
    rows_with_unresolved_taxonomy = sum(x$source_row_count[!accepted]),
    rows_authorized_for_abundance_conversion = 0L,
    readiness_state = if (ds_id == "DS06")
      "provider_carbon_preserved_but_sample_completeness_not_yet_established" else
      "conversion_candidates_audited_none_authorized",
    stringsAsFactors = FALSE, check.names = FALSE
  )
}))
row.names(summary) <- NULL

# Update the issue log only with states demonstrated by this later taxonomy/conversion audit.
issues_path <- "metadata/stage5/harmonization/harmonization_issues.csv"
issues <- utils::read.csv(issues_path, stringsAsFactors = FALSE, check.names = FALSE)
position <- match("S5-DS02-001", issues$issue_id)
issues$state[[position]] <- "partly_resolved_exact_worms_matches_fuzzy_and_unresolved_retained"
issues$evidence[[position]] <- "metadata/stage5/taxonomy/worms_taxonomy_summary.csv"
issues$consequence[[position]] <- "accept_exact_matches_only_and_retain_fuzzy_or_unmatched_names_for_review"
issues <- issues[!issues$issue_id %in% c("S5-CONV-002", "S5-METHOD-001"), , drop = FALSE]
issues <- rbind(
  issues,
  data.frame(
    issue_id = "S5-CONV-002", ds_id = "DS02|DS04|DS05|DS06|DS07|DS16",
    issue_type = "conversion_uncertainty_rule_not_registered", state = "unresolved",
    evidence = "metadata/stage5/harmonization/conversion_readiness_summary.csv",
    consequence = "candidate_envelopes_are_diagnostic_only_and_no_lower_central_upper_reference_series_exists",
    stringsAsFactors = FALSE, check.names = FALSE
  ),
  data.frame(
    issue_id = "S5-METHOD-001", ds_id = "DS02|DS04|DS05|DS06|DS07|DS16",
    issue_type = "sample_method_epoch_and_completeness_unresolved", state = "unresolved",
    evidence = "metadata/stage5/harmonization/sample_method_completeness_summary.csv",
    consequence = "no_sample_can_be_authorized_for_total_biomass_outcomes",
    stringsAsFactors = FALSE, check.names = FALSE
  )
)

write_csv_atomic(profile, "metadata/stage5/harmonization/conversion_readiness_by_taxon.csv")
write_csv_atomic(summary, "metadata/stage5/harmonization/conversion_readiness_summary.csv")
write_csv_atomic(issues, issues_path)
message(sprintf("Audited accepted taxonomy and PEG_BVOL readiness for %d observation rows; zero abundance rows authorized for conversion.",
                sum(summary$source_rows_profiled)))
