# Resume one interrupted LakeEnsemblR 1.2.9.9003 window calibration without
# changing the installed package, parameter pool, model equations, or objective.
#
# The original public API writes parameters.csv before a candidate starts and
# status.csv near the end.  This script validates every retained candidate,
# preserves incomplete candidate directories outside the sealed calibration
# run, executes only missing candidates, and then reproduces the original
# cali_window_ensemble() finalization and R69 calibration receipt.

.rr_resume_source_file <- local({
  path <- tryCatch(sys.frame(1L)$ofile, error = function(e) NULL)
  if (is.null(path) || length(path) != 1L || !nzchar(path)) return(NA_character_)
  normalizePath(path, winslash = "/", mustWork = TRUE)
})

.rr_need <- function(ok, ...) {
  if (!isTRUE(ok)) stop(..., call. = FALSE)
}

.rr_fun <- function(R69, name) {
  fun <- tryCatch(R69[[name]], error = function(e) NULL)
  .rr_need(is.function(fun), "R69 does not provide function: ", name)
  fun
}

.rr_norm <- function(path, mustWork = TRUE) {
  normalizePath(path, winslash = "/", mustWork = mustWork)
}

.rr_stamp <- function() {
  format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
}

.rr_sha <- function(path) {
  digest::digest(file = path, algo = "sha256", serialize = FALSE)
}

.rr_read_csv <- function(path) {
  .rr_need(file.exists(path) && !dir.exists(path), "Missing CSV: ", path)
  out <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE,
                         fileEncoding = "UTF-8-BOM")
  .rr_need(!anyDuplicated(names(out)), "Duplicate CSV columns: ", path)
  out
}

.rr_numeric_equal <- function(a, b, tolerance = 1e-12) {
  a <- suppressWarnings(as.numeric(a))
  b <- suppressWarnings(as.numeric(b))
  if (length(a) != length(b)) return(FALSE)
  both_na <- is.na(a) & is.na(b)
  if (any(xor(is.na(a), is.na(b)))) return(FALSE)
  take <- !both_na
  if (!any(take)) return(TRUE)
  if (any(is.infinite(a[take]) | is.infinite(b[take]))) {
    same_inf <- is.infinite(a[take]) & is.infinite(b[take]) &
      sign(a[take]) == sign(b[take])
    finite <- is.finite(a[take]) & is.finite(b[take])
    if (any(!(same_inf | finite))) return(FALSE)
    if (!any(finite)) return(TRUE)
    aa <- a[take][finite]
    bb <- b[take][finite]
  } else {
    aa <- a[take]
    bb <- b[take]
  }
  all(abs(aa - bb) <= tolerance * pmax(1, abs(aa), abs(bb)))
}

.rr_table_equal <- function(actual, expected, label, tolerance = 1e-12) {
  .rr_need(is.data.frame(actual) && is.data.frame(expected),
           label, ": expected data frames")
  .rr_need(identical(names(actual), names(expected)),
           label, ": column names/order differ")
  .rr_need(nrow(actual) == nrow(expected), label, ": row count differs")
  for (name in names(expected)) {
    want <- expected[[name]]
    got <- actual[[name]]
    if (inherits(want, "POSIXt")) {
      want <- format(want, "%Y-%m-%d %H:%M:%S", tz = "UTC")
    }
    if (is.numeric(want) || is.integer(want)) {
      .rr_need(.rr_numeric_equal(got, want, tolerance),
               label, ": numeric field differs: ", name)
    } else if (is.logical(want)) {
      normalize_bool <- function(x) {
        x <- toupper(as.character(x))
        x[x == "1"] <- "TRUE"
        x[x == "0"] <- "FALSE"
        x
      }
      .rr_need(identical(normalize_bool(got), normalize_bool(want)),
               label, ": logical field differs: ", name)
    } else {
      .rr_need(identical(as.character(got), as.character(want)),
               label, ": text field differs: ", name)
    }
  }
  invisible(TRUE)
}

.rr_candidate_required <- function(ctx, status) {
  files <- c("parameters.csv", "contract.csv", "status.csv", "warnings.txt")
  if (identical(status, "ok")) {
    files <- c(files, "native_audit.csv", "pairs.csv", "metrics.csv")
    if (isTRUE(ctx$control$save_series)) files <- c(files, "native_surface.rds")
  }
  files
}

