# Publication-facing Stage 2 gate. This command validates only existing immutable raw evidence.
# It never invokes scripts/00_downloads/stage2/ or contacts a provider.

output <- system2(
  "Rscript", "scripts/02_stage2/control/99_validate_stage2.R",
  stdout = TRUE, stderr = TRUE
)
status <- attr(output, "status")
if (is.null(status)) status <- 0L
if (status != 0L) stop(paste(output, collapse = "\n"), call. = FALSE)
writeLines(output)
