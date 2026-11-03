# Four-model, three-parameter Simstrat experiment. Source into a NEW environment.
# Source only defines functions; run_remaining_lakes_r4() is the entry point.
# Keep the original CFG, R69, YAMLs, accepted receipts and old results unchanged.
.r4_source <- local({
  found <- as.character(unlist(lapply(sys.frames(), function(f) {
    if (exists("ofile", envir = f, inherits = FALSE)) get("ofile", envir = f) else NULL
  }), use.names = FALSE))
  found <- found[basename(found) == "Run_remaining67_R4ice_12.R"]
  if (!length(found)) NA_character_ else normalizePath(tail(found, 1L), winslash = "/", mustWork = TRUE)
})
.r4_models <- c("FLake", "GLM", "GOTM", "Simstrat")
.r4_schema <- "LER4-ice-20261102-v1"
.r4_need <- function(ok, ...) if (!isTRUE(ok)) stop(..., call. = FALSE)
.r4_private <- function(name) get(name, asNamespace("LakeEnsemblR"))
.r4_sha <- function(p) digest::digest(file = p, algo = "sha256", serialize = FALSE)
.r4_hash <- function(x) digest::digest(x, algo = "sha256", serialize = TRUE)
.r4_stamp <- function() format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
.r4_norm <- function(p) normalizePath(p, winslash = "/", mustWork = TRUE)
.r4_csv <- function(x, p) {
  if (file.exists(p)) .rr_table_equal(.rr_read_csv(p), x, p)
  else .r4_private(".lw_write_csv")(x, p)
  invisible(p)
}
.r4_save <- function(x, p) {
  if (file.exists(p)) {
    .r4_need(identical(.r4_read(p), x), "Existing receipt differs: ", p)
    return(invisible(p))
  }
  dir.create(dirname(p), recursive = TRUE, showWarnings = FALSE)
  tmp <- paste0(p, ".new")
  .r4_need(!file.exists(tmp), "Interrupted receipt write; preserve/check: ", tmp)
  saveRDS(x, tmp, version = 3L)
  writeLines(.r4_sha(tmp), paste0(tmp, ".sha256"), useBytes = TRUE)
  .r4_need(file.rename(tmp, p) && file.rename(paste0(tmp, ".sha256"), paste0(p, ".sha256")),
    "Receipt installation interrupted: ", p)
  invisible(p)
}
.r4_read <- function(p) {
  seal <- paste0(p, ".sha256")
  .r4_need(file.exists(p) && file.exists(seal) &&
    identical(readLines(seal, warn = FALSE), .r4_sha(p)), "Receipt/seal mismatch: ", p)
  readRDS(p)
}
.r4_manifest <- function(files) {
  files <- sort(unique(.r4_norm(files)))
  data.frame(file = files, bytes = as.numeric(file.info(files)$size),
    sha256 = vapply(files, .r4_sha, character(1)), stringsAsFactors = FALSE, row.names = NULL)
}
.r4_check_files <- function(x) {
  .r4_need(identical(.r4_manifest(x$file), x), "Recorded live input/source files changed; use a NEW results root")
  invisible(TRUE)
}
.r4_archive <- function(p, evidence, name = basename(p)) {
  if (!file.exists(p) && !dir.exists(p)) return(invisible(NULL))
  target <- file.path(evidence, name)
  .r4_need(!file.exists(target) && !dir.exists(target) && file.rename(p, target),
    "Cannot preserve interrupted files: ", p)
  invisible(target)
}
.r4_evidence <- function(root, prefix = "e") {
  dir.create(root, recursive = TRUE, showWarnings = FALSE)
  path <- tempfile(paste0(prefix, "_", .r4_stamp(), "_"), tmpdir = root)
  .r4_need(dir.create(path), "Cannot create evidence directory")
  .r4_norm(path)
}
.r4_phase <- function(path, phase, expression) {
  start <- Sys.time(); status <- "failed"; message <- ""
  on.exit({
    end <- Sys.time()
    row <- data.frame(phase = phase, start_UTC = format(start, "%Y-%m-%d %H:%M:%S", tz = "UTC"),
      end_UTC = format(end, "%Y-%m-%d %H:%M:%S", tz = "UTC"),
      elapsed_seconds = as.numeric(difftime(end, start, units = "secs")), status = status, message = message)
    if (file.exists(path)) row <- rbind(.rr_read_csv(path), row)
    tmp <- paste0(path, ".new"); if (file.exists(tmp)) unlink(tmp)
    .r4_private(".lw_write_csv")(row, tmp)
    if (file.exists(path)) unlink(path)
    .r4_need(file.rename(tmp, path), "Cannot install phase log")
  }, add = TRUE)
  value <- tryCatch(force(expression), error = function(e) { message <<- conditionMessage(e); stop(e) })
  status <- "ok"; value
}
.r4_expected_specs <- function(model) {
  x <- data.frame(name = c("wind_speed", "swr"), type = c("met", "met"),
    lower = c(0.5, 0.5), upper = c(2, 1.5), initial = c(1, 1), log = c(FALSE, FALSE))
  if (model == "Simstrat") x <- rbind(x, data.frame(name = "ModelParameters/p_sw_ice", type = "model",
    lower = 0.9, upper = 3, initial = 1, log = FALSE))
  x
}
.r4_live <- function(old_CFG, config_root, row, n, ncores) {
  name <- as.character(row$name); id <- suppressWarnings(as.numeric(row$NAME_ID))
  .r4_need(length(id) == 1L && is.finite(id) && id > 0 && id == floor(id), "Invalid actual NAME_ID")
  spin <- suppressWarnings(as.numeric(row$spin_up_days))
  .r4_need(length(spin) == 1L && is.finite(spin) && spin >= 0, "Invalid preserved spin_up_days")
  yaml <- file.path(config_root, paste0(name, "_LakeEnsemblR.yaml"))
  cfg <- .r4_private(".lw_read_config")(yaml)
  .r4_need(identical(as.character(cfg$location$name), name), "YAML lake name mismatch")
  .r4_need(identical(as.character(cfg$time$start), "1979-01-01 00:00:00") &&
    identical(as.character(cfg$time$stop), "2016-01-01 00:00:00") &&
    isTRUE(all.equal(as.numeric(cfg$time$time_step), 3600)) &&
    isTRUE(all.equal(as.numeric(cfg$output$time_step), 86400)), "Simulation time/steps changed")
  .r4_need(isTRUE(cfg$input$ice$use), "Ice physics must remain enabled")
  .r4_need(setequal(names(cfg$config_files), .r4_models) && is.null(cfg$calibration$MyLake),
    "Expected exactly FLake, GLM, GOTM, Simstrat, with no MyLake calibration")
  specs <- setNames(lapply(.r4_models, function(m) {
    z <- .r4_private(".lw_specs")(cfg, m)
    .rr_table_equal(z, .r4_expected_specs(m), paste(name, m, "design")); z
  }), .r4_models)
  .r4_private(".lw_check_legacy_yaml")(cfg, yaml, .r4_models)
  win <- file.path(old_CFG$windows_dir, paste0(name, "_MODIS_windows_reviewed.csv"))
  con <- file.path(old_CFG$contracts_dir, paste0(name, "_output_contracts.csv"))
  contract_manifest <- file.path(dirname(old_CFG$contracts_dir), "records", "contracts69_manifest.csv")
  approved <- .rr_read_csv(contract_manifest)
  a <- approved[approved$name == name, , drop = FALSE]
  .r4_need(nrow(a) == 1L && identical(as.character(a$file), basename(con)) &&
    identical(as.character(a$sha256), .r4_sha(con)), "Existing approved time-contract manifest does not match this lake")
  seed0 <- if (is.null(old_CFG$seed)) 20261026L else old_CFG$seed
  seed <- as.integer((as.double(seed0) + 104729 * id) %% 2147483646 + 1)
  control <- LakeEnsemblR::ler_window_control(win, con, seed = seed, save_series = FALSE)
  contracts <- .r4_private(".lw_contracts")(control$contracts, .r4_models, require_confirmed = TRUE)
  .r4_need(all(contracts$step_seconds == 86400) &&
    !any(grepl("UNCONFIRMED|PROPOSED|TODO|待确认|未确认", contracts$meaning, ignore.case = TRUE)),
    "Use only the existing confirmed daily output time contracts")
  w <- control$windows; cal <- w[w$use & w$split == "calibration", , drop = FALSE]
  val <- w[w$use & w$split == "validation", , drop = FALSE]
  utc <- .r4_private(".lw_utc")
  .r4_need(nrow(cal) >= 2L && nrow(val) >= 2L &&
    all(cal$window_start >= utc("2001-01-01 00:00:00") & cal$window_end <= utc("2011-01-01 00:00:00")) &&
    all(val$window_start >= utc("2011-01-01 00:00:00") & val$window_end <= utc("2016-01-01 00:00:00")),
    "Calibration must use 2001-2010; validation must use 2011-2015")
  .r4_need((!"name" %in% names(w) || all(w$name == name)) &&
    (!"NAME_ID" %in% names(w) || all(as.numeric(w$NAME_ID) == id)), "Window lake identity mismatch")
  refs <- c(yaml, win, con, contract_manifest, file.path(config_root, "remaining_lakes.csv"), file.path(config_root, "all_lakes.csv"))
  add <- function(value) {
    if (!is.character(value) || length(value) != 1L || !nzchar(value) || value == "NULL") return()
    p <- if (grepl("^(/|[A-Za-z]:[/\\\\])", value)) value else file.path(config_root, value)
    .r4_need(file.exists(p) && !dir.exists(p), "Missing live input: ", p)
    refs <<- c(refs, p)
  }
  walk <- function(x) {
    if (!is.list(x)) return()
    for (key in names(x)) if (key == "file") add(x[[key]]) else if (is.list(x[[key]])) walk(x[[key]])
  }
  add(cfg$location$hypsograph)
  walk(cfg$input)
  walk(cfg$observations)
  for (sec in c("inflows", "outflows")) {
    if (!is.null(cfg[[sec]]$file)) add(cfg[[sec]]$file)
  }
  kw <- cfg$input$light$Kw
  if (is.list(kw)) for (z in kw) add(z) else add(kw)
  for (m in .r4_models) {
    d <- file.path(config_root, m)
    .r4_need(dir.exists(d), "Native template folder missing: ", d)
    rel <- list.files(d, recursive = TRUE, full.names = TRUE, all.files = TRUE, no.. = TRUE)
    refs <- c(refs, rel[!grepl("/output/", rel)])
  }
  generated <- .rr_read_csv(file.path(config_root, "_generated_sha256.csv"))
  .r4_need(all(c("relative_path", "sha256") %in% names(generated)), "Missing generated configuration manifest")
  for (i in seq_len(nrow(generated))) .r4_need(identical(.r4_sha(file.path(config_root, generated$relative_path[i])),
    as.character(generated$sha256[i])), "Generated configuration changed: ", generated$relative_path[i])
  source <- .r4_source
  .r4_need(length(source) == 1L && !is.na(source) && file.exists(source), "Source this saved R script before running")
  helper <- .rr_resume_source_file
  .r4_need(length(helper) == 1L && !is.na(helper) && file.exists(helper) && identical(.r4_sha(helper),
    "74cfbe6a90da76df42c80b168edb45d4a1e78ba08dceac4976ffff84516e5afa"), "Load the preserved rev3 recovery helper into this separate R4 environment")
  sources <- c(source, helper, file.path(config_root, "_generated_sha256.csv"))
  runtime <- .r4_private(".lw_package_state")(c("LakeEnsemblR", "FLakeR", "GLM3r", "GOTMr", "SimstratR", "digest", "yaml"))
  funcs <- sort(c(grep("^\\.lw_", ls(asNamespace("LakeEnsemblR"), all.names = TRUE), value = TRUE),
    "export_config", "export_init_cond", "input_config_value", "evaluate_window_best", "calc_fit_window"))
  code <- vapply(funcs, function(nm) .r4_private(".lw_function_hash")(.r4_private(nm)), character(1))
  payload <- list(schema = .r4_schema, name = name, NAME_ID = id, num = as.integer(n),
    ncores = as.integer(ncores), models = .r4_models, seed = seed, spin_up_days = spin,
    specs = specs, live_files = .r4_manifest(refs), sources = .r4_manifest(sources),
    runtime = runtime, runtime_functions = code,
    helper_functions = vapply(c(".rr_validate_candidate", ".rr_scan_candidates", ".rr_run_lb_tasks", ".rr_atomic_context_replace",
      ".rr_retained_manifest", ".rr_verify_locked_manifest", ".rr_table_equal"), function(nm)
      .r4_private(".lw_function_hash")(get(nm, mode = "function", inherits = TRUE)), character(1)), controls = control,
    min_success_fraction = 0.95, tolerance_celsius = 1e-6)
  list(payload = payload, signature = .r4_hash(payload), config_file = basename(yaml),
    folder = .r4_norm(config_root), control = control, spin_up = spin)
}
.r4_new_context <- function(live, run) {
  .r4_check_files(live$payload$live_files)
  .r4_check_files(live$payload$sources)
  ctx <- .r4_private(".lw_context")(live$config_file, live$folder, .r4_models,
    live$control, run, live$spin_up)
  ctx$specs <- live$payload$specs
  ctx$pools <- setNames(lapply(.r4_models, function(m) .r4_private(".lw_lhc")(
    ctx$specs[[m]], live$payload$num, .r4_private(".lw_seed")(live$payload$seed, m, "LHC"))), .r4_models)
  for (m in .r4_models) {
    .r4_csv(ctx$specs[[m]], file.path(run, paste0("spec_", m, ".csv")))
    .r4_csv(ctx$pools[[m]], file.path(run, paste0("params_", m, ".csv")))
  }
  .r4_private(".lw_select")(ctx$windows, ctx$control$validation_split, ctx$allowed_start, ctx$allowed_end)
  .r4_need(file.copy(.r4_source, file.path(run, "workflow_R4ice.R")), "Cannot retain workflow source")
  .r4_need(file.copy(.rr_resume_source_file, file.path(run, "recovery_helper_rev3.R")), "Cannot retain helper source")
  .r4_csv(live$payload$sources, file.path(run, "workflow_sources.csv"))
  .r4_csv(live$payload$live_files, file.path(run, "live_input_files.csv"))
  ctx$r4_signature <- live$signature; ctx$r4_schema <- .r4_schema
  saveRDS(ctx, file.path(run, "context.rds"), version = 3L)
  .r4_check_files(live$payload$live_files)
  .r4_check_files(live$payload$sources)
  ctx
}
.r4_export_check <- function(ctx, root) {
  .r4_need(dir.create(root, recursive = TRUE), "Cannot create new native export audit")
  .r4_private(".lw_copy_tree")(ctx$snapshot, root)
  old <- getwd(); on.exit(setwd(old), add = TRUE); setwd(root)
  LakeEnsemblR::export_config(ctx$config_file, model = .r4_models, folder = ".")
  ini <- file.path("Simstrat", "init_cond.dat")
  lines <- readLines(ini, warn = FALSE)
  header <- trimws(gsub("[[:space:]]*\\[.*$", "", strsplit(lines[1L], "\t", fixed = TRUE)[[1L]]))
  values <- as.matrix(utils::read.table(ini, skip = 1L, sep = "\t", header = FALSE))
  .r4_need(identical(header, c("Depth", "U", "V", "T", "S", "k", "eps")) &&
    ncol(values) == 7L && all(is.finite(values)) && all(values[, 5L] == 0) &&
    all(values[, 6L] > 0 & values[, 7L] > 0), "Simstrat seven-column initialization audit failed")
  spec <- ctx$specs$Simstrat
  for (v in c(0.9, 1, 3)) {
    row <- as.data.frame(as.list(setNames(spec$initial, spec$name)), check.names = FALSE)
    row[["ModelParameters/p_sw_ice"]] <- v
    .r4_private(".lw_apply_native")(ctx$base, "Simstrat", spec, row)
    text <- readLines(ctx$base$config_files$Simstrat, warn = FALSE)
    key <- grep('"p_sw_ice"[[:space:]]*:', text, value = TRUE)
    value <- suppressWarnings(as.numeric(sub('.*"p_sw_ice"[[:space:]]*:[[:space:]]*([^,!}]+).*', '\\1', key)))
    .r4_need(length(value) == 1L && isTRUE(all.equal(value, v, tolerance = 0)),
      "Native p_sw_ice write/read failed")
    file.copy(ctx$base$config_files$Simstrat, paste0("p_sw_ice_", v, ".json"))
  }
  invisible(TRUE)
}
.r4_tasks <- function(ctx, todo = NULL) {
  tasks <- list(); longest <- max(vapply(ctx$pools, nrow, integer(1)))
  for (i in seq_len(longest)) for (m in ctx$models) {
    if (i > nrow(ctx$pools[[m]])) next
    p <- ctx$pools[[m]][i, , drop = FALSE]
    if (!is.null(todo) && !paste(m, p$par_id, sep = "/") %in% todo) next
    tasks[[length(tasks) + 1L]] <- list(model = m, spec = ctx$specs[[m]], pool = p,
      worker_id = sprintf("j%06d", length(tasks) + 1L))
  }
  tasks
}
.r4_preflight <- function(ctx, lake_root, signature, ncores) {
  receipt <- file.path(lake_root, "preflight.rds")
  if (file.exists(receipt)) {
    old <- .r4_read(receipt)
    .r4_need(identical(old$signature, signature) && isTRUE(old$passed), "New-design preflight signature differs")
    .r4_private(".lw_check_manifest")(file.path(lake_root, "v"), old$files, "New-design preflight")
    return(invisible(old))
  }
  root <- file.path(lake_root, "v")
  if (dir.exists(root)) .r4_archive(root, .r4_evidence(file.path(lake_root, "e")), "preflight_incomplete")
  dir.create(root, recursive = TRUE)
  .r4_export_check(ctx, file.path(root, "x"))
  serial <- ctx; serial$result_dir <- file.path(root, "s"); dir.create(serial$result_dir)
  serial$control$save_series <- TRUE
  serial$pools <- setNames(lapply(ctx$models, function(m) {
    p <- as.data.frame(as.list(setNames(ctx$specs[[m]]$initial, ctx$specs[[m]]$name)), check.names = FALSE)
    if (m == "Simstrat") {
      p <- p[rep(1L, 3L), , drop = FALSE]; p[["ModelParameters/p_sw_ice"]] <- c(0.9, 1, 3)
    }
    p$par_id <- sprintf("v%02d", seq_len(nrow(p))); rownames(p) <- NULL; p
  }), ctx$models)
  serial_out <- lapply(.r4_tasks(serial), .r4_private(".lw_worker"), ctx = serial)
  baseline <- do.call(rbind, serial_out)
  .r4_csv(baseline, file.path(root, "serial_status.csv"))
  .r4_need(all(baseline$status == "ok"), "New-design baseline engine failed; inspect preflight v/s/calibration")
  concurrent <- serial; concurrent$models <- "Simstrat"
  concurrent$pools <- serial$pools["Simstrat"]; concurrent$specs <- serial$specs["Simstrat"]
  concurrent$result_dir <- file.path(root, "p"); dir.create(concurrent$result_dir)
  parallel_out <- .rr_run_lb_tasks(.r4_tasks(concurrent), concurrent, ncores, file.path(root, "workers.log"))
  .r4_csv(do.call(rbind, parallel_out), file.path(root, "parallel_status.csv"))
  for (id in serial$pools$Simstrat$par_id) {
    a <- file.path(serial$result_dir, "calibration", "Simstrat", id)
    b <- file.path(concurrent$result_dir, "calibration", "Simstrat", id)
    .r4_need(all(.rr_read_csv(file.path(b, "status.csv"))$status == "ok"), "New Simstrat concurrent case failed")
    .rr_table_equal(.rr_read_csv(file.path(b, "parameters.csv")), .rr_read_csv(file.path(a, "parameters.csv")), "same parameter replay")
    x <- readRDS(file.path(a, "native_surface.rds")); y <- readRDS(file.path(b, "native_surface.rds"))
    .r4_need(identical(as.numeric(x$datetime), as.numeric(y$datetime)) &&
      all(is.finite(x$temperature)) && all(is.finite(y$temperature)) &&
      all(abs(x$temperature - y$temperature) <= 1e-6), "Simstrat serial/parallel native results differ")
    .rr_table_equal(.rr_read_csv(file.path(b, "pairs.csv")), .rr_read_csv(file.path(a, "pairs.csv")), "same candidate pairs", 1e-6)
  }
  value <- list(schema = .r4_schema, signature = signature, passed = TRUE,
    models = .r4_models, native_ice_values = c(0.9, 1, 3), changed_model_parallel_cases = 3L,
    files = .r4_private(".lw_file_manifest")(root))
  .r4_save(value, receipt)
  cat("NEW_DESIGN_PREFLIGHT_AND_SIMSTRAT_REPLAY_PASSED\nLake:", ctx$base$location$name, "\n")
  invisible(value)
}
.r4_cal_integrity <- function(run) {
  seal <- .rr_read_csv(file.path(run, "context_integrity.csv"))
  .r4_need(nrow(seal) == 1L && identical(as.character(seal$file), "context.rds") &&
    identical(as.character(seal$sha256), .r4_sha(file.path(run, "context.rds"))), "Calibration context seal mismatch")
  ctx <- readRDS(file.path(run, "context.rds"))
  .r4_need(identical(ctx$result_dir, .r4_norm(run)) && identical(ctx$r4_schema, .r4_schema), "Invalid/moved new-design context")
  .r4_private(".lw_verify_runtime")(ctx)
  .r4_need(!is.null(ctx$calibration_files), "Calibration not finalized")
  for (i in seq_len(nrow(ctx$calibration_files))) .r4_need(identical(
    .r4_sha(file.path(run, ctx$calibration_files$file[i])), ctx$calibration_files$sha256[i]), "Calibration artifact changed")
  ctx
}
.r4_load_context <- function(run, root, signature) {
  p <- file.path(run, "context.rds")
  if (!file.exists(p)) {
    files <- list.files(file.path(root, "e"), pattern = "^context_ready[.]rds$", recursive = TRUE, full.names = TRUE)
    if (!length(files)) files <- list.files(file.path(root, "e"), pattern = "^context_before_finalize[.]rds$", recursive = TRUE, full.names = TRUE)
    .r4_need(length(files) == 1L, "Missing context; cannot uniquely recover its atomic-write evidence")
    saved <- readRDS(files)
    .r4_need(identical(saved$r4_signature, signature) && identical(saved$models, .r4_models) &&
      identical(saved$result_dir, .r4_norm(run)), "Context recovery identity mismatch")
    .r4_private(".lw_verify_runtime")(saved)
    if (!is.null(saved$calibration_files)) for (i in seq_len(nrow(saved$calibration_files))) .r4_need(identical(
      .r4_sha(file.path(run, saved$calibration_files$file[i])), saved$calibration_files$sha256[i]), "Context recovery artifact mismatch")
    .r4_need(file.copy(files, p, overwrite = FALSE), "Cannot restore context from preserved finalization evidence")
  }
  readRDS(p)
}
.r4_finalize <- function(ctx, scan, evidence) {
  .r4_need(all(scan$index$state == "complete"), "Incomplete calibration after execution")
  all <- do.call(rbind, scan$statuses)
  all <- all[order(match(all$model, ctx$models), all$par_id), , drop = FALSE]; rownames(all) <- NULL
  fractions <- do.call(rbind, lapply(ctx$models, function(m) {
    p <- all[all$model == m, , drop = FALSE]
    data.frame(model = m, requested = nrow(ctx$pools[[m]]), completed = nrow(p),
      successful = sum(p$status == "ok" & is.finite(p$objective)), failed = sum(p$status == "failed"),
      success_fraction = mean(p$status == "ok" & is.finite(p$objective)))
  }))
  .r4_csv(fractions, file.path(evidence, "success_fractions.csv"))
  .r4_need(all(fractions$success_fraction >= 0.95), "At least one model has <95% successful candidates; inspect recorded failures")
  best <- do.call(rbind, lapply(ctx$models, function(m) {
    p <- all[all$model == m & all$status == "ok" & is.finite(all$objective), , drop = FALSE]
    p[order(p$objective, p$par_id)[1L], , drop = FALSE]
  })); rownames(best) <- NULL
  .r4_csv(all, file.path(ctx$result_dir, "calibration_summary.csv"))
  .r4_csv(best, file.path(ctx$result_dir, "best_by_calibration_RMSE.csv"))
  .r4_csv(fractions, file.path(ctx$result_dir, "candidate_success_fractions.csv"))
  manifest <- .r4_private(".lw_file_manifest")(ctx$result_dir)
  manifest <- manifest[!grepl("^(_work|snapshot)/", manifest$file) &
    !manifest$file %in% c("context.rds", "context_integrity.csv"), , drop = FALSE]; rownames(manifest) <- NULL
  ctx$calibration_files <- manifest
  .rr_atomic_context_replace(file.path(ctx$result_dir, "context.rds"), ctx, evidence)
  .r4_csv(data.frame(file = "context.rds", sha256 = .r4_sha(file.path(ctx$result_dir, "context.rds"))),
    file.path(ctx$result_dir, "context_integrity.csv"))
  .r4_cal_integrity(ctx$result_dir)
}
.r4_calibrate <- function(ctx, root, live, ncores) {
  receipt <- file.path(root, "calibration.rds")
  if (file.exists(receipt)) {
    old <- .r4_read(receipt)
    .r4_need(identical(old$signature, live$signature) && isTRUE(old$passed), "Completed calibration request changed")
    return(.r4_cal_integrity(ctx$result_dir))
  }
  if (file.exists(file.path(ctx$result_dir, "context_integrity.csv"))) {
    ctx <- .r4_cal_integrity(ctx$result_dir)
  } else {
    evidence <- .r4_evidence(file.path(root, "e"), "cal")
    scan <- .rr_scan_candidates(ctx)
    .r4_csv(scan$index, file.path(evidence, "candidate_scan_before.csv"))
    locked <- .rr_retained_manifest(ctx, scan)
    .r4_csv(locked, file.path(evidence, "retained_files.csv"))
    incomplete <- scan$index[scan$index$state == "incomplete", , drop = FALSE]
    for (i in seq_len(nrow(incomplete))) .r4_archive(incomplete$directory[i], evidence,
      paste(incomplete$model[i], incomplete$par_id[i], sep = "_"))
    .r4_archive(file.path(ctx$result_dir, "_work"), evidence, "interrupted_work")
    todo <- scan$index[scan$index$state != "complete", , drop = FALSE]
    tasks <- .r4_tasks(ctx, paste(todo$model, todo$par_id, sep = "/"))
    cat("Lake:", live$payload$name, "Retained:", sum(scan$index$state == "complete"),
      "Candidates to execute:", length(tasks), "\n")
    .r4_phase(file.path(root, "phase_times.csv"), "calibration_candidates", {
      .rr_run_lb_tasks(tasks, ctx, ncores, file.path(evidence, "workers.log"))
    })
    if (nrow(locked)) .rr_verify_locked_manifest(ctx, locked)
    after <- .rr_scan_candidates(ctx)
    .r4_csv(after$index, file.path(evidence, "candidate_scan_after.csv"))
    ctx <- .r4_finalize(ctx, after, evidence)
  }
  summary <- .rr_read_csv(file.path(ctx$result_dir, "calibration_summary.csv"))
  value <- list(schema = .r4_schema, signature = live$signature, passed = TRUE,
    run_dir = ctx$result_dir, num = live$payload$num, models = ctx$models,
    success_count = sum(summary$status == "ok"), failure_count = sum(summary$status == "failed"),
    context_sha256 = .r4_sha(file.path(ctx$result_dir, "context.rds")))
  .r4_save(value, receipt); ctx
}
.r4_verify_final <- function(run) {
  ctx <- .r4_cal_integrity(run)
  metrics <- .rr_read_csv(file.path(run, "final_metrics.csv"))
  expected <- as.vector(outer(ctx$models, c("calibration", "validation"), paste, sep = "/"))
  .r4_need(nrow(metrics) == 8L && !anyDuplicated(paste(metrics$model, metrics$split, sep = "/")) &&
    setequal(paste(metrics$model, metrics$split, sep = "/"), expected), "Incomplete four-model final metrics")
  best <- .rr_read_csv(file.path(run, "best_by_calibration_RMSE.csv"))
  val <- .r4_private(".lw_select")(ctx$windows, ctx$control$validation_split, ctx$allowed_start, ctx$allowed_end)
  for (m in ctx$models) {
    id <- best$par_id[best$model == m]; .r4_need(length(id) == 1L, "Missing unique selected candidate")
    directory <- file.path(run, "final", m, id)
    native <- readRDS(file.path(directory, "native_surface.rds"))
    con <- ctx$contracts[ctx$contracts$model == m, , drop = FALSE]
    for (split in c("calibration", "validation")) {
      windows <- if (split == "calibration") ctx$cal else val
      fit <- LakeEnsemblR::calc_fit_window(native, windows, con)
      recorded <- .rr_read_csv(file.path(directory, paste0("pairs_", split, ".csv")))
      .rr_table_equal(recorded, fit$pairs, paste(m, split, "pairs"), 1e-9)
      row <- metrics[metrics$model == m & metrics$split == split, , drop = FALSE]
      for (key in names(fit$metrics)) .r4_need(.rr_numeric_equal(row[[key]], fit$metrics[[key]], 1e-9),
        "Recalculated final metrics differ: ", m, "/", split, "/", key)
      if (split == "calibration") {
        old <- .rr_read_csv(file.path(run, "calibration", m, id, "pairs.csv"))
        old <- old[match(recorded$window_id, old$window_id), , drop = FALSE]
        .r4_need(!anyNA(old$window_id) && all(abs(old$predicted - recorded$predicted) <= 1e-6),
          "Selected calibration/rerun mismatch")
      }
    }
  }
  list(metrics = metrics, files = .r4_private(".lw_file_manifest")(file.path(run, "final")))
}
.r4_evaluate <- function(ctx, root, signature) {
  receipt <- file.path(root, "evaluation.rds")
  if (file.exists(receipt)) {
    old <- .r4_read(receipt)
    .r4_need(isTRUE(old$passed) && identical(old$signature, signature), "Evaluation signature mismatch")
    verify <- .r4_verify_final(ctx$result_dir)
    .r4_need(identical(old$final_files, verify$files) && identical(old$metrics_sha256,
      .r4_sha(file.path(ctx$result_dir, "final_metrics.csv"))), "Final outputs changed")
    return(verify$metrics)
  }
  if (!file.exists(file.path(ctx$result_dir, "final_metrics.csv"))) {
    if (dir.exists(file.path(ctx$result_dir, "final")) || dir.exists(file.path(ctx$result_dir, "_final_work"))) {
      evidence <- .r4_evidence(file.path(root, "e"), "eval")
      .r4_archive(file.path(ctx$result_dir, "final"), evidence, "interrupted_final")
      .r4_archive(file.path(ctx$result_dir, "_final_work"), evidence, "interrupted_work")
    }
    .r4_phase(file.path(root, "phase_times.csv"), "evaluate_selected", {
      LakeEnsemblR::evaluate_window_best(ctx$result_dir, tolerance_celsius = 1e-6)
    })
  }
  verify <- .r4_verify_final(ctx$result_dir)
  .r4_save(list(schema = .r4_schema, signature = signature, passed = TRUE,
    metrics_sha256 = .r4_sha(file.path(ctx$result_dir, "final_metrics.csv")), final_files = verify$files), receipt)
  verify$metrics
}
.r4_report <- function(ctx, root) {
  out <- file.path(root, "report")
  receipt <- file.path(root, "report.rds")
  if (file.exists(receipt)) {
    old <- .r4_read(receipt)
    .r4_need(identical(old$signature, ctx$r4_signature), "Report signature differs")
    .r4_private(".lw_check_manifest")(out, old$files, "Report")
    return(invisible(out))
  }
  if (dir.exists(out)) .r4_archive(out, .r4_evidence(file.path(root, "e"), "rep"), "interrupted_report")
  dir.create(out)
  metrics <- .rr_read_csv(file.path(ctx$result_dir, "final_metrics.csv"))
  .r4_csv(metrics, file.path(out, "model_metrics.csv"))
  best <- .rr_read_csv(file.path(ctx$result_dir, "best_by_calibration_RMSE.csv"))
  pars <- do.call(rbind, lapply(ctx$models, function(m) {
    p <- ctx$pools[[m]][ctx$pools[[m]]$par_id == best$par_id[best$model == m], , drop = FALSE]
    data.frame(model = m, par_id = p$par_id, parameter = ctx$specs[[m]]$name,
      value = as.numeric(p[1L, ctx$specs[[m]]$name, drop = TRUE]), row.names = NULL)
  }))
  .r4_csv(pars, file.path(out, "selected_parameters.csv"))
  all <- .rr_read_csv(file.path(ctx$result_dir, "calibration_summary.csv"))
  response <- do.call(rbind, lapply(ctx$models, function(m) {
    p <- ctx$pools[[m]]; z <- all[all$model == m, ]; z <- z[match(p$par_id, z$par_id), ]
    do.call(rbind, lapply(ctx$specs[[m]]$name, function(k) data.frame(model = m, par_id = p$par_id,
      parameter = k, value = p[[k]], status = z$status, RMSE = z$RMSE)))
  }))
  .r4_csv(response, file.path(out, "parameter_response.csv"))
  pairs <- list(); ensemble_metrics <- list()
  for (split in c("calibration", "validation")) {
    pp <- lapply(ctx$models, function(m) {
      p <- file.path(ctx$result_dir, "final", m, best$par_id[best$model == m], paste0("pairs_", split, ".csv"))
      x <- .rr_read_csv(p); x$model <- m; x$split <- split; x
    })
    x <- pp[[1L]]
    predicted <- sapply(pp, function(z) {
      .r4_need(setequal(z$window_id, x$window_id), "Ensemble windows differ")
      z$predicted[match(x$window_id, z$window_id)]
    })
    x$predicted <- rowMeans(predicted); x$model <- "Ensemble4"
    x$residual <- x$predicted - x$observed
    pairs[[split]] <- do.call(rbind, c(pp, list(x)))
    err <- x$predicted - x$observed
    ensemble_metrics[[split]] <- data.frame(model = "Ensemble4", split = split, N = nrow(x),
      RMSE = sqrt(mean(err^2)), MAE = mean(abs(err)), bias = mean(err),
      NSE = if (sum((x$observed - mean(x$observed))^2) > 0) 1 - sum(err^2) / sum((x$observed - mean(x$observed))^2) else NA_real_,
      r = if (stats::sd(x$observed) > 0 && stats::sd(x$predicted) > 0) stats::cor(x$observed, x$predicted) else NA_real_)
  }
  .r4_csv(do.call(rbind, pairs), file.path(out, "pairs_models_ensemble4.csv"))
  .r4_csv(do.call(rbind, ensemble_metrics), file.path(out, "ensemble4_metrics.csv"))
  grDevices::png(file.path(out, "RMSE_by_split.png"), width = 1500, height = 800, res = 150)
  oldpar <- graphics::par(mfrow = c(1, 2), mar = c(6, 5, 3, 1))
  on.exit({if (grDevices::dev.cur() > 1L) grDevices::dev.off()}, add = TRUE)
  for (split in c("calibration", "validation")) {
    x <- metrics[metrics$split == split, ]; x <- x[match(ctx$models, x$model), ]
    graphics::barplot(x$RMSE, names.arg = x$model, las = 2, ylab = "RMSE (deg C)", main = split,
      col = c("#3686A0", "#E3A437", "#4D9D70", "#A06FAB"))
  }
  graphics::par(oldpar); grDevices::dev.off()
  writeLines(c("Equal-window RMSE; selection uses calibration (2001-2010) only.",
    "Validation: 2011-2015; four-model ensemble uses fixed equal weights.",
    "Parameter-response scatter data are not delta/S1 global sensitivity indices.",
    "LHC parameters and all success/failure statuses are retained for a separate sensitivity analysis."),
    file.path(out, "READ_ME.txt"))
  .r4_save(list(schema = .r4_schema, signature = ctx$r4_signature,
    files = .r4_private(".lw_file_manifest")(out)), receipt)
  invisible(out)
}