.rr_validate_candidate <- function(ctx, model, pool_row, directory) {
  id <- as.character(pool_row$par_id)
  parameter_file <- file.path(directory, "parameters.csv")
  status_file <- file.path(directory, "status.csv")
  if (!dir.exists(directory)) {
    return(list(state = "missing", status = NULL, reason = "directory absent"))
  }
  if (!file.exists(status_file)) {
    return(list(state = "incomplete", status = NULL, reason = "status.csv absent"))
  }
  .rr_need(file.exists(parameter_file),
           "Candidate has status.csv but no parameters.csv: ", directory)
  parameters <- .rr_read_csv(parameter_file)
  .rr_table_equal(parameters, pool_row, paste(model, id, "parameters"))

  status <- .rr_read_csv(status_file)
  .rr_need(nrow(status) == 1L &&
             all(c("model", "par_id", "random_seed", "status", "stage",
                   "message", "N", "RMSE", "MAE", "bias", "NSE", "r",
                   "objective") %in% names(status)),
           "Invalid status schema: ", status_file)
  .rr_need(identical(as.character(status$model), model) &&
             identical(as.character(status$par_id), id),
           "Candidate status model/par_id mismatch: ", directory)
  expected_seed <- get(".lw_seed", asNamespace("LakeEnsemblR"))(
    ctx$control$seed, model, id)
  .rr_need(.rr_numeric_equal(status$random_seed, expected_seed, 0),
           "Candidate seed mismatch: ", directory)
  state <- as.character(status$status)
  .rr_need(length(state) == 1L && state %in% c("ok", "failed"),
           "Invalid candidate status: ", directory)
  required <- .rr_candidate_required(ctx, state)
  absent <- required[!file.exists(file.path(directory, required))]
  if (length(absent)) {
    return(list(state = "incomplete", status = status,
                reason = paste("missing", paste(absent, collapse = ", "))))
  }

  contract <- .rr_read_csv(file.path(directory, "contract.csv"))
  expected_contract <- ctx$contracts[ctx$contracts$model == model, , drop = FALSE]
  .rr_table_equal(contract, expected_contract,
                  paste(model, id, "contract"))

  if (identical(state, "ok")) {
    audit <- .rr_read_csv(file.path(directory, "native_audit.csv"))
    .rr_need(nrow(audit) == 1L && "model" %in% names(audit) &&
               identical(as.character(audit$model), model),
             "Invalid native_audit.csv: ", directory)
    pairs <- .rr_read_csv(file.path(directory, "pairs.csv"))
    .rr_need(all(c("window_id", "observed", "predicted") %in% names(pairs)) &&
               nrow(pairs) == nrow(ctx$cal) && !anyDuplicated(pairs$window_id) &&
               setequal(as.character(pairs$window_id), as.character(ctx$cal$window_id)),
             "Invalid calibration pairs: ", directory)
    ordered_pairs <- pairs[match(as.character(ctx$cal$window_id),
                                 as.character(pairs$window_id)), , drop = FALSE]
    .rr_need(.rr_numeric_equal(ordered_pairs$observed, ctx$cal$observed, 1e-12) &&
               all(is.finite(suppressWarnings(as.numeric(ordered_pairs$predicted)))),
             "Calibration observations/predictions are invalid: ", directory)
    metrics <- .rr_read_csv(file.path(directory, "metrics.csv"))
    .rr_need(nrow(metrics) == 1L &&
               all(c("N", "RMSE", "MAE", "bias", "NSE", "r") %in% names(metrics)),
             "Invalid metrics.csv: ", directory)
    .rr_need(.rr_numeric_equal(metrics$N, nrow(ctx$cal), 0) &&
               is.finite(suppressWarnings(as.numeric(metrics$RMSE))) &&
               suppressWarnings(as.numeric(metrics$RMSE)) >= 0,
             "Successful candidate metrics are not finite/complete: ", directory)
    for (field in c("N", "RMSE", "MAE", "bias", "NSE", "r")) {
      .rr_need(.rr_numeric_equal(status[[field]], metrics[[field]], 1e-12),
               "status/metrics mismatch for ", model, "/", id, ": ", field)
    }
    .rr_need(.rr_numeric_equal(status$objective, metrics$RMSE, 1e-12),
             "objective/RMSE mismatch for ", model, "/", id)
  } else {
    .rr_need(is.infinite(suppressWarnings(as.numeric(status$objective))) &&
               suppressWarnings(as.numeric(status$objective)) > 0,
             "Failed candidate objective must be Inf: ", directory)
  }
  list(state = "complete", status = status, reason = "")
}

.rr_scan_candidates <- function(ctx) {
  rows <- list()
  statuses <- list()
  for (model in ctx$models) {
    pool <- ctx$pools[[model]]
    .rr_need(is.data.frame(pool) && "par_id" %in% names(pool) &&
               !anyDuplicated(pool$par_id), "Invalid context pool: ", model)
    model_root <- file.path(ctx$result_dir, "calibration", model)
    if (dir.exists(model_root)) {
      existing <- list.dirs(model_root, full.names = FALSE, recursive = FALSE)
      extra <- setdiff(existing, as.character(pool$par_id))
      .rr_need(!length(extra), "Unexpected candidate directories in ", model_root,
               ": ", paste(extra, collapse = ", "))
    }
    for (i in seq_len(nrow(pool))) {
      row <- pool[i, , drop = FALSE]
      id <- as.character(row$par_id)
      directory <- file.path(model_root, id)
      checked <- .rr_validate_candidate(ctx, model, row, directory)
      rows[[length(rows) + 1L]] <- data.frame(
        model = model, par_id = id, state = checked$state,
        reason = checked$reason, directory = directory,
        directory_exists = dir.exists(directory),
        parameters_exists = file.exists(file.path(directory, "parameters.csv")),
        status_exists = file.exists(file.path(directory, "status.csv")),
        stringsAsFactors = FALSE)
      if (identical(checked$state, "complete")) {
        statuses[[paste(model, id, sep = "/")]] <- checked$status
      }
    }
  }
  list(index = do.call(rbind, rows), statuses = statuses)
}

.rr_registry_row <- function(CFG, R69, lake) {
  .rr_fun(R69, "r69_load_runtime")(CFG)
  registry <- .rr_fun(R69, "r69_read_index")(CFG$lake_index, CFG$expected_lakes)
  registry$spin_up_days <- CFG$spin_up_days
  manifest <- file.path(CFG$yaml_dir, "_yaml_manifest.csv")
  if (isTRUE(CFG$use_yaml_spinup_manifest) && file.exists(manifest)) {
    values <- utils::read.csv(manifest, stringsAsFactors = FALSE,
                              fileEncoding = "UTF-8-BOM")
    .rr_need(all(c("name", "spin_up_days") %in% names(values)) &&
               !anyDuplicated(values$name), "Invalid _yaml_manifest.csv")
    positions <- match(registry$name, values$name)
    .rr_need(!anyNA(positions), "YAML manifest does not contain all selected lakes")
    spin <- suppressWarnings(as.numeric(values$spin_up_days[positions]))
    .rr_need(all(is.finite(spin) & spin >= 0), "Invalid YAML spin-up days")
    registry$spin_up_days <- spin
  }
  row <- registry[registry$name == lake, , drop = FALSE]
  .rr_need(nrow(row) == 1L, "Lake is not a unique registry row: ", lake)
  row
}

