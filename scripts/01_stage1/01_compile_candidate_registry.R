# Compile evidence-linked Stage 1 dataset metadata from the pinned immutable search runs.

source("R/01_search_helpers.R")
source("R/01_registry_identity.R")
required_namespace("jsonlite")
verify_raw_data_target(0.01)

active <- utils::read.csv("metadata/stage1/search/active_runs.csv", stringsAsFactors = FALSE, check.names = FALSE)
expected_keys <- c("PLET", "ICES_DOME", "EMODNET_ERDDAP", "OBIS", "SMHI_SHARK", "PANGAEA",
                   "GBIF", "MARINE_SCOTLAND", "CEFAS_DASSH", "ICES_FIGSHARE")
if (!setequal(active$source_key, expected_keys) || anyDuplicated(active$source_key)) {
  stop("Active-run registry must pin exactly one successful run for every required source key.", call. = FALSE)
}

# Later searches are append-only updates with their own frozen configuration. They are pinned in a
# separate registry so the ten-run initial execution and the checksum embedded in those summaries
# remain unchanged and auditable.
append_path <- "metadata/stage1/search/append_runs.csv"
append <- if (file.exists(append_path)) {
  utils::read.csv(append_path, stringsAsFactors = FALSE, check.names = FALSE)
} else {
  data.frame(source_key = character(), search_run_id = character(), configuration_path = character(),
             stringsAsFactors = FALSE)
}
if (nrow(append)) {
  if (!identical(names(append), c("source_key", "search_run_id", "configuration_path")) ||
      any(!append$source_key %in% "EMODNET_BIOLOGY_WFS") || anyDuplicated(append$search_run_id) ||
      any(!file.exists(append$configuration_path))) {
    stop("Stage 1 append-run registry is malformed or references an unsupported update.", call. = FALSE)
  }
}
runs <- rbind(
  data.frame(active, configuration_path = "config/stage1_search_config.json", stringsAsFactors = FALSE),
  append
)

manifest_list <- lapply(seq_len(nrow(runs)), function(i) {
  id <- runs$search_run_id[[i]]
  path <- file.path("data", "raw", "search_runs", id, "manifest.csv")
  summary_path <- file.path("data", "raw", "search_runs", id, "run_summary.json")
  if (!file.exists(path) || !file.exists(summary_path)) stop(sprintf("Missing completed manifest for %s.", id), call. = FALSE)
  summary <- jsonlite::fromJSON(summary_path, simplifyVector = FALSE)
  if (!identical(summary$status, "complete") || !isTRUE(summary$pagination_complete)) stop(sprintf("Run is not complete: %s", id), call. = FALSE)
  if (!identical(summary$configuration_path, runs$configuration_path[[i]]) ||
      !identical(summary$configuration_checksum_sha256, calculate_checksum(runs$configuration_path[[i]]))) {
    stop(sprintf("Search configuration provenance mismatch for %s.", id), call. = FALSE)
  }
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
})
query_log <- do.call(rbind, manifest_list)
utils::write.csv(query_log, "metadata/stage1/search/query_log.csv", row.names = FALSE, na = "")

# Provider payloads are UTF-8, but this pipeline runs under the C locale, where R leaves such
# strings marked "unknown". perl=TRUE matching then cannot translate any row carrying a non-ASCII
# character (for example the NLWKN German provider names) and silently declines to match it, which
# would let a known-item benchmark go unrecalled without any failure being raised.
as_utf8 <- function(x) {
  x <- as.character(x)
  Encoding(x) <- "UTF-8"
  x
}

