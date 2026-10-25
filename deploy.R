# Deploy the calculator to shinyapps.io.
# Builds a self-contained bundle (app + engine + SQL + database) in a temporary folder.
# Run from the project root:  source("deploy.R")

bundle <- file.path(tempdir(), "odds-of-a-lifetime")
unlink(bundle, recursive = TRUE)
dir.create(file.path(bundle, "r"), recursive = TRUE)
dir.create(file.path(bundle, "sql"))

file.copy("app/app.R", bundle)
file.copy(list.files("r", full.names = TRUE), file.path(bundle, "r"))
file.copy(list.files("sql", full.names = TRUE), file.path(bundle, "sql"))

rsconnect::deployApp(bundle, appName = "odds-of-a-lifetime", forceUpdate = TRUE)