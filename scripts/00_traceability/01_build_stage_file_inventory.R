# Generate complete Stage 1 and Stage 2 file inventories from the worktree and raw manifests.
#
# Raw payload checksums are read from their acquisition manifests. Unregistered raw files at most
# 25 MiB are checksummed directly; larger unregistered files remain visible as unresolved instead of
# causing an implicit multi-gigabyte read during every inventory refresh.

source("R/00_core_setup.R")
source("R/04_stage_inventory.R")

dir.create("metadata/stage1/inventory", recursive = TRUE, showWarnings = FALSE)
dir.create("metadata/stage2/inventory", recursive = TRUE, showWarnings = FALSE)

checksum_map <- read_manifest_checksum_map()
inventories <- lapply(c("stage1", "stage2"), build_stage_inventory,
                      raw_checksum_map = checksum_map)
names(inventories) <- c("stage1", "stage2")

utils::write.csv(inventories$stage1, "metadata/stage1/inventory/file_inventory.csv",
                 row.names = FALSE, na = "")
utils::write.csv(inventories$stage2, "metadata/stage2/inventory/file_inventory.csv",
                 row.names = FALSE, na = "")

summary_rows <- do.call(rbind, lapply(names(inventories), function(stage) {
  tab <- inventories[[stage]]
  categories <- sort(unique(tab$category))
  data.frame(
    stage = stage,
    category = categories,
    file_count = vapply(categories, function(x) sum(tab$category == x), integer(1)),
    total_size_bytes = vapply(categories, function(x) sum(tab$size_bytes[tab$category == x], na.rm = TRUE), numeric(1)),
    traceable_count = vapply(categories, function(x) sum(tab$category == x & tab$traceability_state == "traceable"), integer(1)),
    unresolved_count = vapply(categories, function(x) sum(tab$category == x & tab$traceability_state == "unresolved"), integer(1)),
    stringsAsFactors = FALSE
  )
}))
utils::write.csv(summary_rows, "metadata/stage_file_inventory_summary.csv",
                 row.names = FALSE, na = "")

unresolved <- do.call(rbind, lapply(inventories, function(tab) {
  tab[tab$traceability_state == "unresolved",
      c("stage", "category", "path", "producer_script", "checksum_source"), drop = FALSE]
}))
utils::write.csv(unresolved, "metadata/stage_file_inventory_unresolved.csv",
                 row.names = FALSE, na = "")

message(sprintf(
  "Generated Stage 1/2 inventories: %d files; %d unresolved generated/raw artifacts.",
  sum(vapply(inventories, nrow, integer(1))), nrow(unresolved)
))