scalar <- function(x, default = "") {
  if (is.null(x) || !length(x) || all(is.na(x))) return(default)
  value <- x[[1]]
  if (is.list(value)) return(paste(unlist(value), collapse = "; "))
  as.character(value)
}
plain_text <- function(x) {
  x <- as_utf8(scalar(x))
  x <- gsub("<[^>]+>", " ", x, perl = TRUE)
  x <- gsub("&amp;", "&", x, fixed = TRUE)
  x <- gsub("&quot;|&#34;", "\"", x, perl = TRUE)
  x <- gsub("&#39;|&apos;", "'", x, perl = TRUE)
  x <- gsub("&lt;", "<", x, fixed = TRUE); x <- gsub("&gt;", ">", x, fixed = TRUE)
  trimws(gsub("[[:space:]]+", " ", x))
}
extract_xml <- function(xml, tag) {
  pattern <- sprintf("(?s)<(?:[[:alnum:]_]+:)?%s(?: [^>]*)?>(.*?)</(?:[[:alnum:]_]+:)?%s>", tag, tag)
  hit <- regmatches(xml, regexec(pattern, xml, perl = TRUE))[[1]]
  if (length(hit) >= 2L) plain_text(hit[[2]]) else ""
}
join_values <- function(x) {
  if (is.null(x) || !length(x)) return("")
  trimws(paste(unique(as.character(unlist(x))), collapse = "; "))
}
manifest_for <- function(run_id, filename_pattern = NULL, raw_path = NULL, prefer_label = NULL) {
  m <- query_log[query_log$search_run_id == run_id, , drop = FALSE]
  if (!is.null(raw_path)) m <- m[m$raw_response_path == raw_path, , drop = FALSE]
  if (!is.null(filename_pattern)) m <- m[grepl(filename_pattern, basename(m$raw_response_path), perl = TRUE), , drop = FALSE]
  if (!is.null(prefer_label)) {
    preferred <- m[m$query_label == prefer_label, , drop = FALSE]
    if (nrow(preferred)) m <- preferred
  }
  if (!nrow(m)) stop(sprintf("No manifest evidence row for %s / %s.", run_id, filename_pattern %||% raw_path), call. = FALSE)
  m[1, , drop = FALSE]
}
new_candidate <- function(evidence, provider_dataset_id, catalogue_id = provider_dataset_id, title,
                          doi_or_stable_url = "", version = "", geographic_metadata = "",
                          temporal_metadata = "", measurement_types = "", taxonomic_content = "",
                          method_metadata = "unknown at dataset-discovery stage", access_status = "unknown",
                          license = evidence$license, related_identifier = "") {
  data.frame(
    search_run_id = evidence$search_run_id,
    source = evidence$source_family,
    endpoint = evidence$endpoint,
    api_version = evidence$api_version,
    query_hash_sha256 = evidence$query_hash_sha256,
    execution_time_utc = evidence$retrieved_utc,
    raw_response_path = evidence$raw_response_path,
    raw_response_checksum_sha256 = evidence$checksum_sha256,
    provider_dataset_id = as.character(provider_dataset_id),
    catalogue_id = as.character(catalogue_id),
    title = plain_text(title),
    doi_or_stable_url = as.character(doi_or_stable_url),
    version = as.character(version),
    geographic_metadata = plain_text(geographic_metadata),
    temporal_metadata = plain_text(temporal_metadata),
    measurement_types = plain_text(measurement_types),
    taxonomic_content = plain_text(taxonomic_content),
    method_metadata = plain_text(method_metadata),
    access_status = plain_text(access_status),
    license = plain_text(license),
    related_identifier = as.character(related_identifier),
    stringsAsFactors = FALSE
  )
}

occurrences <- list()
add <- function(x) occurrences[[length(occurrences) + 1L]] <<- x
run_id <- function(key) active$search_run_id[match(key, active$source_key)]

# PLET publishes a complete HTML catalogue table with provider, dataset, access, and DOI.
rid <- run_id("PLET"); ev <- manifest_for(rid, "catalogue\\.html$")
html <- as_utf8(paste(readLines(file.path("data", "raw", ev$raw_response_path), warn = FALSE), collapse = "\n"))
trs <- regmatches(html, gregexpr("(?s)<tr[^>]*>.*?</tr>", html, perl = TRUE))[[1]]
for (tr in trs) {
  cells <- regmatches(tr, gregexpr("(?s)<td[^>]*>.*?</td>", tr, perl = TRUE))[[1]]
  # Accept every catalogue data row. Requiring a DOI cell here silently discarded seven real
  # PLET datasets whose DOI column reads "No DOI", including the restricted German coastal
  # series OSPAR_LLUR-SH_2010-2020 (DS17) and the public Environment Agency chlorophyll series.
  # Restricted holdings are the least likely to carry a DOI and the most important to record,
  # so a DOI filter biases discovery against exactly the gap-filling datasets the study needs.
  if (length(cells) != 5L) next
  cells <- vapply(cells, plain_text, character(1))
  doi <- regmatches(cells[[5]], regexpr("10\\.[^[:space:]]+", cells[[5]], perl = TRUE))
  if (!length(doi)) doi <- ""
  add(new_candidate(ev, cells[[3]], paste(cells[[1]], cells[[2]], cells[[3]], sep = ":"), cells[[3]],
    if (nzchar(doi)) paste0("https://doi.org/", doi) else "", geographic_metadata = cells[[1]],
    measurement_types = cells[[3]], taxonomic_content = cells[[3]], access_status = cells[[4]], license = "per underlying PLET dataset"))
}

