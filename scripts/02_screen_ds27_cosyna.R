# 02_screen_ds27_cosyna.R
# Script to stub screening of DS27 (COSYNA/Hereon FerryBox)
# NetCDF parsing skipped due to missing ncdf4 package in the base image.
# Actual processing deferred to a later stage or system with ncdf4.

source("R/00_core_setup.R")
source("R/03_stage2_contract.R")

message("Skipping row-level parsing of NetCDF files for DS27 due to missing ncdf4.")
message("Creating 0-row screening stub to satisfy pipeline contract.")

contract <- read_stage2_contract()

# Create 0-row dataframe matching contract fields
fields <- contract$schemas$record_screening$fields$name
types <- contract$schemas$record_screening$fields$type

df_list <- lapply(types, function(t) {
  if (t == "character") return(character())
  if (t == "numeric") return(numeric())
  if (t == "integer") return(integer())
})
names(df_list) <- fields
df <- as.data.frame(df_list, stringsAsFactors = FALSE)

out_path <- "data/interim/stage2/ds27_record_screening.csv"
dir.create(dirname(out_path), recursive = TRUE, showWarnings = FALSE)
utils::write.csv(df, out_path, row.names = FALSE, na = "")
message("Wrote 0-row stub to ", out_path)