.rr_verify_live_request <- function(CFG, R69, lake, request, lake_root) {
  live <- .rr_fun(R69, "r69_preflight")(
    CFG, .rr_registry_row(CFG, R69, lake))
  .rr_need(isTRUE(live$passed), "Live R69 preflight failed: ",
           paste(live$issues, collapse = " | "))
  .rr_need(identical(live$signature, request$signature),
           "Live R69 input/runtime signature differs from the interrupted request")
  acceptance <- .rr_fun(R69, "r69_read_sealed")(
    file.path(lake_root, "acceptance", "acceptance_receipt.rds"))
  .rr_need(identical(acceptance, request$acceptance),
           "The sealed acceptance receipt differs from request$acceptance")
  .rr_need(identical(acceptance$signature, request$signature) &&
             isTRUE(acceptance$passed) && isTRUE(acceptance$parallel_accepted),
           "Acceptance is not the required passed parallel acceptance")
  live
}

.rr_run_lb_tasks <- function(tasks, ctx, ncores, log_file) {
  if (!length(tasks)) return(list())
  paths <- .libPaths()
  cluster <- parallel::makePSOCKcluster(min(ncores, length(tasks)), outfile = log_file)
  context_key <- paste0(
    ".rr_worker_context_",
    substr(digest::digest(normalizePath(log_file, winslash = "/", mustWork = FALSE),
                          algo = "sha256", serialize = FALSE), 1L, 20L))
  cleanup <- function() {
    if (is.null(cluster)) return(invisible(NULL))
    try(parallel::clusterCall(cluster, function(key) {
      if (exists(key, envir = .GlobalEnv, inherits = FALSE))
        rm(list = key, envir = .GlobalEnv)
      TRUE
    }, context_key), silent = TRUE)
    try(parallel::stopCluster(cluster), silent = TRUE)
    invisible(NULL)
  }
  on.exit(cleanup(), add = TRUE)
  checks <- parallel::clusterCall(cluster, function(paths, ctx, key) {
    .libPaths(paths)
    get(".lw_initialize_runtime", asNamespace("LakeEnsemblR"))(paths)
    get(".lw_verify_runtime", asNamespace("LakeEnsemblR"))(ctx)
    assign(key, ctx, envir = .GlobalEnv)
    TRUE
  }, paths, ctx, context_key)
  .rr_need(all(vapply(checks, isTRUE, logical(1))), "PSOCK worker verification failed")
  results <- parallel::parLapplyLB(
    cluster, tasks,
    function(task, key) {
      worker_ctx <- get(key, envir = .GlobalEnv, inherits = FALSE)
      get(".lw_worker", asNamespace("LakeEnsemblR"))(task, worker_ctx)
    },
    key = context_key, chunk.size = 1L)
  cleanup()
  cluster <- NULL
  results
}

.rr_concurrency_precheck <- function(ctx, scan, ncores, evidence_dir,
                                     tolerance) {
  .rr_need(ncores >= 10L, "The accepted 10-concurrent replay requires ncores >= 10")
  replay_root <- file.path(evidence_dir, "five_model_10_concurrent_replay")
  .rr_need(dir.create(replay_root, recursive = TRUE, showWarnings = FALSE),
           "Could not create five-model replay directory")
  replay_ctx <- ctx
  replay_ctx$result_dir <- .rr_norm(replay_root)
  rows <- list()
  for (model in ctx$models) {
    ids <- sort(scan$index$par_id[
      scan$index$model == model & scan$index$state == "complete"])
    ok <- vapply(ids, function(id) {
      status <- scan$statuses[[paste(model, id, sep = "/")]]
      !is.null(status) && identical(as.character(status$status), "ok")
    }, logical(1))
    ids <- ids[ok]
    .rr_need(length(ids) >= 10L,
             "Need at least 10 retained ok candidates for replay: ", model)
    ids <- ids[seq_len(10L)]
    pool <- ctx$pools[[model]]
    positions <- match(ids, as.character(pool$par_id))
    .rr_need(!anyNA(positions), "Replay IDs are absent from pool: ", model)
    tasks <- lapply(positions, function(position) list(
      model = model, spec = ctx$specs[[model]],
      pool = pool[position, , drop = FALSE],
      worker_id = sprintf("pc%04d", position)))
    .rr_run_lb_tasks(tasks, replay_ctx, 10L,
                     file.path(evidence_dir, paste0(model, "_precheck_workers.log")))
    for (id in ids) {
      original_dir <- file.path(ctx$result_dir, "calibration", model, id)
      replay_dir <- file.path(replay_root, "calibration", model, id)
      original_status <- .rr_read_csv(file.path(original_dir, "status.csv"))
      replay_status <- .rr_read_csv(file.path(replay_dir, "status.csv"))
      .rr_need(identical(names(original_status), names(replay_status)) &&
                 all(vapply(c("model", "par_id", "status", "stage", "message"),
                            function(field) identical(as.character(original_status[[field]]),
                                                      as.character(replay_status[[field]])),
                            logical(1))) &&
                 identical(as.character(original_status$status), "ok"),
               "Concurrency replay did not reproduce ok: ", model, "/", id)
      for (field in c("random_seed", "N", "RMSE", "MAE", "bias", "NSE", "r",
                      "objective")) {
        .rr_need(.rr_numeric_equal(original_status[[field]], replay_status[[field]],
                                   tolerance),
                 "Replay status differs for ", model, "/", id, "/", field)
      }
      original_pairs <- .rr_read_csv(file.path(original_dir, "pairs.csv"))
      replay_pairs <- .rr_read_csv(file.path(replay_dir, "pairs.csv"))
      .rr_need(identical(as.character(original_pairs$window_id),
                         as.character(replay_pairs$window_id)) &&
                 .rr_numeric_equal(original_pairs$observed, replay_pairs$observed, 1e-12) &&
                 .rr_numeric_equal(original_pairs$predicted, replay_pairs$predicted, tolerance),
               "Replay window pairs differ: ", model, "/", id)
      delta <- max(abs(as.numeric(original_pairs$predicted) -
                         as.numeric(replay_pairs$predicted)), na.rm = TRUE)
      rows[[length(rows) + 1L]] <- data.frame(
        model = model, par_id = id, status_match = TRUE,
        window_pairs = nrow(original_pairs), max_prediction_difference = delta,
        tolerance = tolerance, passed = TRUE, stringsAsFactors = FALSE)
    }
  }
  report <- do.call(rbind, rows)
  .rr_write_evidence_csv(report,
                         file.path(evidence_dir, "five_model_10_concurrent_replay.csv"))
  report
}