# DOME is a data service rather than a dataset catalogue, so one discovery-level service row is retained.
rid <- run_id("ICES_DOME"); ev <- manifest_for(rid, "phytoplankton_view\\.html$")
add(new_candidate(ev, "ICES-DOME-PHYTOPLANKTON", "ICES-DOME-PHYTOPLANKTON",
  "ICES DOME phytoplankton community data service", "https://dome.ices.dk/views/phytoplankton.aspx",
  version = "cache timestamp archived in same search run", geographic_metadata = "ICES/OSPAR/HELCOM marine submissions",
  temporal_metadata = "available years archived in same search run", measurement_types = "community parameters",
  taxonomic_content = "phytoplankton", access_status = "public API and download view", license = "CC BY 4.0"))

# ERDDAP rows are a stable dataset-level table; retain the first raw evidence hit per later deduplicated ID.
rid <- run_id("EMODNET_ERDDAP")
for (ev_i in which(query_log$search_run_id == rid & query_log$http_status == 200L)) {
  ev <- query_log[ev_i, , drop = FALSE]; x <- jsonlite::fromJSON(file.path("data", "raw", ev$raw_response_path), simplifyVector = FALSE)
  cols <- unlist(x$table$columnNames); pos <- function(name) match(name, cols)
  for (z in x$table$rows) {
    id <- scalar(z[[pos("Dataset ID")]]); title <- scalar(z[[pos("Title")]]); summary <- scalar(z[[pos("Summary")]])
    add(new_candidate(ev, id, id, title, paste0("https://erddap.emodnet.eu/erddap/info/", id, "/index.html"),
      geographic_metadata = summary, temporal_metadata = summary, measurement_types = summary,
      taxonomic_content = paste(ev$query_label, summary), method_metadata = summary,
      access_status = "public ERDDAP", license = "per ERDDAP dataset"))
  }
}

# The direct Dataportal WFS append retrieves the complete EurOBIS dataset inventory. It is not
# assumed to be biologically or geographically in scope: names are screened locally below, and
# every unmatched relevant title remains visible as a new candidate.
if (nrow(append)) {
  for (rid in append$search_run_id[append$source_key == "EMODNET_BIOLOGY_WFS"]) {
    for (ev_i in which(query_log$search_run_id == rid & grepl("dataset_catalogue_page_", query_log$raw_response_path))) {
      ev <- query_log[ev_i, , drop = FALSE]
      x <- jsonlite::fromJSON(file.path("data", "raw", ev$raw_response_path), simplifyVector = FALSE)
      for (feature in x$features) {
        z <- feature$properties
        id <- scalar(z$id)
        stable_url <- build_query_url(ev$endpoint, c(
          service = "WFS", version = "2.0.0", request = "GetFeature",
          typeNames = "Dataportal:eurobis_datasets", outputFormat = "application/json",
          CQL_FILTER = paste0("id=", id)
        ))
        add(new_candidate(ev, id, paste0("EurOBIS-WFS:", id), z$name, stable_url,
          geographic_metadata = "Complete EurOBIS dataset inventory; record-level coverage not asserted",
          measurement_types = z$name, taxonomic_content = z$name,
          method_metadata = "Dataportal:eurobis_datasets WFS inventory; occurrence schema archived in the same run",
          access_status = "public EMODnet Biology WFS metadata", license = ev$license,
          related_identifier = paste0("EurOBIS dataset id ", id)))
      }
    }
  }
}

# OBIS applies the frozen polygon server-side and returns dataset metadata in one response per clade.
rid <- run_id("OBIS")
for (ev_i in which(query_log$search_run_id == rid)) {
  ev <- query_log[ev_i, , drop = FALSE]; x <- jsonlite::fromJSON(file.path("data", "raw", ev$raw_response_path), simplifyVector = FALSE)
  for (z in x$results) add(new_candidate(ev, z$id, z$id, z$title, z$url,
    version = z$updated, geographic_metadata = z$extent, temporal_metadata = paste(z$published, z$updated, sep = "; "),
    measurement_types = paste(z$abstract, join_values(names(z$statistics)), sep = "; "),
    taxonomic_content = paste(ev$query_label, join_values(lapply(z$keywords, `[[`, "name"))),
    method_metadata = paste("Darwin Core", z$core, join_values(z$extensions), sep = "; "), access_status = "public OBIS/EurOBIS metadata and archive",
    license = z$intellectualrights, related_identifier = z$archive))
}

