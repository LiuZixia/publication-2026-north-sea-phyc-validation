# Spatial assignment utilities for assigning stations to frozen hydrographic regions.

required_namespace <- function(package) {
  if (!requireNamespace(package, quietly = TRUE)) {
    stop(sprintf("Required package '%s' is unavailable.", package), call. = FALSE)
  }
}

# Resolve multiple spatial candidates deterministically using the frozen tie-break order.
choose_spatial_candidate <- function(point, regions, candidate_rows, distance_tie_tolerance_m) {
  candidates <- regions[candidate_rows, , drop = FALSE]
  if (nrow(candidates) == 1L) return(candidates$subregion_id[[1]])

  centroid_distances <- as.numeric(sf::st_distance(point, sf::st_centroid(sf::st_geometry(candidates))))
  candidates <- candidates[abs(centroid_distances - min(centroid_distances)) <= distance_tie_tolerance_m, , drop = FALSE]
  sort(candidates$subregion_id, method = "radix")[[1]]
}

# Assign coordinates using zero polygon distance, then a strict 5,500 m geodesic tolerance.
assign_station <- function(
    lat,
    lon,
    subregions_file = "config/spatial/hydrographic_subregions.geojson",
    max_dist_m = 5500,
    distance_tie_tolerance_m = 0.000001) {
  required_namespace("sf")
  if (!is.numeric(lat) || !is.numeric(lon)) stop("lat and lon must be numeric.", call. = FALSE)
  if (length(lat) != length(lon)) stop("lat and lon must have the same length.", call. = FALSE)
  if (!is.numeric(max_dist_m) || length(max_dist_m) != 1L || is.na(max_dist_m) || max_dist_m < 0) {
    stop("max_dist_m must be one non-negative numeric value.", call. = FALSE)
  }
  if (!is.numeric(distance_tie_tolerance_m) || length(distance_tie_tolerance_m) != 1L ||
      is.na(distance_tie_tolerance_m) || distance_tie_tolerance_m < 0) {
    stop("distance_tie_tolerance_m must be one non-negative numeric value.", call. = FALSE)
  }
  if (!length(lat)) return(character())

  missing_coordinates <- is.na(lat) | is.na(lon)
  invalid_coordinates <- !missing_coordinates & (!is.finite(lat) | !is.finite(lon) | lat < -90 | lat > 90 | lon < -180 | lon > 180)
  if (any(invalid_coordinates)) {
    stop(sprintf("Invalid WGS84 coordinates at input row(s): %s", paste(which(invalid_coordinates), collapse = ", ")), call. = FALSE)
  }

  regions <- sf::st_read(subregions_file, quiet = TRUE)
  required_columns <- c("subregion_id", "geometry")
  if (!all(required_columns %in% names(regions))) stop("Subregion file lacks required columns.", call. = FALSE)
  if (anyNA(regions$subregion_id) || anyDuplicated(regions$subregion_id)) stop("Subregion IDs must be complete and unique.", call. = FALSE)
  if (!identical(sf::st_crs(regions)$epsg, 4326L)) stop("Subregion file must use EPSG:4326.", call. = FALSE)
  if (!all(sf::st_is_valid(regions))) stop("Subregion geometries must be valid.", call. = FALSE)

  output <- rep(NA_character_, length(lat))
  valid_rows <- which(!missing_coordinates)
  if (!length(valid_rows)) return(output)
  points <- sf::st_as_sf(
    data.frame(input_row = valid_rows, lon = lon[valid_rows], lat = lat[valid_rows]),
    coords = c("lon", "lat"),
    crs = 4326
  )

  for (point_row in seq_len(nrow(points))) {
    output_row <- points$input_row[[point_row]]
    polygon_distances <- as.numeric(sf::st_distance(points[point_row, ], regions))
    zero_distance_rows <- which(polygon_distances <= distance_tie_tolerance_m)
    if (length(zero_distance_rows)) {
      output[[output_row]] <- choose_spatial_candidate(
        points[point_row, ], regions, zero_distance_rows, distance_tie_tolerance_m
      )
      next
    }

    if (min(polygon_distances) <= max_dist_m) {
      nearest_rows <- which(abs(polygon_distances - min(polygon_distances)) <= distance_tie_tolerance_m)
      output[[output_row]] <- choose_spatial_candidate(
        points[point_row, ], regions, nearest_rows, distance_tie_tolerance_m
      )
    }
  }

  output
}