.rr_validate_pool_files <- function(ctx) {
  for (model in ctx$models) {
    .rr_need(!is.null(ctx$specs[[model]]) && !is.null(ctx$pools[[model]]),
             "Context lacks spec/pool: ", model)
    pool_file <- file.path(ctx$result_dir, paste0("params_", model, ".csv"))
    spec_file <- file.path(ctx$result_dir, paste0("spec_", model, ".csv"))
    .rr_table_equal(.rr_read_csv(pool_file), ctx$pools[[model]],
                    paste(model, "parameter pool"))
    .rr_table_equal(.rr_read_csv(spec_file), ctx$specs[[model]],
                    paste(model, "parameter specification"))
  }
  invisible(TRUE)
}

.rr_write_evidence_csv <- function(x, path) {
  .rr_need(!file.exists(path), "Evidence file already exists: ", path)
  utils::write.csv(x, path, row.names = FALSE, na = "NA", fileEncoding = "UTF-8")
  invisible(path)
}

.rr_retained_manifest <- function(ctx, scan) {
  manifest_fun <- get(".lw_file_manifest", asNamespace("LakeEnsemblR"))
  rows <- list()
  retained <- scan$index[scan$index$state == "complete", , drop = FALSE]
  for (i in seq_len(nrow(retained))) {
    manifest <- manifest_fun(retained$directory[i])
    manifest$model <- retained$model[i]
    manifest$par_id <- retained$par_id[i]
    rows[[length(rows) + 1L]] <- manifest[
      c("model", "par_id", "file", "bytes", "sha256")]
  }
  if (!length(rows)) {
    return(data.frame(model = character(), par_id = character(),
                      file = character(), bytes = numeric(), sha256 = character()))
  }
  out <- do.call(rbind, rows)
  out <- out[order(match(out$model, ctx$models), out$par_id, out$file), , drop = FALSE]
  rownames(out) <- NULL
  out
}

.rr_verify_locked_manifest <- function(ctx, locked) {
  .rr_need(is.data.frame(locked) &&
             all(c("model", "par_id", "file", "bytes", "sha256") %in% names(locked)) &&
             nrow(locked) > 0L, "Invalid locked retained-candidate manifest")
  for (i in seq_len(nrow(locked))) {
    path <- file.path(ctx$result_dir, "calibration", locked$model[i],
                      locked$par_id[i], locked$file[i])
    .rr_need(file.exists(path) && !dir.exists(path),
             "A retained candidate artifact disappeared: ", path)
    .rr_need(identical(as.numeric(file.info(path)$size), as.numeric(locked$bytes[i])) &&
               identical(.rr_sha(path), as.character(locked$sha256[i])),
             "A retained candidate artifact changed: ", path)
  }
  invisible(TRUE)
}

.rr_valid_prior_evidence <- function(attempt) {
  normalized_attempt <- .rr_norm(attempt)
  directories <- list.dirs(attempt, full.names = TRUE, recursive = FALSE)
  directories <- directories[grepl("^resume_evidence_", basename(directories))]
  directories[vapply(directories, function(directory) {
    identity_file <- file.path(directory, "recovery_identity.txt")
    manifest_file <- file.path(directory, "locked_retained_manifest.csv")
    if (!file.exists(identity_file) || !file.exists(manifest_file)) return(FALSE)
    identity <- readLines(identity_file, warn = FALSE)
    identical(identity[startsWith(identity, "attempt=")],
              paste0("attempt=", normalized_attempt)) &&
      any(identical(identity[startsWith(identity, "LakeEnsemblR=")],
                    "LakeEnsemblR=1.2.9.9003"))
  }, logical(1))]
}

.rr_new_evidence_dir <- function(attempt) {
  base <- paste0("resume_evidence_", .rr_stamp())
  directory <- file.path(attempt, base)
  suffix <- 0L
  while (file.exists(directory)) {
    suffix <- suffix + 1L
    directory <- file.path(attempt, paste0(base, "_", suffix))
  }
  .rr_need(dir.create(directory, recursive = TRUE, showWarnings = FALSE),
           "Could not create recovery evidence directory")
  directory
}

.rr_write_or_verify_package_csv <- function(x, target, evidence_dir) {
  writer <- get(".lw_write_csv", asNamespace("LakeEnsemblR"))
  expected <- file.path(evidence_dir, paste0("expected_", basename(target)))
  writer(x, expected)
  if (file.exists(target)) {
    .rr_need(identical(.rr_sha(target), .rr_sha(expected)),
             "Existing finalization file differs from expected: ", target)
  } else {
    .rr_need(file.copy(expected, target, overwrite = FALSE),
             "Could not install finalization file: ", target)
  }
  invisible(target)
}

.rr_copy_or_verify <- function(source, target) {
  .rr_need(file.exists(source) && !dir.exists(source), "Missing source file: ", source)
  dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
  if (file.exists(target)) {
    .rr_need(identical(.rr_sha(source), .rr_sha(target)),
             "Existing provenance file differs: ", target)
  } else {
    .rr_need(file.copy(source, target, overwrite = FALSE),
             "Could not copy provenance file: ", target)
  }
  invisible(target)
}

