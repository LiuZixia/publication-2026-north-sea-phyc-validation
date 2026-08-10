#!/usr/bin/env Rscript
# Checksum the authoritative Stage 4 generated outputs.

source("R/00_core_setup.R")
source("R/03_stage2_contract.R")

paths <- c(sort(list.files("metadata/stage4/feasibility", pattern = "[.]csv$", full.names = TRUE)),
           "metadata/stage4/gate/stage4_gate_status.csv", "outputs/reports/stage4_feasibility.md")
if (length(paths) != 8L || any(!file.exists(paths)) || any(file.info(paths)$size <= 0)) {
  stop("Stage 4 output registry requires eight non-empty authoritative outputs.", call. = FALSE)
}
value <- data.frame(path = paths,
                    checksum_sha256 = unname(vapply(paths, calculate_checksum, character(1))),
                    size_bytes = as.numeric(file.info(paths)$size),
                    stringsAsFactors = FALSE, check.names = FALSE)
write_csv_atomic(value, "metadata/stage4/inventory/stage4_output_registry.csv")
message(sprintf("Registered %d Stage 4 outputs.", nrow(value)))
