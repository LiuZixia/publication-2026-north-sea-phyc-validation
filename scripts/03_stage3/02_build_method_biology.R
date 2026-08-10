#!/usr/bin/env Rscript
# Audit method and biological-variable availability without constructing biomass or outcomes.

source("R/00_core_setup.R")
source("R/03_stage2_contract.R")
source("R/05_stage3_contract.R")

manifest <- utils::read.csv("metadata/stage3/input/stage3_input_manifest.csv",
                            stringsAsFactors = FALSE, check.names = FALSE)

evidence_text <- function(row) {
  ds <- row$ds_id[[1]]
  inventory <- list.files("metadata/stage2/screening",
                          pattern = paste0("^", tolower(ds), ".*variable_inventory[.]csv$"),
                          full.names = TRUE)
  pieces <- c(row$observation_kind[[1]], row$stage3_scope[[1]])
  summary <- utils::read.csv(row$status_evidence_path[[1]], stringsAsFactors = FALSE, check.names = FALSE)
  pieces <- c(pieces, unlist(summary, use.names = FALSE))
  if (length(inventory)) {
    inv <- utils::read.csv(inventory[[1]], stringsAsFactors = FALSE, check.names = FALSE)
    fields <- intersect(c("column_name", "semantic_role", "reported_unit", "example_values"), names(inv))
    pieces <- c(pieces, unlist(inv[fields], use.names = FALSE))
  }
  if (row$adapter_id[[1]] == "plet_csv") {
    dirs <- stage3_pin_run_dirs(ds)
    m <- utils::read.csv(file.path(dirs[[1]], "manifest.csv"), stringsAsFactors = FALSE)
    path <- file.path(dirs[[1]], m$file_name[grepl("[.]csv$", m$file_name)][[1]])
    preview <- utils::read.csv(path, nrows = 1000L, stringsAsFactors = FALSE, check.names = FALSE)
    pieces <- c(pieces, names(preview), unlist(preview[intersect(
      c("biomass_param", "biomass_param_units", "abundance_type", "lifeforms", "plankton_type"),
      names(preview))], use.names = FALSE))
  }
  if (row$adapter_id[[1]] == "eurobis_dwca") {
    dirs <- stage3_pin_run_dirs(ds); m <- utils::read.csv(file.path(dirs[[1]], "manifest.csv"))
    zips <- file.path(dirs[[1]], m$file_name[grepl("[.]zip$", m$file_name)])
    for (zip in zips) {
      for (member in c("event.txt", "occurrence.txt", "extendedmeasurementorfact.txt")) {
        con <- unz(zip, member); lines <- readLines(con, n = 200L, warn = FALSE); close(con)
        pieces <- c(pieces, lines)
      }
    }
  }
  if (row$adapter_id[[1]] == "pangaea_tabular") {
    dirs <- stage3_pin_run_dirs(ds); m <- utils::read.csv(file.path(dirs[[1]], "manifest.csv"))
    paths <- file.path(dirs[[1]], m$file_name[grepl("[.]txt$", m$file_name)])
    pieces <- c(pieces, unlist(lapply(utils::head(paths, 3L), readLines, n = 120L, warn = FALSE), use.names = FALSE))
  }
  if (row$adapter_id[[1]] == "comp4_station") {
    dirs <- stage3_pin_run_dirs(ds); m <- utils::read.csv(file.path(dirs[[1]], "manifest.csv"))
    paths <- file.path(dirs[[1]], m$file_name[grepl("StationSamples.*[.]gz$", m$file_name)])
    pieces <- c(pieces, unlist(lapply(paths, function(path) readLines(gzfile(path), n = 1L, warn = FALSE)), use.names = FALSE))
  }
  paste(pieces[!is.na(pieces)], collapse = " | ")
}

