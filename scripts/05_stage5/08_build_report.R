#!/usr/bin/env Rscript
# Render the Stage 5 status directly from generated observation-only audit outputs.

source("R/00_core_setup.R")

canonical <- read.csv("metadata/stage5/harmonization/canonical_observation_summary.csv",
                      stringsAsFactors = FALSE)
taxonomy <- read.csv("metadata/stage5/taxonomy/worms_taxonomy_summary.csv", stringsAsFactors = FALSE)
conversion <- read.csv("metadata/stage5/harmonization/conversion_readiness_summary.csv",
                       stringsAsFactors = FALSE)
samples <- read.csv("metadata/stage5/harmonization/sample_method_completeness_summary.csv",
                    stringsAsFactors = FALSE)
issues <- read.csv("metadata/stage5/harmonization/harmonization_issues.csv", stringsAsFactors = FALSE)
gate <- read.csv("metadata/stage5/gate/stage5_gate_status.csv", stringsAsFactors = FALSE)
peg <- read.csv("metadata/stage5/conversion/conversion_authority_summary.csv", stringsAsFactors = FALSE)

fmt <- function(value) format(value, big.mark = ",", scientific = FALSE, trim = TRUE)
ds02_taxonomy <- taxonomy[taxonomy$input_route == "ds02_taxamatch_name", ]
id_taxonomy <- taxonomy[taxonomy$input_route == "reported_aphia_id", ]
open <- issues[issues$state == "unresolved", ]

lines <- c(
  "# Stage 5 — In-Situ Harmonization and Biomass Construction",
  "",
  "## Conclusion",
  "",
  paste0("Stage 5 has started and its current artifacts validate, but the gate is **not passed**. ",
         "Six monitoring datasets contribute ", fmt(sum(canonical$source_rows)),
         " provisional taxon-measurement records and ", fmt(sum(samples$samples_audited)),
         " provisional samples. No sample is yet authorized for a total-biomass outcome, no ",
         "lower/central/upper biomass series has been constructed, Stage 6 remains blocked, and no ",
         "CMEMS PhyC value has been accessed."),
  "",
  "## Authoritative source evidence",
  "",
  paste0("- The canonical Stage 2 DS04 PLET abundance export contains ",
         fmt(canonical$source_rows[canonical$ds_id == "DS04"]),
         " records and passes the Stage 2 abundance-schema checks."),
  paste0("- The provider PEG_BVOL2026 workbook contains ", fmt(peg$conversion_rows),
         " conversion rows and ", fmt(peg$unique_aphia_ids),
         " unique non-missing AphiaIDs; it is read from the canonical Stage 2 provider archive."),
  "",
  "## Taxonomy and conversion audit",
  "",
  paste0("- WoRMS validated ", fmt(id_taxonomy$provider_id_validated), " of ",
         fmt(id_taxonomy$requested_terms), " reported AphiaIDs."),
  paste0("- For DS02, WoRMS returned exact matches for ", fmt(ds02_taxonomy$exact_name_matches),
         " of ", fmt(ds02_taxonomy$requested_terms), " requested names; ",
         fmt(ds02_taxonomy$fuzzy_candidates), " names have fuzzy candidates and ",
         fmt(ds02_taxonomy$unresolved), " have no match. The conversion audit accepts only unique exact valid-ID resolutions."),
  paste0("- Across all records, ", fmt(sum(conversion$rows_with_accepted_taxonomy)),
         " have accepted taxonomy and ", fmt(sum(conversion$rows_with_unique_authority_row)),
         " have one PEG_BVOL authority candidate. These are candidates, not converted biomass: ",
         fmt(sum(conversion$rows_authorized_for_abundance_conversion)),
         " abundance records are currently authorized for conversion."),
  "",
  "## Why the gate remains closed",
  "",
  paste0("The unresolved blockers are: ", paste(open$issue_type, collapse = "; "), "."),
  "PLET abundance units are absent from the exports; sample methods and method epochs have not been joined; and a sourced uncertainty rule capable of producing parallel lower, central, and upper reference series is not registered. Provider carbon and biovolume values from DS06 are preserved, but autotrophic scope and sample completeness are not yet established, so they are not silently promoted to total phytoplankton biomass.",
  "",
  "## Gate state",
  "",
  paste0("`", gate$gate_state, "`: Stage 5 remains in progress. Stage 6 outcomes and CMEMS acquisition are not authorized."),
  ""
)
dir.create("outputs/reports", recursive = TRUE, showWarnings = FALSE)
writeLines(lines, "outputs/reports/stage5_harmonization.md", useBytes = TRUE)
message("Rendered outputs/reports/stage5_harmonization.md")
