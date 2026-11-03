# Source defines a read-only runtime inventory function; it never starts models.
export_current_ler_runtime_inventory <- function(
  iso = paste0("D:/Geography/R/dissertation_LakeEnsemblR/LER_window/",
               "MyLake_v121_ordering_isolated_20261029"),
  output = file.path("C:/LER9003_archives", paste0("runtime_inventory_",
    format(Sys.time(), "%Y%m%dT%H%M%S", tz = "Asia/Shanghai")))) {
  lib <- normalizePath(file.path(iso, "library_R4_6_mylake_v121_order9002"),
                       winslash = "/", mustWork = TRUE)
  stopifnot(!dir.exists(output), !file.exists(output))
  ns <- asNamespace("LakeEnsemblR")
  actual <- normalizePath(getNamespaceInfo(ns, "path"), winslash = "/", mustWork = TRUE)
  stopifnot(identical(actual, file.path(lib, "LakeEnsemblR")),
            identical(as.character(utils::packageVersion("LakeEnsemblR", lib.loc = lib)), "1.2.9.9003"),
            identical(as.character(utils::packageVersion("MyLakeR", lib.loc = lib)), "0.0.1.9002"))
  dir.create(output, recursive = TRUE)
  packages <- utils::installed.packages(lib.loc = lib)
  utils::write.csv(packages, file.path(output, "installed_packages.csv"), row.names = FALSE)
  state <- get(".lw_package_state", ns)(c("LakeEnsemblR", "FLakeR", "GLM3r", "GOTMr",
    "SimstratR", "MyLakeR", "glmtools", "gotmtools", "digest", "yaml"))
  saveRDS(state, file.path(output, "engine_package_runtime.rds"), version = 3L)
  utils::write.csv(state$packages, file.path(output, "engine_packages.csv"), row.names = FALSE)
  files <- do.call(rbind, lapply(names(state$files), function(p)
    data.frame(package = p, state$files[[p]], stringsAsFactors = FALSE, row.names = NULL)))
  utils::write.csv(files, file.path(output, "engine_package_files.csv"), row.names = FALSE)
  names <- ls(ns, all.names = TRUE)
  names <- names[vapply(names, function(n) is.function(get(n, ns)), logical(1))]
  hash <- get(".lw_function_hash", ns)
  functions <- data.frame(function_name = names,
    source_sha256 = vapply(names, function(n) hash(get(n, ns)), character(1)), stringsAsFactors = FALSE)
  utils::write.csv(functions, file.path(output, "LakeEnsemblR_runtime_functions.csv"), row.names = FALSE)
  capture.output(utils::sessionInfo(), file = file.path(output, "sessionInfo.txt"))
  cat("CURRENT_LER9003_RUNTIME_INVENTORY_EXPORTED_NO_MODELS_STARTED\n", output, "\n")
  invisible(output)
}
