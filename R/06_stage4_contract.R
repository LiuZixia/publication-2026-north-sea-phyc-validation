# Helpers for the observation-only Stage 4 feasibility and confirmatory-design gate.

stage4_read_inputs <- function() {
  paths <- c(
    manifest = "metadata/stage3/input/stage3_input_manifest.csv",
    gate = "metadata/stage3/gate/dataset_region_period_role_gate.csv",
    biology = "metadata/stage3/method/method_biological_coverage.csv",
    design = "config/stage4_design_gate.csv"
  )
  missing <- paths[!file.exists(paths)]
  if (length(missing)) stop(sprintf("Stage 4 input is missing: %s", paste(missing, collapse = ", ")), call. = FALSE)
  value <- lapply(paths, utils::read.csv, stringsAsFactors = FALSE, check.names = FALSE)
  if (nrow(value$manifest) != 19L || anyDuplicated(value$manifest$ds_id) ||
      any(value$gate$phy_c_inspected) || anyDuplicated(value$design$decision_id)) {
    stop("Stage 4 inputs violate the Stage 3 handoff or PhyC boundary.", call. = FALSE)
  }
  value
}

stage4_primary_ids <- function() c("DS02", "DS04", "DS05", "DS06", "DS07", "DS16")

stage4_dataset_role <- function(ds_id) {
  if (ds_id == "DS06") return(c("primary_direct_carbon_anchor", "priority_harmonization"))
  if (ds_id %in% setdiff(stage4_primary_ids(), "DS06")) {
    return(c("primary_conversion_candidate", "priority_harmonization_and_conversion_audit"))
  }
  map <- list(
    DS03 = c("duplicate_audit_secondary", "deduplicate_against_DS02"),
    DS08 = c("unavailable", "no_current_stage5_input"),
    DS09 = c("exploratory_observation", "defer_unless_primary_gap_requires"),
    DS10 = c("lifeform_secondary", "secondary_method_harmonization"),
    DS11 = c("chlorophyll_comparator", "defer_to_comparator_harmonization"),
    DS12 = c("offshore_recurrence_secondary", "retain_for_required_offshore_secondary_arm"),
    DS15 = c("exploratory_derived_product", "no_observation_harmonization"),
    DS22 = c("required_conversion_authority", "required_for_stage5_conversion"),
    DS23 = c("unavailable", "no_current_stage5_input"),
    DS24 = c("chlorophyll_nutrient_comparator", "defer_to_comparator_harmonization"),
    DS26 = c("lifeform_method_secondary", "secondary_method_harmonization"),
    DS27 = c("chlorophyll_comparator", "defer_to_comparator_harmonization"),
    DS28 = c("unavailable", "no_current_stage5_input")
  )
  value <- map[[ds_id]]
  if (is.null(value)) stop(sprintf("No Stage 4 role for %s.", ds_id), call. = FALSE)
  value
}

stage4_reference_route <- function(ds_id, biology) {
  row <- biology[biology$ds_id == ds_id, , drop = FALSE]
  if (!nrow(row)) return("not_applicable")
  if (ds_id == "DS06") return("direct_carbon_or_biovolume_anchor")
  if (ds_id %in% setdiff(stage4_primary_ids(), "DS06")) {
    return("taxon_abundance_requires_stage5_carbon_conversion")
  }
  if (ds_id == "DS22") return("conversion_coefficient_authority")
  if (row$work_state == "unavailable") return("unavailable")
  "secondary_or_comparator_not_primary_truth"
}

stage4_frozen_subregions <- function() {
  required_namespace("sf")
  value <- sf::st_read("config/spatial/hydrographic_subregions.geojson", quiet = TRUE)
  sort(as.character(value$subregion_id))
}
