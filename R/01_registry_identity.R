# Pure identity and dataset-metadata screening rules for the Stage 1 candidate registry.
#
# These functions carry no file or namespace dependencies so that they can be unit tested
# directly. They decide which catalogue rows are clearly out of biological scope and which
# catalogue rows describe the same underlying dataset; both decisions are auditable inputs
# to the search-flow counts, so a silent change here changes a reported number.

# Screening terms live in config/screening_rules.json, not in code, so that a screening
# correction is a reviewable configuration change. They are deliberately NOT in
# config/stage1_search_config.json, whose checksum is embedded in every archived run summary:
# correcting a screen must not invalidate a pinned search response and force a re-run.
stage1_screening_rules <- function(path = "config/screening_rules.json") {
  if (!requireNamespace("jsonlite", quietly = TRUE)) stop("jsonlite is required.", call. = FALSE)
  if (!file.exists(path)) stop("Missing versioned Stage 1 screening rules.", call. = FALSE)
  rules <- jsonlite::fromJSON(path, simplifyVector = FALSE)
  if (!identical(rules$schema_version, "1.0.0")) stop("Unsupported screening-rule schema.", call. = FALSE)
  rules
}

# Classify what the archived evidence says about using a catalogue record now.
#
#   contact_required - the provider states the record is restricted, unreleased, or that the
#                      licence is unknown and access must be requested from an author. Under the
#                      frozen access policy these are unavailable at the current stage: the study
#                      proceeds without them and applies the declared fallback immediately.
#   open             - the archived evidence names an open licence (Creative Commons, CC0, OGL,
#                      public domain).
#   unverified       - the record is openly reachable but states no licence. Usable for
#                      exploratory Stage 2-4 work, never redistributed, and the licence must be
#                      resolved before the Stage 7 manifest freeze.
#
# Access status is checked first: a provider that marks a record restricted overrides whatever a
# generic catalogue-level licence string claims about the collection it sits in.
stage1_access_class <- function(license, access_status) {
  # An entry that resolved to no retained record must yield no classes. Guard the empty case
  # explicitly: paste0(character(0), "") returns a length-one "", which would silently report a
  # dataset with zero evidence as openly available.
  n <- max(length(license), length(access_status))
  if (n == 0L) return(character(0))
  license <- tolower(as.character(rep_len(license, n)))
  access_status <- tolower(as.character(rep_len(access_status, n)))
  license[is.na(license)] <- ""
  access_status[is.na(access_status)] <- ""
  contact_access <- "restrict|embargo|moratorium|not released|unreleased|on request|by request|login"
  contact_licence <- "licensing unknown|licence unknown|license unknown|contact principal investigator|contact the author|contact author"
  open_licence <- "cc-by|cc by|cc0|creativecommons\\.org/licenses|creativecommons\\.org/publicdomain|open government licen|public domain|creative commons attribution"

  ifelse(grepl(contact_access, access_status, perl = TRUE) | grepl(contact_licence, license, perl = TRUE),
    "contact_required",
    ifelse(grepl(open_licence, license, perl = TRUE), "open", "unverified"))
}

# Roll per-record access classes up to one availability state for a register entry.
stage1_availability <- function(access_class) {
  if (!length(access_class)) return("no_route")
  open_or_unverified <- sum(access_class %in% c("open", "unverified"))
  if (open_or_unverified == 0L) return("contact_required")
  if (open_or_unverified == length(access_class)) return("open_route_archived")
  "partially_open"
}

# Build a single alternation pattern from a list of controlled terms.
stage1_pattern <- function(terms) {
  terms <- unlist(terms, use.names = FALSE)
  if (!length(terms)) stop("A screening pattern needs at least one term.", call. = FALSE)
  paste(tolower(terms), collapse = "|")
}

# Normalize a DOI to its bare "10.x/y" form; anything that is not a DOI becomes "".
stage1_norm_doi <- function(x) {
  x <- tolower(trimws(as.character(x)))
  x <- sub("^https?://(dx\\.)?doi\\.org/", "", x)
  x <- sub("^doi:", "", x)
  ifelse(grepl("^10\\.", x), x, "")
}

# Normalize a title for identity comparison. tolower() must run BEFORE the character class is
# applied: "[^a-z0-9]" deletes uppercase letters, so stripping first would silently drop every
# capital and make identity depend on a provider's capitalisation.
stage1_norm_title <- function(x) {
  gsub("[^a-z0-9]", "", tolower(as.character(x)))
}

# Note on cross-catalogue linkage that this module deliberately does NOT attempt. PLET lists the
# Cefas SmartBuoy series as one record covering 2001-2019, while the Cefas Data Hub splits the
# same observations across holdings titled 2001-2017 and 2018-2019, and Cefas's holdings API
# exposes no DOI to link them by. The relationship is one-to-many over time, so no dataset-level
# title or DOI rule can express it without asserting a duplication that does not exist. It is
# resolved by record-level linkage in Stage 2, and remains a declared Stage 1 limitation.

# Some providers mint one DOI for a whole collection. PLET, for example, publishes eight
# distinct Marine Scotland series (Loch Ewe, Scalloway, Scapa, Stonehaven; phytoplankton,
# zooplankton, chlorophyll) under 10.17031/1637. Treating such a DOI as a dataset identity
# merges unrelated observatories into one "family" and would later report genuinely
# independent monitoring stations as duplicates of each other.
#
# A DOI is a collection DOI when a single source attaches it to more than one distinct title.
stage1_collection_dois <- function(source, norm_doi, norm_title) {
  keep <- nzchar(norm_doi)
  if (!any(keep)) return(character(0))
  key <- paste(source[keep], norm_doi[keep], sep = "\r")
  distinct_titles <- tapply(norm_title[keep], key, function(x) length(unique(x)))
  collection_keys <- names(distinct_titles)[distinct_titles > 1L]
  unique(sub("^[^\r]*\r", "", collection_keys))
}

# Union catalogue rows that share a dataset-identifying DOI or an identical normalized title.
# Grouping is transitive, so a row linked by DOI to one record and by title to another places
# all three in the same family.
stage1_identity_groups <- function(identity_doi, norm_title) {
  n <- length(identity_doi)
  group_id <- seq_len(n)
  merge_on <- function(group_id, values) {
    for (value in unique(values[nzchar(values)])) {
      idx <- which(values == value)
      if (length(idx) < 2L) next
      target <- min(group_id[idx])
      group_id[group_id %in% group_id[idx]] <- target
    }
    group_id
  }
  group_id <- merge_on(group_id, identity_doi)
  merge_on(group_id, norm_title)
}
