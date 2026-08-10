#!/usr/bin/env Rscript
# Generate coverage-only figures; no ecological interpolation and no PhyC values are used.

temporal <- utils::read.csv("metadata/stage3/coverage/temporal_cadence_by_year.csv", stringsAsFactors = FALSE)
spatial <- utils::read.csv("metadata/stage3/coverage/spatial_support.csv", stringsAsFactors = FALSE)
dir.create("outputs/figures", recursive = TRUE, showWarnings = FALSE)

png("outputs/figures/stage3_temporal_coverage.png", width = 1800, height = 1200, res = 180)
ids <- sort(unique(temporal$ds_id)); y <- match(temporal$ds_id, ids)
plot(as.Date(temporal$first_date), y, type = "n", yaxt = "n", xlab = "Observation date",
     ylab = "Dataset", main = "Stage 3 observation support by year")
segments(as.Date(temporal$first_date), y, as.Date(temporal$last_date), y, col = "#2563EB55", lwd = 2)
axis(2, at = seq_along(ids), labels = ids, las = 1)
dev.off()

png("outputs/figures/stage3_spatial_support.png", width = 1800, height = 1200, res = 180)
valid <- is.finite(spatial$longitude_min) & is.finite(spatial$longitude_max) &
  is.finite(spatial$latitude_min) & is.finite(spatial$latitude_max)
plot(c(spatial$longitude_min[valid], spatial$longitude_max[valid]),
     c(spatial$latitude_min[valid], spatial$latitude_max[valid]), type = "n",
     xlab = "Longitude", ylab = "Latitude", main = "Sampling-support bounds (not ecological coverage)")
segments(spatial$longitude_min[valid], spatial$latitude_min[valid],
         spatial$longitude_max[valid], spatial$latitude_max[valid], col = "#05966966", lwd = 2)
text((spatial$longitude_min[valid] + spatial$longitude_max[valid]) / 2,
     (spatial$latitude_min[valid] + spatial$latitude_max[valid]) / 2,
     labels = spatial$ds_id[valid], cex = 0.7)
dev.off()

message("Generated Stage 3 coverage figures without interpolation.")
