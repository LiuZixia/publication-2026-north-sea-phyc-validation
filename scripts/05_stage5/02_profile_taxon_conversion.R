#!/usr/bin/env Rscript
# Profile reported taxa and units, then audit possible PEG_BVOL matches without applying conversions.

source("R/00_core_setup.R")
source("R/03_stage2_contract.R")
source("R/07_stage5_contract.R")

contract <- stage5_read_source_contract()
peg_path <- "data/interim/stage5/reference/peg_bvol_2026.csv"
if (!file.exists(peg_path)) stop("Run the PEG_BVOL extraction before taxon profiling.", call. = FALSE)
peg <- utils::read.csv(peg_path, stringsAsFactors = FALSE, check.names = FALSE)
peg$aphia_integer <- suppressWarnings(as.integer(peg$AphiaID))
peg$size_class_character <- trimws(as.character(peg$SizeClassNo))
peg$carbon_pg <- suppressWarnings(as.numeric(peg$`Calculated_Carbon_pg/counting_unit`))
peg$normalized_species <- tolower(trimws(peg$Species))
peg$normalized_genus <- tolower(trimws(peg$Genus))

profile_parts <- list()
part_index <- 0L
add_profile <- function(value) {
  fields <- c("ds_id", "reported_taxon_name", "reported_aphia_id", "reported_size_class",
              "reported_lifeforms", "reported_measurement", "reported_unit")
  if (!all(fields %in% names(value))) stop("Internal Stage 5 taxon-profile schema failure.", call. = FALSE)
  for (name in fields) {
    value[[name]] <- as.character(value[[name]])
    value[[name]][is.na(value[[name]])] <- ""
  }
  key <- interaction(value[fields], drop = TRUE, lex.order = TRUE)
  groups <- split(seq_len(nrow(value)), key)
  rows <- lapply(groups, function(index) {
    row <- value[index[[1]], fields, drop = FALSE]
    row$source_row_count <- length(index)
    row
  })
  part_index <<- part_index + 1L
  profile_parts[[part_index]] <<- do.call(rbind, rows)
}

profile_stage2_identity <- function(ds_id, path) {
  stage5_stream_csv(path, function(chunk, row_number) {
    if (ds_id == "DS02") {
      required <- c("parameter", "quantity", "unit")
      if (!all(required %in% names(chunk))) stop("DS02 identity schema changed.", call. = FALSE)
      add_profile(data.frame(
        ds_id = ds_id, reported_taxon_name = chunk$parameter, reported_aphia_id = "",
        reported_size_class = "", reported_lifeforms = "",
        reported_measurement = chunk$quantity, reported_unit = chunk$unit,
        stringsAsFactors = FALSE, check.names = FALSE
      ))
    } else {
      required <- c("scientific_name", "aphia_id", "parameter", "unit")
      if (!all(required %in% names(chunk))) stop("DS06 identity schema changed.", call. = FALSE)
      add_profile(data.frame(
        ds_id = ds_id, reported_taxon_name = chunk$scientific_name,
        reported_aphia_id = chunk$aphia_id, reported_size_class = "",
        reported_lifeforms = "", reported_measurement = chunk$parameter,
        reported_unit = chunk$unit, stringsAsFactors = FALSE, check.names = FALSE
      ))
    }
  }, chunk_lines = 10000L)
}

profile_plet <- function(ds_id, path) {
  stage5_stream_csv(path, function(chunk, row_number) {
    required <- c("aphia_id", "size_class", "taxon", "abundance", "lifeforms")
    if (!all(required %in% names(chunk))) stop(sprintf("%s PLET schema changed.", ds_id), call. = FALSE)
    add_profile(data.frame(
      ds_id = ds_id, reported_taxon_name = chunk$taxon, reported_aphia_id = chunk$aphia_id,
      reported_size_class = chunk$size_class, reported_lifeforms = chunk$lifeforms,
      reported_measurement = "abundance", reported_unit = "not_reported_in_plet_export",
      stringsAsFactors = FALSE, check.names = FALSE
    ))
  }, chunk_lines = 5000L)
}

profile_stage2_identity("DS02", "data/interim/stage2_ds02_rws_duplicate_identity.csv")
profile_stage2_identity("DS06", "data/interim/stage2_ds06_smhi_shark_duplicate_identity.csv")
for (ds_id in c("DS04", "DS05", "DS07", "DS16")) {
  row <- contract[contract$ds_id == ds_id, , drop = FALSE]
  files <- stage5_resolve_source(row)$files
  csv <- files$path[grepl("[.]csv$", files$path, ignore.case = TRUE)]
  if (length(csv) != 1L) stop(sprintf("Expected one PLET payload for %s.", ds_id), call. = FALSE)
  profile_plet(ds_id, csv)
}

profile <- do.call(rbind, profile_parts)
group_fields <- setdiff(names(profile), "source_row_count")
key <- interaction(profile[group_fields], drop = TRUE, lex.order = TRUE)
groups <- split(seq_len(nrow(profile)), key)
profile <- do.call(rbind, lapply(groups, function(index) {
  row <- profile[index[[1]], group_fields, drop = FALSE]
  row$source_row_count <- sum(profile$source_row_count[index])
  row
}))
row.names(profile) <- NULL

