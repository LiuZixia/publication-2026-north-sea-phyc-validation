#!/usr/bin/env Rscript
# Checksum the authoritative Stage 5 metadata and report; large tables are represented by manifests.

source("R/00_core_setup.R")
source("R/03_stage2_contract.R")

paths <- sort(c(
  list.files("metadata/stage5", pattern = "[.]csv$", recursive = TRUE, full.names = TRUE),
  "outputs/reports/stage5_harmonization.md"
))
paths <- paths[!grepl("metadata/stage5/inventory/", paths, fixed = TRUE)]
paths <- paths[basename(paths) != "stage5_output_registry.csv"]
if (length(paths) < 20L || any(!file.exists(paths)) || any(file.info(paths)$size <= 0)) {
  stop("Stage 5 output registry requires all non-empty authoritative metadata and report outputs.",
       call. = FALSE)
}
value <- data.frame(
  path = paths, checksum_sha256 = unname(vapply(paths, calculate_checksum, character(1))),
  size_bytes = as.numeric(file.info(paths)$size), stringsAsFactors = FALSE, check.names = FALSE
)
dir.create("metadata/stage5/inventory", recursive = TRUE, showWarnings = FALSE)
write_csv_atomic(value, "metadata/stage5/inventory/stage5_output_registry.csv")
message(sprintf("Registered %d Stage 5 outputs.", nrow(value)))