# Session-only PSOCK transport setup. Does not edit model/workflow functions.
r4_prepare_local_parallel <- function(ncores = 10L) {
  ns <- asNamespace("parallel")
  set_defaults <- get("setDefaultClusterOptions", ns)
  option_env <- get("defaultClusterOptions", ns)
  old <- lapply(c("port", "master", "setup_strategy"), function(n) get(n, option_env))
  names(old) <- c("port", "master", "setup_strategy")
  port <- NA_integer_
  candidates <- 22000L + ((Sys.getpid() + (0:63) * 997L) %% 20000L)
  for (candidate in candidates) {
    listener <- try(suppressWarnings(serverSocket(candidate)), silent = TRUE)
    if (inherits(listener, "try-error")) next
    close(listener)
    port <- as.integer(candidate)
    break
  }
  if (is.na(port)) stop("No usable local PSOCK port found; no models started.")
  set_defaults(port = port, master = "127.0.0.1", setup_strategy = "parallel")
  cluster <- NULL
  passed <- FALSE
  on.exit({
    if (!is.null(cluster)) try(parallel::stopCluster(cluster), silent = TRUE)
    if (!passed) do.call(set_defaults, old)
  }, add = TRUE)
  log_file <- file.path(tempdir(), paste0("R4_psock_", port, ".log"))
  cat("Testing local PSOCK port:", port, "\nWorker log:", log_file, "\n")
  cluster <- parallel::makePSOCKcluster(
    ncores, outfile = log_file, setup_timeout = 30L
  )
  pids <- unlist(parallel::clusterCall(cluster, Sys.getpid), use.names = FALSE)
  stopifnot(length(pids) == ncores, length(unique(pids)) == ncores)
  parallel::stopCluster(cluster)
  cluster <- NULL
  passed <- TRUE
  cat("R4_LOCAL_PSOCK_TEST_PASSED\nWorkers:", ncores, " Port:", port, "\n")
  invisible(port)
}

