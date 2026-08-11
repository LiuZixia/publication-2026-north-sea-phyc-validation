library(testthat)

root <- if (file.exists("README.md")) "." else ".."
at_root <- function(...) file.path(root, ...)
read_project_csv <- function(path) read.csv(at_root(path), stringsAsFactors = FALSE, check.names = FALSE)

test_that("Stage 5 audits the complete authorized source set without PhyC", {
  source <- read_project_csv("metadata/stage5/input/source_readiness.csv")
  expect_equal(nrow(source), 7L)
  expect_setequal(source$ds_id, c("DS02", "DS04", "DS05", "DS06", "DS07", "DS16", "DS22"))
  expect_true(all(source$checksum_state == "verified"))
  expect_false(any(grepl("phyc|phy_c", paste(source, collapse = " "), ignore.case = TRUE)))
})

test_that("canonical Stage 2 PLET and PEG_BVOL inputs are explicit", {
  source <- read_project_csv("metadata/stage5/input/source_readiness.csv")
  canonical <- read_project_csv("metadata/stage5/harmonization/canonical_observation_summary.csv")
  peg <- read_project_csv("metadata/stage5/conversion/conversion_authority_summary.csv")
  expect_true(all(source$provenance_state == "stage2_active_pin_authoritative"))
  expect_equal(canonical$source_rows[canonical$ds_id == "DS04"], 365548L)
  expect_equal(peg$conversion_rows, 3539L)
  expect_equal(peg$unique_aphia_ids, 968L)
  expect_equal(peg$rows_with_central_carbon, 3539L)
})

test_that("taxonomy resolution preserves exact, fuzzy, and unresolved states", {
  taxonomy <- read_project_csv("metadata/stage5/taxonomy/worms_taxonomy_summary.csv")
  ids <- taxonomy[taxonomy$input_route == "reported_aphia_id", ]
  names <- taxonomy[taxonomy$input_route == "ds02_taxamatch_name", ]
  expect_equal(ids$requested_terms, 1331L)
  expect_equal(ids$provider_id_validated, 1330L)
  expect_equal(names$requested_terms, 2127L)
  expect_gt(names$exact_name_matches, 0L)
  expect_gt(names$fuzzy_candidates, 0L)
  expect_gt(names$unresolved, 0L)
})

test_that("conversion candidates are not promoted to biomass", {
  readiness <- read_project_csv("metadata/stage5/harmonization/conversion_readiness_summary.csv")
  expect_equal(sum(readiness$source_rows_profiled), 2369523L)
  expect_gt(sum(readiness$rows_with_accepted_taxonomy), 0L)
  expect_gt(sum(readiness$rows_with_unique_authority_row), 0L)
  expect_true(all(readiness$rows_authorized_for_abundance_conversion == 0L))
  issues <- read_project_csv("metadata/stage5/harmonization/harmonization_issues.csv")
  expect_true(all(c("S5-PLET-001", "S5-CONV-001", "S5-CONV-002", "S5-METHOD-001") %in%
                    issues$issue_id[issues$state == "unresolved"]))
})

test_that("lifeform rules preserve trophic and Phaeocystis uncertainty", {
  life <- read_project_csv("metadata/stage5/lifeform/lifeform_crosswalk.csv")
  summary <- read_project_csv("metadata/stage5/lifeform/lifeform_crosswalk_summary.csv")
  expect_equal(nrow(life), 3539L)
  expect_setequal(unique(life$lifeform_primary),
                  c("diatom", "phaeocystis_haptophyte", "dinoflagellate_autotroph",
                    "coccolithophore", "other_autotrophic_phytoplankton",
                    "unresolved_autotroph", "heterotroph_or_mixotroph_uncertain"))
  phaeo <- life[life$lifeform_primary == "phaeocystis_haptophyte", ]
  expect_gt(nrow(phaeo), 0L)
  expect_true(all(phaeo$phaeocystis_state == "taxon_identified_form_not_inferred"))
  expect_true(all(summary$observation_rows_assigned == 0L))
})

test_that("sample audit retains unknown completeness and blocks Stage 6", {
  sample <- read_project_csv("metadata/stage5/harmonization/sample_method_completeness_summary.csv")
  gate <- read_project_csv("metadata/stage5/gate/stage5_gate_status.csv")
  expect_equal(nrow(sample), 6L)
  expect_equal(sum(sample$total_biomass_outcome_eligible_samples), 0L)
  expect_equal(sum(sample$samples_with_resolved_method_epoch), 0L)
  expect_equal(gate$gate_state, "harmonization_in_progress_biomass_construction_blocked")
  expect_false(gate$stage5_gate_passed)
  expect_false(gate$stage6_outcome_authorized)
  expect_false(gate$cmems_acquisition_authorized)
  expect_false(gate$phy_c_values_accessed)
})
