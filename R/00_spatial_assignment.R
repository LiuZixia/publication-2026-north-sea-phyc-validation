# R/00_spatial_assignment.R
# Spatial assignment utilities for assigning stations to hydrographic subregions.

library(sf)

#' Assign a station to a subregion
#'
#' @param lat Numeric. Latitude in decimal degrees (WGS84).
#' @param lon Numeric. Longitude in decimal degrees (WGS84).
#' @param subregions_file Character. Path to the hydrographic_subregions.geojson.
#' @param max_dist_m Numeric. Maximum distance in meters (approx 5500m ~ 0.05deg) to allow assigning to the nearest region if outside.
#' @return Character vector of subregion_id.
assign_station <- function(lat, lon, subregions_file = "config/spatial/hydrographic_subregions.geojson", max_dist_m = 5500) {
  if (length(lat) != length(lon)) stop("lat and lon must be the same length")
  if (length(lat) == 0) return(character(0))
  
  # Return NA if coordinates are missing
  out_ids <- rep(NA_character_, length(lat))
  valid_idx <- which(!is.na(lat) & !is.na(lon))
  if (length(valid_idx) == 0) return(out_ids)
  
  regions <- sf::st_read(subregions_file, quiet = TRUE)
  # Create point geometry
  pts <- sf::st_as_sf(data.frame(lon = lon[valid_idx], lat = lat[valid_idx]), 
                      coords = c("lon", "lat"), 
                      crs = sf::st_crs(regions))
  
  # Perform spatial join (which point is in which polygon)
  joined <- sf::st_join(pts, regions, join = sf::st_within)
  
  for (i in seq_along(valid_idx)) {
    orig_idx <- valid_idx[i]
    pt <- pts[i, ]
    match_ids <- joined$subregion_id[which(joined$geometry == pt$geometry)]
    match_ids <- match_ids[!is.na(match_ids)]
    
    if (length(match_ids) == 1) {
      out_ids[orig_idx] <- match_ids[1]
    } else if (length(match_ids) > 1) {
      # Overlap tie-breaking: distance to centroid (closest centroid wins)
      # Calculate centroid distance for all matching regions
      c_dists <- numeric(length(match_ids))
      for (j in seq_along(match_ids)) {
        poly <- regions[regions$subregion_id == match_ids[j], ]
        c_dists[j] <- as.numeric(sf::st_distance(pt, sf::st_centroid(poly)))
      }
      out_ids[orig_idx] <- match_ids[which.min(c_dists)]
    } else {
      # Point is outside valid regions. Use coastal buffer logic.
      # Find distance to nearest polygon
      dists <- sf::st_distance(pt, regions)
      min_dist <- min(dists)
      if (as.numeric(min_dist) <= max_dist_m) {
        # Inside buffer, assign to nearest
        out_ids[orig_idx] <- regions$subregion_id[which.min(dists)]
      } else {
        # Outside buffer
        out_ids[orig_idx] <- NA_character_
      }
    }
  }
  
  return(out_ids)
}