# The two completed lakes are verified read-only and excluded from this batch.
.r67_completed <- c("akesaiqin", "namco")
.r67_default_config <- "C:/Geography/R/dissertation_LakeEnsemblR/yaml/r4_ice_20261103_core12"

.r67_rows <- function(config_root) {
  check <- function(x, n, label) {
    .r4_need(is.data.frame(x) && nrow(x) == n && all(c("name", "NAME_ID", "spin_up_days") %in% names(x)),
      label, " must have ", n, " rows and name, NAME_ID, spin_up_days")
    x <- x[c("name", "NAME_ID", "spin_up_days")]
    x$name <- as.character(x$name)
    ids <- suppressWarnings(as.numeric(x$NAME_ID))
    spin <- suppressWarnings(as.numeric(x$spin_up_days))
    .r4_need(!anyNA(x$name) && !anyDuplicated(tolower(x$name)) &&
      all(grepl("^[A-Za-z0-9][A-Za-z0-9_-]*$", x$name)) &&
      all(is.finite(ids) & ids > 0 & ids == floor(ids)) && !anyDuplicated(ids) &&
      all(is.finite(spin) & spin >= 0), "Invalid registry identity/spin-up: ", label)
    x$NAME_ID <- as.integer(ids); x$spin_up_days <- spin
    x <- x[order(x$name), , drop = FALSE]; rownames(x) <- NULL
    x
  }
  all <- check(.rr_read_csv(file.path(config_root, "all_lakes.csv")), 69L, "all_lakes.csv")
  remaining <- check(.rr_read_csv(file.path(config_root, "remaining_lakes.csv")), 67L, "remaining_lakes.csv")
  expected <- all[!all$name %in% .r67_completed, , drop = FALSE]; rownames(expected) <- NULL
  .r4_need(identical(remaining, expected) && !any(remaining$name %in% .r67_completed),
    "Remaining registry must contain exactly the 67 other lakes, with original NAME_ID and spin-up")
  yaml_names <- sub("_LakeEnsemblR[.]yaml$", "", list.files(config_root, pattern = "_LakeEnsemblR[.]yaml$"))
  .r4_need(setequal(yaml_names, all$name), "69 generated YAMLs and all_lakes.csv disagree")
  manifest <- .rr_read_csv(file.path(config_root, "_yaml_manifest.csv"))
  k <- match(all$name, manifest$name)
  .r4_need(nrow(manifest) == 69L && !anyNA(k) && !anyDuplicated(manifest$name) &&
    all(as.numeric(manifest$spin_up_days[k]) == all$spin_up_days), "YAML spin-up manifest and registry disagree")
  list(all = all, remaining = remaining)
}