# SHARK returns the complete provider dataset list for the Phytoplankton datatype.
rid <- run_id("SMHI_SHARK"); ev <- manifest_for(rid, "phytoplankton\\.json$")
x <- jsonlite::fromJSON(file.path("data", "raw", ev$raw_response_path), simplifyVector = FALSE)
for (z in x) add(new_candidate(ev, z$dataset_name, z$dataset_name, z$dataset_name,
  paste0("https://shark.smhi.se/api/dataset/get/", utils::URLencode(z$dataset_file_name, reserved = TRUE)),
  version = z$version, geographic_metadata = z$dataset_name, temporal_metadata = z$dataset_name,
  measurement_types = z$datatype, taxonomic_content = "phytoplankton", access_status = "public SHARK API", license = "CC0 metadata; delivered-file terms require confirmation"))

# PANGAEA XML embedded in the unchanged response supplies readable titles and provider metadata.
rid <- run_id("PANGAEA")
for (ev_i in which(query_log$search_run_id == rid)) {
  ev <- query_log[ev_i, , drop = FALSE]; x <- jsonlite::fromJSON(file.path("data", "raw", ev$raw_response_path), simplifyVector = FALSE)
  for (hit in x$hits$hits) {
    z <- hit$`_source`; xml <- scalar(z$xml); title <- extract_xml(xml, "title")
    if (!nzchar(title)) title <- paste("PANGAEA dataset", hit$`_id`)
    geo <- paste(c(z$westBoundLongitude, z$southBoundLatitude, z$eastBoundLongitude, z$northBoundLatitude, join_values(z$`agg-location`)), collapse = "; ")
    add(new_candidate(ev, hit$`_id`, paste0("PANGAEA.", hit$`_id`), title, z$URI,
      version = z$`sp-lastModified`, geographic_metadata = geo, temporal_metadata = paste(z$minDateTime, z$maxDateTime, sep = "; "),
      measurement_types = join_values(c(z$techKeyword, z$`agg-topic`)), taxonomic_content = ev$query_label,
      method_metadata = join_values(z$`agg-method`), access_status = paste0("PANGAEA data status ", scalar(z$`sp-dataStatus`)),
      license = extract_xml(xml, "license"), related_identifier = paste(z$parentURI, scalar(z$parentIdDataSet), sep = "; ")))
  }
}

# GBIF has no dataset-level spatial filter; the archived search terms are retained for later geographic screening.
rid <- run_id("GBIF")
for (ev_i in which(query_log$search_run_id == rid)) {
  ev <- query_log[ev_i, , drop = FALSE]; x <- jsonlite::fromJSON(file.path("data", "raw", ev$raw_response_path), simplifyVector = FALSE)
  for (z in x$results) add(new_candidate(ev, z$key, z$key, z$title,
    if (nzchar(scalar(z$doi))) paste0("https://doi.org/", z$doi) else paste0("https://www.gbif.org/dataset/", z$key),
    version = z$modified, geographic_metadata = paste(z$publishingCountry, z$description, sep = "; "),
    temporal_metadata = join_values(z$decades), measurement_types = z$description,
    taxonomic_content = paste(ev$query_label, join_values(z$keywords), sep = "; "),
    method_metadata = scalar(z$type), access_status = "public GBIF metadata", license = z$license))
}

# The Scottish DKAN route is a complete catalogue; title-level relevance is screened below.
rid <- run_id("MARINE_SCOTLAND")
for (ev_i in which(query_log$search_run_id == rid & query_log$records_returned > 0L)) {
  ev <- query_log[ev_i, , drop = FALSE]; x <- jsonlite::fromJSON(file.path("data", "raw", ev$raw_response_path), simplifyVector = FALSE)
  for (z in x) add(new_candidate(ev, z$nid, z$uuid, z$title,
    sub("/api/dataset/node/", "/dataset/", z$uri, fixed = TRUE), version = z$vid,
    geographic_metadata = "Scotland catalogue; exact coverage pending record-level screening",
    temporal_metadata = paste("created", z$created, "changed", z$changed), measurement_types = z$title,
    taxonomic_content = z$title, access_status = if (z$status == "1") "published catalogue record" else "unpublished catalogue record",
    license = "per dataset record"))
}

