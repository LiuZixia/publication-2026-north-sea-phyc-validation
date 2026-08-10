#!/usr/bin/env Rscript
# Apply the prespecified Stage 3 coverage gate without using any PhyC value.

source("R/00_core_setup.R")
source("R/03_stage2_contract.R")

manifest <- utils::read.csv("metadata/stage3/input/stage3_input_manifest.csv", stringsAsFactors = FALSE)
biology <- utils::read.csv("metadata/stage3/method/method_biological_coverage.csv", stringsAsFactors = FALSE)
temporal <- utils::read.csv("metadata/stage3/coverage/temporal_cadence_by_year.csv", stringsAsFactors = FALSE)
spatial <- utils::read.csv("metadata/stage3/coverage/spatial_support.csv", stringsAsFactors = FALSE)
samples <- utils::read.csv("data/interim/stage3_sample_support.csv", stringsAsFactors = FALSE)

windows <- c("daily", "3_day", "7_day", "cadence_matched")
support_column <- c(daily = "supports_daily", `3_day` = "supports_3_day",
                    `7_day` = "supports_7_day", cadence_matched = "supports_cadence_matched")
gate_rows <- list()
for (i in seq_len(nrow(manifest))) {
  m <- manifest[i, , drop = FALSE]
  b <- biology[biology$ds_id == m$ds_id, , drop = FALSE]
  t <- temporal[temporal$ds_id == m$ds_id, , drop = FALSE]
  periods <- if (nrow(t)) split(t, seq_len(nrow(t))) else list(data.frame())
  for (tr in periods) {
    region <- if (nrow(tr)) tr$subregion_id[[1]] else "not_applicable"
    for (window in windows) {
      supported <- nrow(tr) && isTRUE(tr[[support_column[[window]]]][[1]])
      role <- "unusable"
      reason <- "no_observation_coverage"
      if (m$work_state == "unavailable") {
        reason <- "temporarily_unavailable_under_frozen_access_policy"
      } else if (m$adapter_id == "conversion_authority") {
        role <- "secondary"; reason <- "conversion_authority_not_observation_network"
      } else if (m$adapter_id == "non_observational_product") {
        role <- "exploratory"; reason <- "derived_product_not_independent_event_truth"
      } else if (!supported) {
        reason <- paste0("cadence_does_not_support_", window)
      } else if (m$stage3_scope == "primary_candidate_duplicate_audit") {
        role <- "secondary"; reason <- "aggregator_copy_shares_independence_unit_with_DS02"
      } else if (m$stage3_scope == "primary_candidate") {
        convertible <- b$has_carbon || b$has_biovolume || (b$has_abundance && b$has_taxonomy) ||
          grepl("generic_biomass_parameter", b$potential_convertibility_state)
        if (convertible) {
          role <- "eligible"; reason <- "primary_reference_candidate_with_supported_coverage_pending_stage5_compatibility"
        } else {
          role <- "exploratory"; reason <- "primary_candidate_lacks_current_biomass_or_conversion_inputs"
        }
      } else if (m$stage3_scope %in% c("lifeform_secondary", "lifeform_method_secondary",
                                       "recurrence_secondary", "comparator")) {
        role <- "secondary"; reason <- paste0(m$stage3_scope, "_only")
      } else {
        role <- "exploratory"; reason <- paste0(m$stage3_scope, "_not_primary_truth")
      }
      gate_rows[[length(gate_rows) + 1L]] <- data.frame(
        ds_id = m$ds_id, monitoring_network = m$monitoring_network,
        independence_unit = m$independence_unit, duplicate_family = m$duplicate_family,
        subregion_id = region,
        method_epoch = if (nrow(tr)) tr$method_epoch[[1]] else "not_applicable",
        year = if (nrow(tr)) tr$year[[1]] else NA_integer_,
        period_start = if (nrow(tr)) tr$first_date[[1]] else "",
        period_end = if (nrow(tr)) tr$last_date[[1]] else "",
        analysis_window = window, reference_tier = m$stage2_tier,
        stage3_role = role, role_reason = reason,
        stage5_compatibility_still_required = role == "eligible",
        phy_c_inspected = FALSE,
        stringsAsFactors = FALSE, check.names = FALSE
      )
    }
  }
}
gate <- do.call(rbind, gate_rows)
allowed <- c("eligible", "secondary", "exploratory", "unusable")
key <- c("ds_id", "monitoring_network", "subregion_id", "period_start", "period_end",
         "method_epoch", "year", "analysis_window", "reference_tier")