.r67_shared_check <- function(config_root, ncores, num) {
  .r4_need(identical(as.integer(ncores), 12L) && ncores == 12 &&
    identical(as.integer(num), 500L) && num == 500, "This release uses exactly N=500 and 12 workers")
  .r4_private(".lw_initialize_runtime")()
  .r4_need(identical(as.character(utils::packageVersion("LakeEnsemblR")), "1.2.9.9003"),
    "Use the existing isolated LakeEnsemblR 1.2.9.9003 library")
  .r4_need(length(.r4_source) == 1L && !is.na(.r4_source) && file.exists(.r4_source),
    "Load the saved remaining-67 runner and record its actual source path")
  .r4_need(length(.rr_resume_source_file) == 1L && !is.na(.rr_resume_source_file) &&
    file.exists(.rr_resume_source_file) && identical(.r4_sha(.rr_resume_source_file),
    "74cfbe6a90da76df42c80b168edb45d4a1e78ba08dceac4976ffff84516e5afa"),
    "The unchanged rev3 recovery helper must be loaded from its actual file")
  generated <- .rr_read_csv(file.path(config_root, "_generated_sha256.csv"))
  .r4_need(all(c("relative_path", "sha256") %in% names(generated)) &&
    all(c("all_lakes.csv", "remaining_lakes.csv") %in% generated$relative_path),
    "Use the 20261103 configuration manifest containing both 69/67 registries")
  for (i in seq_len(nrow(generated))) .r4_need(identical(
    .r4_sha(file.path(config_root, generated$relative_path[i])), as.character(generated$sha256[i])),
    "Generated shared configuration changed: ", generated$relative_path[i])
  .r67_rows(config_root)
}

