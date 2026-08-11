#!/usr/bin/env Rscript
# Parse cached WoRMS responses into a versioned crosswalk while retaining match provenance.

source("R/00_core_setup.R")
source("R/03_stage2_contract.R")
required_namespace("jsonlite")

pin_path <- "metadata/stage5/taxonomy/worms_active_run.csv"
if (!file.exists(pin_path)) stop("Run the WoRMS acquisition before building the crosswalk.", call. = FALSE)
pin <- utils::read.csv(pin_path, stringsAsFactors = FALSE, check.names = FALSE)
run_dir <- file.path("data", "raw", pin$run_relative_path[[1]])
terms <- utils::read.csv(file.path(run_dir, "request_terms.csv"), stringsAsFactors = FALSE,
                         check.names = FALSE)

field <- function(record, name) {
  value <- record[[name]]
  if (is.null(value) || !length(value) || is.na(value[[1]])) "" else as.character(value[[1]])
}
normalize_name <- function(value) tolower(trimws(gsub("[[:space:]]+", " ", value)))
rows <- list(); row_index <- 0L
for (route in unique(terms$route)) {
  route_terms <- terms[terms$route == route, , drop = FALSE]
  prefix <- if (route == "reported_aphia_id") "aphia" else "name"
  for (batch in sort(unique(route_terms$batch))) {
    request <- route_terms[route_terms$batch == batch, , drop = FALSE]
    path <- file.path(run_dir, sprintf("%s_batch_%03d.json", prefix, batch))
    response <- jsonlite::fromJSON(path, simplifyVector = FALSE)
    if (length(response) != nrow(request)) {
      stop(sprintf("WoRMS response cardinality mismatch: %s", path), call. = FALSE)
    }
    for (i in seq_len(nrow(request))) {
      result <- response[[i]]
      # ID responses contain one named record. TAXAMATCH responses contain an array of zero or
      # more candidate records for each requested name; preserve every candidate and its API type.
      candidates <- if (route == "reported_aphia_id") list(result) else
        if (is.null(result) || !length(result)) list(list()) else
          if (!is.null(names(result)) && "AphiaID" %in% names(result)) list(result) else result
      for (record in candidates) {
        row_index <- row_index + 1L
        if (is.null(record) || !length(record)) record <- list()
        scientific <- field(record, "scientificname")
        valid_name <- field(record, "valid_name")
        input <- request$input_term[[i]]
        exact <- route != "reported_aphia_id" &&
          normalize_name(input) %in% c(normalize_name(scientific), normalize_name(valid_name))
        match_type <- if (route == "reported_aphia_id" && nzchar(field(record, "AphiaID")))
          "provider_aphia_id_validated" else if (route == "reported_aphia_id")
            "provider_aphia_id_unresolved" else if (exact) "exact_name_match" else
              if (nzchar(field(record, "AphiaID"))) "taxamatch_fuzzy_candidate_requires_review" else "no_match"
        rows[[row_index]] <- data.frame(
        input_route = route, input_term = input, match_type = match_type,
        api_match_type = field(record, "match_type"), AphiaID = field(record, "AphiaID"), scientificname = scientific,
        authority = field(record, "authority"), status = field(record, "status"),
        unacceptreason = field(record, "unacceptreason"), taxonRankID = field(record, "taxonRankID"),
        rank = field(record, "rank"), valid_AphiaID = field(record, "valid_AphiaID"),
        valid_name = valid_name, valid_authority = field(record, "valid_authority"),
        kingdom = field(record, "kingdom"), phylum = field(record, "phylum"),
        class = field(record, "class"), order = field(record, "order"), family = field(record, "family"),
        genus = field(record, "genus"), isMarine = field(record, "isMarine"),
        isBrackish = field(record, "isBrackish"), isFreshwater = field(record, "isFreshwater"),
        isTerrestrial = field(record, "isTerrestrial"), isExtinct = field(record, "isExtinct"),
        response_path = sub("^data/raw/", "", path), stringsAsFactors = FALSE, check.names = FALSE
        )
      }
    }
  }
}
crosswalk <- do.call(rbind, rows)
summary <- do.call(rbind, lapply(split(crosswalk, crosswalk$input_route), function(value) data.frame(
  input_route = value$input_route[[1]], requested_terms = length(unique(value$input_term)),
  returned_candidate_rows = nrow(value),
  provider_id_validated = length(unique(value$input_term[value$match_type == "provider_aphia_id_validated"])),
  exact_name_matches = length(unique(value$input_term[value$match_type == "exact_name_match"])),
  fuzzy_candidates = length(unique(value$input_term[value$match_type ==
                                                        "taxamatch_fuzzy_candidate_requires_review"])),
  unresolved = length(unique(value$input_term[value$match_type %in%
                                                c("provider_aphia_id_unresolved", "no_match")])),
  stringsAsFactors = FALSE, check.names = FALSE
)))
row.names(summary) <- NULL
dir.create("metadata/stage5/taxonomy", recursive = TRUE, showWarnings = FALSE)
write_csv_atomic(crosswalk, "metadata/stage5/taxonomy/worms_taxonomy_crosswalk.csv")
write_csv_atomic(summary, "metadata/stage5/taxonomy/worms_taxonomy_summary.csv")
message(sprintf("WoRMS crosswalk built for %d reported identifiers/names.", nrow(crosswalk)))