.rr_atomic_context_replace <- function(context_file, ctx, evidence_dir) {
  before <- file.path(evidence_dir, "context_before_finalize.rds")
  ready <- file.path(evidence_dir, "context_ready.rds")
  after <- file.path(evidence_dir, "context_after_finalize.rds")
  .rr_need(!file.exists(before) && !file.exists(ready) && !file.exists(after),
           "Context finalization evidence paths already exist")
  saveRDS(ctx, ready, version = 3L)
  .rr_need(file.rename(context_file, before),
           "Could not atomically preserve the initial context.rds")
  installed <- file.rename(ready, context_file)
  if (!isTRUE(installed)) {
    rollback <- file.rename(before, context_file)
    .rr_need(isTRUE(rollback),
             "New context install and rollback both failed; preserve the evidence directory")
    stop("Could not atomically install finalized context.rds; original restored", call. = FALSE)
  }
  .rr_need(file.copy(context_file, after, overwrite = FALSE),
           "Finalized context installed but its evidence copy failed")
  invisible(context_file)
}

.rr_complete_receipt <- function(CFG, R69, attempt, ctx, request, summary,
                                 evidence_dir, script_sha256) {
  minimum <- if (is.null(CFG$min_success_fraction)) 0.95 else
    suppressWarnings(as.numeric(CFG$min_success_fraction))
  .rr_need(length(minimum) == 1L && is.finite(minimum) &&
             minimum > 0 && minimum <= 1,
           "Invalid CFG$min_success_fraction")
  for (model in ctx$models) {
    part <- summary[summary$model == model, , drop = FALSE]
    .rr_need(nrow(part) == as.integer(request$num),
             "Incomplete candidate count after recovery: ", model)
    fraction <- mean(part$status == "ok" & is.finite(part$RMSE))
    .rr_need(fraction >= minimum, model, ": successful candidate fraction ",
             fraction, " is below ", minimum)
  }

  selected <- list(
    signature = request$signature,
    run_dir = .rr_norm(ctx$result_dir),
    attempt_dir = .rr_norm(attempt),
    success_count = sum(summary$status == "ok"),
    failure_count = sum(summary$status != "ok"),
    num = as.integer(request$num),
    seed = request$seed
  )
  receipt_file <- file.path(attempt, "calibration_receipt.rds")
  read_sealed <- .rr_fun(R69, "r69_read_sealed")
  save_sealed <- .rr_fun(R69, "r69_save_sealed")
  if (file.exists(receipt_file) || file.exists(paste0(receipt_file, ".sha256"))) {
    old <- read_sealed(receipt_file)
    .rr_need(identical(old, selected),
             "Existing calibration receipt differs; it was not replaced")
  } else {
    save_sealed(selected, receipt_file)
  }

  recovery <- list(
    lake = request$name,
    attempt_dir = selected$attempt_dir,
    run_dir = selected$run_dir,
    retained_candidates = nrow(summary),
    success_count = selected$success_count,
    failure_count = selected$failure_count,
    script_sha256 = script_sha256,
    completed_UTC = format(Sys.time(), "%Y-%m-%d %H:%M:%S", tz = "UTC")
  )
  save_sealed(recovery, file.path(evidence_dir, "recovery_completion.rds"))
  selected
}

