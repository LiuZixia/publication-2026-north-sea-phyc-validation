# Screen the canonical RWS catalogue to define, but not yet execute, DS02 observation requests.

source("R/00_core_setup.R")
source("R/03_stage2_contract.R")
required_namespace("jsonlite")
required_namespace("sf")

contract <- read_stage2_contract()
pin <- utils::read.csv("metadata/stage2_ds02_rws_catalogue_active_run.csv",
                       stringsAsFactors = FALSE, check.names = FALSE)
manifest <- utils::read.csv("metadata/stage2_ds02_rws_catalogue_acquisition_manifest.csv",
                            stringsAsFactors = FALSE, check.names = FALSE)
access <- utils::read.csv("metadata/stage2_ds02_rws_v3_access_diagnosis.csv",
                          stringsAsFactors = FALSE, check.names = FALSE)
access_pin <- utils::read.csv("metadata/stage2_ds02_rws_v3_access_active_run.csv",
                              stringsAsFactors = FALSE, check.names = FALSE)
if (nrow(pin) != 1L || pin$work_item_id[[1]] != "REGISTER:DS02" || nrow(manifest) != 3L) {
  stop("DS02 RWS catalogue active run or manifest is invalid.", call. = FALSE)
}
if (nrow(access) != 1L || nrow(access_pin) != 1L || access$http_status[[1]] != 401L ||
    isTRUE(access$authentication_sent[[1]]) || access$observation_rows_acquired[[1]] != 0L ||
    !identical(calculate_checksum(file.path("data", "raw", access$evidence_relative_path[[1]])),
               access$evidence_checksum_sha256[[1]])) {
  stop("DS02 RWS V3 access diagnosis is missing or invalid.", call. = FALSE)
}
validate_stage2_table(manifest, "acquisition_manifest", contract)
run_dir <- file.path("data", "raw", pin$run_relative_path[[1]])
catalogue_path <- file.path(run_dir, "rws_extended_catalogue.json")
if (!identical(calculate_checksum(file.path(run_dir, "manifest.csv")),
               pin$manifest_checksum_sha256[[1]]) ||
    !identical(calculate_checksum(catalogue_path), pin$catalogue_checksum_sha256[[1]])) {
  stop("DS02 RWS catalogue checksums do not reconcile with the active pin.", call. = FALSE)
}

metadata_path <- "metadata/stage2_ds02_rws_catalogue_metadata.csv"
location_path <- "metadata/stage2_ds02_rws_catalogue_location_screen.csv"
link_summary_path <- "metadata/stage2_ds02_rws_catalogue_link_summary.csv"

registry_path <- "metadata/stage2_ds02_rws_catalogue_output_registry.csv"

catalogue <- jsonlite::fromJSON(catalogue_path, simplifyVector = FALSE)
if (!isTRUE(catalogue$Succesvol) || length(catalogue$AquoMetadataLijst) != 2757L ||
    length(catalogue$LocatieLijst) != 2635L ||
    length(catalogue$AquoMetadataLocatieLijst) != 104679L) {
  stop("DS02 RWS catalogue totals differ from the pinned response.", call. = FALSE)
}

