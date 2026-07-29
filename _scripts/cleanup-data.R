# Post-render: remove the downloaded data, but ONLY in CI.
#
# The guard on the CI env var is deliberate: during local development `data` may
# be a symlink to the live sedimenter data area, and deleting after every
# `quarto render` would remove those files. GitHub Actions sets CI=true, so the
# cleanup runs only on the runner, leaving local renders untouched.

if (!nzchar(Sys.getenv("CI"))) {
  message("not CI: keeping data")
} else {
  sources <- c("mareano", "vannmiljo", "ices_dome", "mudab", "4demon")
  files <- c(
    file.path("data/db", sprintf("%s_clean.sqlite", sources)),
    list.files("data/analysis", pattern = "\\.csv$", recursive = TRUE,
               full.names = TRUE)
  )
  for (f in files) if (file.exists(f)) {
    message("remove: ", f)
    file.remove(f)
  }
}