# Cefas holdings query results contain stable holding/version IDs and direct self links.
rid <- run_id("CEFAS_DASSH")
for (ev_i in which(query_log$search_run_id == rid & grepl("query_", query_log$raw_response_path))) {
  ev <- query_log[ev_i, , drop = FALSE]; x <- jsonlite::fromJSON(file.path("data", "raw", ev$raw_response_path), simplifyVector = FALSE)
  for (z in x$items) add(new_candidate(ev, z$id, paste0(z$id, ":", z$versionId), z$title,
    scalar(z$links$Self$href, paste0("https://data.cefas.co.uk/view/", z$id)), version = z$versionId,
    geographic_metadata = z$title, temporal_metadata = z$startDate,
    measurement_types = paste(ev$query_label, join_values(lapply(z$recordsets, `[[`, "name")), sep = "; "),
    taxonomic_content = z$title, method_metadata = join_values(lapply(z$recordsets, `[[`, "description")),
    access_status = z$status, license = "OGL metadata; recordset licence requires confirmation"))
}

# Figshare cursor pages form a complete ICES Library catalogue. Direct benchmark records supersede cursor copies as evidence.
rid <- run_id("ICES_FIGSHARE")
fig_rows <- list()
for (ev_i in which(query_log$search_run_id == rid & grepl("ices_library_page_", query_log$raw_response_path))) {
  ev <- query_log[ev_i, , drop = FALSE]; x <- jsonlite::fromJSON(file.path("data", "raw", ev$raw_response_path), simplifyVector = FALSE)
  for (z in x) fig_rows[[length(fig_rows) + 1L]] <- new_candidate(ev, z$id, z$id, z$title,
    if (nzchar(scalar(z$doi))) paste0("https://doi.org/", z$doi) else z$url_public_html,
    version = sub(".*\\.v", "", scalar(z$doi)), temporal_metadata = paste(z$published_date, z$modified_date, sep = "; "),
    measurement_types = z$defined_type_name, taxonomic_content = z$title, access_status = "public ICES Library article", license = "per article")
}
for (label in c("DS22", "DS24")) {
  ev <- manifest_for(rid, paste0(tolower(label), "_article\\.json$")); z <- jsonlite::fromJSON(file.path("data", "raw", ev$raw_response_path), simplifyVector = FALSE)
  add(new_candidate(ev, z$id, z$id, z$title, z$url_public_html, version = z$version,
    temporal_metadata = paste(z$published_date, z$modified_date, sep = "; "), measurement_types = paste(z$defined_type_name, z$description),
    taxonomic_content = paste(join_values(z$tags), join_values(z$keywords)), access_status = "public ICES Library article", license = scalar(z$license$name, "per article")))
}
for (z in fig_rows) add(z)
ev <- manifest_for(rid, "PEG_BVOL_2025\\.zip$")
add(new_candidate(ev, "PEG_BVOL_2025", "DS22-CONVERSION-AUTHORITY", "HELCOM EG PHYTO PEG_BVOL biovolume conversion file",
  ev$endpoint, version = "provider current file acquired 2026-08-08", geographic_metadata = "HELCOM/North Sea taxon conversion authority",
  measurement_types = "taxon geometric shapes, size classes, and biovolume coefficients", taxonomic_content = "phytoplankton taxa",
  method_metadata = "provider ZIP validated and checksummed", access_status = "public direct download", license = ev$license, related_identifier = "Figshare article 27900237"))

identified <- do.call(rbind, occurrences)
if (!nrow(identified)) stop("No candidate metadata were parsed.", call. = FALSE)

# Collapse repeated query hits within a provider while preferring direct benchmark evidence.
key <- paste(identified$source, identified$provider_dataset_id, sep = "::")
registry <- identified[!duplicated(key), , drop = FALSE]
rownames(registry) <- NULL

# Conservative dataset-level screening: only clearly irrelevant catalogue rows are excluded here.
cfg <- jsonlite::fromJSON("config/stage1_search_config.json", simplifyVector = FALSE)
rules <- stage1_screening_rules()
geo_pattern <- stage1_pattern(cfg$geographic_scope$terms)

