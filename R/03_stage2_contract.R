# Helpers for the prospectively frozen Stage 2 acquisition and screening contract.

read_stage2_contract <- function(path = "config/stage2_record_screening_contract.json") {
  required_namespace("jsonlite")
  if (!file.exists(path)) {
    stop(sprintf("Stage 2 contract does not exist: %s", path), call. = FALSE)
  }
  contract <- jsonlite::fromJSON(path, simplifyVector = FALSE)
  required_top <- c("schema_version", "frozen_at_utc", "stage", "status", "phy_c_boundary",
                    "raw_storage", "decision_rules", "controlled_vocabularies", "tables")
  missing_top <- setdiff(required_top, names(contract))
  if (length(missing_top)) {
    stop(sprintf("Stage 2 contract lacks required sections: %s", paste(missing_top, collapse = ", ")), call. = FALSE)
  }
  if (!identical(contract$stage, 2L) ||
      !identical(contract$status, "prospectively_frozen_before_observation_acquisition")) {
    stop("Stage 2 contract is not marked as a prospective Stage 2 freeze.", call. = FALSE)
  }
  contract
}

# Resolve paths embedded in checksum-pinned historical configurations without modifying those
# configurations. The relocated file must retain the exact checksum declared by its frozen config.
stage2_relocated_path <- function(frozen_path) {
  if (file.exists(frozen_path)) return(frozen_path)
  relocations <- c(
    "metadata/stage2_wfs_geometry_queue.csv" = "metadata/stage2/control/wfs_geometry_queue.csv",
    "metadata/stage2_emodnet_wfs_geometry_evidence.csv" =
      "metadata/stage2/screening/emodnet_wfs_geometry_evidence.csv",
    "metadata/stage2_ds26_smhi_ifcb_figshare_file_inventory.csv" =
      "metadata/stage2/acquisition/ds26_smhi_ifcb_figshare_file_inventory.csv"
  )
  relocated <- unname(relocations[[frozen_path]])
  if (is.null(relocated) || !file.exists(relocated)) {
    stop(sprintf("Frozen Stage 2 artifact is missing and has no registered relocation: %s", frozen_path),
         call. = FALSE)
  }
  relocated
}

# Update paths stored inside generated Stage 2 output registries after the metadata consolidation.
# Unlike stage2_relocated_path(), this is only for generated registries: frozen configuration bytes
# and immutable raw evidence are never changed. A relocation is accepted only when exactly one
# stage-owned destination already exists.
stage2_relocated_generated_path <- function(path) {
  if (file.exists(path) || !grepl("^metadata/stage2_", path)) return(path)
  filename <- sub("^stage2_", "", basename(path))
  candidates <- file.path(
    "metadata", "stage2", c("control", "acquisition", "screening", "inventory"), filename
  )
  existing <- candidates[file.exists(candidates)]
  if (length(existing) != 1L) {
    stop(sprintf("Generated Stage 2 path has %d possible relocations: %s",
                 length(existing), path), call. = FALSE)
  }
  existing[[1]]
}

relocate_stage2_registry_paths <- function(registry, registry_path, column = "path") {
  if (!column %in% names(registry)) {
    stop(sprintf("Stage 2 registry lacks path column '%s': %s", column, registry_path),
         call. = FALSE)
  }
  relocated <- vapply(registry[[column]], stage2_relocated_generated_path, character(1))
  changed <- !identical(as.character(registry[[column]]), relocated)
  registry[[column]] <- relocated
  if (changed) write_csv_atomic(registry, registry_path)
  registry
}

stage2_table_spec <- function(contract, table_name) {
  spec <- contract$tables[[table_name]]
  if (is.null(spec)) stop(sprintf("Unknown Stage 2 contract table: %s", table_name), call. = FALSE)
  spec
}

stage2_field_names <- function(contract, table_name) {
  fields <- stage2_table_spec(contract, table_name)$fields
  vapply(fields, function(field) field$name, character(1))
}

stage2_empty_table <- function(contract, table_name) {
  fields <- stage2_table_spec(contract, table_name)$fields
  values <- lapply(fields, function(field) {
    switch(field$type,
      character = character(),
      integer = integer(),
      numeric = numeric(),
      logical = logical(),
      stop(sprintf("Unsupported contract field type '%s'.", field$type), call. = FALSE)
    )
  })
  names(values) <- vapply(fields, function(field) field$name, character(1))
  as.data.frame(values, stringsAsFactors = FALSE, check.names = FALSE)
}

stage2_is_missing <- function(value) {
  is.na(value) | (is.character(value) & !nzchar(trimws(value)))
}

