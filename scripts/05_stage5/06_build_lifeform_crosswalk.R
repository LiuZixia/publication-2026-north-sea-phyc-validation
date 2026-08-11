#!/usr/bin/env Rscript
# Build a versioned, rule-traceable lifeform crosswalk from the PEG_BVOL authority fields.

source("R/00_core_setup.R")
source("R/03_stage2_contract.R")

path <- "data/interim/stage5/reference/peg_bvol_2026.csv"
if (!file.exists(path)) stop("PEG_BVOL extraction is missing.", call. = FALSE)
x <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)

division <- toupper(trimws(x$Division))
class <- toupper(trimws(x$Class))
genus <- tolower(trimws(x$Genus))
trophy <- toupper(trimws(x$Trophy))

x$lifeform_primary <- ifelse(
  genus == "phaeocystis", "phaeocystis_haptophyte",
  ifelse(class == "BACILLARIOPHYCEAE", "diatom",
  ifelse(class == "DINOPHYCEAE" & trophy == "AU", "dinoflagellate_autotroph",
  ifelse(class == "COCCOLITHOPHYCEAE", "coccolithophore",
  ifelse(trophy == "AU", "other_autotrophic_phytoplankton",
  ifelse(trophy %in% c("HT", "MX"), "heterotroph_or_mixotroph_uncertain",
         "unresolved_autotroph"))))))
x$autotrophy_status <- ifelse(trophy == "AU", "autotroph",
                       ifelse(trophy == "HT", "heterotroph",
                       ifelse(trophy == "MX", "mixotroph", "unresolved")))
x$autotrophy_uncertainty <- trophy != "AU"
x$lifeform_secondary <- ifelse(class == "DINOPHYCEAE" & trophy != "AU",
                               "dinoflagellate_trophy_uncertain", "")
x$colony_state <- ifelse(grepl("colony", x$`Comment_on_colony_form \" - \" indicates solitary life form, i.e. does nor form colonies  - NOT IMPORTED, NOT handled by ICES`,
                                   ignore.case = TRUE), "provider_comment_mentions_colony", "not_resolved")
x$phaeocystis_state <- ifelse(genus == "phaeocystis",
                              "taxon_identified_form_not_inferred", "not_phaeocystis")
x$assignment_rule <- ifelse(genus == "phaeocystis", "peg_genus_exact_phaeocystis",
                     ifelse(class == "BACILLARIOPHYCEAE", "peg_class_bacillariophyceae",
                     ifelse(class == "DINOPHYCEAE" & trophy == "AU", "peg_class_dinophyceae_and_trophy_au",
                     ifelse(class == "COCCOLITHOPHYCEAE", "peg_class_coccolithophyceae",
                     ifelse(trophy == "AU", "peg_trophy_au_other",
                     ifelse(trophy %in% c("HT", "MX"), "peg_trophy_ht_or_mx", "peg_trophy_blank_unresolved"))))))
x$crosswalk_version <- "PEG_BVOL2026_stage5_v1"
x$crosswalk_state <- "authority_rule_assignment_not_yet_applied_to_biomass"

keep <- c("crosswalk_version", "AphiaID", "Species", "Genus", "Class", "Division", "Trophy",
          "SizeClassNo", "lifeform_primary", "lifeform_secondary", "autotrophy_status",
          "autotrophy_uncertainty", "colony_state", "phaeocystis_state", "assignment_rule",
          "crosswalk_state")
crosswalk <- x[keep]
names(crosswalk)[names(crosswalk) == "AphiaID"] <- "accepted_aphia_id"
names(crosswalk)[names(crosswalk) == "Species"] <- "authority_species"
names(crosswalk)[names(crosswalk) == "Genus"] <- "authority_genus"
names(crosswalk)[names(crosswalk) == "Class"] <- "authority_class"
names(crosswalk)[names(crosswalk) == "Division"] <- "authority_division"
names(crosswalk)[names(crosswalk) == "Trophy"] <- "authority_trophy"
names(crosswalk)[names(crosswalk) == "SizeClassNo"] <- "authority_size_class"

summary <- as.data.frame(table(crosswalk$lifeform_primary), stringsAsFactors = FALSE)
names(summary) <- c("lifeform_primary", "authority_rows")
summary$crosswalk_version <- "PEG_BVOL2026_stage5_v1"
summary$observation_rows_assigned <- 0L
summary$use_state <- "not_yet_applied_pending_conversion_and_sample_compatibility"

dir.create("metadata/stage5/lifeform", recursive = TRUE, showWarnings = FALSE)
write_csv_atomic(crosswalk, "metadata/stage5/lifeform/lifeform_crosswalk.csv")
write_csv_atomic(summary, "metadata/stage5/lifeform/lifeform_crosswalk_summary.csv")
message(sprintf("Built the PEG_BVOL2026 lifeform authority crosswalk with %d size/stage rows.", nrow(crosswalk)))
