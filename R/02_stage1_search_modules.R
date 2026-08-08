# Source-specific Stage 1 catalogue acquisition modules.

source("R/01_search_helpers.R")

stage1_terms <- function(cfg) unique(c(unlist(cfg$biological_terms), unlist(cfg$measurement_terms)))
bind_manifest_rows <- function(rows) do.call(rbind, rows)

run_plet_search <- function() {
  cfg <- read_stage1_config(); run <- new_search_run("PLET"); rows <- list()
  requests <- list(
    catalogue = "https://www.dassh.ac.uk/lifeforms/",
    automation_guidance = "https://www.dassh.ac.uk/lifeforms/docs/automation_guidance.txt"
  )
  for (label in names(requests)) {
    dest <- file.path(run$path, paste0(label, if (label == "catalogue") ".html" else ".txt"))
    ans <- perform_request("GET", requests[[label]], dest)
    text_body <- paste(readLines(dest, warn = FALSE), collapse = "\n")
    catalogue_count <- if (label == "catalogue") {
      length(regmatches(text_body, gregexpr("<a href=\"https://doi.org/", text_body, fixed = TRUE))[[1]])
    } else 1L
    rows[[length(rows) + 1L]] <- artifact_row(
      run, "PLET", "DASSH", "documented web export interface, 2026-08-08", "per underlying dataset",
      "GET", requests[[label]], requests[[label]], label, dest, ans,
      catalogue_count,
      query_label = label
    )
  }
  html <- paste(readLines(file.path(run$path, "catalogue.html"), warn = FALSE), collapse = "\n")
  benchmarks <- c("RWS_Fpzout_2000-2019_phyto", "BSH_Phyto_Zoo", "NOVANA phytoplankton", "10.17031/1633", "10.14466/CefasDataHub.58")
  if (!all(vapply(benchmarks, grepl, logical(1), x = html, fixed = TRUE))) stop("PLET catalogue failed known-item precheck.", call. = FALSE)
  catalogue_count <- rows[[1]]$records_returned
  write_search_manifest(run, bind_manifest_rows(rows), catalogue_count, catalogue_count, TRUE,
    "Complete public PLET catalogue plus the provider's official automation guidance.")
  run$id
}

run_ices_dome_search <- function() {
  cfg <- read_stage1_config(); run <- new_search_run("ICESDOME"); rows <- list()
  requests <- list(
    swagger = "https://dome.ices.dk/api/swagger/v1/swagger.json",
    phytoplankton_view = "https://dome.ices.dk/views/phytoplankton.aspx",
    community_years = "https://dome.ices.dk/api/GetCommunity_GetListYears",
    phytoplankton_cache = "https://dome.ices.dk/api/Download/GetPPCachedViewTimestampPEGproduct"
  )
  extensions <- c(swagger = ".json", phytoplankton_view = ".html", community_years = ".json", phytoplankton_cache = ".json")
  counts <- integer()
  for (label in names(requests)) {
    dest <- file.path(run$path, paste0(label, extensions[[label]]))
    ans <- perform_request("GET", requests[[label]], dest)
    n <- 1L
    if (grepl("json$", dest)) {
      x <- assert_json_file(dest)
      n <- if (label == "community_years") length(x) else 1L
    }
    counts[label] <- n
    rows[[length(rows) + 1L]] <- artifact_row(run, "ICES DOME", "ICES",
      "OpenAPI v1", "CC BY 4.0", "GET", requests[[label]], requests[[label]], label,
      dest, ans, n, query_label = label)
  }
  swagger <- jsonlite::fromJSON(file.path(run$path, "swagger.json"), simplifyVector = FALSE)
  if (is.null(swagger$paths[["/GetCommunity_GetListYears"]])) stop("Required DOME API operation absent.", call. = FALSE)
  write_search_manifest(run, bind_manifest_rows(rows), sum(counts), sum(counts), TRUE,
    "DOME publishes observations through parameterized download operations rather than a dataset catalogue; official API capabilities and current availability metadata are archived.")
  run$id
}