# Candidate matching is deliberately conservative: PLET/SHARK IDs use AphiaID, while DS02 name
# matches are only diagnostics pending the required cached WoRMS resolution.
profile$match_route <- ""
profile$peg_candidate_rows <- 0L
profile$peg_carbon_pg_min <- NA_real_
profile$peg_carbon_pg_max <- NA_real_
profile$conversion_match_state <- ""
for (i in seq_len(nrow(profile))) {
  aphia <- suppressWarnings(as.integer(profile$reported_aphia_id[[i]]))
  size <- trimws(profile$reported_size_class[[i]])
  if (!is.na(aphia)) {
    candidate <- which(peg$aphia_integer == aphia)
    route <- "reported_aphia_id"
    if (length(candidate) && nzchar(size)) {
      size_candidate <- candidate[peg$size_class_character[candidate] == size]
      if (length(size_candidate)) {
        candidate <- size_candidate
        route <- "reported_aphia_id_and_size_class"
      }
    }
  } else {
    normalized <- tolower(trimws(profile$reported_taxon_name[[i]]))
    candidate <- which(nzchar(normalized) &
                       (peg$normalized_species == normalized | peg$normalized_genus == normalized))
    route <- if (length(candidate)) "reported_name_diagnostic_only" else "no_match_key"
  }
  profile$match_route[[i]] <- route
  profile$peg_candidate_rows[[i]] <- length(candidate)
  if (length(candidate)) {
    carbon <- peg$carbon_pg[candidate]
    carbon <- carbon[is.finite(carbon)]
    if (length(carbon)) {
      profile$peg_carbon_pg_min[[i]] <- min(carbon)
      profile$peg_carbon_pg_max[[i]] <- max(carbon)
    }
  }
  profile$conversion_match_state[[i]] <- if (!length(candidate)) "unmatched" else
    if (route == "reported_name_diagnostic_only") "name_candidate_requires_worms_validation" else
    if (length(candidate) == 1L) "unique_authority_row_candidate" else
      "multiple_size_or_stage_candidates"
}

summary <- do.call(rbind, lapply(stage5_required_ids()[stage5_required_ids() != "DS22"], function(ds_id) {
  x <- profile[profile$ds_id == ds_id, , drop = FALSE]
  total <- sum(x$source_row_count)
  data.frame(
    ds_id = ds_id, monitoring_network = contract$monitoring_network[match(ds_id, contract$ds_id)],
    source_rows_profiled = total, distinct_reported_taxon_keys = nrow(x),
    rows_with_reported_aphia_id = sum(x$source_row_count[nzchar(x$reported_aphia_id)]),
    rows_with_any_peg_candidate = sum(x$source_row_count[x$peg_candidate_rows > 0L]),
    rows_with_unique_peg_candidate = sum(x$source_row_count[x$conversion_match_state ==
                                                              "unique_authority_row_candidate"]),
    rows_with_multiple_candidates = sum(x$source_row_count[x$conversion_match_state ==
                                                             "multiple_size_or_stage_candidates"]),
    rows_with_name_only_candidate = sum(x$source_row_count[x$conversion_match_state ==
                                                            "name_candidate_requires_worms_validation"]),
    rows_unmatched = sum(x$source_row_count[x$conversion_match_state == "unmatched"]),
    provider_unit_state = if (ds_id %in% c("DS04", "DS05", "DS07", "DS16"))
      "unit_not_reported_in_plet_export" else "unit_preserved_from_provider",
    biomass_conversion_state = if (ds_id == "DS06") "provider_carbon_and_biovolume_routes_present" else
      "not_ready_pending_taxonomy_size_unit_and_method_audit",
    stringsAsFactors = FALSE, check.names = FALSE
  )
}))

issues <- data.frame(
  issue_id = c("S5-PLET-001", "S5-DS02-001", "S5-CONV-001"),
  ds_id = c("DS04|DS05|DS07|DS16", "DS02", "DS02|DS04|DS05|DS07|DS16"),
  issue_type = c("measurement_unit_absent", "accepted_taxonomy_unresolved",
                 "conversion_not_yet_authorized"),
  state = c("unresolved", "unresolved", "unresolved"),
  evidence = c("metadata/stage5/harmonization/taxon_conversion_summary.csv",
               "metadata/stage5/harmonization/taxon_conversion_coverage.csv",
               "metadata/stage5/harmonization/taxon_conversion_summary.csv"),
  consequence = c("cannot_normalize_plet_abundance_until_provider_unit_is_verified",
                  "do_not_treat_exact_name_diagnostics_as_accepted_taxonomy",
                  "do_not_calculate_total_biomass_or_lifeform_carbon_share"),
  stringsAsFactors = FALSE, check.names = FALSE
)

dir.create("metadata/stage5/harmonization", recursive = TRUE, showWarnings = FALSE)
write_csv_atomic(profile, "metadata/stage5/harmonization/taxon_conversion_coverage.csv")
write_csv_atomic(summary, "metadata/stage5/harmonization/taxon_conversion_summary.csv")
write_csv_atomic(issues, "metadata/stage5/harmonization/harmonization_issues.csv")
message(sprintf("Profiled %d observation rows into %d distinct reported taxon/measurement keys.",
                sum(summary$source_rows_profiled), nrow(profile)))
