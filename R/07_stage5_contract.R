# Contracts and parsers for Stage 5 observation harmonization and conversion auditing.

stage5_required_ids <- function() c("DS02", "DS04", "DS05", "DS06", "DS07", "DS16", "DS22")

stage5_read_source_contract <- function(path = "config/stage5_source_contract.csv") {
  if (!file.exists(path)) stop("Stage 5 source contract is missing.", call. = FALSE)
  value <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
  expected <- c("ds_id", "monitoring_network", "stage5_role", "source_format", "active_pin_path",
                "authoritative_raw_path", "authoritative_checksum_sha256", "stage5_action")
  if (!identical(names(value), expected) || !identical(value$ds_id, stage5_required_ids()) ||
      anyDuplicated(value$ds_id) || any(!nzchar(value$monitoring_network)) ||
      any(!nzchar(value$stage5_role)) || any(!nzchar(value$source_format)) ||
      any(!nzchar(value$active_pin_path)) || any(!nzchar(value$stage5_action))) {
    stop("Stage 5 source contract violates its seven-source schema.", call. = FALSE)
  }
  value
}

stage5_manifest_file_table <- function(manifest_path) {
  manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE, check.names = FALSE)
  checksum_name <- intersect(c("checksum_sha256", "sha256"), names(manifest))[1]
  size_name <- intersect(c("file_size_bytes", "size_bytes"), names(manifest))[1]
  path_name <- intersect(c("raw_relative_path", "file_name", "filename"), names(manifest))[1]
  if (!nrow(manifest) || is.na(checksum_name) || is.na(size_name) || is.na(path_name)) {
    stop(sprintf("Unsupported Stage 5 raw manifest schema: %s", manifest_path), call. = FALSE)
  }
  raw_value <- as.character(manifest[[path_name]])
  paths <- if (path_name %in% c("file_name", "filename")) {
    file.path(dirname(manifest_path), raw_value)
  } else {
    file.path("data", "raw", sub("^(data/raw/)?", "", raw_value))
  }
  data.frame(
    path = gsub("\\\\", "/", paths),
    checksum_sha256 = as.character(manifest[[checksum_name]]),
    file_size_bytes = as.numeric(manifest[[size_name]]),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

stage5_validate_manifest <- function(manifest_path) {
  files <- stage5_manifest_file_table(manifest_path)
  if (any(!file.exists(files$path)) || any(dir.exists(files$path)) ||
      any(file.size(files$path) != files$file_size_bytes)) {
    stop(sprintf("Stage 5 raw files fail existence or size validation: %s", manifest_path), call. = FALSE)
  }
  actual <- unname(vapply(files$path, calculate_checksum, character(1)))
  if (!identical(actual, files$checksum_sha256)) {
    stop(sprintf("Stage 5 raw checksum mismatch: %s", manifest_path), call. = FALSE)
  }
  files
}

stage5_resolve_source <- function(contract_row) {
  pin_path <- contract_row$active_pin_path[[1]]
  if (!file.exists(pin_path)) stop(sprintf("Stage 5 active pin is missing: %s", pin_path), call. = FALSE)
  pin <- utils::read.csv(pin_path, stringsAsFactors = FALSE, check.names = FALSE)
  if (nrow(pin) != 1L || !"run_relative_path" %in% names(pin)) {
    stop(sprintf("Stage 5 active pin is invalid: %s", pin_path), call. = FALSE)
  }
  stage2_manifest <- file.path("data", "raw", pin$run_relative_path[[1]], "manifest.csv")
  if (!file.exists(stage2_manifest)) stop(sprintf("Pinned manifest is missing: %s", stage2_manifest), call. = FALSE)
  if ("manifest_checksum_sha256" %in% names(pin) &&
      !identical(calculate_checksum(stage2_manifest), pin$manifest_checksum_sha256[[1]])) {
    stop(sprintf("Pinned manifest checksum mismatch: %s", stage2_manifest), call. = FALSE)
  }

  list(
    files = stage5_validate_manifest(stage2_manifest),
    stage2_manifest = stage2_manifest,
    stage2_files = NULL,
    provenance_state = "stage2_active_pin_authoritative"
  )
}

stage5_xml_decode <- function(value) {
  value <- gsub("&lt;", "<", value, fixed = TRUE)
  value <- gsub("&gt;", ">", value, fixed = TRUE)
  value <- gsub("&quot;", "\"", value, fixed = TRUE)
  value <- gsub("&apos;", "'", value, fixed = TRUE)
  gsub("&amp;", "&", value, fixed = TRUE)
}

stage5_xml_blocks <- function(value, pattern) {
  match <- gregexpr(pattern, value, perl = TRUE)[[1]]
  if (identical(match[[1]], -1L)) return(character())
  regmatches(value, list(match))[[1]]
}

stage5_xlsx_column_number <- function(reference) {
  letters <- strsplit(sub("[0-9]+$", "", reference), "", fixed = TRUE)[[1]]
  Reduce(function(total, letter) total * 26L + match(letter, LETTERS), letters, init = 0L)
}

stage5_read_peg_bvol_xlsx <- function(outer_zip, inner_xlsx = "PEG_BVOL2026.xlsx") {
  if (!file.exists(outer_zip)) stop("PEG_BVOL outer ZIP is missing.", call. = FALSE)
  outer_listing <- utils::unzip(outer_zip, list = TRUE)
  if (!inner_xlsx %in% outer_listing$Name) {
    stop(sprintf("PEG_BVOL ZIP does not contain %s.", inner_xlsx), call. = FALSE)
  }
  temporary <- tempfile("stage5_peg_")
  dir.create(temporary)
  on.exit(unlink(temporary, recursive = TRUE), add = TRUE)
  utils::unzip(outer_zip, files = inner_xlsx, exdir = temporary)
  xlsx_path <- file.path(temporary, inner_xlsx)

  shared_xml <- paste(readLines(unz(xlsx_path, "xl/sharedStrings.xml"), warn = FALSE,
                                encoding = "UTF-8"), collapse = "")
  shared_blocks <- stage5_xml_blocks(shared_xml, "(?s)<si(?: [^>]*)?>.*?</si>")
  shared <- vapply(shared_blocks, function(block) {
    text_blocks <- stage5_xml_blocks(block, "(?s)<t(?: [^>]*)?>.*?</t>")
    paste(vapply(text_blocks, function(text) {
      stage5_xml_decode(sub("(?s)^<t(?: [^>]*)?>(.*?)</t>$", "\\1", text, perl = TRUE))
    }, character(1)), collapse = "")
  }, character(1))

  sheet_xml <- paste(readLines(unz(xlsx_path, "xl/worksheets/sheet1.xml"), warn = FALSE,
                               encoding = "UTF-8"), collapse = "")
  row_blocks <- stage5_xml_blocks(sheet_xml, "(?s)<row(?: [^>]*)?>.*?</row>")
  parsed <- lapply(row_blocks, function(row) {
    cells <- stage5_xml_blocks(row, "(?s)<c(?: [^>]*)?>.*?</c>")
    if (!length(cells)) return(list(index = integer(), value = character()))
    references <- sub("(?s)^<c[^>]* r=\"([A-Z]+[0-9]+)\".*$", "\\1", cells, perl = TRUE)
    indexes <- vapply(references, stage5_xlsx_column_number, integer(1))
    values <- vapply(cells, function(cell) {
      type <- if (grepl(" t=\"s\"", cell, fixed = TRUE)) "s" else
        if (grepl(" t=\"inlineStr\"", cell, fixed = TRUE)) "inline" else "value"
      if (type == "inline") {
        texts <- stage5_xml_blocks(cell, "(?s)<t(?: [^>]*)?>.*?</t>")
        return(paste(vapply(texts, function(text) stage5_xml_decode(
          sub("(?s)^<t(?: [^>]*)?>(.*?)</t>$", "\\1", text, perl = TRUE)), character(1)), collapse = ""))
      }
      raw <- if (grepl("<v>", cell, fixed = TRUE))
        sub("(?s).*?<v>(.*?)</v>.*", "\\1", cell, perl = TRUE) else ""
      if (type == "s" && nzchar(raw)) {
        position <- suppressWarnings(as.integer(raw)) + 1L
        if (is.na(position) || position < 1L || position > length(shared))
          stop("Invalid shared-string index in PEG_BVOL workbook.", call. = FALSE)
        return(shared[[position]])
      }
      stage5_xml_decode(raw)
    }, character(1))
    list(index = indexes, value = values)
  })
  width <- max(vapply(parsed, function(row) if (length(row$index)) max(row$index) else 0L, integer(1)))
  matrix_value <- matrix("", nrow = length(parsed), ncol = width)
  for (i in seq_along(parsed)) if (length(parsed[[i]]$index)) {
    matrix_value[i, parsed[[i]]$index] <- parsed[[i]]$value
  }
  headers <- matrix_value[1L, ]
  if (any(!nzchar(headers)) || anyDuplicated(headers)) {
    stop("PEG_BVOL workbook has blank or duplicated headers.", call. = FALSE)
  }
  value <- as.data.frame(matrix_value[-1L, , drop = FALSE], stringsAsFactors = FALSE,
                         check.names = FALSE)
  names(value) <- headers
  value <- value[rowSums(value != "") > 0L, , drop = FALSE]
  required <- c("Division", "Class", "Order", "Genus", "Species", "AphiaID", "Trophy",
                "Geometric_shape", "SizeClassNo", "Calculated_volume_µm3/counting_unit",
                "Calculated_Carbon_pg/counting_unit")
  if (!all(required %in% names(value)) || nrow(value) < 3000L) {
    stop("PEG_BVOL workbook does not satisfy its expected conversion-table contract.", call. = FALSE)
  }
  value
}

# Process a provider CSV in bounded memory while preserving RFC-style quoted fields within each line.
# The registered Stage 5 CSV inputs contain no embedded physical newlines inside a quoted field.
stage5_stream_csv <- function(path, callback, chunk_lines = 5000L, encoding = "UTF-8") {
  if (!file.exists(path)) stop(sprintf("Stage 5 CSV input is missing: %s", path), call. = FALSE)
  connection <- file(path, open = "r", encoding = encoding)
  on.exit(close(connection), add = TRUE)
  header <- readLines(connection, n = 1L, warn = FALSE)
  if (length(header) != 1L || !nzchar(header)) stop(sprintf("Empty CSV header: %s", path), call. = FALSE)
  total <- 0L
  repeat {
    lines <- readLines(connection, n = chunk_lines, warn = FALSE)
    if (!length(lines)) break
    value <- utils::read.csv(text = paste(c(header, lines), collapse = "\n"),
                             stringsAsFactors = FALSE, check.names = FALSE)
    if (nrow(value) != length(lines)) {
      stop(sprintf("Physical-line and parsed-row counts differ in %s.", path), call. = FALSE)
    }
    callback(value, total + seq_len(nrow(value)))
    total <- total + nrow(value)
  }
  total
}

stage5_stream_csv_pair <- function(left_path, right_path, callback, chunk_lines = 5000L) {
  connections <- list(file(left_path, open = "r", encoding = "UTF-8"),
                      file(right_path, open = "r", encoding = "UTF-8"))
  on.exit(lapply(connections, close), add = TRUE)
  headers <- vapply(connections, function(connection) readLines(connection, n = 1L, warn = FALSE),
                    character(1))
  total <- 0L
  repeat {
    lines <- lapply(connections, function(connection) readLines(connection, n = chunk_lines, warn = FALSE))
    if (!length(lines[[1]]) && !length(lines[[2]])) break
    if (length(lines[[1]]) != length(lines[[2]])) {
      stop(sprintf("Paired Stage 5 tables have different row counts: %s and %s", left_path, right_path),
           call. = FALSE)
    }
    tables <- Map(function(header, rows) utils::read.csv(
      text = paste(c(header, rows), collapse = "\n"), stringsAsFactors = FALSE, check.names = FALSE
    ), headers, lines)
    if (any(vapply(tables, nrow, integer(1)) != length(lines[[1]]))) {
      stop("Paired Stage 5 physical-line and parsed-row counts differ.", call. = FALSE)
    }
    callback(tables[[1]], tables[[2]], total + seq_len(length(lines[[1]])))
    total <- total + length(lines[[1]])
  }
  total
}