run_emodnet_search <- function() {
  cfg <- read_stage1_config(); run <- new_search_run("EMODNET"); rows <- list(); all_ids <- character()
  endpoint <- "https://erddap.emodnet.eu/erddap/search/index.json"
  for (term in stage1_terms(cfg)) {
    page <- 1L; seen_hashes <- character()
    repeat {
      url <- build_query_url(endpoint, c(page = page, itemsPerPage = 1000, searchFor = term))
      dest <- file.path(run$path, sprintf("query_%02d_page_%04d.json", match(term, stage1_terms(cfg)), page))
      ans <- perform_request("GET", url, dest, acceptable_status = c(200:299, 404L))
      if (ans$status == 404L) {
        n <- 0L; x <- list(table = list(columnNames = list(), rows = list()))
      } else {
        x <- jsonlite::fromJSON(dest, simplifyVector = FALSE)
        if (is.null(x$table$columnNames) || is.null(x$table$rows)) stop("Malformed ERDDAP response.", call. = FALSE)
        n <- length(x$table$rows)
      }
      page_hash <- stage1_query_hash("CONTENT", "", if (n) paste(vapply(x$table$rows, function(z) paste(z, collapse = "|"), character(1)), collapse = "\n") else paste0("zero:", term))
      if (page_hash %in% seen_hashes) stop("ERDDAP pagination loop detected.", call. = FALSE)
      seen_hashes <- c(seen_hashes, page_hash)
      id_col <- match("Dataset ID", unlist(x$table$columnNames))
      if (n && !is.na(id_col)) all_ids <- c(all_ids, vapply(x$table$rows, function(z) as.character(z[[id_col]]), character(1)))
      rows[[length(rows) + 1L]] <- artifact_row(run, "EMODnet ERDDAP", "EMODnet",
        "ERDDAP search/index.json", "per dataset", "GET", endpoint, url, page, dest, ans, n,
        query_label = term)
      if (n < 1000L) break
      page <- page + 1L
      if (page > 10000L) stop("ERDDAP pagination safety limit reached.", call. = FALSE)
    }
  }
  write_search_manifest(run, bind_manifest_rows(rows), length(all_ids), length(unique(all_ids)), TRUE)
  run$id
}

run_obis_search <- function() {
  cfg <- read_stage1_config(); run <- new_search_run("OBIS"); rows <- list(); all_ids <- character()
  endpoint <- "https://api.obis.org/v3/dataset"
  taxa <- c("Bacillariophyta", "Dinoflagellata", "Haptophyta", "Cyanobacteria", "Chlorophyta", "Phaeocystis")
  wkt <- cfg$geographic_scope$wkt_wgs84
  for (taxon in taxa) {
    url <- build_query_url(endpoint, c(scientificname = taxon, geometry = wkt))
    dest <- file.path(run$path, sprintf("taxon_%02d.json", match(taxon, taxa)))
    ans <- perform_request("GET", url, dest)
    x <- jsonlite::fromJSON(dest, simplifyVector = FALSE)
    if (is.null(x$results)) stop("Malformed OBIS dataset response.", call. = FALSE)
    n <- length(x$results); reported <- as.integer(x$total %||% n)
    if (!identical(n, reported)) stop(sprintf("OBIS total mismatch for %s: %d versus %d.", taxon, n, reported), call. = FALSE)
    ids <- vapply(x$results, function(z) as.character(z$id %||% z$dataset_id %||% z$url), character(1))
    all_ids <- c(all_ids, ids)
    rows[[length(rows) + 1L]] <- artifact_row(run, "OBIS", "OBIS",
      "OBIS v3", "per dataset", "GET", endpoint, url, 1L, dest, ans, n, reported,
      query_label = taxon)
  }
  write_search_manifest(run, bind_manifest_rows(rows), sum(vapply(rows, function(x) x$records_returned, integer(1))), length(unique(all_ids)), TRUE)
  run$id
}

run_smhi_search <- function() {
  cfg <- read_stage1_config(); run <- new_search_run("SMHISHARK")
  endpoint <- "https://shark.smhi.se/api/dataset/list.json"
  url <- build_query_url(endpoint, c(datatype = "Phytoplankton")); dest <- file.path(run$path, "phytoplankton.json")
  ans <- perform_request("GET", url, dest); x <- jsonlite::fromJSON(dest, simplifyVector = FALSE)
  n <- length(x); ids <- unique(vapply(x, function(z) as.character(z$dataset_name), character(1)))
  row <- artifact_row(run, "SMHI SHARK", "SMHI", "SHARK dataset list API", "CC0 metadata; per dataset",
    "GET", endpoint, url, 1L, dest, ans, n, n, query_label = "datatype=Phytoplankton")
  write_search_manifest(run, row, n, length(ids), TRUE)
  run$id
}

