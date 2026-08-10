#!/usr/bin/env Rscript
# Generate the Stage 4 observation-only feasibility, scope, and design registers.

source("R/00_core_setup.R")
source("R/03_stage2_contract.R")
source("R/06_stage4_contract.R")

input <- stage4_read_inputs()
manifest <- input$manifest
biology <- input$biology
gate <- input$gate
primary_ids <- stage4_primary_ids()
subregions <- stage4_frozen_subregions()
windows <- c("daily", "3_day", "7_day", "cadence_matched")

# Declare a role for every Stage 2 work item; no unavailable source becomes a zero-row observation.
role_values <- lapply(manifest$ds_id, stage4_dataset_role)
dataset_manifest <- manifest[c("ds_id", "monitoring_network", "independence_unit", "duplicate_family",
                               "work_state", "stage2_tier", "stage3_scope", "status_evidence_path")]
dataset_manifest$stage4_role <- vapply(role_values, `[[`, character(1), 1L)
dataset_manifest$stage5_action <- vapply(role_values, `[[`, character(1), 2L)
dataset_manifest$reference_route <- vapply(manifest$ds_id, stage4_reference_route, character(1), biology = biology)
dataset_manifest$independent_primary_network <- manifest$ds_id %in% primary_ids
dataset_manifest$final_primary_eligibility <- "pending_stage5_compatibility_and_stage6_outcomes"
dataset_manifest$phy_c_inspected <- FALSE
if (nrow(dataset_manifest) != 19L || anyDuplicated(dataset_manifest$ds_id) ||
    sum(dataset_manifest$independent_primary_network) != 6L || any(dataset_manifest$phy_c_inspected)) {
  stop("Stage 4 dataset manifest violates its complete-handoff contract.", call. = FALSE)
}

# Coverage years are an upper ceiling only; adequacy and events are deliberately not inferred.
eligible <- gate[gate$stage3_role == "eligible" & gate$ds_id %in% primary_ids &
                   gate$subregion_id %in% subregions, , drop = FALSE]
grid <- expand.grid(subregion_id = subregions, analysis_window = windows,
                    stringsAsFactors = FALSE, KEEP.OUT.ATTRS = FALSE)
feasibility_rows <- lapply(seq_len(nrow(grid)), function(i) {
  z <- eligible[eligible$subregion_id == grid$subregion_id[[i]] &
                  eligible$analysis_window == grid$analysis_window[[i]], , drop = FALSE]
  by_network <- if (nrow(z)) aggregate(year ~ independence_unit, z, function(x) length(unique(x))) else
    data.frame(independence_unit = character(), year = integer())
  network_count <- length(unique(z$independence_unit))
  max_years <- if (nrow(by_network)) max(by_network$year) else 0L
  networks_five_years <- if (nrow(by_network)) sum(by_network$year >= 5L) else 0L
  year_ceiling <- max_years >= 10L || networks_five_years >= 2L
  direct <- unique(z$independence_unit[z$ds_id == "DS06"])
  converted <- unique(z$independence_unit[z$ds_id != "DS06"])
  data.frame(
    subregion_id = grid$subregion_id[[i]], analysis_window = grid$analysis_window[[i]],
    primary_dataset_count = length(unique(z$ds_id)), independent_network_count = network_count,
    coverage_year_count = length(unique(z$year)), max_coverage_years_in_one_network = max_years,
    networks_with_at_least_five_coverage_years = networks_five_years,
    direct_carbon_network_count = length(direct), conversion_candidate_network_count = length(converted),
    recurrence_year_count_ceiling = if (year_ceiling) "potentially_satisfiable" else "not_satisfied",
    adequately_sampled_year_state = "unknown_pending_prespecified_adequacy_rules",
    bloom_event_count_state = "unknown_until_stage6_observation_only_outcomes",
    heldout_evaluation_state = if (network_count >= 2L && year_ceiling)
      "potential_only_pending_adequacy_conversion_and_events" else "insufficient_current_coverage_ceiling",
    stage5_route = if (network_count >= 1L && year_ceiling) "proceed_selected_datasets_to_stage5" else "no_primary_stage5_route_for_this_combination",
    phy_c_inspected = FALSE,
    stringsAsFactors = FALSE, check.names = FALSE
  )
})
feasibility <- do.call(rbind, feasibility_rows)
if (nrow(feasibility) != length(subregions) * length(windows) ||
    anyDuplicated(feasibility[c("subregion_id", "analysis_window")]) || any(feasibility$phy_c_inspected)) {
  stop("Stage 4 subregion/window feasibility grid is incomplete.", call. = FALSE)
}

