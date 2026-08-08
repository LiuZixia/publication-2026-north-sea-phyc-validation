# Resolve the narrative candidate register (DS01-DS34) against the executed Stage 1 search and
# generate the ranked acquisition shortlist that Stage 2 consumes.
#
# Stage 1 action 11 asks for an "advanced to acquisition" count. A count of one, against 8,060
# undifferentiated pending rows, is technically compliant and operationally useless: it hands
# Stage 2 no ordered work. This script produces the missing bridge. It resolves each register
# DS-ID to archived registry evidence, distinguishes diagnosed absence from an undiagnosed search
# failure, and ranks the resolved candidates so acquisition begins with the datasets that can
# actually change the Stage 4 feasibility verdict.
#
# Nothing here decides eligibility. Ranking is a work order, not a scientific inclusion.

source("R/01_search_helpers.R")
source("R/01_registry_identity.R")
required_namespace("jsonlite")

registry <- utils::read.csv("metadata/candidate_registry.csv", stringsAsFactors = FALSE, check.names = FALSE)
spec <- jsonlite::fromJSON("config/ds_register_crosswalk.json", simplifyVector = FALSE)

rank_of <- function(table, key, label) {
  value <- table[[key]]
  if (is.null(value)) stop(sprintf("No %s rank declared for '%s'.", label, key), call. = FALSE)
  as.numeric(value)
}

search_fields <- c("provider_dataset_id", "catalogue_id", "title", "doi_or_stable_url", "related_identifier")
haystack <- apply(registry[, search_fields, drop = FALSE], 1L, paste, collapse = " | ")
registry_id <- paste(registry$source, registry$provider_dataset_id, sep = ":")

rows <- lapply(spec$entries, function(e) {
  target <- if (identical(e$match_field, "source")) registry$source else haystack
  idx <- which(grepl(e$pattern, target, ignore.case = TRUE, perl = TRUE))

  retained <- idx[registry$screening_status[idx] != "excluded"]
  states <- registry$geographic_screen_state[retained]

  # Availability is determined from archived licence and access evidence, not from the narrative
  # register's claim. The register calls DS08 a public-then-request dataset; the archive shows
  # that all 28 of its carbon and all 24 of its biovolume children state an unknown licence
  # requiring author contact, while only its abundance children are CC-BY.
  # Catalogue duplicates are discovery evidence, not additional acquisition routes. Classify
  # access once per canonical dataset family using the provider-priority representative; an
  # unlicensed WFS metadata copy must not downgrade an openly licensed provider or OBIS archive.
  canonical <- unique(registry$canonical_provider_dataset_id[retained])
  access_idx <- match(canonical, registry_id)
  missing_canonical <- is.na(access_idx)
  if (any(missing_canonical)) {
    access_idx[missing_canonical] <- vapply(canonical[missing_canonical], function(id) {
      retained[match(id, registry$canonical_provider_dataset_id[retained])]
    }, integer(1))
  }
  access_class <- stage1_access_class(registry$license[access_idx], registry$access_status[access_idx])
  availability <- stage1_availability(access_class)

  tier_rank <- rank_of(spec$ranking$tier_rank, e$tier, "tier")
  domain_rank <- rank_of(spec$ranking$domain_rank, e$domain, "domain")
  access_rank <- rank_of(spec$ranking$access_rank, e$access, "access")
  overlap_rank <- rank_of(spec$ranking$cmems_overlap_rank, e$cmems_overlap, "CMEMS overlap")

  data.frame(
    ds_id = e$ds_id,
    name = e$name,
    entry_type = e$entry_type,
    register_section = e$register_section,
    resolved = length(idx) > 0L,
    registry_rows = length(idx),
    retained_rows = length(retained),
    sources = paste(sort(unique(registry$source[idx])), collapse = "; "),
    canonical_families = length(unique(registry$canonical_provider_dataset_id[retained])),
    geographic_screen_states = paste(sort(unique(states)), collapse = "; "),
    availability = availability,
    rows_open_licence = sum(access_class == "open"),
    rows_licence_unverified = sum(access_class == "unverified"),
    rows_contact_required = sum(access_class == "contact_required"),
    declared_tier = e$tier,
    declared_domain = e$domain,
    declared_access = e$access,
    declared_cmems_overlap = e$cmems_overlap,
    planned_role = e$planned_role,
    priority_score = 3 * tier_rank + 2 * domain_rank + 2 * access_rank + 2 * overlap_rank,
    resolution_pattern = e$pattern,
    stringsAsFactors = FALSE
  )
})
crosswalk <- do.call(rbind, rows)
crosswalk <- crosswalk[order(crosswalk$ds_id), ]
utils::write.csv(crosswalk, "metadata/stage1_ds_crosswalk.csv", row.names = FALSE, na = "")