run_pangaea_search <- function() {
  cfg <- read_stage1_config(); run <- new_search_run("PANGAEA"); rows <- list(); all_ids <- character()
  endpoint <- "https://ws.pangaea.de/es/pangaea/panmd/_search"
  scroll_endpoint <- "https://ws.pangaea.de/es/_search/scroll"
  quote_query_term <- function(x) paste0("\"", x, "\"")
  biological <- paste(vapply(unlist(cfg$biological_terms), quote_query_term, character(1)), collapse = " OR ")
  geography <- paste(vapply(unlist(cfg$geographic_scope$terms), quote_query_term, character(1)), collapse = " OR ")
  query <- sprintf("(%s) AND (%s)", biological, geography)
  url <- build_query_url(endpoint, c(scroll = "5m", q = query, size = 250))
  page <- 1L; total <- NA_integer_; cursor <- ""; seen_cursors <- character()
  repeat {
    dest <- file.path(run$path, sprintf("response_page_%04d.json", page))
    if (page == 1L) {
      ans <- perform_request("GET", url, dest); request_text <- url; method <- "GET"; page_key <- "initial"
    } else {
      body <- jsonlite::toJSON(list(scroll = "5m", scroll_id = cursor), auto_unbox = TRUE)
      ans <- perform_request("POST", scroll_endpoint, dest, body); request_text <- body; method <- "POST"; page_key <- substr(cursor, 1L, 24L)
    }
    x <- jsonlite::fromJSON(dest, simplifyVector = FALSE)
    if (is.null(x$hits$hits)) stop("Malformed PANGAEA response.", call. = FALSE)
    if (page == 1L) total <- as.integer(if (is.list(x$hits$total)) x$hits$total$value else x$hits$total)
    hits <- x$hits$hits; n <- length(hits)
    if (n) all_ids <- c(all_ids, vapply(hits, function(z) as.character(z$`_id`), character(1)))
    rows[[length(rows) + 1L]] <- artifact_row(run, "PANGAEA", "PANGAEA",
      "Elasticsearch panmd search/scroll", "per dataset", method,
      if (page == 1L) endpoint else scroll_endpoint, request_text, page_key, dest, ans, n, total,
      query_label = query)
    if (!n) break
    next_cursor <- as.character(x$`_scroll_id` %||% "")
    if (!nzchar(next_cursor)) stop("PANGAEA omitted its scroll cursor.", call. = FALSE)
    if (next_cursor %in% seen_cursors && page > 1L) {
      # Elasticsearch may legitimately keep a stable cursor; progress is checked by unique IDs below.
      if (length(unique(all_ids)) < sum(vapply(rows, function(z) z$records_returned, integer(1)))) stop("PANGAEA returned a duplicate page.", call. = FALSE)
    }
    seen_cursors <- c(seen_cursors, next_cursor); cursor <- next_cursor; page <- page + 1L
    if (page > 10000L) stop("PANGAEA pagination safety limit reached.", call. = FALSE)
  }
  if (length(unique(all_ids)) != total) stop(sprintf("PANGAEA total mismatch: %d unique versus %d reported.", length(unique(all_ids)), total), call. = FALSE)
  write_search_manifest(run, bind_manifest_rows(rows), total, length(unique(all_ids)), TRUE)
  run$id
}

run_gbif_search <- function() {
  cfg <- read_stage1_config(); run <- new_search_run("GBIF"); rows <- list(); all_ids <- character()
  endpoint <- "https://api.gbif.org/v1/dataset/search"
  terms <- c(unlist(cfg$biological_terms), paste("phytoplankton", unlist(cfg$measurement_terms)))
  query_no <- 0L
  for (query in terms) {
    query_no <- query_no + 1L; offset <- 0L; page <- 1L
    repeat {
      url <- build_query_url(endpoint, c(q = query, offset = offset, limit = 1000))
      dest <- file.path(run$path, sprintf("query_%03d_page_%04d.json", query_no, page))
      ans <- perform_request("GET", url, dest); x <- jsonlite::fromJSON(dest, simplifyVector = FALSE)
      reported_total <- x$count %||% x$total
      if (is.null(x$results) || is.null(reported_total)) stop("Malformed GBIF response.", call. = FALSE)
      n <- length(x$results); total <- as.integer(reported_total)
      if (n) all_ids <- c(all_ids, vapply(x$results, function(z) as.character(z$key), character(1)))
      rows[[length(rows) + 1L]] <- artifact_row(run, "GBIF", "GBIF", "REST v1 dataset/search",
        "per dataset", "GET", endpoint, url, page, dest, ans, n, total, query_label = query)
      offset <- offset + n
      if (isTRUE(x$endOfRecords) || n == 0L || offset >= total) break
      page <- page + 1L
      if (page > 10000L) stop("GBIF pagination safety limit reached.", call. = FALSE)
    }
  }
  write_search_manifest(run, bind_manifest_rows(rows), sum(vapply(rows, function(x) x$records_returned, integer(1))), length(unique(all_ids)), TRUE)
  run$id
}

