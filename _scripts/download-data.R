# Pre-render: fetch the data files the site reads from the GitHub release.
#
# The site reads the clean SQLite databases (site-locations page) and the
# per-source analysis outputs written by the sedimenter pipeline (the grain-size,
# Fe/Al normalisation and organic-carbon pages). Release assets are flat-named;
# this script maps each to its expected path under data/ and downloads it.
#
# Files that already exist are skipped, so a local `data` (which may be a symlink
# to the live sedimenter data area during development) is never overwritten.
# Change the release tag here or via the DB_RELEASE env var (e.g. in the workflow).

tag  <- Sys.getenv("DB_RELEASE", "v0.1.0")
repo <- "seafood-hazards/multised-clean"
base <- sprintf("https://github.com/%s/releases/download/%s", repo, tag)

sources <- c("mareano", "vannmiljo", "ices_dome", "mudab", "4demon")

assets <- c(
  # clean databases -> data/db
  sprintf("%s_clean.sqlite", sources),
  # aquaculture reference database -> data/db
  "aquaculture.sqlite",
  # grain-size analysis -> data/analysis/grainsize
  "grainsize_targets_fines.csv", "grainsize_fraction_summary.csv",
  "grainsize_fines_summary.csv", "grainsize_conc_vs_fines.csv",
  "grainsize_bulk_vs_sieved.csv",
  # Fe/Al normalisation -> data/analysis/normalisation
  "normalisation_pairs.csv", "normalisation_availability.csv",
  "normalisation_correlation.csv", "normalisation_ratios.csv",
  # organic carbon -> data/analysis/organic
  "organic_pairs.csv", "organic_availability.csv",
  "organic_distribution.csv", "organic_correlation.csv",
  # depth / distance-to-coast -> data/analysis/spatial
  "spatial_enrichment.csv", "spatial_normaliser.csv", "spatial_pairs.csv",
  # sampling year -> data/analysis/temporal
  "temporal_enrichment.csv", "temporal_normaliser.csv", "temporal_pairs.csv"
)

# clean DBs live under data/db; an analysis CSV goes under data/analysis/<module>,
# where <module> is the asset name up to its first underscore.
dest_of <- function(asset) {
  if (grepl("\\.sqlite$", asset)) return(file.path("data/db", asset))
  module <- sub("_.*$", "", asset)
  file.path("data/analysis", module, asset)
}

# Download with retries: the GitHub -> asset-host redirect occasionally throws a
# transient SSL / connection error on CI, so retry a few times with backoff and
# discard any partial file between attempts.
download_retry <- function(url, dest, tries = 5) {
  for (i in seq_len(tries)) {
    ok <- tryCatch(
      suppressWarnings(utils::download.file(url, dest, mode = "wb", quiet = TRUE)),
      error = function(e) { message("  attempt ", i, " failed: ", conditionMessage(e)); 1L })
    if (identical(as.integer(ok), 0L) && file.exists(dest) && file.size(dest) > 0)
      return(invisible(TRUE))
    if (file.exists(dest)) file.remove(dest)   # drop partial before retrying
    if (i < tries) Sys.sleep(2 * i)
  }
  stop("failed to download after ", tries, " attempts: ", url)
}

for (asset in assets) {
  dest <- dest_of(asset)
  if (file.exists(dest)) {
    message("skip (exists): ", dest)
    next
  }
  dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
  url <- sprintf("%s/%s", base, asset)
  message("download: ", url)
  download_retry(url, dest)
}
