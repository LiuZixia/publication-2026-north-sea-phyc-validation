# Execute all frozen Stage 1 source-family searches and pin their successful runs.

source("R/02_stage1_search_modules.R")

modules <- list(
  PLET = run_plet_search,
  ICES_DOME = run_ices_dome_search,
  EMODNET_ERDDAP = run_emodnet_search,
  OBIS = run_obis_search,
  SMHI_SHARK = run_smhi_search,
  PANGAEA = run_pangaea_search,
  GBIF = run_gbif_search,
  MARINE_SCOTLAND = run_scotland_search,
  CEFAS_DASSH = run_cefas_search,
  ICES_FIGSHARE = run_figshare_search
)

completed <- data.frame(source_key = character(), search_run_id = character(), stringsAsFactors = FALSE)
for (source_key in names(modules)) {
  message(sprintf("Starting Stage 1 source family: %s", source_key))
  run_id <- modules[[source_key]]()
  completed <- rbind(completed, data.frame(source_key = source_key, search_run_id = run_id, stringsAsFactors = FALSE))
}

dir.create("metadata", showWarnings = FALSE)
utils::write.csv(completed, "metadata/stage1_active_runs.csv", row.names = FALSE)
message("All Stage 1 searches completed and metadata/stage1_active_runs.csv was pinned.")