run_scotland_search <- function() {
  cfg <- read_stage1_config(); run <- new_search_run("SCOTMARINE"); rows <- list(); all_ids <- character()
  endpoint <- "https://data.marine.gov.scot/api/dataset/node.json"; page <- 0L; seen_hashes <- character()
  repeat {
    url <- build_query_url(endpoint, c("parameters[type]" = "dataset", pagesize = 20, page = page))
    dest <- file.path(run$path, sprintf("catalogue_page_%04d.json", page))
    ans <- perform_request("GET", url, dest); x <- jsonlite::fromJSON(dest, simplifyVector = FALSE); n <- length(x)
    if (n) {
      ids <- vapply(x, function(z) as.character(z$nid), character(1)); hash <- stage1_query_hash("IDS", "", paste(ids, collapse = "|"))
      if (hash %in% seen_hashes) stop("Marine Scotland pagination loop detected.", call. = FALSE)
      seen_hashes <- c(seen_hashes, hash); all_ids <- c(all_ids, ids)
    }
    rows[[length(rows) + 1L]] <- artifact_row(run, "Marine Scotland", "Scottish Government Marine Directorate",
      "DKAN REST node API", "per dataset", "GET", endpoint, url, page, dest, ans, n,
      query_label = "complete dataset-node catalogue")
    if (n == 0L) break
    page <- page + 1L
    if (page > 10000L) stop("Marine Scotland pagination safety limit reached.", call. = FALSE)
  }
  if (anyDuplicated(all_ids)) stop("Marine Scotland catalogue contains duplicated pages or node IDs.", call. = FALSE)
  write_search_manifest(run, bind_manifest_rows(rows), length(all_ids), length(all_ids), TRUE)
  run$id
}

run_cefas_search <- function() {
  cfg <- read_stage1_config(); run <- new_search_run("CEFASDASSH"); rows <- list(); all_ids <- character()
  fixed <- list(
    portal_config = "https://data.cefas.co.uk/config/config.prod.json",
    endpoint_catalogue = "https://data-api.cefas.co.uk/api/endpoints",
    swagger = "https://data-api.cefas.co.uk/swagger/v2/swagger.json"
  )
  for (label in names(fixed)) {
    dest <- file.path(run$path, paste0(label, ".json")); ans <- perform_request("GET", fixed[[label]], dest); assert_json_file(dest)
    rows[[length(rows) + 1L]] <- artifact_row(run, "Cefas Data Hub/DASSH", "Cefas", "Data Portal API v2",
      "OGL metadata; per dataset", "GET", fixed[[label]], fixed[[label]], label, dest, ans, 1L, query_label = label)
  }
  endpoint <- "https://data-api.cefas.co.uk/api/holdings"; terms <- stage1_terms(cfg)
  for (term in terms) {
    page <- 1L; retrieved <- 0L; expected <- NA_integer_
    repeat {
      url <- build_query_url(endpoint, c(page = page, resultsPerPage = 100, searchterm = term, enableThesaurus = "false"))
      dest <- file.path(run$path, sprintf("query_%02d_page_%04d.json", match(term, terms), page)); ans <- perform_request("GET", url, dest)
      x <- jsonlite::fromJSON(dest, simplifyVector = FALSE)
      if (is.null(x$items) || is.null(x$totalItems)) stop("Malformed Cefas holdings response.", call. = FALSE)
      n <- length(x$items); expected <- as.integer(x$totalItems); retrieved <- retrieved + n
      if (n) all_ids <- c(all_ids, vapply(x$items, function(z) as.character(z$id), character(1)))
      rows[[length(rows) + 1L]] <- artifact_row(run, "Cefas Data Hub/DASSH", "Cefas", "Data Portal API v2",
        "OGL metadata; per dataset", "GET", endpoint, url, page, dest, ans, n, expected, query_label = term)
      if (page >= as.integer(x$totalPages) || n == 0L) break
      page <- page + 1L
    }
    if (retrieved != expected) stop(sprintf("Cefas total mismatch for %s.", term), call. = FALSE)
  }
  write_search_manifest(run, bind_manifest_rows(rows), sum(vapply(rows, function(x) x$records_returned, integer(1))), length(unique(all_ids)), TRUE)
  run$id
}

