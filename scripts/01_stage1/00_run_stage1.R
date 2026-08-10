# Publication-facing Stage 1 entry point.
#
# This rebuilds generated Stage 1 results from the pinned immutable responses and runs the Stage 1
# gate. It deliberately does not contact providers or create a new search run. New searches are an
# append-only operation owned by scripts/00_downloads/stage1/.

status <- system2("Rscript", "scripts/01_stage1/99_validate_stage1.R")
if (status != 0L) {
  stop("Stage 1 validation failed; see the validator output above.", call. = FALSE)
}