rows <- lapply(seq_len(nrow(manifest)), function(i) {
  row <- manifest[i, , drop = FALSE]
  ds <- row$ds_id[[1]]
  text <- tolower(evidence_text(row))
  present <- function(pattern) grepl(pattern, text, perl = TRUE)
  unavailable <- row$work_state[[1]] == "unavailable"
  carbon <- !unavailable && present("carbon|[µu]g[ _]?c|biomass.*c/l")
  biovolume <- !unavailable && present("biovol|bvol|cell volume|cubic millimetres")
  abundance <- !unavailable && present("abundance|biological density|number per litre|#/l|n/l|n/ml|cells? per|count|aantal")
  chlorophyll <- !unavailable && present("chlorophyll|chla|chlt|cphl")
  taxonomy <- !unavailable && present("taxon|scientificname|aphia|species")
  biomass_generic <- !unavailable && present("biomass_param|biomass value|biomass_value")
  if (ds == "DS09") carbon <- biovolume <- FALSE
  if (ds == "DS11") { abundance <- taxonomy <- biomass_generic <- FALSE }
  if (ds == "DS27") carbon <- biovolume <- FALSE
  conversion <- if (unavailable) "unavailable" else if (carbon) "direct_or_provider_carbon_present" else
    if (biovolume) "biovolume_present_conversion_required" else
    if (abundance && taxonomy) "abundance_taxonomy_present_stage5_conversion_audit_required" else
    if (biomass_generic) "generic_biomass_parameter_type_requires_audit" else "not_convertible_from_current_evidence"
  data.frame(
    ds_id = row$ds_id, monitoring_network = row$monitoring_network,
    work_state = row$work_state, stage2_tier = row$stage2_tier,
    has_carbon = carbon, has_biovolume = biovolume, has_abundance = abundance,
    has_chlorophyll = chlorophyll, has_taxonomy = taxonomy,
    has_depth = !unavailable && present("depth"), has_method = !unavailable && present("method|gear|instrument|device"),
    has_size_class = !unavailable && present("size[_ ]class|size fraction|size domain"),
    has_lifeform = !unavailable && present("lifeform|plankton_type|trophic"),
    has_colony_fields = !unavailable && present("colony|colonial|solitary"),
    potential_convertibility_state = conversion,
    cross_lifeform_dominance_permitted_now = (carbon || biovolume) && row$stage3_scope[[1]] == "primary_candidate",
    method_epoch_state = if (unavailable) "unavailable" else "requires_source_specific_stage5_harmonization",
    evidence_source = if (unavailable) row$status_evidence_path else
      paste(c(row$status_evidence_path, row$raw_manifest_paths), collapse = "|"),
    stringsAsFactors = FALSE, check.names = FALSE
  )
})
biology <- do.call(rbind, rows)
if (nrow(biology) != 19L || anyDuplicated(biology$ds_id) ||
    !all(biology$ds_id == manifest$ds_id) || any(biology$work_state == "unavailable" &
      (biology$has_carbon | biology$has_biovolume | biology$has_abundance))) {
  stop("Stage 3 method/biology output violates its contract.", call. = FALSE)
}
dir.create("metadata/stage3/method", recursive = TRUE, showWarnings = FALSE)
write_csv_atomic(biology, "metadata/stage3/method/method_biological_coverage.csv")

temporal <- utils::read.csv("metadata/stage3/coverage/temporal_cadence_by_year.csv",
                            stringsAsFactors = FALSE, check.names = FALSE)
epochs <- unique(temporal[c("ds_id", "monitoring_network", "method_epoch")])
epochs <- merge(epochs, biology[c("ds_id", "has_method", "method_epoch_state")], by = "ds_id", all.x = TRUE)
epochs$pooling_permission <- "not_permitted_until_method_epochs_are_harmonized"
write_csv_atomic(epochs, "metadata/stage3/method/method_epoch_register.csv")

network_year <- unique(temporal[c("ds_id", "monitoring_network", "subregion_id", "year")])
network_year <- merge(network_year, biology[c("ds_id", "stage2_tier", "has_carbon", "has_biovolume",
  "has_abundance", "has_chlorophyll", "has_taxonomy", "potential_convertibility_state")],
  by = "ds_id", all.x = TRUE)
write_csv_atomic(network_year, "metadata/stage3/method/network_year_variable_matrix.csv")

message("Generated Stage 3 method, biological, method-epoch, and network-year-variable evidence.")