if (anyDuplicated(gate[key]) || any(!gate$stage3_role %in% allowed) || any(gate$phy_c_inspected) ||
    !all(manifest$ds_id %in% gate$ds_id) || !any(gate$stage3_role == "eligible")) {
  stop("Stage 3 role gate violates identity, vocabulary, boundary, or evidence assertions.", call. = FALSE)
}
dir.create("metadata/stage3/gate", recursive = TRUE, showWarnings = FALSE)
write_csv_atomic(gate, "metadata/stage3/gate/dataset_region_period_role_gate.csv")

# Product identity is intentionally not guessed before its prospective freeze.
starts <- aggregate(first_date ~ ds_id + monitoring_network, data = temporal, FUN = min)
ends <- aggregate(last_date ~ ds_id + monitoring_network, data = temporal, FUN = max)
periods <- merge(starts, ends, by = c("ds_id", "monitoring_network"), sort = FALSE)
overlap <- data.frame(
  ds_id = periods$ds_id, monitoring_network = periods$monitoring_network,
  observation_start = periods$first_date,
  observation_end = periods$last_date,
  candidate_cmems_product_id = "not_prospectively_frozen",
  candidate_product_start = "", candidate_product_end = "",
  temporal_overlap_state = "unknown_until_product_metadata_is_frozen",
  phy_c_values_accessed = FALSE,
  stringsAsFactors = FALSE, check.names = FALSE
)
write_csv_atomic(overlap, "metadata/stage3/gate/cmems_metadata_overlap.csv")

sample_state <- do.call(rbind, lapply(split(samples, samples$ds_id), function(x) data.frame(
  ds_id = x$ds_id[[1]], sample_support_rows = nrow(x),
  missing_datetime_rows = sum(!nzchar(x$datetime_utc)),
  missing_coordinate_rows = sum(!is.finite(x$latitude) | !is.finite(x$longitude)),
  missing_depth_rows = sum(!is.finite(x$depth_min_m) & !is.finite(x$depth_max_m)),
  proxy_station_rows = sum(grepl("^(coordinate_proxy|transect):", x$station_id)),
  stringsAsFactors = FALSE
)))
gaps <- merge(manifest[c("ds_id", "work_state", "adapter_id", "stage3_scope", "status_evidence_path")],
              sample_state, by = "ds_id", all.x = TRUE)
for (name in c("sample_support_rows", "missing_datetime_rows", "missing_coordinate_rows",
               "missing_depth_rows", "proxy_station_rows")) gaps[[name]][is.na(gaps[[name]])] <- 0L
gaps$coverage_gap_state <- ifelse(gaps$work_state == "unavailable", "access_unavailable",
  ifelse(gaps$adapter_id %in% c("conversion_authority", "non_observational_product"),
         "not_an_observation_network",
  ifelse(gaps$sample_support_rows == 0, "adapter_has_no_sample_support", "sample_support_available")))
gaps$known_bias_or_limit <- ifelse(gaps$stage3_scope == "primary_candidate_duplicate_audit",
  "aggregator_copy_not_independent_from_RWS_MWTL",
  ifelse(gaps$proxy_station_rows > 0, "coordinates_or_transects_must_not_be_called_stations",
  ifelse(gaps$missing_depth_rows > 0, "vertical_support_incomplete", "none_recorded_at_stage3")))
write_csv_atomic(gaps, "metadata/stage3/gate/coverage_gaps.csv")

message("Generated the dataset-region-period/window/tier Stage 3 role gate and explicit gap registers.")