.r67_semantic_config <- function(cfg, folder) {
  file_value <- function(value) {
    if (is.null(value) || !is.character(value) || length(value) != 1L || value %in% c("", "NULL")) return(value)
    path <- if (grepl("^(/|[A-Za-z]:[/\\\\])", value)) value else file.path(folder, value)
    .r4_need(file.exists(path) && !dir.exists(path), "Missing configuration comparison input: ", path)
    paste0("sha256:", .r4_sha(path))
  }
  walk <- function(x) {
    if (!is.list(x)) return(x)
    for (nm in names(x)) if (nm == "file") x[nm] <- list(file_value(x[[nm]])) else
      if (is.list(x[[nm]])) x[[nm]] <- walk(x[[nm]])
    x
  }
  cfg$location$hypsograph <- file_value(cfg$location$hypsograph)
  for (sec in c("input", "observations", "inflows", "outflows")) cfg[sec] <- list(walk(cfg[[sec]]))
  kw <- cfg$input$light$Kw
  if (is.list(kw)) cfg$input$light$Kw <- lapply(kw, file_value) else cfg$input$light$Kw <- file_value(kw)
  cfg$config_files <- lapply(cfg$config_files, file_value)
  canonical <- function(x) {
    if (!is.list(x)) return(x)
    if (!is.null(names(x))) x <- x[order(names(x))]
    lapply(x, canonical)
  }
  canonical(cfg)
}

