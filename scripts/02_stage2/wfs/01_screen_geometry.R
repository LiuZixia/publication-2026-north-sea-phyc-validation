# Intersect archived EMODnet WFS records with the exact frozen polygon and update candidate routing.

source("R/00_core_setup.R")
source("R/03_stage2_contract.R")
required_namespace("jsonlite")
required_namespace("sf")

# GeoJSON polygon rings are defined by their recorded coordinate vertices. GEOS prepared predicates
# evaluate that unchanged linear-ring geometry directly and avoid repeatedly rebuilding an 8 MB s2
# geography for every 10,000-record page.
sf::sf_use_s2(FALSE)

pin <- utils::read.csv("metadata/stage2/acquisition/emodnet_wfs_active_run.csv", stringsAsFactors = FALSE,
                       check.names = FALSE)
if (nrow(pin) != 1L) stop("Exactly one Stage 2 WFS geometry run must be active.", call. = FALSE)
run_dir <- file.path("data", "raw", pin$run_relative_path[[1]])
if (!identical(calculate_checksum(file.path(run_dir, "manifest.csv")),
               pin$manifest_checksum_sha256[[1]]) ||
    !identical(calculate_checksum(file.path(run_dir, "dataset_hit_summary.csv")),
               pin$dataset_hit_summary_checksum_sha256[[1]]) ||
    !identical(calculate_checksum(file.path(run_dir, "run_summary.json")),
               pin$run_summary_checksum_sha256[[1]])) {
  stop("The active WFS run differs from its tracked pin.", call. = FALSE)
}

contract <- read_stage2_contract()
initial_queue <- utils::read.csv("metadata/stage2/control/wfs_geometry_queue.csv", stringsAsFactors = FALSE,
                                 check.names = FALSE, colClasses = c(wfs_dataset_id = "character"))
validate_stage2_wfs_queue(initial_queue, contract, require_initial = TRUE)
hits <- utils::read.csv(file.path(run_dir, "dataset_hit_summary.csv"), stringsAsFactors = FALSE,
                        check.names = FALSE, colClasses = c(wfs_dataset_id = "character"))
if (!setequal(hits$wfs_dataset_id, initial_queue$wfs_dataset_id)) {
  stop("WFS hit summary IDs differ from the frozen queue.", call. = FALSE)
}

domain <- sf::st_read("config/spatial/greater_north_sea.geojson", quiet = TRUE)
subregions <- sf::st_read("config/spatial/hydrographic_subregions.geojson", quiet = TRUE)
if (nrow(domain) != 1L || !all(sf::st_is_valid(domain)) || !all(sf::st_is_valid(subregions))) {
  stop("Frozen spatial geometries are invalid.", call. = FALSE)
}

value_or_missing <- function(feature, field) {
  value <- feature$properties[[field]]
  if (is.null(value) || !length(value)) NA_character_ else as.character(value[[1]])
}

