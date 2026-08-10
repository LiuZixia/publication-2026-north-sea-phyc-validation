# Historical generator for the immutable raw-store Markdown inventory.
#
# The publication inventory is metadata/stage2/inventory/file_inventory.csv. This script is retained
# only to identify the producer of the pre-consolidation raw artifact and is not part of the gate.
# Rewriting immutable raw evidence requires an explicit one-off opt-in.

if (!identical(Sys.getenv("ALLOW_LEGACY_RAW_INVENTORY_REWRITE"), "true")) {
  stop(paste0(
    "Refusing to rewrite immutable data/raw/stage2/downloaded_files_inventory.md. ",
    "Use Rscript scripts/00_traceability/01_build_stage_file_inventory.R instead."
  ), call. = FALSE)
}

# Create inventory of downloaded files in stage2

stage2_dir <- "data/raw/stage2"
dirs <- list.dirs(stage2_dir, recursive = FALSE)

inventory_md <- "data/raw/stage2/downloaded_files_inventory.md"
sink(inventory_md)
cat("# Stage 2 Downloaded Files Inventory\n\n")
cat("| Dataset Directory | Run Date | Manifest Files | Records Returned | Total Size | Notes |\n")
cat("|---|---|---|---|---|---|\n")

for (d in dirs) {
  run_dirs <- list.dirs(d, recursive = FALSE)
  if (length(run_dirs) == 0) {
    # Could be files directly
    run_dirs <- d
  } else {
    run_dirs <- run_dirs[length(run_dirs)] # latest run
  }
  
  manifest_path <- file.path(run_dirs, "manifest.csv")
  dataset_name <- basename(d)
  
  if (file.exists(manifest_path)) {
    manifest <- read.csv(manifest_path, stringsAsFactors = FALSE)
    files <- sum(manifest$format != "status_log", na.rm = TRUE)
    records <- sum(manifest$records_returned, na.rm = TRUE)
    
    # Calculate size of the directory
    cmd <- sprintf("du -sh %s", shQuote(run_dirs))
    size_str <- system(cmd, intern = TRUE)
    size <- strsplit(size_str, "\t")[[1]][1]
    
    cat(sprintf("| %s | %s | %s | %s | %s | |\n", 
                dataset_name, basename(run_dirs), files, records, size))
  } else {
    # Calculate size of the directory
    cmd <- sprintf("du -sh %s", shQuote(run_dirs))
    size_str <- tryCatch(system(cmd, intern = TRUE), error = function(e) "0")
    size <- if(length(size_str) > 0) strsplit(size_str, "\t")[[1]][1] else "0"
    cat(sprintf("| %s | N/A | No manifest | N/A | %s | |\n", dataset_name, size))
  }
}
sink()

cat("Inventory created at", inventory_md, "\n")