resume_interrupted_lake_calibration <- function(
    CFG,
    R69,
    lake = "akesaiqin",
    ncores = 10L,
    expected_completed = c(FLake = 334L, GLM = 430L, GOTM = 240L,
                           Simstrat = 80L, MyLake = 17L),
    expected_started = c(FLake = 336L, GLM = 432L, GOTM = 242L,
                         Simstrat = 82L, MyLake = 19L),
    attempt_dir = NULL,
    execute_missing = TRUE,
    worker_runner = NULL,
    precheck_runner = NULL) {
  .rr_need(requireNamespace("digest", quietly = TRUE), "digest is required")
  .rr_need(identical(as.character(utils::packageVersion("LakeEnsemblR")),
                     "1.2.9.9003"),
           "This recovery is locked to LakeEnsemblR 1.2.9.9003; found ",
           as.character(utils::packageVersion("LakeEnsemblR")))
  .rr_need(is.character(lake) && length(lake) == 1L &&
             grepl("^[A-Za-z0-9][A-Za-z0-9_-]*$", lake), "Invalid lake name")
  ncores <- suppressWarnings(as.integer(ncores))
  .rr_need(length(ncores) == 1L && is.finite(ncores) && ncores >= 1L,
           "ncores must be a positive integer")
  .rr_need(!is.null(CFG$results_root) && dir.exists(CFG$results_root),
           "CFG$results_root does not exist")
  .rr_need(isTRUE(CFG$resume), "CFG$resume must remain TRUE")
  .rr_need(as.integer(CFG$num) == 500L, "CFG$num must remain 500")
  .rr_need(as.integer(CFG$ncores) == ncores,
           "Use the accepted CFG$ncores value; expected ", CFG$ncores)
  .rr_need(!is.na(.rr_resume_source_file) && file.exists(.rr_resume_source_file),
           "Source this recovery from its saved .R file so its SHA256 can be sealed")

  lake_root <- file.path(CFG$results_root, "lakes", lake)
  attempts_root <- file.path(lake_root, "attempts")
  .rr_need(dir.exists(attempts_root), "Missing attempts directory: ", attempts_root)
  read_sealed <- .rr_fun(R69, "r69_read_sealed")
  if (is.null(attempt_dir)) {
    attempts <- list.dirs(attempts_root, full.names = TRUE, recursive = FALSE)
    eligible <- attempts[vapply(attempts, function(path) {
      file.exists(file.path(path, "request.rds")) &&
        !file.exists(file.path(path, "calibration_receipt.rds"))
    }, logical(1))]
    .rr_need(length(eligible) == 1L,
             "Expected exactly one unsealed attempt for ", lake, "; found ",
             length(eligible), if (length(eligible)) paste0(": ", paste(eligible, collapse = ", ")) else "")
    attempt <- eligible[[1L]]
  } else {
    attempt <- attempt_dir
  }
  attempt <- .rr_norm(attempt)
  .rr_need(identical(dirname(attempt), .rr_norm(attempts_root)),
           "Attempt is outside the selected lake: ", attempt)
  request <- read_sealed(file.path(attempt, "request.rds"))
  .rr_need(identical(as.character(request$name), lake) &&
             isTRUE(request$acceptance$passed) &&
             as.integer(request$num) == 500L,
           "Request receipt does not describe the accepted 500-member lake run")
  live_r69 <- .rr_verify_live_request(CFG, R69, lake, request, lake_root)

  run_dir <- file.path(attempt, "calibration")
  .rr_need(dir.exists(run_dir), "Missing interrupted calibration directory: ", run_dir)
  context_file <- file.path(run_dir, "context.rds")
  if (!file.exists(context_file)) {
    recovery_dirs <- rev(sort(.rr_valid_prior_evidence(attempt)))
    restored <- FALSE
    for (directory in recovery_dirs) {
      ready <- file.path(directory, "context_ready.rds")
      before_context <- file.path(directory, "context_before_finalize.rds")
      source <- if (file.exists(ready)) ready else before_context
      if (file.exists(source)) {
        restored <- file.copy(source, context_file, overwrite = FALSE)
        if (isTRUE(restored)) break
      }
    }
    .rr_need(isTRUE(restored),
             "context.rds is missing and no recovery backup could restore it")
  }
  .rr_need(file.exists(context_file), "Missing interrupted context.rds")
  ctx <- readRDS(context_file)
  .rr_need(identical(.rr_norm(ctx$result_dir), .rr_norm(run_dir)),
           "context.rds result_dir mismatch")
  .rr_need(identical(as.character(ctx$models), names(expected_completed)) &&
             identical(names(expected_completed), names(expected_started)),
           "Expected-count model order differs from the calibration context")
  .rr_need(all(vapply(ctx$pools, nrow, integer(1)) == as.integer(request$num)),
           "Context pools do not contain exactly 500 candidates per model")
  .rr_need(.rr_numeric_equal(ctx$control$seed, request$seed, 0),
           "Context seed differs from request seed")
  get(".lw_verify_runtime", asNamespace("LakeEnsemblR"))(ctx)
  .rr_validate_pool_files(ctx)

  integrity_file <- file.path(run_dir, "context_integrity.csv")
  receipt_file <- file.path(attempt, "calibration_receipt.rds")
  if (file.exists(integrity_file)) {
    checked_ctx <- .rr_fun(R69, "r69_check_calibration_integrity")(run_dir)
    .rr_need(!is.null(checked_ctx$calibration_files),
             "Existing integrity record is not a completed calibration")
    summary <- .rr_read_csv(file.path(run_dir, "calibration_summary.csv"))
    script_sha <- .rr_sha(.rr_resume_source_file)
    evidence_dir <- .rr_new_evidence_dir(attempt)
    return(invisible(.rr_complete_receipt(CFG, R69, attempt, checked_ctx,
                                          request, summary, evidence_dir,
                                          script_sha)))
  }
  .rr_need(!file.exists(receipt_file) && !file.exists(paste0(receipt_file, ".sha256")),
           "A calibration receipt exists without a completed integrity record; inspect manually")

  prior_evidence <- .rr_valid_prior_evidence(attempt)
  evidence_dir <- .rr_new_evidence_dir(attempt)
  script_sha <- .rr_sha(.rr_resume_source_file)
  writeLines(c(paste0("script=", .rr_resume_source_file),
               paste0("script_sha256=", script_sha),
               paste0("LakeEnsemblR=", utils::packageVersion("LakeEnsemblR")),
               paste0("attempt=", attempt),
               paste0("started_UTC=", format(Sys.time(), "%Y-%m-%d %H:%M:%S", tz = "UTC"))),
             file.path(evidence_dir, "recovery_identity.txt"), useBytes = TRUE)

  before <- .rr_scan_candidates(ctx)
  .rr_write_evidence_csv(before$index, file.path(evidence_dir, "candidate_scan_before.csv"))
  observed_completed <- table(factor(
    before$index$model[before$index$state == "complete"], levels = ctx$models))
  observed_status <- table(factor(
    before$index$model[before$index$status_exists], levels = ctx$models))
  observed_started <- table(factor(
    before$index$model[before$index$directory_exists], levels = ctx$models))
  names(observed_completed) <- names(observed_status) <-
    names(observed_started) <- ctx$models
  current_manifest <- .rr_retained_manifest(ctx, before)
  .rr_write_evidence_csv(current_manifest,
                         file.path(evidence_dir, "retained_manifest_current.csv"))
  if (!length(prior_evidence)) {
    .rr_need(identical(as.integer(observed_status), as.integer(expected_completed)),
             "status.csv counts differ from the reported stopped run. Observed: ",
             paste(names(observed_status), observed_status, sep = "=", collapse = ", "))
    .rr_need(identical(as.integer(observed_started), as.integer(expected_started)),
             "Started counts differ from the reported stopped run. Observed: ",
             paste(names(observed_started), observed_started, sep = "=", collapse = ", "))
    locked_manifest <- current_manifest
  } else {
    prior_evidence <- sort(prior_evidence)
    locked_manifest <- .rr_read_csv(file.path(
      prior_evidence[[1L]], "locked_retained_manifest.csv"))
    .rr_verify_locked_manifest(ctx, locked_manifest)
    .rr_need(all(observed_started >= observed_completed) &&
               all(observed_started <= as.integer(request$num)),
             "Invalid candidate counts in repeated recovery")
  }
  .rr_write_evidence_csv(locked_manifest,
                         file.path(evidence_dir, "locked_retained_manifest.csv"))
  .rr_verify_locked_manifest(ctx, locked_manifest)

  incomplete <- before$index[before$index$state == "incomplete", , drop = FALSE]
  .rr_need(nrow(incomplete) == sum(observed_started - observed_completed),
           "Candidate scan has inconsistent incomplete-directory counts")
  missing_before_move <- before$index[before$index$state != "complete", , drop = FALSE]
  if (!isTRUE(execute_missing)) {
    .rr_write_evidence_csv(missing_before_move,
                           file.path(evidence_dir, "missing_to_execute.csv"))
    cat("RECOVERY_AUDIT_PASSED_NO_FILES_MOVED\nEvidence:\n", evidence_dir,
        "\nRetained validated candidates: ", sum(observed_completed),
        "\nCandidates still required: ", nrow(missing_before_move), "\n", sep = "")
    return(invisible(list(status = "audit_only", evidence_dir = evidence_dir,
                          missing = missing_before_move, attempt_dir = attempt)))
  }
  stale_work <- file.path(run_dir, "_work")
  if (dir.exists(stale_work)) {
    stale_target <- file.path(evidence_dir, "stale_work_before_resume")
    .rr_need(!file.exists(stale_target) && file.rename(stale_work, stale_target),
             "Could not preserve stale calibration _work directory")
    writeLines(c(paste0("original=", stale_work), paste0("archive=", stale_target)),
               file.path(evidence_dir, "stale_work_archive.txt"), useBytes = TRUE)
  }
  archive_root <- file.path(evidence_dir, "interrupted_candidates")
  archive_rows <- list()
  if (nrow(incomplete)) {
    for (i in seq_len(nrow(incomplete))) {
      source <- incomplete$directory[i]
      target <- file.path(archive_root, incomplete$model[i], incomplete$par_id[i])
      .rr_need(!file.exists(target), "Archive target already exists: ", target)
      target_parent <- dirname(target)
      .rr_need(dir.exists(target_parent) ||
                 dir.create(target_parent, recursive = TRUE, showWarnings = FALSE),
               "Could not create archive parent: ", dirname(target))
      .rr_need(file.rename(source, target),
               "Could not preserve interrupted candidate: ", source)
      archive_rows[[length(archive_rows) + 1L]] <- data.frame(
        model = incomplete$model[i], par_id = incomplete$par_id[i],
        original = source, archive = target, reason = incomplete$reason[i],
        stringsAsFactors = FALSE)
    }
  }
  archive_table <- if (length(archive_rows)) do.call(rbind, archive_rows) else
    data.frame(model = character(), par_id = character(), original = character(),
               archive = character(), reason = character())
  .rr_write_evidence_csv(archive_table, file.path(evidence_dir, "archive_manifest.csv"))

  after_archive <- .rr_scan_candidates(ctx)
  missing <- after_archive$index[after_archive$index$state == "missing", , drop = FALSE]
  .rr_need(nrow(missing) == 5L * as.integer(request$num) - sum(observed_completed),
           "Missing-candidate count changed unexpectedly after preservation")
  .rr_write_evidence_csv(missing, file.path(evidence_dir, "missing_to_execute.csv"))

  tolerance <- if (is.null(CFG$tolerance_celsius)) 1e-6 else
    suppressWarnings(as.numeric(CFG$tolerance_celsius))
  .rr_need(length(tolerance) == 1L && is.finite(tolerance) && tolerance >= 0,
           "Invalid CFG$tolerance_celsius")
  precheck <- if (is.null(precheck_runner)) {
    .rr_concurrency_precheck(ctx, before, ncores, evidence_dir, tolerance)
  } else {
    .rr_need(is.function(precheck_runner), "precheck_runner must be a function")
    precheck_runner(ctx, before, ncores, evidence_dir, tolerance)
  }
  .rr_need(is.data.frame(precheck) && nrow(precheck) == 50L &&
             all(precheck$passed %in% TRUE),
           "The five-model 10-concurrent replay precheck did not pass")

  tasks <- list()
  for (model in ctx$models) {
    pool <- ctx$pools[[model]]
    ids <- missing$par_id[missing$model == model]
    positions <- match(ids, as.character(pool$par_id))
    .rr_need(!anyNA(positions), "Missing candidate is absent from context pool: ", model)
    for (position in positions) {
      id <- as.character(pool$par_id[position])
      tasks[[length(tasks) + 1L]] <- list(
        model = model,
        spec = ctx$specs[[model]],
        pool = pool[position, , drop = FALSE],
        worker_id = paste0("resume_", model, "_", id))
    }
  }
  .rr_need(length(tasks) == nrow(missing), "Task construction count mismatch")

  if (!length(tasks)) {
    results <- list()
  } else if (is.null(worker_runner)) {
    results <- .rr_run_lb_tasks(tasks, ctx, ncores,
                                file.path(evidence_dir, "psock_workers.log"))
  } else {
    .rr_need(is.function(worker_runner), "worker_runner must be a function")
    results <- worker_runner(tasks, ctx, ncores, evidence_dir)
  }
  .rr_need(is.list(results) && length(results) == length(tasks),
           "Worker result count mismatch")

  completed <- .rr_scan_candidates(ctx)
  .rr_write_evidence_csv(completed$index, file.path(evidence_dir, "candidate_scan_after.csv"))
  .rr_verify_locked_manifest(ctx, locked_manifest)
  .rr_need(all(completed$index$state == "complete"),
           "Some candidates remain incomplete; rerun this recovery script. Evidence: ", evidence_dir)
  keys <- paste(completed$index$model, completed$index$par_id, sep = "/")
  .rr_need(length(completed$statuses) == 5L * as.integer(request$num) &&
             setequal(names(completed$statuses), keys),
           "Completed status set is not exactly the locked 2500-candidate pool")
  summary <- do.call(rbind, unname(completed$statuses))
  summary <- summary[order(match(summary$model, ctx$models), summary$par_id), , drop = FALSE]
  .rr_need(nrow(summary) == 5L * as.integer(request$num),
           "Recovered calibration summary row count is not 2500")
  best <- lapply(ctx$models, function(model) {
    part <- summary[summary$model == model & summary$status == "ok" &
                      is.finite(summary$objective), , drop = FALSE]
    .rr_need(nrow(part) > 0L, "All candidates failed for ", model)
    part[order(part$objective, part$par_id)[1L], , drop = FALSE]
  })
  best <- do.call(rbind, best)
  .rr_write_or_verify_package_csv(summary,
                                  file.path(run_dir, "calibration_summary.csv"),
                                  evidence_dir)
  .rr_write_or_verify_package_csv(best,
                                  file.path(run_dir, "best_by_calibration_RMSE.csv"),
                                  evidence_dir)

  recovery_run_dir <- file.path(run_dir, "recovery")
  .rr_need(identical(.rr_sha(.rr_resume_source_file), script_sha),
           "Recovery script changed while the recovery was running")
  .rr_copy_or_verify(.rr_resume_source_file,
                     file.path(recovery_run_dir,
                               "Resume_interrupted_calibration_9003_rev3.R"))
  .rr_copy_or_verify(file.path(evidence_dir, "locked_retained_manifest.csv"),
                     file.path(recovery_run_dir,
                               "locked_retained_manifest.csv"))
  replay_file <- file.path(evidence_dir, "five_model_10_concurrent_replay.csv")
  .rr_copy_or_verify(replay_file,
                     file.path(recovery_run_dir,
                               paste0(basename(evidence_dir), "_concurrency_replay.csv")))
  provenance <- data.frame(
    schema = "LER9003-interrupted-calibration-resume-v1",
    script_sha256 = script_sha,
    scheduler = "parallel::parLapplyLB; one candidate per task; chunk.size=1",
    ncores = ncores,
    request_signature = request$signature,
    live_signature = live_r69$signature,
    acceptance_signature = request$acceptance$signature,
    retained_validated_candidates = sum(observed_completed),
    newly_executed_candidates = length(tasks),
    concurrency_replay_candidates = nrow(precheck),
    external_evidence_directory = evidence_dir,
    completed_UTC = format(Sys.time(), "%Y-%m-%d %H:%M:%S", tz = "UTC"),
    stringsAsFactors = FALSE)
  .rr_write_or_verify_package_csv(
    provenance,
    file.path(recovery_run_dir,
              paste0(basename(evidence_dir), "_provenance.csv")),
    evidence_dir)

  manifest <- get(".lw_file_manifest", asNamespace("LakeEnsemblR"))(run_dir)
  manifest <- manifest[!grepl("^(_work|snapshot)/", manifest$file) &
                         manifest$file != "context.rds", , drop = FALSE]
  rownames(manifest) <- NULL
  ctx$calibration_files <- manifest
  .rr_atomic_context_replace(context_file, ctx, evidence_dir)
  integrity <- data.frame(file = "context.rds", sha256 = .rr_sha(context_file),
                          stringsAsFactors = FALSE)
  .rr_write_or_verify_package_csv(integrity, integrity_file, evidence_dir)
  checked_ctx <- .rr_fun(R69, "r69_check_calibration_integrity")(run_dir)
  .rr_need(identical(checked_ctx$calibration_files, manifest),
           "Final calibration manifest did not survive integrity verification")
  selected <- .rr_complete_receipt(CFG, R69, attempt, checked_ctx, request,
                                   summary, evidence_dir, script_sha)
  cat("INTERRUPTED_CALIBRATION_RECOVERED\n",
      "Lake: ", lake, "\n",
      "Retained completed candidates: ", sum(observed_completed), "\n",
      "Newly executed candidates: ", length(tasks), "\n",
      "Successful candidates: ", selected$success_count, "\n",
      "Failed candidates: ", selected$failure_count, "\n",
      "Evidence: ", evidence_dir, "\n",
      "NEXT: evaluate_recovered_lake_only(CFG, R69, \"", lake, "\")\n",
      sep = "")
  invisible(list(status = "complete", selected = selected,
                 evidence_dir = evidence_dir, summary = summary, best = best))
}