run_figshare_search <- function() {
  cfg <- read_stage1_config(); run <- new_search_run("FIGSHARE"); rows <- list(); all_ids <- character()
  endpoint <- "https://api.figshare.com/v2/articles/search"
  body <- jsonlite::toJSON(list(search_for = ":institution: ices-library", limit = 1000), auto_unbox = TRUE)
  cursor <- ""; page <- 1L; seen_ids <- character()
  repeat {
    dest <- file.path(run$path, sprintf("ices_library_page_%04d.json", page))
    headers <- if (nzchar(cursor)) list(`X-Cursor` = cursor) else list()
    ans <- perform_request("POST", endpoint, dest, body, request_headers = headers)
    x <- jsonlite::fromJSON(dest, simplifyVector = FALSE); n <- length(x)
    ids <- if (n) vapply(x, function(z) as.character(z$id), character(1)) else character()
    if (length(intersect(ids, seen_ids))) stop("Figshare cursor returned duplicate records.", call. = FALSE)
    seen_ids <- c(seen_ids, ids); all_ids <- c(all_ids, ids)
    request_text <- paste(body, if (nzchar(cursor)) paste0("X-Cursor:", cursor) else "X-Cursor:<initial>", sep = "\n")
    rows[[length(rows) + 1L]] <- artifact_row(run, "ICES Figshare", "ICES Library", "Figshare public API v2",
      "per article", "POST", endpoint, request_text, page, dest, ans, n, query_label = "complete ICES Library institution catalogue")
    next_cursor <- ans$response_cursor
    if (n < 1000L || !nzchar(next_cursor)) break
    cursor <- next_cursor; page <- page + 1L
    if (page > 100L) stop("Figshare cursor safety limit reached.", call. = FALSE)
  }
  direct <- c(DS22 = "27900237", DS24 = "22189111")
  for (label in names(direct)) {
    url <- paste0("https://api.figshare.com/v2/articles/", direct[[label]]); dest <- file.path(run$path, paste0(tolower(label), "_article.json"))
    ans <- perform_request("GET", url, dest); x <- assert_json_file(dest)
    rows[[length(rows) + 1L]] <- artifact_row(run, "ICES Figshare", "ICES Library", "Figshare public API v2",
      "per article", "GET", url, url, label, dest, ans, 1L, 1L, query_label = paste(label, "known-item diagnostic"))
    all_ids <- c(all_ids, as.character(x$id))
  }
  peg_url <- "https://www.ices.dk/data/Documents/ENV/PEG_BVOL.zip"; peg_dest <- file.path(run$path, "PEG_BVOL_2025.zip")
  peg <- perform_request("GET", peg_url, peg_dest, minimum_bytes = 1000L)
  zip_listing <- tryCatch(utils::unzip(peg_dest, list = TRUE), error = function(e) stop("DS22 PEG_BVOL ZIP validation failed.", call. = FALSE))
  if (!nrow(zip_listing)) stop("DS22 PEG_BVOL archive is empty.", call. = FALSE)
  rows[[length(rows) + 1L]] <- artifact_row(run, "ICES Figshare", "ICES/HELCOM EG PHYTO", "PEG_BVOL file current at 2026-08-08",
    "provider-published conversion authority", "GET", peg_url, peg_url, "DS22-file", peg_dest, peg, nrow(zip_listing), nrow(zip_listing),
    query_label = "DS22 pinned conversion file")
  write_search_manifest(run, bind_manifest_rows(rows), length(unique(all_ids)), length(unique(all_ids)), TRUE,
    "Complete ICES Library institution catalogue retrieved with the Figshare cursor; DS22/DS24 direct metadata and the actual current PEG_BVOL ZIP are separately pinned.")
  run$id
}