# Candidate-window roles depend only on independent observation breadth and recurrence-year ceilings.
window_rows <- lapply(windows, function(window) {
  z <- feasibility[feasibility$analysis_window == window, , drop = FALSE]
  supported_regions <- sum(z$independent_network_count >= 2L &
                             z$recurrence_year_count_ceiling == "potentially_satisfiable")
  role <- if (supported_regions == length(subregions)) "primary_window_candidate" else
    if (supported_regions >= 1L) "secondary_window_candidate" else "not_confirmatory"
  data.frame(
    analysis_window = window,
    frozen_subregions_with_two_network_and_year_ceiling = supported_regions,
    total_independent_networks = length(unique(eligible$independence_unit[eligible$analysis_window == window])),
    window_design_role = role,
    timing_claim = if (window == "daily") "daily_state_only_where_observation_cadence_supports" else
      if (window == "cadence_matched") "concurrent_state_at_observation_supported_cadence" else
        paste0("concurrent_", window, "_window_state"),
    final_primary_window_frozen = FALSE,
    stringsAsFactors = FALSE
  )
})
window_register <- do.call(rbind, window_rows)

# Lifeform status remains prospective; recurrence and dominance are not generated from coverage.
lifeforms <- data.frame(
  lifeform = c("diatom", "phaeocystis_haptophyte", "dinoflagellate",
               "coccolithophore", "pico_nanophytoplankton"),
  prospective_role = c(rep("confirmatory_candidate_pending_stage5_stage6", 3L),
                       rep("exploratory_unless_stage6_rules_pass", 2L)),
  primary_networks_with_lifeform_fields = sum(biology$ds_id %in% primary_ids & biology$has_lifeform),
  primary_networks_with_direct_carbon_or_biovolume = sum(biology$ds_id %in% primary_ids &
                                                           (biology$has_carbon | biology$has_biovolume)),
  recurrence_state = "not_calculated_before_stage6",
  dominance_state = "pending_stage5_carbon_or_biovolume_shares",
  confirmatory_now = FALSE,
  phy_c_inspected = FALSE,
  stringsAsFactors = FALSE
)

scope_limitations <- data.frame(
  limitation_id = c("tier_a_base", "offshore_central_northern", "target_season_adequacy",
                    "event_counts", "cmems_overlap", "contact_required_inputs"),
  current_state = c(
    "only_DS06_direct_carbon_anchor_in_external_transfer_region",
    "not_separately_represented_by_frozen_two_polygon_scheme",
    "numeric_rules_not_yet_prespecified",
    "not_available_before_stage6",
    "unknown_until_product_metadata_is_frozen",
    "DS08_DS23_DS28_unavailable_under_frozen_policy"
  ),
  consequence = c(
    "primary_route_expected_to_depend_on_tier_c_conversion_uncertainty",
    "cannot_claim_offshore_adequacy_or_absence_from_broad_core_polygon",
    "cannot_label adequately sampled years or observed negatives",
    "heldout_event_feasibility remains unknown",
    "no observation is excluded for assumed model nonoverlap",
    "missing access remains unknown and not an ecological zero"
  ),
  required_resolution = c(
    "stage5_three_series_conversion_and_stage10_uncertainty_propagation",
    "prospective_spatial_protocol_amendment_or_explicit_unresolved_scope",
    "principal_investigator_freeze_before_stage6_outcomes",
    "stage6_observation_only_event_catalogue",
    "stage7_selection_freeze_and_stage8_product_audit",
    "dated_stage2_reentry_only_if_provider_evidence_arrives"
  ),
  phy_c_inspected = FALSE,
  stringsAsFactors = FALSE
)

questions <- data.frame(
  question = c("primary_total_biomass_validation", "network_transfer", "region_transfer",
               "heldout_event_evaluation", "lifeform_stratified_validation",
               "basin_wide_offshore_claim", "daily_confirmatory_validation"),
  stage4_state = c(
    "conditionally_supportable_for_stage5_harmonization_only",
    "potentially_supportable_six_independent_primary_candidates",
    "potentially_supportable_two_broad_regions_only",
    "not_yet_estimable_without_events",
    "not_yet_estimable_without_converted_dominance_and_recurrence",
    "not_operationally_assessable_with_current_spatial_units",
    "not_confirmatory"
  ),
  next_gate = c("stage5", "stage5_stage7", "spatial_amendment_stage5_stage7", "stage6_stage7",
                "stage5_stage6", "protocol_decision", "none_secondary_only"),
  phy_c_inspected = FALSE,
  stringsAsFactors = FALSE
)

dir.create("metadata/stage4/feasibility", recursive = TRUE, showWarnings = FALSE)
write_csv_atomic(dataset_manifest, "metadata/stage4/feasibility/provisional_dataset_manifest.csv")
write_csv_atomic(feasibility, "metadata/stage4/feasibility/subregion_window_feasibility.csv")
write_csv_atomic(window_register, "metadata/stage4/feasibility/window_candidate_register.csv")
write_csv_atomic(lifeforms, "metadata/stage4/feasibility/lifeform_feasibility.csv")
write_csv_atomic(scope_limitations, "metadata/stage4/feasibility/scope_limitations.csv")
write_csv_atomic(questions, "metadata/stage4/feasibility/question_feasibility.csv")
message("Generated Stage 4 observation-only feasibility and design registers.")
