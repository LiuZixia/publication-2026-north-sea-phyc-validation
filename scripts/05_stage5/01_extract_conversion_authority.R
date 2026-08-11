#!/usr/bin/env Rscript
# Extract the checksum-pinned PEG_BVOL2026 workbook using a dependency-free OOXML reader.

source("R/00_core_setup.R")
source("R/03_stage2_contract.R")
source("R/07_stage5_contract.R")

contract <- stage5_read_source_contract()
row <- contract[contract$ds_id == "DS22", , drop = FALSE]
resolved <- stage5_resolve_source(row)
archive <- resolved$files[grepl("[.]zip$", resolved$files$path, ignore.case = TRUE), , drop = FALSE]
if (nrow(archive) != 1L) stop("DS22 Stage 2 pin must contain one PEG_BVOL ZIP.", call. = FALSE)
peg <- stage5_read_peg_bvol_xlsx(archive$path[[1]], "PEG_BVOL2026.xlsx")

dir.create("data/interim/stage5/reference", recursive = TRUE, showWarnings = FALSE)
interim_path <- "data/interim/stage5/reference/peg_bvol_2026.csv"
write_csv_atomic(peg, interim_path)

numeric_value <- function(name) suppressWarnings(as.numeric(peg[[name]]))
aphia <- suppressWarnings(as.integer(peg$AphiaID))
volume <- numeric_value("Calculated_volume_µm3/counting_unit")
carbon <- numeric_value("Calculated_Carbon_pg/counting_unit")
summary <- data.frame(
  authority_id = "DS22", authority_version = "PEG_BVOL2026",
  conversion_rows = nrow(peg), unique_aphia_ids = length(unique(aphia[!is.na(aphia)])),
  unique_reported_species = length(unique(peg$Species[nzchar(peg$Species)])),
  rows_with_central_volume = sum(is.finite(volume)), rows_with_central_carbon = sum(is.finite(carbon)),
  rows_without_aphia_id = sum(is.na(aphia)), duplicate_aphia_sizeclass_rows =
    sum(duplicated(paste(aphia, peg$SizeClassNo, peg$STAGE, sep = "|"))),
  extraction_state = "parsed_and_checksum_linked_not_yet_matched_to_observations",
  stringsAsFactors = FALSE, check.names = FALSE
)
provenance <- data.frame(
  authority_id = "DS22", authority_version = "PEG_BVOL2026",
  raw_outer_zip_path = archive$path[[1]],
  raw_outer_zip_checksum_sha256 = archive$checksum_sha256[[1]],
  inner_workbook = "PEG_BVOL2026.xlsx", worksheet = "Biovolume file",
  parser = "R/07_stage5_contract.R:stage5_read_peg_bvol_xlsx",
  acquisition_state = "canonical_stage2_provider_archive",
  phy_c_values_accessed = FALSE, stringsAsFactors = FALSE, check.names = FALSE
)
fields <- data.frame(
  source_field = names(peg),
  stage5_role = ifelse(names(peg) %in% c("AphiaID", "Genus", "Species", "STAGE"), "taxon_match_key",
                ifelse(names(peg) %in% c("Calculated_volume_µm3/counting_unit",
                                        "Calculated_Carbon_pg/counting_unit"), "central_conversion_value",
                ifelse(grepl("Length|Width|Height|Diameter|No_of_cells|Size", names(peg)),
                       "size_or_geometry_input", "preserved_authority_field"))),
  stringsAsFactors = FALSE, check.names = FALSE
)
dir.create("metadata/stage5/conversion", recursive = TRUE, showWarnings = FALSE)
write_csv_atomic(summary, "metadata/stage5/conversion/conversion_authority_summary.csv")
write_csv_atomic(provenance, "metadata/stage5/conversion/conversion_authority_provenance.csv")
write_csv_atomic(fields, "metadata/stage5/conversion/conversion_field_registry.csv")
message(sprintf("Extracted PEG_BVOL2026: %d conversion rows and %d unique AphiaIDs.",
                summary$conversion_rows, summary$unique_aphia_ids))