validate_stage2_table <- function(value, table_name, contract = read_stage2_contract()) {
  if (!is.data.frame(value)) stop(sprintf("%s must be a data frame.", table_name), call. = FALSE)
  spec <- stage2_table_spec(contract, table_name)
  fields <- spec$fields
  expected <- vapply(fields, function(field) field$name, character(1))
  if (!identical(names(value), expected)) {
    stop(sprintf("%s columns differ from the frozen contract. Expected: %s",
                 table_name, paste(expected, collapse = ", ")), call. = FALSE)
  }

  for (field in fields) {
    name <- field$name
    column <- value[[name]]
    type_ok <- switch(field$type,
      character = is.character(column),
      integer = is.integer(column) || (is.numeric(column) && all(is.na(column) | column == as.integer(column))),
      numeric = is.numeric(column),
      logical = is.logical(column),
      FALSE
    )
    if (!type_ok) stop(sprintf("%s.%s violates type '%s'.", table_name, name, field$type), call. = FALSE)

    missing <- stage2_is_missing(column)
    if (isTRUE(field$required) && !isTRUE(field$allow_missing) && any(missing)) {
      stop(sprintf("%s.%s contains missing values prohibited by the contract.", table_name, name), call. = FALSE)
    }
    populated <- !missing
    if (!is.null(field$pattern) && any(populated & !grepl(field$pattern, as.character(column), perl = TRUE))) {
      stop(sprintf("%s.%s contains a value outside pattern %s.", table_name, name, field$pattern), call. = FALSE)
    }
    if (!is.null(field$vocabulary)) {
      allowed <- unlist(contract$controlled_vocabularies[[field$vocabulary]], use.names = FALSE)
      if (is.null(allowed) || any(populated & !as.character(column) %in% allowed)) {
        stop(sprintf("%s.%s contains a value outside vocabulary '%s'.", table_name, name, field$vocabulary), call. = FALSE)
      }
    }
  }

  keys <- unlist(spec$unique_key, use.names = FALSE)
  if (nrow(value) && anyDuplicated(value[keys])) {
    stop(sprintf("%s violates its unique key: %s", table_name, paste(keys, collapse = " + ")), call. = FALSE)
  }
  invisible(value)
}

validate_stage2_work_order <- function(value, contract = read_stage2_contract()) {
  validate_stage2_table(value, "acquisition_work_order", contract)
  if (nrow(value) != 19L || !identical(value$acquisition_rank, seq_len(19L))) {
    stop("Stage 2 work order must contain the 19 Stage 1 shortlist rows in exact rank order.", call. = FALSE)
  }
  if (!all(value$work_item_id == paste0("REGISTER:", value$ds_id)) ||
      !all(value$work_state == "not_started")) {
    stop("Stage 2 work order identity or initial work state is invalid.", call. = FALSE)
  }
  invisible(value)
}

validate_stage2_wfs_queue <- function(value, contract = read_stage2_contract(), require_initial = TRUE) {
  validate_stage2_table(value, "wfs_geometry_queue", contract)
  if (nrow(value) != 40L ||
      !identical(as.integer(table(factor(value$title_domain_signal,
                                         levels = c("out_of_domain", "unknown")))), c(18L, 22L))) {
    stop("WFS queue must retain all 40 unmatched candidates with 18 title signals and 22 unknowns.", call. = FALSE)
  }
  if (require_initial && (any(value$screening_decision != "pending") ||
      any(value$record_geometry_state != "not_checked") ||
      any(value$record_access_state != "not_checked") ||
      any(value$duplicate_resolution_state != "not_checked"))) {
    stop("No WFS candidate may receive a final decision before record geometry, access, and duplicates are checked.", call. = FALSE)
  }
  if (!require_initial) {
    invalid_exclusion <- value$screening_decision == "excluded" &
      value$record_geometry_state != "resolved"
    if (any(invalid_exclusion)) {
      stop("A WFS exclusion requires resolved record geometry.", call. = FALSE)
    }
  }
  invisible(value)
}

write_csv_atomic <- function(value, destination) {
  dir.create(dirname(destination), recursive = TRUE, showWarnings = FALSE)
  partial <- paste0(destination, ".partial")
  on.exit(if (file.exists(partial)) unlink(partial), add = TRUE)
  utils::write.csv(value, partial, row.names = FALSE, na = "", fileEncoding = "UTF-8")
  if (file.exists(destination) && unlink(destination) != 0L) {
    stop(sprintf("Unable to replace generated file: %s", destination), call. = FALSE)
  }
  if (!file.rename(partial, destination)) {
    stop(sprintf("Atomic rename failed for generated file: %s", destination), call. = FALSE)
  }
  invisible(destination)
}

write_json_atomic <- function(value, destination) {
  required_namespace("jsonlite")
  dir.create(dirname(destination), recursive = TRUE, showWarnings = FALSE)
  partial <- paste0(destination, ".partial")
  on.exit(if (file.exists(partial)) unlink(partial), add = TRUE)
  jsonlite::write_json(value, partial, pretty = TRUE, auto_unbox = TRUE, null = "null")
  if (file.exists(destination) && unlink(destination) != 0L) {
    stop(sprintf("Unable to replace generated file: %s", destination), call. = FALSE)
  }
  if (!file.rename(partial, destination)) {
    stop(sprintf("Atomic rename failed for generated file: %s", destination), call. = FALSE)
  }
  invisible(destination)
}