.r67_window_table_equal <- function(actual, expected, label) {
  .r4_need(is.data.frame(actual) && is.data.frame(expected), label, ": expected data frames")
  .r4_need(identical(names(actual), names(expected)) && nrow(actual) == nrow(expected),
    label, ": window table shape/order differs")
  for (field in c("window_start", "window_end")) {
    .r4_need(field %in% names(actual), label, ": missing timestamp field: ", field)
    got <- as.numeric(.r4_private(".lw_utc")(actual[[field]], field))
    want <- as.numeric(.r4_private(".lw_utc")(expected[[field]], field))
    .r4_need(identical(got, want), label, ": UTC instant differs: ", field)
    actual[[field]] <- got
    expected[[field]] <- want
  }
  .rr_table_equal(actual, expected, label)
}

.r67_verify_completed_two <- function(completed_root, config_root, old_CFG, all_rows) {
  completed_root <- .r4_norm(completed_root)
  rows <- list()
  for (name in .r67_completed) {
    root <- file.path(completed_root, name); run <- file.path(root, "c")
    request <- .r4_read(file.path(root, "request.rds"))
    calibration <- .r4_read(file.path(root, "calibration.rds"))
    evaluation <- .r4_read(file.path(root, "evaluation.rds"))
    report <- .r4_read(file.path(root, "report.rds"))
    row <- all_rows[all_rows$name == name, , drop = FALSE]
    seed0 <- if (is.null(old_CFG$seed)) 20261026L else old_CFG$seed
    expected_seed <- as.integer((as.double(seed0) + 104729 * row$NAME_ID) %% 2147483646 + 1)
    .r4_need(nrow(row) == 1L && identical(request$payload$name, name) &&
      as.integer(request$payload$NAME_ID) == row$NAME_ID && request$payload$num == 500L &&
      request$payload$ncores == 10L && identical(request$payload$models, .r4_models) &&
      request$payload$spin_up_days == row$spin_up_days && request$payload$seed == expected_seed &&
      identical(calibration$signature, request$signature) && isTRUE(calibration$passed) &&
      identical(evaluation$signature, request$signature) && isTRUE(evaluation$passed) &&
      identical(report$signature, request$signature), "Completed two-lake receipt identity mismatch: ", name)
    ctx <- .r4_cal_integrity(run)
    .r4_need(identical(ctx$r4_signature, request$signature) && identical(ctx$models, .r4_models),
      "Completed two-lake context mismatch: ", name)
    for (model in .r4_models) {
      .rr_table_equal(ctx$specs[[model]], .r4_expected_specs(model),
        paste("Completed two-lake parameter design", name, model))
      expected_pool <- .r4_private(".lw_lhc")(ctx$specs[[model]], 500L,
        .r4_private(".lw_seed")(expected_seed, model, "LHC"))
      .rr_table_equal(ctx$pools[[model]], expected_pool, paste("Unchanged 500-set pool", name, model), 0)
    }
    cfg <- .r4_private(".lw_read_config")(file.path(config_root, paste0(name, "_LakeEnsemblR.yaml")))
    .r4_need(identical(.r67_semantic_config(ctx$base, ctx$snapshot),
      .r67_semantic_config(cfg, config_root)), "Completed lake and new 67-lake scheme inputs/physics differ: ", name)
    windows <- .r4_private(".lw_windows")(file.path(old_CFG$windows_dir, paste0(name, "_MODIS_windows_reviewed.csv")))
    .r67_window_table_equal(ctx$windows, windows, paste("Unchanged reviewed windows", name))
    contracts <- .r4_private(".lw_contracts")(file.path(old_CFG$contracts_dir,
      paste0(name, "_output_contracts.csv")), .r4_models, require_confirmed = TRUE)
    .rr_table_equal(ctx$contracts, contracts, paste("Unchanged time contracts", name))
    final <- .r4_verify_final(run)
    .r4_need(identical(evaluation$final_files, final$files) && identical(evaluation$metrics_sha256,
      .r4_sha(file.path(run, "final_metrics.csv"))), "Completed two-lake final outputs changed: ", name)
    .r4_private(".lw_check_manifest")(file.path(root, "report"), report$files, "Completed two-lake report")
    rows[[name]] <- data.frame(name = name, NAME_ID = row$NAME_ID, ncores = 10L, num = 500L,
      run_dir = run, signature = request$signature, calibration_status = "verified",
      evaluation_status = "verified", metrics_sha256 = evaluation$metrics_sha256,
      stringsAsFactors = FALSE)
    cat("COMPLETED_LAKE_VERIFIED_WITHOUT_RERUN:", name, "\n")
  }
  do.call(rbind, rows)
}