scope_text <- tolower(paste(registry$title, registry$measurement_types, registry$taxonomic_content))
geo_text <- tolower(paste(registry$title, registry$geographic_metadata))

scope_guaranteed <- vapply(rules$biological_scope$scope_guaranteed_sources, `[[`, character(1), "source")
relevant <- registry$source %in% scope_guaranteed |
  grepl(stage1_pattern(rules$biological_scope$terms), scope_text, perl = TRUE)

# Demonstrate rather than assume the relationship between the direct WFS inventory and the
# previously searched catalogues. Exact normalized-title equality is conservative: it records
# positive overlap without claiming that similarly named holdings are identical.
wfs_idx <- which(registry$source == "EMODnet Biology WFS")
other_idx <- which(registry$source != "EMODnet Biology WFS")
if (length(wfs_idx)) {
  normalized <- stage1_norm_title(registry$title)
  existing_by_title <- split(other_idx[nzchar(normalized[other_idx])], normalized[other_idx][nzchar(normalized[other_idx])])
  overlap_rows <- lapply(wfs_idx, function(i) {
    matches <- existing_by_title[[normalized[[i]]]]
    if (is.null(matches)) matches <- integer()
    obis_matches <- matches[registry$source[matches] == "OBIS"]
    data.frame(
      search_run_id = registry$search_run_id[[i]],
      wfs_dataset_id = registry$provider_dataset_id[[i]],
      wfs_dataset_name = registry$title[[i]],
      normalized_title = normalized[[i]],
      exact_title_match_existing = length(matches) > 0L,
      exact_title_match_obis = length(obis_matches) > 0L,
      matched_existing_sources = paste(sort(unique(registry$source[matches])), collapse = ";"),
      matched_existing_provider_ids = paste(sort(unique(registry$provider_dataset_id[matches])), collapse = ";"),
      biological_title_match = relevant[[i]],
      disposition = if (length(matches)) "catalogue_overlap_demonstrated" else if (relevant[[i]])
        "new_title_candidate_retained" else "unmatched_outside_biological_scope_at_dataset_metadata_screen",
      stringsAsFactors = FALSE
    )
  })
  overlap <- do.call(rbind, overlap_rows)
  utils::write.csv(overlap, "metadata/stage1/search/emodnet_wfs_overlap.csv", row.names = FALSE, na = "")
  overlap_summary <- data.frame(
    metric = c("wfs_dataset_inventory_rows", "exact_title_matches_any_archived_catalogue",
               "exact_title_matches_obis", "biological_title_candidates",
               "unmatched_biological_title_candidates"),
    count = c(nrow(overlap), sum(overlap$exact_title_match_existing), sum(overlap$exact_title_match_obis),
              sum(overlap$biological_title_match),
              sum(overlap$biological_title_match & !overlap$exact_title_match_existing)),
    generated_from = "pinned Dataportal:eurobis_datasets WFS responses and normalized titles in the Stage 1 registry",
    stringsAsFactors = FALSE
  )
  utils::write.csv(overlap_summary, "metadata/stage1/search/emodnet_wfs_overlap_summary.csv", row.names = FALSE)
}

conversion <- registry$provider_dataset_id == "PEG_BVOL_2025"
registry$screening_status <- ifelse(conversion, "advanced_to_acquisition", ifelse(relevant, "pending", "excluded"))
registry$exclusion_reason <- ifelse(registry$screening_status == "excluded", "outside_biological_scope_at_dataset_metadata_screen", "")

# Geography is recorded, not enforced, at dataset level. Only OBIS applies the frozen polygon
# server-side; every other family returns catalogue metadata whose stated coverage cannot prove
# where the underlying records lie. Stage 2 performs the record-level domain intersection, so
# this column hands that step an explicit state per row instead of an undifferentiated backlog.
registry$geographic_screen_state <- ifelse(
  registry$source == "OBIS", "in_domain_by_server_side_query_geometry",
  ifelse(grepl(geo_pattern, geo_text, perl = TRUE), "dataset_metadata_matches_frozen_domain_terms",
    ifelse(grepl(stage1_pattern(rules$geographic_screen$out_of_domain_terms), geo_text, perl = TRUE),
      "dataset_metadata_indicates_out_of_domain",
      "dataset_metadata_lacks_domain_evidence")))