evidence_rows <- list()
for (i in seq_len(nrow(initial_queue))) {
  dataset_id <- initial_queue$wfs_dataset_id[[i]]
  hit_row <- hits[hits$wfs_dataset_id == dataset_id, , drop = FALSE]
  files <- sort(list.files(run_dir,
    pattern = sprintf("^dataset_%s_bbox_records_[0-9]{4}\\.json$", dataset_id), full.names = TRUE))
  exact_records <- 0L
  boundary_touch_records <- 0L
  core_records <- 0L
  external_records <- 0L
  unique_positions <- character()
  dates <- character()
  institutions <- character()
  min_lon <- Inf; max_lon <- -Inf; min_lat <- Inf; max_lat <- -Inf

  for (file in files) {
    response <- jsonlite::fromJSON(file, simplifyVector = FALSE)
    features <- response$features %||% list()
    if (!length(features)) next
    coordinates <- do.call(rbind, lapply(features, function(feature) {
      point <- unlist(feature$geometry$coordinates %||% list(), use.names = FALSE)
      if (length(point) < 2L) c(NA_real_, NA_real_) else as.numeric(point[1:2])
    }))
    if (any(!is.finite(coordinates))) stop(sprintf("Invalid WFS point geometry in %s", file), call. = FALSE)
    points <- sf::st_as_sf(data.frame(row = seq_len(nrow(coordinates)), lon = coordinates[, 1],
                                      lat = coordinates[, 2]), coords = c("lon", "lat"), crs = 4326)
    in_domain <- lengths(sf::st_intersects(points, domain, prepared = TRUE)) > 0L
    if (!any(in_domain)) next
    selected <- points[in_domain, , drop = FALSE]
    boundary_touch_records <- boundary_touch_records +
      sum(lengths(sf::st_intersects(selected, sf::st_boundary(domain), prepared = TRUE)) > 0L)
    region_hits <- sf::st_intersects(selected, subregions, prepared = TRUE)
    region_index <- vapply(region_hits, function(value) if (length(value)) value[[1]] else NA_integer_, integer(1))
    roles <- rep(NA_character_, length(region_index))
    roles[!is.na(region_index)] <- subregions$role[region_index[!is.na(region_index)]]
    exact_records <- exact_records + sum(in_domain)
    core_records <- core_records + sum(roles == "core-domain", na.rm = TRUE)
    external_records <- external_records + sum(roles == "external-transfer", na.rm = TRUE)
    selected_coordinates <- coordinates[in_domain, , drop = FALSE]
    unique_positions <- c(unique_positions, sprintf("%.7f|%.7f", selected_coordinates[, 1], selected_coordinates[, 2]))
    min_lon <- min(min_lon, selected_coordinates[, 1]); max_lon <- max(max_lon, selected_coordinates[, 1])
    min_lat <- min(min_lat, selected_coordinates[, 2]); max_lat <- max(max_lat, selected_coordinates[, 2])
    selected_features <- features[in_domain]
    dates <- c(dates, vapply(selected_features, value_or_missing, character(1), field = "datecollected"))
    institutions <- c(institutions, vapply(selected_features, value_or_missing, character(1), field = "institutioncode"))
  }
  if (exact_records != core_records + external_records) {
    stop(sprintf("Exact-domain records do not all resolve to a frozen subregion for WFS %s.", dataset_id), call. = FALSE)
  }
  dates <- dates[!is.na(dates) & nzchar(dates)]
  institutions <- sort(unique(institutions[!is.na(institutions) & nzchar(institutions)]))
  evidence_rows[[length(evidence_rows) + 1L]] <- data.frame(
    work_item_id = paste0("EMODNET-WFS:", dataset_id),
    wfs_dataset_id = dataset_id,
    domain_bbox_records = as.integer(hit_row$domain_bbox_records),
    exact_domain_records = as.integer(exact_records),
    boundary_touch_records = as.integer(boundary_touch_records),
    core_domain_records = as.integer(core_records),
    external_transfer_records = as.integer(external_records),
    exact_unique_positions = as.integer(length(unique(unique_positions))),
    earliest_record_datetime = if (length(dates)) min(dates) else "",
    latest_record_datetime = if (length(dates)) max(dates) else "",
    minimum_longitude = if (exact_records) min_lon else NA_real_,
    maximum_longitude = if (exact_records) max_lon else NA_real_,
    minimum_latitude = if (exact_records) min_lat else NA_real_,
    maximum_latitude = if (exact_records) max_lat else NA_real_,
    institution_codes = paste(institutions, collapse = ";"),
    active_run_relative_path = pin$run_relative_path[[1]],
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}
evidence <- do.call(rbind, evidence_rows)
if (sum(evidence$domain_bbox_records) != pin$bbox_records_archived[[1]]) {
  stop("Derived WFS bounding-box total differs from the active run pin.", call. = FALSE)
}
write_csv_atomic(evidence, "metadata/stage2/screening/emodnet_wfs_geometry_evidence.csv")

screened <- initial_queue
evidence <- evidence[match(screened$work_item_id, evidence$work_item_id), , drop = FALSE]
has_domain_records <- evidence$exact_domain_records > 0L
screened$record_geometry_state <- "resolved"
screened$record_access_state <- ifelse(has_domain_records, "not_checked", "not_applicable")
screened$duplicate_resolution_state <- ifelse(has_domain_records, "not_checked", "not_applicable")
screened$screening_decision <- ifelse(has_domain_records, "pending", "excluded")
screened$required_next_action <- ifelse(
  has_domain_records,
  "resolve_canonical_provider_licence_and_duplicate_family",
  "none_no_occurrence_geometry_intersects_frozen_domain"
)
screened$decision_detail <- sprintf(
  "Provider WFS returned %d frozen-bbox records; exact checksum-pinned polygon intersection retained %d (%d core, %d external-transfer).",
  evidence$domain_bbox_records, evidence$exact_domain_records,
  evidence$core_domain_records, evidence$external_transfer_records
)
validate_stage2_wfs_queue(screened, contract, require_initial = FALSE)
write_csv_atomic(screened, "metadata/stage2/screening/emodnet_wfs_screening.csv")
message(sprintf("Exact WFS screening complete: %d candidates retain domain records; %d excluded by record geometry.",
                sum(has_domain_records), sum(!has_domain_records)))