.r67_atomic_index <- function(index, path) {
  tmp <- paste0(path, ".new")
  if (file.exists(tmp)) unlink(tmp)
  .r4_private(".lw_write_csv")(index, tmp)
  if (file.exists(path)) .r4_need(unlink(path) == 0L, "Cannot replace progress index; close spreadsheet using it")
  .r4_need(file.rename(tmp, path), "Cannot install remaining-lake progress index")
  invisible(index)
}

.r67_runtime_resume_check <- function(prior, current) {
  for (field in c("schema", "models", "num", "ncores", "sources", "runtime", "runtime_functions", "helper_functions"))
    .r4_need(identical(prior$payload[[field]], current$payload[[field]]),
      "FATAL_SHARED_RUNTIME_OR_SCHEME_CHANGE: ", field,
      "; preserve this batch and use a new reviewed release/results directory")
  invisible(TRUE)
}

.r67_current_runtime_check <- function(live, config_root, ncores, num) {
  .r67_shared_check(config_root, ncores, num)
  .r4_check_files(live$payload$sources)
  runtime <- .r4_private(".lw_package_state")(c("LakeEnsemblR", "FLakeR", "GLM3r", "GOTMr", "SimstratR", "digest", "yaml"))
  code <- vapply(names(live$payload$runtime_functions), function(nm)
    .r4_private(".lw_function_hash")(.r4_private(nm)), character(1))
  helpers <- vapply(names(live$payload$helper_functions), function(nm)
    .r4_private(".lw_function_hash")(get(nm, mode = "function", inherits = TRUE)), character(1))
  .r4_need(identical(runtime, live$payload$runtime) && identical(code, live$payload$runtime_functions) &&
    identical(helpers, live$payload$helper_functions),
    "FATAL_SHARED_RUNTIME_OR_SCHEME_CHANGE: package/functions changed during the batch")
  invisible(TRUE)
}