review <- jsonlite::fromJSON("config/scientific_review.json", simplifyVector = FALSE)$stage1_search_strategy
registry$reviewer <- sprintf("automated_prespecified_metadata_screen; %s by %s; independent_second_review_%s",
  review$review_type, review$reviewer, review$independent_review$status)
registry$decision_date <- "2026-08-08"

# Link cross-catalogue duplicates and choose a deterministic provider-priority canonical record.
dois <- stage1_norm_doi(registry$doi_or_stable_url)
norm_titles <- stage1_norm_title(registry$title)
collection_dois <- stage1_collection_dois(registry$source, dois, norm_titles)
identity_dois <- ifelse(dois %in% collection_dois, "", dois)

registry_id <- paste(registry$source, registry$provider_dataset_id, sep = ":")
priority_order <- c("SMHI SHARK", "PANGAEA", "Marine Scotland", "Cefas Data Hub/DASSH", "PLET", "OBIS",
                    "EMODnet Biology WFS", "GBIF", "EMODnet ERDDAP", "ICES Figshare", "ICES DOME")
registry$canonical_provider_dataset_id <- registry_id
registry$duplicate_catalogue_ids <- ""

group_id <- stage1_identity_groups(identity_dois, norm_titles)

for (g in unique(group_id)) {
  idx <- which(group_id == g)
  if (length(idx) > 1L) {
    ord <- order(match(registry$source[idx], priority_order), registry_id[idx])
    canonical <- registry_id[idx[ord[[1]]]]
    registry$canonical_provider_dataset_id[idx] <- canonical
    registry$duplicate_catalogue_ids[idx] <- vapply(idx, function(i) paste(setdiff(registry_id[idx], registry_id[i]), collapse = ";"), character(1))
  }
}

essential <- c("search_run_id", "source", "endpoint", "api_version", "query_hash_sha256", "execution_time_utc",
  "raw_response_path", "raw_response_checksum_sha256", "provider_dataset_id", "catalogue_id", "title",
  "doi_or_stable_url", "version", "geographic_metadata", "temporal_metadata", "measurement_types", "taxonomic_content",
  "method_metadata", "access_status", "license", "screening_status", "exclusion_reason", "geographic_screen_state",
  "reviewer", "decision_date", "duplicate_catalogue_ids", "canonical_provider_dataset_id", "related_identifier")
registry <- registry[, essential]
if (any(!nzchar(registry$provider_dataset_id)) || any(!nzchar(registry$title)) || any(!nzchar(registry$raw_response_path)) ||
    any(!nzchar(registry$raw_response_checksum_sha256))) stop("Essential candidate evidence fields are incomplete.", call. = FALSE)
utils::write.csv(registry, "metadata/stage1/search/candidate_registry.csv", row.names = FALSE, na = "")

# Search-flow values are computed from the parsed occurrence and screening tables.
flow <- data.frame(
  stage = c("records_identified", "duplicate_catalogue_or_query_records", "unique_catalogue_records",
            "unique_dataset_families", "screened", "excluded", "pending", "advanced_to_acquisition"),
  count = c(nrow(identified), nrow(identified) - nrow(registry), nrow(registry),
            length(unique(registry$canonical_provider_dataset_id)), nrow(registry),
            sum(registry$screening_status == "excluded"), sum(registry$screening_status == "pending"),
            sum(registry$screening_status == "advanced_to_acquisition")),
  generated_from = "metadata/stage1/search/candidate_registry.csv and pinned raw response parsers",
  # A result rebuilt from pinned evidence must be byte-identical. Use the latest archived response
  # timestamp rather than the wall clock, which previously changed this file on every validation.
  generated_utc = max(query_log$retrieved_utc), stringsAsFactors = FALSE
)
utils::write.csv(flow, "metadata/stage1/search/search_flow.csv", row.names = FALSE)

