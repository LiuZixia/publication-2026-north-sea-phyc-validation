# Acquisition script for DS28: LifeWatch Belgium HPLC pigments

source("R/03_stage2_acquisition.R")
source("R/01_search_helpers.R")

run <- new_acquisition_run("DS28")

# Note: The exact VLIZ IMIS DOI or EurOBIS IPT resource name for the 
# LifeWatch HPLC pigment dataset needs manual confirmation.
# The URL below uses a placeholder resource name.
dataset_url <- "http://ipt.vliz.be/eurobis/archive.do?r=lifewatch_hplc_pigments_placeholder"
dest <- file.path(run$path, "DS28_LifeWatch_HPLC.zip")

cat(sprintf("Acquiring DS28 LifeWatch HPLC from: %s\n", dataset_url))

# To execute the download once the URL is confirmed, uncomment the following:
# ans <- perform_request("GET", dataset_url, dest)
# 
# row <- artifact_row(
#   run = run,
#   provider = "VLIZ / LifeWatch Belgium",
#   source = "EurOBIS IPT",
#   format = "DwC-A ZIP",
#   licence = "CC BY (expected)",
#   method = "GET",
#   endpoint = dataset_url,
#   request_text = dataset_url,
#   page_key = "1",
#   dest_path = dest,
#   response_meta = ans,
#   records_returned = NA_integer_,
#   expected_records = NA_integer_,
#   query_label = "DS28 DwC-A archive"
# )
# 
# write_acquisition_manifest(run, row, "Downloaded DS28 LifeWatch HPLC pigments.")
# update_stage2_status("REGISTER:DS28", "acquired_and_awaiting_screening")

cat("Script stub generated. Awaiting manual URL confirmation to proceed with the actual download.\n")