nested_value <- function(value, parent, child) {
  result <- value[[parent]][[child]]
  if (is.null(result)) "" else as.character(result)
}
metadata <- do.call(rbind, lapply(catalogue$AquoMetadataLijst, function(value) data.frame(
  metadata_id = as.integer(value$AquoMetadata_MessageID),
  biotaxon_code = nested_value(value, "BioTaxon", "Code"),
  biotaxon_description = nested_value(value, "BioTaxon", "Omschrijving"),
  compartment_code = nested_value(value, "Compartiment", "Code"),
  compartment_description = nested_value(value, "Compartiment", "Omschrijving"),
  unit_code = nested_value(value, "Eenheid", "Code"),
  unit_description = nested_value(value, "Eenheid", "Omschrijving"),
  quantity_code = nested_value(value, "Grootheid", "Code"),
  quantity_description = nested_value(value, "Grootheid", "Omschrijving"),
  condition_code = nested_value(value, "Hoedanigheid", "Code"),
  condition_description = nested_value(value, "Hoedanigheid", "Omschrijving"),
  organ_code = nested_value(value, "Orgaan", "Code"),
  organ_description = nested_value(value, "Orgaan", "Omschrijving"),
  parameter_code = nested_value(value, "Parameter", "Code"),
  parameter_description = nested_value(value, "Parameter", "Omschrijving"),
  reported_description = as.character(value$Parameter_Wat_Omschrijving %||% ""),
  process_type = as.character(value$ProcesType %||% ""),
  typing_code = nested_value(value, "Typering", "Code"),
  value_processing_method_code = nested_value(value, "WaardeBewerkingsMethode", "Code"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)))
if (anyDuplicated(metadata$metadata_id)) stop("RWS catalogue metadata IDs collide.", call. = FALSE)

locations <- do.call(rbind, lapply(catalogue$LocatieLijst, function(value) data.frame(
  location_id = as.integer(value$Locatie_MessageID),
  location_code = as.character(value$Code %||% ""),
  location_name = as.character(value$Naam %||% ""),
  location_description = as.character(value$Omschrijving %||% ""),
  reported_crs = as.character(value$Coordinatenstelsel %||% ""),
  reported_latitude = as.numeric(value$Lat),
  reported_longitude = as.numeric(value$Lon),
  stringsAsFactors = FALSE,
  check.names = FALSE
)))
if (anyDuplicated(locations$location_id) || any(locations$reported_crs != "ETRS89")) {
  stop("RWS catalogue locations have duplicate IDs or an unexpected CRS.", call. = FALSE)
}

# Apply the exact frozen geometry. ETRS89 coordinates are transformed from EPSG:4258 to WGS84.
valid <- is.finite(locations$reported_latitude) & is.finite(locations$reported_longitude) &
  locations$reported_latitude >= -90 & locations$reported_latitude <= 90 &
  locations$reported_longitude >= -180 & locations$reported_longitude <= 180
locations$longitude <- NA_real_
locations$latitude <- NA_real_
locations$domain_state <- "invalid_coordinate"
locations$subregion_id <- NA_character_
sf::sf_use_s2(FALSE)
domain <- sf::st_read("config/spatial/greater_north_sea.geojson", quiet = TRUE)
subregions <- sf::st_read("config/spatial/hydrographic_subregions.geojson", quiet = TRUE)
points <- sf::st_as_sf(
  data.frame(row = which(valid), lon = locations$reported_longitude[valid],
             lat = locations$reported_latitude[valid]),
  coords = c("lon", "lat"), crs = 4258
)
points <- sf::st_transform(points, 4326)
coordinates <- sf::st_coordinates(points)
locations$longitude[points$row] <- coordinates[, 1]
locations$latitude[points$row] <- coordinates[, 2]
domain_hit <- lengths(suppressMessages(sf::st_intersects(points, domain, prepared = TRUE))) > 0L
locations$domain_state[points$row] <- "outside_domain"
if (any(domain_hit)) {
  region_hit <- suppressMessages(sf::st_intersects(points[domain_hit, , drop = FALSE], subregions,
                                                    prepared = TRUE))
  region_index <- vapply(region_hit, function(value) if (length(value)) value[[1]] else NA_integer_,
                         integer(1))
  if (anyNA(region_index)) stop("An in-domain RWS location lacks a frozen subregion.", call. = FALSE)
  selected_rows <- points$row[domain_hit]
  locations$domain_state[selected_rows] <- ifelse(subregions$role[region_index] == "core-domain",
                                                   "core", "external_transfer")
  locations$subregion_id[selected_rows] <- subregions$subregion_id[region_index]
}

links <- do.call(rbind, lapply(catalogue$AquoMetadataLocatieLijst, function(value) data.frame(
  metadata_id = as.integer(value$AquoMetaData_MessageID),
  location_id = as.integer(value$Locatie_MessageID),
  stringsAsFactors = FALSE,
  check.names = FALSE
)))
if (any(!links$metadata_id %in% metadata$metadata_id) ||
    any(!links$location_id %in% locations$location_id)) {
  stop("RWS metadata-location links contain orphan keys.", call. = FALSE)
}
link_domain <- locations$domain_state[match(links$location_id, locations$location_id)]
metadata_domain <- unique(links$metadata_id[link_domain %in% c("core", "external_transfer")])
metadata$domain_location_present <- metadata$metadata_id %in% metadata_domain

# The public DD API 2.0 catalogue contains only freshwater cyanobacteria among count-per-volume
# taxon definitions. This is route evidence, not an ecological exclusion: marine taxon-resolved
# observations may reside only in the credentialed DD API V3/Waterinfo export.
phytoplankton_pattern <- "phytoplank|fytoplank|phaeocystis|diatom|dinoflagell|haptophyt|coccolith"
metadata$explicit_marine_phytoplankton_signal <- grepl(
  phytoplankton_pattern,
  paste(metadata$biotaxon_code, metadata$biotaxon_description,
        metadata$parameter_code, metadata$parameter_description, metadata$reported_description),
  ignore.case = TRUE
)
metadata$count_or_biovolume_signal <- metadata$quantity_code %in%
  c("AANTPVLME", "BIOVLMPVLME")
if (any(metadata$explicit_marine_phytoplankton_signal)) {
  stop("The RWS DD API 2.0 catalogue now exposes explicit marine phytoplankton metadata; review the frozen selection before observation requests.",
       call. = FALSE)
}

link_summary <- data.frame(
  catalogue_metadata_rows = nrow(metadata),
  catalogue_location_rows = nrow(locations),
  catalogue_metadata_location_links = nrow(links),
  core_locations = sum(locations$domain_state == "core"),
  external_transfer_locations = sum(locations$domain_state == "external_transfer"),
  outside_domain_locations = sum(locations$domain_state == "outside_domain"),
  invalid_coordinate_locations = sum(locations$domain_state == "invalid_coordinate"),
  domain_linked_metadata_rows = sum(metadata$domain_location_present),
  count_or_biovolume_metadata_rows = sum(metadata$count_or_biovolume_signal),
  explicit_marine_phytoplankton_metadata_rows =
    sum(metadata$explicit_marine_phytoplankton_signal),
  observation_rows_acquired = 0L,
  stringsAsFactors = FALSE,
  check.names = FALSE
)

write_csv_atomic(metadata, metadata_path)
write_csv_atomic(locations, location_path)
write_csv_atomic(link_summary, link_summary_path)
registry <- data.frame(
  artifact_role = c("catalogue_metadata", "catalogue_location_screen", "catalogue_link_summary"),
  path = c(metadata_path, location_path, link_summary_path),
  row_count = c(nrow(metadata), nrow(locations), nrow(link_summary)),
  checksum_sha256 = vapply(c(metadata_path, location_path, link_summary_path),
                           calculate_checksum, character(1)),
  generated_from_manifest_sha256 = pin$manifest_checksum_sha256[[1]],
  stringsAsFactors = FALSE,
  check.names = FALSE
)
write_csv_atomic(registry, registry_path)
message(sprintf(
  "DS02 catalogue screen complete: %d core, %d external, %d outside locations; observations pending.",
  link_summary$core_locations, link_summary$external_transfer_locations,
  link_summary$outside_domain_locations
))