# Every benchmark is located by an explicit, auditable provider identifier or title/DOI pattern.
#
# The original set (DS02, DS04, DS05, DS06, DS07, DS08, DS10, DS16, DS24) tested only datasets the
# search modules were built around, so it could not detect a systematic discovery failure. It is
# extended here with the register's remaining load-bearing candidates: the offshore evidence base
# (DS12 CPR), the restricted German coastal series (DS17, DS18), the second Wadden Sea sentinel
# (DS09), the Dutch historical extension (DS03), the GBIF-only Dutch record (DS23), and the
# external-transfer imaging series (DS26). DS17 was added because it exposed a real parser defect:
# it was present in the archived PLET catalogue and silently dropped for having no DOI.
benchmarks <- data.frame(
  benchmark_id = c("DS02", "DS03", "DS04", "DS05", "DS06", "DS07", "DS08", "DS09", "DS10",
                   "DS12", "DS16", "DS17", "DS18", "DS23", "DS24", "DS26"),
  description = c("RWS phytoplankton", "Dutch long-term monitoring", "BSH phytoplankton",
                  "NOVANA phytoplankton", "SMHI Kattegat/Skagerrak", "Cefas SmartBuoy",
                  "Helgoland Roads", "Sylt Roads", "VLIZ LifeWatch FlowCam",
                  "Continuous Plankton Recorder", "Stonehaven Observatory",
                  "LLUR Schleswig-Holstein (restricted)", "NLWKN Lower Saxony (restricted)",
                  "NIOZ Wadden Sea phytoplankton", "OSPAR COMPEAT inputs", "SMHI IFCB imaging"),
  pattern = c("66f557fe4103f", "Dutch long term monitoring of phytoplankton", "66f41f3f2a72e",
              "66f42801afddd", "10.17031/1633", "CefasDataHub.58",
              "PANGAEA.960407", "Sylt Roads", "956d618f-91dc-4930-a253-cdf80ddb9371|10.14284/760",
              "Continuous Plankton Recorder", "Stonehaven", "OSPAR_LLUR-SH", "OSPAR_NLWKN",
              "okwkou|1d276c75-d90c-40c8-973d-2eac7c8089e5", "22189111",
              "Imaging Flow Cytobot|IFCB"),
  stringsAsFactors = FALSE
)
recall_fields <- c("provider_dataset_id", "catalogue_id", "title", "doi_or_stable_url", "related_identifier")
haystack <- apply(registry[, recall_fields, drop = FALSE], 1L, paste, collapse = " | ")
recall_rows <- lapply(seq_len(nrow(benchmarks)), function(i) {
  idx <- which(grepl(benchmarks$pattern[[i]], haystack, ignore.case = TRUE, perl = TRUE))
  if (!length(idx)) return(data.frame(benchmarks[i, ], found = FALSE, matched_source = "", matched_provider_dataset_id = "",
    screening_status = "", canonical_provider_dataset_id = "", raw_response_path = "", raw_response_checksum_sha256 = ""))
  # Prefer a match that survived screening and was present in the initial execution. An
  # append-only aggregator audit must not replace the benchmark evidence already pinned before
  # the update merely because its rows were parsed earlier in this build.
  retained <- idx[registry$screening_status[idx] != "excluded"]
  candidates <- if (length(retained)) retained else idx
  initial_candidates <- candidates[registry$source[candidates] != "EMODnet Biology WFS"]
  j <- if (length(initial_candidates)) initial_candidates[[1]] else candidates[[1]]
  data.frame(benchmarks[i, ], found = TRUE, matched_source = registry$source[[j]], matched_provider_dataset_id = registry$provider_dataset_id[[j]],
    screening_status = registry$screening_status[[j]], canonical_provider_dataset_id = registry$canonical_provider_dataset_id[[j]],
    raw_response_path = registry$raw_response_path[[j]], raw_response_checksum_sha256 = registry$raw_response_checksum_sha256[[j]])
})
recall <- do.call(rbind, recall_rows)
utils::write.csv(recall, "metadata/stage1/search/known_item_recall.csv", row.names = FALSE)
if (!all(recall$found)) stop(sprintf("Known-item recall failed: %s", paste(recall$benchmark_id[!recall$found], collapse = ", ")), call. = FALSE)

# Recall alone does not prove a benchmark survived screening. A prespecified known item that is
# present but excluded is a screening defect, and it must stop the build rather than be reported
# as a successful recall.
dropped <- recall$benchmark_id[recall$screening_status == "excluded"]
if (length(dropped)) {
  stop(sprintf("Prespecified benchmarks were recalled but excluded by the metadata screen: %s",
    paste(dropped, collapse = ", ")), call. = FALSE)
}

message(sprintf("Compiled %d unique catalogue records from %d identified query hits; all %d benchmarks recalled.",
  nrow(registry), nrow(identified), nrow(recall)))
