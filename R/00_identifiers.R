# R/00_identifiers.R
# Deterministic identifier generation for Stage 0 governance

library(digest)

#' Base hash generator
#' @param prefix Character prefix.
#' @param fields Character vector of inputs.
#' @return A stable ID string.
generate_stable_id <- function(prefix, fields) {
  # Normalize missing values to "NA" and ensure character type
  clean_fields <- vapply(fields, function(x) {
    if (length(x) == 0 || is.na(x) || trimws(as.character(x)) == "") {
      "NA"
    } else {
      trimws(as.character(x))
    }
  }, character(1))
  
  # Concatenate with pipe separator
  concat_str <- paste(clean_fields, collapse = "|")
  
  # Generate SHA-256 hash and truncate to 16 characters for brevity but low collision
  hash_full <- digest::digest(concat_str, algo = "sha256", serialize = FALSE)
  hash_short <- substr(hash_full, 1, 16)
  
  paste0(prefix, "-", hash_short)
}

# Specific generators with canonical inputs

generate_dataset_id <- function(provider, source_dataset_name, version) {
  generate_stable_id("DS", c(provider, source_dataset_name, version))
}

generate_station_id <- function(dataset_id, provider_station_name, lat, lon) {
  # Round lat/lon to 4 decimal places for stable identity matching (approx 11m precision)
  r_lat <- sprintf("%.4f", as.numeric(lat))
  r_lon <- sprintf("%.4f", as.numeric(lon))
  generate_stable_id("STN", c(dataset_id, provider_station_name, r_lat, r_lon))
}

generate_sample_id <- function(station_id, utc_timestamp, depth) {
  # Timestamp in ISO format (YYYY-MM-DDTHH:MM:SSZ), Depth rounded to 1 decimal place
  r_depth <- sprintf("%.1f", as.numeric(depth))
  generate_stable_id("SMP", c(station_id, utc_timestamp, r_depth))
}

generate_source_record_id <- function(dataset_id, provider_record_id, collision_index = 1) {
  generate_stable_id("REC", c(dataset_id, provider_record_id, as.character(collision_index)))
}

generate_taxon_record_id <- function(sample_id, taxon_name, life_stage) {
  generate_stable_id("TAX", c(sample_id, tolower(taxon_name), tolower(life_stage)))
}

generate_event_id <- function(subregion_id, year, event_number) {
  generate_stable_id("EVT", c(subregion_id, year, event_number))
}

generate_year_id <- function(subregion_id, year) {
  generate_stable_id("YR", c(subregion_id, year))
}

generate_network_id <- function(provider) {
  generate_stable_id("NET", c(provider))
}

generate_subregion_id <- function(name) {
  generate_stable_id("REG", c(name))
}

generate_search_run_id <- function(provider, timestamp) {
  generate_stable_id("SEARCH", c(provider, timestamp))
}

generate_observation_window_id <- function(station_id, start_date, end_date) {
  generate_stable_id("WIN", c(station_id, start_date, end_date))
}

generate_model_file_id <- function(filename, checksum) {
  generate_stable_id("MOD", c(filename, checksum))
}