run_remaining_lakes_r4 <- function(old_CFG, config_root = .r67_default_config,
  results_root = "D:/LER4_ice_20261103/n500_c12",
  completed_root = "D:/LER4_ice_20261102/n500", num = 500L, ncores = 12L,
  continue_on_error = TRUE) {
  config_root <- .r4_norm(config_root)
  registry <- .r67_shared_check(config_root, ncores, num)
  dir.create(results_root, recursive = TRUE, showWarnings = FALSE)
  results_root <- .r4_norm(results_root)
  .r4_need(nchar(results_root, type = "chars") <= 75L && !grepl("[[:space:]]", results_root) &&
    !identical(results_root, .r4_norm(completed_root)), "Use a short, distinct remaining-67 results directory")
  if (!is.null(old_CFG$results_root)) .r4_need(!identical(results_root, .r4_norm(old_CFG$results_root)),
    "Preserve the previous five-model results")
  .r4_need(is.logical(continue_on_error) && length(continue_on_error) == 1L && !is.na(continue_on_error),
    "continue_on_error must be TRUE or FALSE")
  completed <- .r67_verify_completed_two(completed_root, config_root, old_CFG, registry$all)
  .r4_csv(completed, file.path(results_root, "completed_two_verified.csv"))
  rows <- registry$remaining
  .r4_csv(rows, file.path(results_root, "remaining_lakes_effective.csv"))
  .r4_need(all(nchar(file.path(results_root, rows$name, "v", "p", "_work", "j000007",
    paste0(rows$name, "_LakeEnsemblR.yaml")), type = "chars") < 240L),
    "Shorten results_root: a native case path would approach Windows path limits")
  index <- data.frame(name = rows$name, NAME_ID = rows$NAME_ID,
    run_dir = file.path(results_root, rows$name, "c"), ncores = 12L, num = 500L,
    input_status = "not_run", preflight_status = "not_run", calibration_status = "not_run",
    evaluation_status = "not_run", report_status = "not_run", error = "", stringsAsFactors = FALSE)
  index_path <- file.path(results_root, "remaining_lake_run_index.csv")
  if (file.exists(index_path)) {
    before <- .rr_read_csv(index_path)
    .r4_need(identical(as.character(before$name), rows$name) &&
      identical(as.integer(before$NAME_ID), rows$NAME_ID), "Existing remaining-batch index registry changed")
    for (field in intersect(names(index), names(before))) index[[field]] <- before[[field]]
  }
  write_index <- function() .r67_atomic_index(index, index_path)
  write_index()
  lives <- vector("list", nrow(rows))
  # No engine starts until all 67 input/identity checks and shared-state checks finish.
  for (i in seq_len(nrow(rows))) {
    cat("Input audit", i, "/67:", rows$name[i], "\n")
    live <- tryCatch(.r4_live(old_CFG, config_root, rows[i, , drop = FALSE], num, ncores), error = identity)
    if (inherits(live, "error")) {
      index$input_status[i] <- "failed"; index$error[i] <- conditionMessage(live); write_index()
      if (!continue_on_error) stop(live)
      next
    }
    request <- file.path(results_root, rows$name[i], "request.rds")
    if (file.exists(request)) .r67_runtime_resume_check(.r4_read(request), live)
    lives[[i]] <- live; index$input_status[i] <- "ok"; index$error[i] <- ""; write_index()
  }
  r4_prepare_local_parallel(as.integer(ncores))
  for (i in seq_len(nrow(rows))) {
    if (is.null(lives[[i]])) next
    live <- lives[[i]]; root <- file.path(results_root, rows$name[i]); run <- file.path(root, "c")
    .r67_current_runtime_check(live, config_root, ncores, num)
    dir.create(root, recursive = TRUE, showWarnings = FALSE)
    request <- file.path(root, "request.rds")
    cat("REMAINING_LAKE", i, "/67:", rows$name[i], "\n")
    active <- "input_status"
    tryCatch({
      fresh <- .r4_live(old_CFG, config_root, rows[i, , drop = FALSE], num, ncores)
      .r4_need(identical(fresh$payload, live$payload),
        "Lake input changed after its startup audit; preserve its results and review: ", rows$name[i])
      active <- "initialization"
      if (file.exists(request)) {
        prior <- .r4_read(request)
        .r4_need(identical(prior$signature, live$signature) && identical(prior$payload, live$payload),
          "Saved lake input/design signature differs; preserve its results and review the changed input")
        ctx <- .r4_load_context(run, root, live$signature)
        .r4_need(identical(ctx$r4_signature, live$signature) && identical(ctx$models, .r4_models),
          "Remaining-lake context request mismatch")
        .r4_private(".lw_verify_runtime")(ctx)
      } else {
        if (dir.exists(run)) .r4_archive(run, .r4_evidence(file.path(root, "e"), "init"), "interrupted_unsealed_initialization")
        ctx <- .r4_new_context(live, run)
        .r4_save(list(schema = .r4_schema, signature = live$signature, payload = live$payload), request)
      }
      active <- "preflight_status"
      .r4_phase(file.path(root, "phase_times.csv"), "preflight_and_changed_model_replay", {
        .r4_preflight(ctx, root, live$signature, ncores)
      })
      index$preflight_status[i] <- "ok"; write_index()
      active <- "calibration_status"
      ctx <- .r4_calibrate(ctx, root, live, ncores)
      index$calibration_status[i] <- "ok"; write_index()
      active <- "evaluation_status"
      .r4_evaluate(ctx, root, live$signature)
      index$evaluation_status[i] <- "ok"; write_index()
      active <- "report_status"
      .r4_report(ctx, root)
      index$report_status[i] <- "ok"; index$error[i] <- ""; write_index()
    }, error = function(e) {
      if (active %in% names(index)) index[[active]][i] <<- "failed"
      index$error[i] <<- conditionMessage(e); write_index()
      cat("LAKE_FAILED_AND_RECORDED:", rows$name[i], "\n", conditionMessage(e), "\n")
      if (!continue_on_error) stop(e)
    })
  }
  passed <- index$input_status == "ok" & index$preflight_status == "ok" &
    index$calibration_status == "ok" & index$evaluation_status == "ok" & index$report_status == "ok" & index$error == ""
  .r67_atomic_index(index[!passed, , drop = FALSE], file.path(results_root, "remaining_failed_lakes.csv"))
  if (!all(passed)) {
    stop("REMAINING_67_NOT_ALL_PASSED; completed ", sum(passed), "/67; inspect remaining_failed_lakes.csv. Completed results are retained.", call. = FALSE)
  }
  combined <- rbind(data.frame(name = completed$name, NAME_ID = completed$NAME_ID, run_dir = completed$run_dir,
    ncores = 10L, num = 500L, calibration_status = "ok", evaluation_status = "ok", source_batch = "completed_two"),
    data.frame(name = index$name, NAME_ID = index$NAME_ID, run_dir = index$run_dir, ncores = 12L, num = 500L,
      calibration_status = "ok", evaluation_status = "ok", source_batch = "remaining67"))
  combined <- combined[order(combined$name), , drop = FALSE]; rownames(combined) <- NULL
  .r4_need(nrow(combined) == 69L && !anyDuplicated(combined$name), "Combined 69-lake index is incomplete")
  .r4_csv(combined, file.path(results_root, "combined_69_lake_run_index.csv"))
  cat("REMAINING_67_FOUR_MODELS_CALIBRATION_EVALUATION_PASSED\n")
  cat("ALL_69_FOUR_MODELS_CALIBRATION_EVALUATION_PASSED\nResults:", results_root, "\n")
  invisible(index)
}