# The shortlist is the acquisition work order: register entries that resolved to evidence reachable
# without a provider request. Out-of-domain entries, excluded-by-decision entries, and entries whose
# every retained record requires contacting an author stay in the crosswalk for audit but must never
# enter the acquisition queue.
#
# Under the frozen access policy a dataset that can only be obtained by request is unavailable at
# the current stage. Its declared fallback applies immediately rather than at a deadline, so the
# resulting scope is a design decision taken here, in the open, before any PhyC value is inspected.
eligible_for_queue <- crosswalk$resolved &
  crosswalk$retained_rows > 0L &
  crosswalk$entry_type %in% c("dataset", "dataset_group", "conversion_reference") &
  crosswalk$declared_domain != "out_of_domain" &
  crosswalk$availability %in% c("open_route_archived", "partially_open")

shortlist <- crosswalk[eligible_for_queue, ]
shortlist <- shortlist[order(-shortlist$priority_score, shortlist$ds_id), ]
shortlist$acquisition_rank <- seq_len(nrow(shortlist))
shortlist$acquisition_status <- ifelse(shortlist$availability == "partially_open",
  "queued_open_subset_only", "queued_for_stage2_acquisition")
shortlist$licence_action <- ifelse(shortlist$rows_licence_unverified > 0L,
  "resolve_licence_before_stage7_manifest_freeze", "open_licence_recorded")
shortlist <- shortlist[, c("acquisition_rank", "ds_id", "name", "priority_score", "acquisition_status",
  "availability", "licence_action", "declared_tier", "declared_domain", "declared_cmems_overlap",
  "retained_rows", "rows_open_licence", "rows_licence_unverified", "rows_contact_required",
  "canonical_families", "sources", "planned_role", "register_section")]
utils::write.csv(shortlist, "metadata/stage1_acquisition_shortlist.csv", row.names = FALSE, na = "")

# Datasets the study proceeds without. Recorded explicitly so that a scope limit arising from
# access can never be mistaken later for an ecological or performance-driven exclusion.
unavailable <- crosswalk[crosswalk$entry_type %in% c("dataset", "dataset_group") &
  crosswalk$declared_domain != "out_of_domain" &
  !crosswalk$availability %in% c("open_route_archived", "partially_open"), ]
unavailable <- unavailable[order(-unavailable$priority_score, unavailable$ds_id),
  c("ds_id", "name", "availability", "priority_score", "declared_tier", "declared_domain",
    "retained_rows", "rows_contact_required", "planned_role", "register_section")]
utils::write.csv(unavailable, "metadata/stage1_unavailable_candidates.csv", row.names = FALSE, na = "")

diagnosed_absence <- !crosswalk$resolved &
  (crosswalk$availability == "no_route" | crosswalk$entry_type == "excluded_decision")
diagnosed <- crosswalk$ds_id[diagnosed_absence]
undiagnosed <- crosswalk$ds_id[!crosswalk$resolved & !diagnosed_absence]
message(sprintf("Resolved %d of %d register entries; %d datasets shortlisted for Stage 2 acquisition.",
  sum(crosswalk$resolved), nrow(crosswalk), nrow(shortlist)))
if (length(diagnosed)) {
  message(sprintf("Diagnosed without retained registry evidence: %s", paste(diagnosed, collapse = ", ")))
}
if (length(undiagnosed)) {
  stop(sprintf("Undiagnosed register entries require query or API review: %s",
    paste(undiagnosed, collapse = ", ")), call. = FALSE)
}