evaluate_recovered_lake_only <- function(CFG, R69, lake = "akesaiqin") {
  .rr_need(identical(as.character(utils::packageVersion("LakeEnsemblR")),
                     "1.2.9.9003"),
           "One-lake evaluation requires the unchanged 1.2.9.9003 environment")
  cfg <- CFG
  cfg$stage <- "research"
  row <- .rr_registry_row(cfg, R69, lake)
  live <- .rr_fun(R69, "r69_preflight")(cfg, row)
  .rr_need(isTRUE(live$passed), "One-lake live preflight failed: ",
           paste(live$issues, collapse = " | "))
  request_paths <- list.files(file.path(cfg$results_root, "lakes", lake, "attempts"),
                              pattern = "^request[.]rds$", recursive = TRUE,
                              full.names = TRUE)
  .rr_need(length(request_paths) >= 1L, "No sealed request exists for ", lake)
  request_paths <- sort(request_paths, decreasing = TRUE)
  request <- .rr_fun(R69, "r69_read_sealed")(request_paths[[1L]])
  .rr_need(identical(live$signature, request$signature),
           "One-lake live signature differs from the recovered request")
  result <- .rr_fun(R69, "r69_run_lake")(cfg, row, ctx = live)
  .rr_need(is.data.frame(result) && nrow(result) == 1L &&
             identical(as.character(result$calibration_status), "ok") &&
             identical(as.character(result$evaluation_status), "ok"),
           "Recovered lake evaluation did not complete")
  index_file <- file.path(cfg$results_root, "run_index.csv")
  index <- .rr_read_csv(index_file)
  position <- match(lake, index$name)
  .rr_need(length(position) == 1L && !is.na(position),
           "Recovered lake is absent from run_index.csv")
  backup_dir <- file.path(cfg$results_root, "one_lake_evaluation_backups")
  dir.create(backup_dir, recursive = TRUE, showWarnings = FALSE)
  backup <- file.path(backup_dir,
                      paste0("run_index_before_", lake, "_", .rr_stamp(), ".csv"))
  .rr_need(file.copy(index_file, backup, overwrite = FALSE),
           "Could not preserve run_index.csv before one-lake update")
  common <- intersect(names(index), names(result))
  index[position, common] <- result[1L, common, drop = FALSE]
  .rr_fun(R69, "r69_write_csv")(index, index_file)
  cat("RECOVERED_LAKE_EVALUATION_PASSED\nLake: ", lake,
      "\nrun_index backup: ", backup,
      "\nDo not call run_stage(\"research\") yet; use the load-balanced remaining-lakes handoff.\n",
      sep = "")
  invisible(result)
}

