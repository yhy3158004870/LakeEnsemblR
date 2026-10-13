# [LER-WINDOW NEW FILE BEGIN A001] Entire file added relative to official LER.
# No original model equations, engine binaries or output reader are replaced here.
# LakeEnsemblR window-calibration extension, 0.2.0
# Target: LakeEnsemblR 1.2.9 public API. GPL-2.0.
# This is research code, not an upstream-endorsed LakeEnsemblR release.
# All model engines and their physical equations remain unchanged.

.lw_version <- function() "0.2.0"
.lw_models <- function() c("FLake", "GLM", "GOTM", "Simstrat", "MyLake")
.lw_fail <- function(...) stop(..., call. = FALSE)
.lw_require_cols <- function(x, n, what) {
  if (!is.data.frame(x) || !all(n %in% names(x)))
    .lw_fail(what, " requires columns: ", paste(n, collapse = ", "))
  if (anyDuplicated(names(x))) .lw_fail(what, " has duplicate column names")
}
.lw_utc <- function(x, what = "datetime") {
  if (inherits(x, "POSIXt")) {
    ans <- as.POSIXct(as.numeric(x), origin = "1970-01-01", tz = "UTC")
  } else {
    if (!is.character(x)) .lw_fail(what, " must be UTC text or POSIXct; numeric/Date is not accepted")
    ans <- as.POSIXct(strptime(x, "%Y-%m-%d %H:%M:%S", tz = "UTC"))
    good <- !is.na(ans)
    if (any(!good) || any(format(ans[good], "%Y-%m-%d %H:%M:%S", tz = "UTC") != x[good]))
      .lw_fail(what, " must use exact UTC YYYY-mm-dd HH:MM:SS")
  }
  if (any(!is.finite(as.numeric(ans)))) .lw_fail(what, " contains invalid times")
  ans
}
.lw_fmt <- function(x) format(x, "%Y-%m-%d %H:%M:%S", tz = "UTC")
.lw_bool <- function(x, what) {
  if (is.logical(x) && !anyNA(x)) return(x)
  x <- toupper(as.character(x))
  if (anyNA(x) || any(!x %in% c("TRUE", "FALSE", "1", "0")))
    .lw_fail(what, " must contain TRUE/FALSE or 1/0; blanks are not approved")
  x %in% c("TRUE", "1")
}
.lw_num <- function(x, what) {
  # Numeric-looking strings are accepted when coming from CSV; factors are not.
  if (is.factor(x)) .lw_fail(what, " must not be a factor")
  z <- suppressWarnings(as.numeric(x))
  if (length(z) != length(x) || any(!is.finite(z))) .lw_fail(what, " must be finite numeric values")
  z
}
.lw_read_table <- function(x) {
  if (is.character(x) && length(x) == 1L) {
    if (!file.exists(x)) .lw_fail("File does not exist: ", x)
    return(utils::read.csv(x, stringsAsFactors = FALSE, check.names = FALSE))
  }
  x
}
.lw_write_csv <- function(x, path) {
  # Fail rather than silently overwriting a previous run/candidate.
  if (file.exists(path)) .lw_fail("Refusing to overwrite: ", path)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  for (nm in names(x)) if (inherits(x[[nm]], "POSIXt")) x[[nm]] <- .lw_fmt(x[[nm]])
  old <- options(digits = 17); on.exit(options(old), add = TRUE)
  utils::write.table(x, path, sep = ",", row.names = FALSE, col.names = TRUE,
                    quote = TRUE, na = "NA", fileEncoding = "UTF-8")
  invisible(path)
}
# [LER-WINDOW NEW SECTION A001] Reproducibility, canonical hashes and runtime checks
.lw_canonical_text <- function(x) {
  # deparse reads language/formals, excluding environments, bytecode and srcref.
  paste(enc2utf8(deparse(x, width.cutoff = 500L, control = c("keepInteger", "keepNA"))), collapse = "\n")
}
.lw_md5_object <- function(x) {
  # Kept for compatibility with the original internal tests. Never serialize ASTs.
  digest::digest(.lw_canonical_text(x), algo = "md5", serialize = FALSE)
}
.lw_function_hash <- function(fun) {
  if (!is.function(fun)) .lw_fail("A runtime fingerprint requires a function")
  digest::digest(paste(.lw_canonical_text(formals(fun)), .lw_canonical_text(body(fun)), sep = "\n"),
                 algo = "sha256", serialize = FALSE)
}
.lw_sha256_file <- function(path) {
  if (!file.exists(path) || dir.exists(path)) .lw_fail("Missing audit file: ", path)
  digest::digest(file = path, algo = "sha256", serialize = FALSE)
}
.lw_file_manifest <- function(root) {
  if (!dir.exists(root)) .lw_fail("Missing audit directory: ", root)
  files <- sort(list.files(root, recursive = TRUE, full.names = FALSE,
                           all.files = TRUE, no.. = TRUE))
  full <- file.path(root, files)
  links <- Sys.readlink(full)
  if (any(!is.na(links) & nzchar(links))) .lw_fail("Symlink in reproducibility inputs: ", root)
  data.frame(file = files, bytes = as.numeric(file.info(full)$size),
             sha256 = vapply(full, .lw_sha256_file, character(1)), stringsAsFactors = FALSE,
             row.names = NULL)
}
.lw_check_manifest <- function(root, recorded, what) {
  current <- .lw_file_manifest(root)
  if (!identical(current, recorded))
    .lw_fail(what, " changed since calibration; restore the recorded inputs/build before rerun")
  invisible(TRUE)
}
.lw_seed <- function(seed, model, par_id) {
  seed <- .lw_num(seed, "seed")
  if (length(seed) != 1L || seed < 1 || seed > .Machine$integer.max || seed != floor(seed))
    .lw_fail("seed must be a positive R integer")
  token <- paste(seed, as.character(model), as.character(par_id), sep = "|")
  as.integer(strtoi(substr(digest::digest(token, algo = "sha256", serialize = FALSE), 1L, 7L), 16L) + 1L)
}
.lw_with_seed <- function(seed, code) {
  had_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  if (had_seed) old_seed <- get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  old_kind <- RNGkind()
  on.exit({
    do.call(RNGkind, as.list(old_kind))
    if (had_seed) assign(".Random.seed", old_seed, envir = .GlobalEnv)
    else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE))
      rm(".Random.seed", envir = .GlobalEnv)
  }, add = TRUE)
  RNGkind("Mersenne-Twister", "Inversion", "Rejection")
  set.seed(seed)
  force(code)
}
.lw_initialize_runtime <- function(paths = .libPaths()) {
  .libPaths(paths)
  # Original LER export functions use unqualified lazy-data dictionaries. Loading
  # only the namespace is insufficient on clean Windows PSOCK workers.
  suppressPackageStartupMessages(library("LakeEnsemblR", character.only = TRUE))
  for (nm in c("lake_var_dic", "met_var_dic", "var_names_dic", "pars_dic")) {
    if (!exists(nm, envir = as.environment("package:LakeEnsemblR"), inherits = FALSE))
      .lw_fail("LakeEnsemblR package data are unavailable: ", nm)
  }
  invisible(TRUE)
}
.lw_package_state <- function(packages) {
  ip <- utils::installed.packages()
  # Respect .libPaths precedence when more than one library has a package.
  ip <- ip[!duplicated(rownames(ip)), , drop = FALSE]
  present <- packages[packages %in% rownames(ip)]
  deps <- tools::package_dependencies(present, db = ip,
    which = c("Depends", "Imports", "LinkingTo"), recursive = TRUE)
  packages <- sort(unique(c(packages, unlist(deps, use.names = FALSE))))
  packages <- packages[packages != "R"]
  # Base and recommended libraries are covered by the exact R build declaration.
  keep <- !(packages %in% rownames(ip) & !is.na(ip[match(packages, rownames(ip)), "Priority"]))
  packages <- packages[keep]
  manifests <- list()
  rows <- lapply(packages, function(p) {
    if (!requireNamespace(p, quietly = TRUE))
      return(data.frame(package = p, version = "NOT_INSTALLED", remote_sha = "", build_sha256 = ""))
    d <- utils::packageDescription(p)
    root <- find.package(p)
    manifests[[p]] <<- .lw_file_manifest(root)
    data.frame(package = p, version = as.character(d$Version),
      remote_sha = if (is.null(d$RemoteSha)) "UNRECORDED" else as.character(d$RemoteSha),
      build_sha256 = digest::digest(.lw_canonical_text(manifests[[p]]), algo = "sha256", serialize = FALSE))
  })
  glm_path <- Sys.getenv("GLM_PATH", unset = "")
  external <- if (nzchar(glm_path)) list(GLM_PATH = normalizePath(glm_path, winslash = "/", mustWork = TRUE),
                                       sha256 = .lw_sha256_file(glm_path)) else list()
  list(packages = do.call(rbind, rows), files = manifests, external = external,
       R = list(version = R.version$version.string, platform = R.version$platform,
                arch = R.version$arch, os = R.version$os))
}
.lw_verify_runtime <- function(ctx) {
  live_hash <- vapply(names(ctx$metadata$function_hashes), function(n)
    .lw_function_hash(get(n, asNamespace("LakeEnsemblR"))), character(1))
  if (!identical(live_hash, ctx$metadata$function_hashes))
    .lw_fail("Runtime source changed since calibration; restore the recorded package before rerun")
  live <- .lw_package_state(ctx$metadata$package_manifest$package)
  recorded <- list(packages = ctx$metadata$package_manifest,
                   files = ctx$metadata$package_files, external = ctx$metadata$external_engines, R = ctx$metadata$R)
  if (!identical(live, recorded))
    .lw_fail("R or dependency commit/build changed since calibration; restore the recorded environment")
  .lw_check_manifest(ctx$snapshot, ctx$metadata$snapshot_files, "Input/configuration snapshot")
  invisible(TRUE)
}

#' Make explicit MOD11A2 calendar windows; never infer them from a midpoint.
#' @export
# [LER-WINDOW NEW SECTION A001] MODIS calendar and observation/contract validation
ler_modis_windows <- function(year, doy) {
  year <- .lw_num(year, "year"); doy <- .lw_num(doy, "doy")
  if (length(year) != length(doy) || any(year != floor(year)) || any(year < 1900 | year > 2200) ||
      any(doy != floor(doy)) || any(!doy %in% seq(1, 361, 8)))
    .lw_fail("Use equal-length year and DOY vectors; DOY must be 1,9,...,361")
  a <- .lw_utc(sprintf("%04d-01-01 00:00:00", as.integer(year))) + (doy - 1) * 86400
  y1 <- .lw_utc(sprintf("%04d-01-01 00:00:00", as.integer(year + 1)))
  b <- as.POSIXct(pmin(as.numeric(a) + 8 * 86400, as.numeric(y1)), origin = "1970-01-01", tz = "UTC")
  data.frame(window_id = sprintf("%04d_%03d", as.integer(year), as.integer(doy)),
             window_start = a, window_end = b,
             label_datetime = a + as.numeric(difftime(b, a, units = "secs")) / 2,
             stringsAsFactors = FALSE)
}

.lw_windows <- function(x) {
  x <- .lw_read_table(x)
  .lw_require_cols(x, c("window_id", "window_start", "window_end", "observed",
                       "split", "use", "ice_free", "qc_pass"), "windows")
  if (!nrow(x)) .lw_fail("No windows supplied")
  x$window_id <- as.character(x$window_id)
  if (anyNA(x$window_id) || any(!nzchar(x$window_id)) || anyDuplicated(x$window_id))
    .lw_fail("window_id must be nonempty and unique within one lake")
  x$window_start <- .lw_utc(x$window_start, "window_start")
  x$window_end <- .lw_utc(x$window_end, "window_end")
  if (any(x$window_end <= x$window_start)) .lw_fail("Every window must have positive duration")
  x$split <- as.character(x$split)
  if (anyNA(x$split) || any(!nzchar(x$split))) .lw_fail("Every window needs a split label")
  for (nm in c("use", "ice_free", "qc_pass")) x[[nm]] <- .lw_bool(x[[nm]], nm)
  if ("Depth_meter" %in% names(x) && any(.lw_num(x$Depth_meter, "Depth_meter") != 0))
    .lw_fail("This extension is LSWT-only: observation Depth_meter must be 0")
  # Excluded records may retain NA observations for provenance.
  if (is.factor(x$observed)) .lw_fail("observed must not be a factor")
  x$observed <- suppressWarnings(as.numeric(x$observed))
  if (any(x$use & (!x$ice_free | !x$qc_pass | !is.finite(x$observed))))
    .lw_fail("Every use=TRUE record must be explicitly ice_free, qc_pass, and finite")
  x <- x[order(x$window_start, x$window_end, x$window_id), , drop = FALSE]
  z <- x[x$use, , drop = FALSE]
  if (nrow(z) > 1L && any(as.numeric(z$window_start[-1L]) <
                         cummax(as.numeric(z$window_end))[-nrow(z)]))
    .lw_fail("Approved windows overlap (including overlaps between calibration and validation)")
  rownames(x) <- NULL
  x
}
.lw_select <- function(w, split, allowed_start, allowed_end) {
  a <- .lw_utc(allowed_start); b <- .lw_utc(allowed_end)
  if (length(a) != 1L || length(b) != 1L || a >= b) .lw_fail("Invalid allowed time range")
  take <- w$use & w$split == split
  ans <- w[take, , drop = FALSE]
  if (!nrow(ans)) .lw_fail("No approved windows for split: ", split)
  # Do not silently remove a requested cross-spinup / out-of-range window.
  bad <- ans$window_start < a | ans$window_end > b
  if (any(bad)) .lw_fail("Approved windows cross spin-up/simulation boundaries: ",
                        paste(ans$window_id[bad], collapse = ", "))
  ans
}

.lw_contracts <- function(x, models, require_confirmed = TRUE) {
  x <- .lw_read_table(x)
  .lw_require_cols(x, c("model", "method", "step_seconds", "phase_seconds", "label_position",
                       "timestamp_shift_seconds", "temperature_column", "confirmed", "meaning"), "contracts")
  x$model <- as.character(x$model)
  if (anyDuplicated(x$model) || any(!x$model %in% .lw_models()) || !all(models %in% x$model))
    .lw_fail("One contract row per model is required")
  x <- x[match(models, x$model), , drop = FALSE]
  for (nm in c("step_seconds", "phase_seconds", "timestamp_shift_seconds")) x[[nm]] <- .lw_num(x[[nm]], nm)
  if (any(x$step_seconds <= 0 | x$step_seconds > 86400 | x$step_seconds != floor(x$step_seconds)))
    .lw_fail("step_seconds must be a whole number of seconds in (0,86400]")
  if (any(x$phase_seconds < 0 | x$phase_seconds >= x$step_seconds))
    .lw_fail("phase_seconds must be in [0, step_seconds)")
  if (any(!x$method %in% c("sample_mean", "linear_time_mean", "interval_mean")))
    .lw_fail("Unknown aggregation method")
  if (any(!x$label_position %in% c("point", "start", "center", "end")))
    .lw_fail("Unknown label_position")
  if (any(x$method == "interval_mean" & x$label_position == "point") ||
      any(x$method != "interval_mean" & x$label_position != "point"))
    .lw_fail("interval_mean requires start/center/end; other methods require point")
  x$confirmed <- .lw_bool(x$confirmed, "confirmed")
  if (require_confirmed && any(!x$confirmed)) .lw_fail("Output time semantics are not yet confirmed for: ",
                                                   paste(x$model[!x$confirmed], collapse = ", "))
  if (anyNA(x$meaning) || any(!nzchar(trimws(x$meaning)))) .lw_fail("Document every output's physical time meaning")
  if (anyNA(x$temperature_column) || any(!nzchar(x$temperature_column))) .lw_fail("An explicit temperature_column is required")
  if (any(x$model == "MyLake" & (x$step_seconds != 86400 | x$method != "sample_mean")))
    .lw_fail("MyLake support here is daily_state sample_mean, not reconstructed subdaily temperature")
  x
}
.lw_contract <- function(x) {
  if (!is.data.frame(x) || nrow(x) != 1L) .lw_fail("Supply one model's contract row")
  .lw_contracts(x, as.character(x$model), require_confirmed = FALSE)
}

#' Aggregate a complete surface time series over explicit half-open windows.
#' Input series: datetime, temperature. No temporal extrapolation or NA deletion.
#' @export
# [LER-WINDOW NEW SECTION A001] Window observation operators and complete coverage checks
ler_window_predict <- function(series, windows, contract) {
  .lw_require_cols(series, c("datetime", "temperature"), "series")
  .lw_require_cols(windows, c("window_id", "window_start", "window_end"), "windows")
  c <- .lw_contract(contract)
  t <- as.numeric(.lw_utc(series$datetime)) + c$timestamp_shift_seconds
  if (is.factor(series$temperature)) .lw_fail("series.temperature must not be a factor")
  y <- suppressWarnings(as.numeric(series$temperature))
  if (length(t) < 2L || anyDuplicated(t) || any(diff(t) <= 0))
    .lw_fail("Native output timestamps must be unique and strictly increasing")
  dt <- c$step_seconds; phase <- c$phase_seconds; tol <- 1e-3
  # phase is relative to the UTC Unix epoch, not to the first (possibly missing) row.
  grid_error <- abs((t - phase) / dt - round((t - phase) / dt)) * dt
  if (any(grid_error > tol)) .lw_fail("Native output is off the declared UTC grid; inspect timestamps/contract")
  # Only sub-millisecond numerical clock roundoff is snapped, never a missing time step.
  t <- phase + round((t - phase) / dt) * dt
  if (anyDuplicated(t) || any(diff(t) <= 0)) .lw_fail("Duplicate times after sub-millisecond grid snapping")
  a <- as.numeric(.lw_utc(windows$window_start)); b <- as.numeric(.lw_utc(windows$window_end))
  if (!length(a) || any(b <= a)) .lw_fail("Empty or invalid windows")
  ans <- windows[, c("window_id", "window_start", "window_end"), drop = FALSE]
  ans$predicted <- NA_real_; ans$n_expected <- NA_integer_; ans$n_used <- NA_integer_
  ans$duration_seconds <- b - a
  for (k in seq_along(a)) {
    fail <- function(msg) .lw_fail("Window ", windows$window_id[k], ": ", msg)
    if (c$method == "sample_mean") {
      # Regular-grid point-sample mean; NOT claimed to be an exact time integral.
      n <- (b[k] - a[k]) / dt
      if (abs(n - round(n)) > 1e-8) fail("sample_mean needs an integer number of intervals")
      first <- phase + ceiling((a[k] - phase) / dt - tol / dt) * dt
      expected <- first + seq.int(0L, as.integer(round(n)) - 1L) * dt
      ii <- which(t >= a[k] - tol & t < b[k] - tol)
      if (length(ii) != length(expected) || any(abs(t[ii] - expected) > tol))
        fail("missing or extra point samples; partial-window means are forbidden")
      if (any(!is.finite(y[ii]))) fail("nonfinite temperature in required samples")
      ans$predicted[k] <- mean(y[ii]); ans$n_expected[k] <- length(expected); ans$n_used[k] <- length(ii)
    } else if (c$method == "linear_time_mean") {
      # Exact integration of the piecewise-linear interpolant. Both boundaries bracketed.
      lo <- which(t <= a[k] + tol); hi <- which(t >= b[k] - tol)
      if (!length(lo) || !length(hi)) fail("endpoints not bracketed; extrapolation forbidden")
      left <- max(lo); right <- min(hi)
      if (left >= right) fail("insufficient bracket points")
      ii <- seq.int(left, right)
      if (any(abs(diff(t[ii]) - dt) > tol)) fail("missing timestamps in integration support")
      if (any(!is.finite(y[ii]))) fail("nonfinite temperature in integration support")
      knots <- sort(unique(c(a[k], t[ii][t[ii] > a[k] & t[ii] < b[k]], b[k])))
      yy <- stats::approx(t[ii], y[ii], xout = knots, method = "linear", rule = 1, ties = "ordered")$y
      if (any(!is.finite(yy))) fail("boundary interpolation failed")
      ans$predicted[k] <- sum(diff(knots) * (head(yy, -1) + tail(yy, -1)) / 2) / (b[k] - a[k])
      ans$n_expected[k] <- as.integer(round((t[right] - t[left]) / dt)) + 1L
      ans$n_used[k] <- length(ii)
    } else {
      # Interval means are weighted by overlap duration, never interpolated as point states.
      offset <- switch(as.character(c$label_position), start = 0, center = dt / 2, end = dt)
      s <- t - offset; e <- s + dt
      ii <- which(e > a[k] + tol & s < b[k] - tol)
      if (!length(ii)) fail("no interval support")
      if (s[ii[1]] > a[k] + tol || e[tail(ii, 1)] < b[k] - tol ||
          (length(ii) > 1L && any(abs(diff(s[ii]) - dt) > tol)))
        fail("interval coverage has a gap")
      if (any(!is.finite(y[ii]))) fail("nonfinite interval mean")
      w <- pmin(e[ii], b[k]) - pmax(s[ii], a[k])
      if (abs(sum(w) - (b[k] - a[k])) > tol) fail("interval duration does not cover full window")
      ans$predicted[k] <- sum(w * y[ii]) / sum(w)
      ans$n_expected[k] <- length(ii); ans$n_used[k] <- length(ii)
    }
  }
  ans$method <- as.character(c$method); ans$model <- as.character(c$model)
  ans$step_seconds <- dt
  ans
}

.lw_metrics <- function(O, P) {
  if (!length(O) || length(O) != length(P) || any(!is.finite(O)) || any(!is.finite(P)))
    .lw_fail("Scoring needs equal nonempty finite vectors; no na.rm is permitted")
  e <- P - O; vo <- sum((O - mean(O))^2); vp <- sum((P - mean(P))^2)
  data.frame(N = length(O), RMSE = sqrt(mean(e^2)), MAE = mean(abs(e)), bias = mean(e),
             NSE = if (vo > 0) 1 - sum(e^2) / vo else NA_real_,
             r = if (vo > 0 && vp > 0) sum((O - mean(O)) * (P - mean(P))) / sqrt(vo * vp) else NA_real_)
}
#' Same scoring function for every LHC run and every final evaluation.
#' @export
# [LER-WINDOW NEW SECTION A001] Window error metrics
calc_fit_window <- function(series, windows, contract) {
  .lw_require_cols(windows, "observed", "windows")
  O <- .lw_num(windows$observed, "observed")
  pairs <- ler_window_predict(series, windows, contract)
  pairs$observed <- O
  pairs$residual <- pairs$predicted - O
  list(pairs = pairs, metrics = .lw_metrics(O, pairs$predicted))
}

#' Explicit configuration object for cali_ensemble(window = ...).
#' @export
# [LER-WINDOW NEW SECTION A001] Public control object and parameter sampling
ler_window_control <- function(windows, contracts, seed = 20261004L,
                               calibration_split = "calibration",
                               validation_split = "validation", save_series = TRUE,
                               allow_constant_Kw_override = FALSE) {
  if (length(seed) != 1L || !is.finite(seed) || seed != floor(seed) || seed < 1 || seed > .Machine$integer.max)
    .lw_fail("seed must be a positive R integer")
  if (length(calibration_split) != 1L || length(validation_split) != 1L ||
      is.na(calibration_split) || is.na(validation_split) ||
      !nzchar(calibration_split) || !nzchar(validation_split) ||
      identical(calibration_split, validation_split))
    .lw_fail("Calibration and validation need two different nonempty split names")
  if (!is.logical(save_series) || length(save_series) != 1L || is.na(save_series) ||
      !is.logical(allow_constant_Kw_override) || length(allow_constant_Kw_override) != 1L ||
      is.na(allow_constant_Kw_override)) .lw_fail("save_series and allow_constant_Kw_override must be scalar logical values")
  list(windows = .lw_windows(windows), contracts = .lw_read_table(contracts),
       seed = as.integer(seed), calibration_split = calibration_split,
       validation_split = validation_split, save_series = isTRUE(save_series),
       allow_constant_Kw_override = isTRUE(allow_constant_Kw_override), extension_version = .lw_version())
}

.lw_specs <- function(cfg, model) {
  out <- list()
  add <- function(section, type) {
    if (is.null(section) || !length(section)) return(invisible(NULL))
    for (nm in names(section)) {
      z <- section[[nm]]
      if (!is.list(z) || !all(c("lower", "upper", "initial", "log") %in% names(z)))
        .lw_fail("Invalid calibration definition: ", model, "/", nm, "; use flat slash-separated model keys")
      nums <- .lw_num(c(z$lower, z$upper, z$initial), paste(model, nm))
      if (length(nums) != 3L || nums[1] >= nums[2] || nums[3] < nums[1] || nums[3] > nums[2])
        .lw_fail("Invalid bounds/initial value for ", nm)
      lg <- .lw_bool(z$log, paste(nm, "log"))
      if (length(lg) != 1L || (lg && nums[1] <= 0)) .lw_fail("Log sampling requires a positive lower bound")
      out[[length(out) + 1L]] <<- data.frame(name = nm, type = type, lower = nums[1], upper = nums[2],
                                          initial = nums[3], log = lg, stringsAsFactors = FALSE)
    }
  }
  cal <- cfg$calibration
  if (is.null(cal)) .lw_fail("Missing YAML calibration section")
  add(cal$met, "met")
  if (!is.null(cal$Kw)) add(list(Kw = cal$Kw), "kw")
  add(cal[[model]], "model")
  if (!length(out)) .lw_fail("No calibration parameters for ", model)
  x <- do.call(rbind, out)
  if (anyDuplicated(x$name) || any(x$name == "par_id")) .lw_fail("Parameter names must be unique; par_id is reserved")
  if (any(x$type == "kw" & x$lower <= 0)) .lw_fail("Kw is an absolute positive extinction coefficient (m^-1)")
  if (any(x$type == "met" & !x$name %in% c("wind_speed", "swr")))
    .lw_fail("This version supports wind_speed/swr calibration plus Kw and native model parameters; other forcing keys require a separately audited adapter")
  x
}

# Base-R randomized Latin hypercube. Every marginal stratum is sampled once.
.lw_lhc <- function(spec, n, seed) {
  if (length(n) != 1L || !is.finite(n) || n != floor(n) || n < 1) .lw_fail("num must be a positive integer")
  .lw_with_seed(seed, {
  p <- matrix(NA_real_, nrow = n, ncol = nrow(spec))
  for (j in seq_len(nrow(spec))) {
    u <- (sample.int(n) - 1 + stats::runif(n)) / n
    a <- spec$lower[j]; b <- spec$upper[j]
    if (spec$log[j]) p[, j] <- 10^(log10(a) + u * (log10(b) - log10(a)))
    else p[, j] <- a + u * (b - a)
  }
  p <- as.data.frame(p); names(p) <- spec$name
  p$par_id <- sprintf("p%07d", seq_len(n))
  p
  })
}
.lw_parameter_pool <- function(x, spec) {
  x <- .lw_read_table(x)
  .lw_require_cols(x, c(spec$name, "par_id"), "parameter pool")
  if (!setequal(names(x), c(spec$name, "par_id"))) .lw_fail("Unexpected parameter-pool columns")
  x <- x[, c(spec$name, "par_id"), drop = FALSE]
  x$par_id <- as.character(x$par_id)
  if (!nrow(x) || anyNA(x$par_id) || anyDuplicated(x$par_id) ||
      any(!grepl("^[A-Za-z0-9_-]+$", x$par_id))) .lw_fail("par_id must be unique and file-name safe")
  for (j in seq_len(nrow(spec))) {
    z <- .lw_num(x[[spec$name[j]]], spec$name[j])
    if (any(z < spec$lower[j] | z > spec$upper[j])) .lw_fail("Parameter outside declared bounds: ", spec$name[j])
    x[[spec$name[j]]] <- z
  }
  x
}

# [LER-WINDOW NEW SECTION A001] Legacy-compatible YAML and immutable input snapshot
.lw_read_config <- function(path) {
  if (!requireNamespace("configr", quietly = TRUE)) .lw_fail("Install configr and LakeEnsemblR dependencies first")
  configr::read.config(path)
}
.lw_write_config <- function(cfg, path) {
  # gotmtools 0.x is a text reader: exactly three spaces, unquoted booleans,
  # double-quoted NULL file markers, and indented block sequences are required.
  # yaml::as.yaml emits yes/no and single quotes, which that reader misinterprets.
  normalize <- function(x) {
    if (!is.list(x)) return(x)
    for (nm in names(x)) {
      if (nm == "file" && (is.null(x[[nm]]) || identical(x[[nm]], "")))
        x[nm] <- list("NULL")
      else if (is.list(x[[nm]])) x[nm] <- list(normalize(x[[nm]]))
    }
    x
  }
  cfg <- normalize(cfg)
  for (sec in c("temperature", "ice_height", "water_level")) {
    if (is.null(cfg$observations[[sec]])) cfg$observations[[sec]] <- list(file = "NULL")
    if (is.null(cfg$observations[[sec]]$file)) cfg$observations[[sec]]$file <- "NULL"
  }
  scalar <- function(x) {
    if (is.null(x)) return("~")
    if (length(x) != 1L || is.na(x)) .lw_fail("YAML scalar must be finite/nonmissing")
    if (is.logical(x)) return(if (x) "true" else "false")
    if (is.numeric(x)) {
      if (!is.finite(x)) .lw_fail("YAML numeric values must be finite")
      value <- format(x, digits = 17L, scientific = NA, trim = TRUE)
      # YAML 1.1 needs a decimal mantissa to decode scientific notation as numeric.
      return(sub("^(-?[0-9]+)(e[+-][0-9]+)$", "\\1.0\\2", value))
    }
    if (!is.character(x)) .lw_fail("Unsupported YAML value class: ", class(x)[1L])
    # Plain timestamps are necessary for the legacy gotmtools reader. Otherwise
    # emit double quotes only when needed for an unambiguous YAML string type.
    if (grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$", x)) return(x)
    plain <- grepl("^[A-Za-z_][A-Za-z0-9_./-]*$", x) &&
      !tolower(x) %in% c("null", "true", "false", "yes", "no", "on", "off", ".nan", ".inf")
    if (plain) return(x)
    x <- gsub("\\", "\\\\", x, fixed = TRUE)
    x <- gsub('"', '\\"', x, fixed = TRUE)
    x <- gsub("\n", "\\n", x, fixed = TRUE)
    x <- gsub("\r", "\\r", x, fixed = TRUE)
    x <- gsub("\t", "\\t", x, fixed = TRUE)
    paste0('"', enc2utf8(x), '"')
  }
  lines <- character()
  emit <- function(x, indent) {
    pad <- paste(rep(" ", indent), collapse = "")
    mapping <- is.list(x) && length(x) && !is.null(names(x))
    if (mapping) {
      if (anyNA(names(x)) || any(!nzchar(names(x))) || anyDuplicated(names(x)))
        .lw_fail("YAML mapping names must be unique and nonempty")
      for (nm in names(x)) {
        # Master-YAML keys, including canonical parameter slash keys, need no quotes.
        if (!grepl("^[A-Za-z_][A-Za-z0-9_./-]*$", nm)) .lw_fail("Unsupported YAML key: ", nm)
        value <- x[[nm]]
        complex <- (is.list(value) && length(value)) || (!is.list(value) && length(value) > 1L)
        if (complex) { lines <<- c(lines, paste0(pad, nm, ":")); emit(value, indent + 3L) }
        else lines <<- c(lines, paste0(pad, nm, ": ",
          if (is.list(value) && !length(value)) "{}" else scalar(value)))
      }
    } else {
      for (value in x) {
        if (is.list(value) || length(value) != 1L) .lw_fail("Nested YAML sequence objects are not supported by LakeEnsemblR's reader")
        lines <<- c(lines, paste0(pad, "- ", scalar(value)))
      }
    }
  }
  emit(cfg, 0L)
  writeLines(lines, path, useBytes = TRUE)
  # Verify YAML decoding before any engine is allowed to consume this configuration.
  reread <- .lw_read_config(path)
  same <- function(a, b) {
    if (is.null(a) || is.null(b)) return(is.null(a) && is.null(b))
    if (is.list(a) || is.list(b)) {
      # yaml may decode a homogeneous sequence as an atomic vector and a mixed
      # integer/double sequence as an unnamed list. These carry the same values.
      if (is.list(a) && is.null(names(a)) && !is.list(b) && length(a) == length(b)) b <- as.list(b)
      if (is.list(b) && is.null(names(b)) && !is.list(a) && length(a) == length(b)) a <- as.list(a)
      if (!is.list(a) || !is.list(b) || !identical(names(a), names(b)) || length(a) != length(b)) return(FALSE)
      return(all(vapply(seq_along(a), function(i) same(a[[i]], b[[i]]), logical(1))))
    }
    isTRUE(all.equal(a, b, check.attributes = FALSE, tolerance = 0))
  }
  if (!same(cfg, reread)) .lw_fail("Master YAML serialization failed semantic round-trip verification: ", path)
  invisible(path)
}
.lw_check_legacy_yaml <- function(cfg, path, models) {
  # A valid YAML parser round-trip is necessary but not sufficient: upstream
  # exporters also call gotmtools' legacy text reader. Check the fields they use
  # before invoking an engine; reject silent truncation/coercion of a user value.
  groups <- list(location = cfg$location, time = cfg$time,
    config_files = cfg$config_files[models], output = cfg$output,
    temperature = cfg$observations$temperature, ice_height = cfg$observations$ice_height,
    water_level = cfg$observations$water_level, init_temp_profile = cfg$input$init_temp_profile,
    meteo = cfg$input$meteo, ice = cfg$input$ice, inflows = cfg$inflows, outflows = cfg$outflows)
  for (label in names(groups)) {
    section <- groups[[label]]
    if (is.null(section)) next
    for (key in names(section)) {
      expected <- section[[key]]
      if (is.null(expected) || is.list(expected)) next
      actual <- tryCatch(gotmtools::get_yaml_value(path, label, key), error = identity)
      if (inherits(actual, "error") || !isTRUE(all.equal(expected, actual, check.attributes = FALSE, tolerance = 0)))
        .lw_fail("Master YAML field ", label, "/", key,
          " cannot be read faithfully by the upstream gotmtools text reader. ",
          "Use a simple label/value; input paths are normalized automatically in the snapshot.")
    }
  }
  invisible(TRUE)
}
.lw_copy_tree <- function(from, to, exclude_top = character()) {
  if (!dir.exists(from)) .lw_fail("Missing directory: ", from)
  dir.create(to, recursive = TRUE, showWarnings = FALSE)
  fs <- list.files(from, all.files = TRUE, recursive = TRUE, full.names = FALSE,
                   include.dirs = TRUE, no.. = TRUE)
  fs <- fs[!vapply(strsplit(fs, "/", fixed = TRUE), function(z) z[1] %in% exclude_top, logical(1))]
  if (!length(fs)) return(invisible(to))
  for (rel in fs) {
    src <- file.path(from, rel); dst <- file.path(to, rel)
    link <- Sys.readlink(src)
    if (!is.na(link) && nzchar(link)) .lw_fail("Symlinks are not supported in model cases: ", src)
    if (dir.exists(src)) dir.create(dst, recursive = TRUE, showWarnings = FALSE)
    else {
      dir.create(dirname(dst), recursive = TRUE, showWarnings = FALSE)
      if (!file.copy(src, dst, overwrite = TRUE, copy.mode = TRUE)) .lw_fail("Copy failed: ", src)
    }
  }
  invisible(to)
}
.lw_snapshot <- function(folder, config_file, dest, models) {
  src <- normalizePath(folder, winslash = "/", mustWork = TRUE)
  if (basename(config_file) != config_file) .lw_fail("config_file must be a basename in folder")
  cfg_path <- file.path(src, config_file)
  cfg <- .lw_read_config(cfg_path)
  if (!all(c("time", "input", "output", "config_files", "location") %in% names(cfg)))
    .lw_fail("Expected the LakeEnsemblR 1.2.9 master YAML schema")
  if (is.null(cfg$input$init_temp_profile$file) || !nzchar(cfg$input$init_temp_profile$file) ||
      cfg$input$init_temp_profile$file == "NULL")
    .lw_fail("Provide an explicit initial profile: MODIS window LSWT is not an initial depth profile")
  if (dir.exists(dest)) .lw_fail("Snapshot directory already exists: ", dest)
  dir.create(dest, recursive = TRUE); dir.create(file.path(dest, "_inputs"))
  counter <- 0L; manifest <- list()
  cp <- function(v, key, required = FALSE) {
    if (is.null(v) || (is.character(v) && length(v) == 1L && v %in% c("", "NULL"))) {
      if (required) .lw_fail("Required input missing: ", key)
      return(v)
    }
    if (!is.character(v) || length(v) != 1L) .lw_fail("Expected input filename at ", key)
    # Resolve relative to the source project, never the caller's arbitrary working directory.
    p <- if (grepl("^(/|[A-Za-z]:[/\\\\])", v)) v else file.path(src, v)
    if (!file.exists(p) || dir.exists(p)) .lw_fail("Missing input at ", key, ": ", p)
    p <- normalizePath(p, winslash = "/", mustWork = TRUE)
    counter <<- counter + 1L
    ext <- tools::file_ext(p)
    if (!grepl("^[A-Za-z0-9]*$", ext)) ext <- "dat"
    rel <- file.path("_inputs", paste0(sprintf("%04d_input", counter), if (nzchar(ext)) paste0(".", ext) else ""))
    if (!file.copy(p, file.path(dest, rel))) .lw_fail("Could not copy input: ", p)
    manifest[[length(manifest) + 1L]] <<- data.frame(key = key, source = p, snapshot = rel,
                                                   sha256 = .lw_sha256_file(p), stringsAsFactors = FALSE)
    rel
  }
  cfg$location$hypsograph <- cp(cfg$location$hypsograph, "location.hypsograph", TRUE)
  # All file fields under input and observations are copied. Kw can be a file or numeric value.
  walk <- function(x, prefix) {
    if (!is.list(x)) return(x)
    for (nm in names(x)) {
      if (nm == "file") x[nm] <- list(cp(x[[nm]], paste(prefix, nm, sep = ".")))
      else if (is.list(x[[nm]])) x[[nm]] <- walk(x[[nm]], paste(prefix, nm, sep = "."))
    }
    x
  }
  cfg$input <- walk(cfg$input, "input")
  cfg$observations <- walk(cfg$observations, "observations")
  for (sec in c("inflows", "outflows")) if (!is.null(cfg[[sec]]$file))
    cfg[[sec]]$file <- cp(cfg[[sec]]$file, paste0(sec, ".file"))
  kw <- cfg$input$light$Kw
  if (is.character(kw) && length(kw) == 1L) cfg$input$light$Kw <- cp(kw, "input.light.Kw")
  else if (is.list(kw)) for (nm in names(kw)) if (is.character(kw[[nm]]) && length(kw[[nm]]) == 1L)
    cfg$input$light$Kw[[nm]] <- cp(kw[[nm]], paste0("input.light.Kw.", nm))
  for (m in models) {
    cf <- cfg$config_files[[m]]
    if (is.null(cf) || !startsWith(cf, paste0(m, "/")) || grepl("(^|/)\\.\\.(/|$)", cf))
      .lw_fail("config_files.", m, " must point inside ", m, "/")
    # Preserve the user's existing native model customization, excluding old output.
    if (dir.exists(file.path(src, m))) .lw_copy_tree(file.path(src, m), file.path(dest, m), "output")
    # Stable ASCII filenames also support original projects whose path contains
    # spaces/non-ASCII text; the legacy text reader must not see those paths.
    ext <- tools::file_ext(cf)
    if (!grepl("^[A-Za-z0-9]*$", ext)) .lw_fail("Unsafe native configuration extension: ", cf)
    safe_cf <- file.path(m, paste0("native_config", if (nzchar(ext)) paste0(".", ext) else ""))
    old_cf <- file.path(dest, cf)
    if (file.exists(old_cf) && !identical(cf, safe_cf)) {
      if (file.exists(file.path(dest, safe_cf))) .lw_fail("Native snapshot filename collision: ", safe_cf)
      if (!file.rename(old_cf, file.path(dest, safe_cf))) .lw_fail("Cannot normalize native configuration filename")
    }
    cfg$config_files[[m]] <- safe_cf
  }
  .lw_write_config(cfg, file.path(dest, config_file))
  cfg <- .lw_read_config(file.path(dest, config_file))
  .lw_check_legacy_yaml(cfg, file.path(dest, config_file), models)
  .lw_write_csv(do.call(rbind, manifest), file.path(dest, "input_manifest.csv"))
  cfg
}
.lw_cfg_sample <- function(base, model, spec, row, contract, allow_constant_Kw_override = FALSE) {
  cfg <- base
  for (j in seq_len(nrow(spec))) {
    nm <- spec$name[j]; value <- as.numeric(row[[nm]])
    if (spec$type[j] == "met") {
      if (is.null(cfg$scaling_factors)) cfg$scaling_factors <- list()
      if (is.null(cfg$scaling_factors[[model]])) cfg$scaling_factors[[model]] <- list()
      # In LER, model-specific scaling overrides the corresponding all-model value.
      cfg$scaling_factors[[model]][[nm]] <- value
    } else if (spec$type[j] == "kw") {
      kw <- cfg$input$light$Kw
      active <- if (is.list(kw)) { if (!is.null(kw[[model]])) kw[[model]] else kw$all } else kw
      if (is.character(active) && !allow_constant_Kw_override)
        .lw_fail("Kw is a time-series file. Explicit permission is required to replace it by a constant")
      if (!is.list(kw)) kw <- list(all = kw)
      kw[[model]] <- value # Absolute m^-1, not a multiplier.
      cfg$input$light$Kw <- kw
    } else {
      # Native model parameters are applied explicitly after export_config().
      # Avoid having duplicate shorthand/canonical keys in the master YAML.
      basepars <- cfg$model_parameters[[model]]
      if (length(basepars)) {
        leaf <- sub(".*/", "", nm)
        keys <- names(basepars)
        hits <- keys == nm | (keys == leaf)
        basepars <- basepars[!hits]
      }
      cfg$model_parameters[[model]] <- basepars
    }
  }
  # Set output frequency explicitly for models that support this LER control.
  # FLake writes at its native forcing/solver schedule; the reader checks actual coverage.
  cfg$output$time_unit <- "second"
  cfg$output$time_step <- as.numeric(contract$step_seconds)
  if (model == "GOTM") cfg$output$time_method <- if (contract$method == "interval_mean") "mean" else "point"
  cfg$output$variables <- unique(c("temp", unlist(cfg$output$variables)))
  h <- as.numeric(cfg$time$time_step)
  if (model %in% c("GLM", "Simstrat")) {
    ratio <- contract$step_seconds / h
    if (!is.finite(ratio) || ratio < 1 || abs(ratio - round(ratio)) > 1e-8)
      .lw_fail("Output interval must be an integer multiple of integration timestep for ", model)
  }
  cfg
}
.lw_apply_native <- function(cfg, model, spec, row) {
  for (j in which(spec$type == "model")) {
    parts <- strsplit(spec$name[j], "/", fixed = TRUE)[[1]]
    if (length(parts) > 2L) .lw_fail("Only key or section/key model-parameter syntax is supported")
    LakeEnsemblR::input_config_value(model = model, folder = ".", file = cfg$config_files[[model]],
      label = if (length(parts) == 2L) parts[1] else NULL, key = tail(parts, 1),
      value = as.numeric(row[[spec$name[j]]]))
  }
}
.lw_mylake_globals <- function(code) {
  # MyLakeR 0.0.1 intentionally writes/removes these variables in .GlobalEnv.
  # Preserve caller objects even when the model errors, without changing equations.
  names <- c("albedot1", "Wt", "tt", "In_Tz", "In_Z", "M_start", "M_stop",
    "Bio_par_names", "Bio_par_range", "Bio_par", "Phys_par_names", "Phys_par_range",
    "Phys_par", "Inflw", "Ice0", "In_FIM", "In_Chlz_sed", "In_TPz_sed", "In_DOCz",
    "In_Chlz", "In_DOPz", "In_TPz", "In_Sz", "In_Cz", "In_Az", "g", "sigmaSB",
    "eps_air", "gas_const_R", "CtoK", "kappa_val", "Charnock_alpha", "R_roughness",
    "cp", "rho_air", "Ta_default", "P_default", "psych_default", "Qsat_coeff",
    "CVB_depth", "min_gustiness", "beta_conv", "Solar_const", "emiss_lw", "bulkf_default")
  existed <- names[vapply(names, exists, logical(1), envir = .GlobalEnv, inherits = FALSE)]
  if (any(vapply(existed, bindingIsLocked, logical(1), env = .GlobalEnv)) ||
      any(vapply(existed, bindingIsActive, logical(1), env = .GlobalEnv)))
    .lw_fail("MyLakeR would overwrite a locked caller binding; run in a clean R session")
  saved <- mget(existed, envir = .GlobalEnv, inherits = FALSE)
  on.exit({
    introduced <- setdiff(names, existed)
    introduced <- introduced[vapply(introduced, exists, logical(1), envir = .GlobalEnv, inherits = FALSE)]
    if (length(introduced)) rm(list = introduced, envir = .GlobalEnv)
    for (nm in existed) assign(nm, saved[[nm]], envir = .GlobalEnv)
  }, add = TRUE)
  force(code)
}
# [LER-WINDOW NEW SECTION A001] Adapters invoking the supplied model engines
.lw_run_engine <- function(model, cfg, verbose = FALSE) {
  cf <- basename(cfg$config_files[[model]])
  oldwd <- getwd(); oldld <- Sys.getenv("LD_LIBRARY_PATH", unset = NA_character_)
  on.exit({
    setwd(oldwd)
    if (is.na(oldld)) Sys.unsetenv("LD_LIBRARY_PATH") else Sys.setenv(LD_LIBRARY_PATH = oldld)
  }, add = TRUE)
  if (.Platform$OS.type == "windows" && model != "MyLake") {
    if (.Machine$sizeof.pointer != 8L) .lw_fail("Windows model engines require 64-bit R")
    # Modern Windows R no longer has the x64 subarchitecture string checked by
    # some historical wrappers. Invoke exactly their bundled executable instead.
    package <- switch(model, FLake = "FLakeR", GLM = "GLM3r", GOTM = "GOTMr", Simstrat = "SimstratR")
    relative <- switch(model, FLake = "extbin/win/flake.exe",
      GLM = "extbin/glm-3.0.5_x64/glm.exe", GOTM = "extbin/win64GOTM/gotm.exe",
      Simstrat = "extbin/win/simstrat_windows_301.exe")
    exe <- system.file(relative, package = package)
    if (!nzchar(exe) || !file.exists(exe)) .lw_fail("Missing Windows executable: ", package, "/", relative)
    if (model == "GLM" && nzchar(Sys.getenv("GLM_PATH"))) exe <- Sys.getenv("GLM_PATH")
    if (!file.exists(exe)) .lw_fail("Configured Windows executable is missing")
    setwd(model)
    args <- if (model == "GLM") c("--nml", shQuote(cf)) else shQuote(cf)
    status <- system2(exe, args = args, stdout = "engine_console.log", stderr = "engine_console.log", wait = TRUE)
    if (!identical(as.integer(status), 0L)) .lw_fail(model, " engine exit status ", status, "; inspect engine_console.log")
    if (verbose) cat(readLines("engine_console.log", warn = FALSE), sep = "\n")
    return(invisible(status))
  }
  result <- if (model == "FLake") FLakeR::run_flake(sim_folder = "FLake", nml_file = cf, verbose = verbose)
    else if (model == "GLM") GLM3r::run_glm(sim_folder = "GLM", nml_file = cf, verbose = verbose)
    # Linux/macOS GOTMr wrappers ignore yaml_file; supplying args is required for
    # a nondefault filename. This invokes the same installed GOTM executable.
    else if (model == "GOTM") GOTMr::run_gotm(sim_folder = "GOTM", yaml_file = cf, verbose = verbose, args = shQuote(cf))
    else if (model == "Simstrat") SimstratR::run_simstrat(sim_folder = "Simstrat", par_file = cf, verbose = verbose)
    else if (model == "MyLake") .lw_mylake_globals(MyLakeR::run_mylake(sim_folder = ".", config_dat = cf))
    else .lw_fail("Unknown model")
  status <- attr(result, "status")
  if (is.null(status) && is.numeric(result) && length(result) == 1L) status <- result
  if (!is.null(status) && (length(status) != 1L || is.na(status) || status != 0L))
    .lw_fail(model, " engine returned nonzero exit status: ", paste(status, collapse = ","))
  invisible(result)
}
.lw_output_path <- function(model) {
  file.path(model, "output", switch(model, FLake = "output.dat", GLM = "output.nc",
                                    GOTM = "output.nc", Simstrat = "T_out.dat", MyLake = "output.RData"))
}

#' Read the LER model-specific output before run_ensemble's common-time merge.
#' @export
# [LER-WINDOW NEW SECTION A001] Read near-surface output with explicit time/depth contract
ler_read_window_surface <- function(config_file, model, contract, folder = ".") {
  if (length(model) != 1L || !model %in% .lw_models()) .lw_fail("Supply one supported model")
  c <- .lw_contract(contract)
  if (c$model != model) .lw_fail("Contract/model mismatch")
  oldwd <- getwd(); oldtz <- Sys.getenv("TZ", unset = NA_character_)
  on.exit({ setwd(oldwd); if (is.na(oldtz)) Sys.unsetenv("TZ") else Sys.setenv(TZ = oldtz) }, add = TRUE)
  setwd(folder); Sys.setenv(TZ = "UTC")
  cfg <- .lw_read_config(config_file)
  a <- .lw_utc(cfg$time$start); b <- .lw_utc(cfg$time$stop)
  rawpath <- .lw_output_path(model)
  if (!file.exists(rawpath) || is.na(file.info(rawpath)$size) || file.info(rawpath)$size <= 0)
    .lw_fail("Missing/empty native output: ", rawpath)
  # Full native cadence for FLake, not the sparse MODIS labels and not one record/day.
  step <- as.numeric(c$step_seconds)
  out_hour <- 0L
  if (model == "FLake") {
    native_step <- suppressWarnings(glmtools::get_nml_value(
      nml_file = cfg$config_files[[model]], arg_name = "del_time_lk"))
    native_step <- suppressWarnings(as.numeric(native_step))
    if (length(native_step) != 1L || !is.finite(native_step) || native_step <= 0)
      .lw_fail("Cannot determine FLake del_time_lk; inspect the local read_flake_out and namelist")
    step <- min(step, native_step)
    # Subdaily forcing already has absolute hour/minute labels. Passing the start
    # hour would add it a second time in upstream read_flake_out(). Only its daily
    # date-label convention requires the documented out_hour compensation.
    if (native_step == 86400) {
      if (as.integer(format(a, "%M", tz = "UTC")) != 0L || as.integer(format(a, "%S", tz = "UTC")) != 0L)
        .lw_fail("Daily FLake output supports whole-hour start labels only")
      out_hour <- as.integer(format(a, "%H", tz = "UTC"))
    }
  }
  requested <- data.frame(datetime = seq(a, b, by = step))
  out <- LakeEnsemblR::get_output(config_file = config_file, model = model, vars = "temp",
    obs_depths = 0, folder = ".", out_time = requested, out_hour = out_hour)
  if (is.list(out) && !is.data.frame(out)) {
    if (!"temp" %in% names(out)) .lw_fail("get_output did not return its named temp component")
    out <- out[["temp"]]
  }
  if (!is.data.frame(out)) .lw_fail("Unexpected get_output structure")
  .lw_require_cols(out, c("datetime", as.character(c$temperature_column)), "model output")
  series <- data.frame(datetime = .lw_utc(out$datetime),
                       temperature = suppressWarnings(as.numeric(out[[as.character(c$temperature_column)]])))
  # Do not sort/deduplicate/repair here: the strict aggregation validator reports problems.
  attr(series, "surface_definition") <- paste(model, c$temperature_column,
      "from LER get_output(obs_depths=0); near-surface proxy, not a skin-temperature correction")
  series
}

# [LER-WINDOW NEW SECTION A001] Candidate execution, failure handling and permanent evidence
.lw_candidate <- function(ctx, model, spec, row, contract, work, tag, windows,
                          save_series = TRUE, keep_case = FALSE) {
  id <- as.character(row$par_id)
  if (!grepl("^[A-Za-z0-9_-]+$", id)) .lw_fail("Invalid par_id")
  dest <- file.path(ctx$result_dir, tag, model, id)
  if (dir.exists(dest)) .lw_fail("Candidate output already exists: ", dest)
  dir.create(dest, recursive = TRUE)
  # Preserve the requested inputs even if preparation or the engine fails.
  .lw_write_csv(row, file.path(dest, "parameters.csv"))
  .lw_write_csv(contract, file.path(dest, "contract.csv"))
  oldwd <- getwd(); oldtz <- Sys.getenv("TZ", unset = NA_character_)
  on.exit({ setwd(oldwd); if (is.na(oldtz)) Sys.unsetenv("TZ") else Sys.setenv(TZ = oldtz) }, add = TRUE)
  stage <- "prepare"; fit <- NULL; warnings_seen <- character(); err <- NULL; series <- NULL
  prepared_case <- FALSE
  # Each work path is owned by this worker; never delete user project files.
  if (!dir.exists(work)) dir.create(work, recursive = TRUE)
  setwd(work); Sys.setenv(TZ = "UTC")
  candidate_seed <- .lw_seed(ctx$control$seed, model, id)
  run <- tryCatch(.lw_with_seed(candidate_seed, withCallingHandlers({
    .lw_check_manifest(ctx$snapshot, ctx$metadata$snapshot_files, "Input/configuration snapshot")
    unlink(model, recursive = TRUE)
    unlink(ctx$config_file) # A failed candidate must not archive a previous master YAML.
    prepared_case <- TRUE
    if (dir.exists(file.path(ctx$snapshot, model)))
      .lw_copy_tree(file.path(ctx$snapshot, model), model, exclude_top = "output")
    # Discard a project/snapshot console log before starting this candidate.
    unlink(file.path(model, "engine_console.log"))
    if (!dir.exists("_inputs")) .lw_copy_tree(file.path(ctx$snapshot, "_inputs"), "_inputs")
    cfg <- .lw_cfg_sample(ctx$base, model, spec, row, contract,
                          ctx$control$allow_constant_Kw_override)
    .lw_write_config(cfg, ctx$config_file)
    stage <- "export_config"
    # Fresh export on every sample is deliberately conservative (more I/O, no inherited parameter state).
    LakeEnsemblR::export_config(config_file = ctx$config_file, model = model, folder = ".")
    stage <- "apply_native_parameters"
    .lw_apply_native(cfg, model, spec, row)
    # Also persist canonical parameter names in the archived master YAML.
    for (j in which(spec$type == "model"))
      cfg$model_parameters[[model]][[spec$name[j]]] <- as.numeric(row[[spec$name[j]]])
    .lw_write_config(cfg, ctx$config_file)
    # Remove stale output after export and before the engine, including copied sample output.
    unlink(file.path(model, "output"), recursive = TRUE)
    dir.create(file.path(model, "output"), recursive = TRUE)
    stage <- "run_engine"
    .lw_run_engine(model, cfg)
    stage <- "read_native"
    series <- ler_read_window_surface(ctx$config_file, model, contract, folder = ".")
    if (save_series) saveRDS(series, file.path(dest, "native_surface.rds"), compress = TRUE)
    audit <- data.frame(model = model, records = nrow(series),
      first_time_UTC = .lw_fmt(head(series$datetime, 1)),
      last_time_UTC = .lw_fmt(tail(series$datetime, 1)),
      median_interval_seconds = if (nrow(series)>1) median(diff(as.numeric(series$datetime))) else NA_real_,
      max_interval_seconds = if (nrow(series)>1) max(diff(as.numeric(series$datetime))) else NA_real_,
      finite_temperatures = sum(is.finite(series$temperature)))
    .lw_write_csv(audit, file.path(dest, "native_audit.csv"))
    stage <- "window_score"
    fit <- calc_fit_window(series, windows, contract)
    .lw_write_csv(fit$pairs, file.path(dest, "pairs.csv"))
    .lw_write_csv(fit$metrics, file.path(dest, "metrics.csv"))
    if (keep_case) {
      stage <- "archive_case"
      case <- file.path(dest, "case"); dir.create(case)
      .lw_copy_tree("_inputs", file.path(case, "_inputs"))
      .lw_copy_tree(model, file.path(case, model))
      file.copy(ctx$config_file, file.path(case, ctx$config_file))
    }
    TRUE
  }, warning = function(w) {
    warnings_seen <<- c(warnings_seen, conditionMessage(w)); invokeRestart("muffleWarning")
  })), error = function(e) { err <<- conditionMessage(e); FALSE })
  log <- file.path(model, "engine_console.log")
  if (prepared_case && file.exists(log) && !file.copy(log, file.path(dest, "engine_console.log")))
    warnings_seen <- c(warnings_seen, "Could not retain engine console log")
  if (!isTRUE(run) && prepared_case) {
    debug <- file.path(dest, "debug_config")
    dir.create(debug, showWarnings = FALSE)
    # Keep only small configuration objects. The immutable run snapshot already
    # retains forcing inputs, and failed outputs can be very large or incomplete.
    files <- if (dir.exists(model)) list.files(model, recursive = TRUE, full.names = FALSE,
                                               all.files = TRUE, no.. = TRUE) else character()
    files <- files[!grepl("^output/", files) &
      grepl("\\.(nml|yaml|yml|json|par|rdata|rds)$", files, ignore.case = TRUE)]
    files <- file.path(model, files)
    if (file.exists(ctx$config_file)) files <- c(ctx$config_file, files)
    for (file in files) {
      target <- file.path(debug, file)
      dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
      if (!file.copy(file, target))
        warnings_seen <- c(warnings_seen, paste("Could not retain failed-case configuration:", file))
    }
  }
  summary <- data.frame(model = model, par_id = id, random_seed = candidate_seed, status = if (isTRUE(run)) "ok" else "failed",
                        stage = stage, message = if (is.null(err)) "" else err, stringsAsFactors = FALSE)
  met <- if (isTRUE(run)) fit$metrics else data.frame(N = nrow(windows), RMSE = NA_real_, MAE = NA_real_,
                                                    bias = NA_real_, NSE = NA_real_, r = NA_real_)
  summary <- cbind(summary, met)
  summary$objective <- if (isTRUE(run)) met$RMSE else Inf
  .lw_write_csv(summary, file.path(dest, "status.csv"))
  writeLines(warnings_seen, file.path(dest, "warnings.txt"), useBytes = TRUE)
  summary
}

.lw_context <- function(config_file, folder, models, control, out_dir, spin_up) {
  models <- as.character(models)
  if (!length(models) || anyDuplicated(models) || any(!models %in% .lw_models())) .lw_fail("Invalid models")
  .lw_initialize_runtime()
  version <- as.character(utils::packageVersion("LakeEnsemblR"))
  if (version != "1.2.9.9002")
    .lw_fail("Install the patched 1.2.9.9002 package before engine runs; found ", version)
  if (is.null(spin_up)) spin_up <- 0
  if (length(spin_up) != 1L || !is.finite(spin_up) || spin_up < 0) .lw_fail("Invalid spin_up days")
  if (dir.exists(out_dir) || file.exists(out_dir)) .lw_fail("Use a new, nonexistent result directory: ", out_dir)
  dir.create(out_dir, recursive = TRUE)
  result_dir <- normalizePath(out_dir, winslash = "/", mustWork = TRUE)
  snapshot <- file.path(result_dir, "snapshot")
  cfg <- .lw_snapshot(folder, config_file, snapshot, models)
  start <- .lw_utc(cfg$time$start); end <- .lw_utc(cfg$time$stop)
  if (length(start) != 1L || length(end) != 1L || start >= end) .lw_fail("Invalid YAML time.start/stop")
  allowed_start <- start + spin_up * 86400
  w <- .lw_windows(control$windows)
  cal <- .lw_select(w, control$calibration_split, allowed_start, end)
  if (nrow(cal) < 2L) .lw_fail("At least two calibration windows required; many more are needed scientifically")
  contracts <- .lw_contracts(control$contracts, models, require_confirmed = FALSE)
  .lw_write_csv(w, file.path(result_dir, "windows_all.csv"))
  .lw_write_csv(cal, file.path(result_dir, "windows_calibration.csv"))
  .lw_write_csv(contracts, file.path(result_dir, "contracts.csv"))
  ns_names <- ls(asNamespace("LakeEnsemblR"), all.names = TRUE)
  funcs <- sort(unique(c("get_output", "read_flake_out", "export_config", "input_config_value", "cali_ensemble",
    "ler_modis_windows", "ler_window_predict", "calc_fit_window", "ler_window_control",
    "ler_read_window_surface", "ler_window_probe", "cali_window_ensemble", "evaluate_window_best",
    grep("^\\.lw_", ns_names, value = TRUE))))
  fingerprints <- vapply(funcs, function(n) .lw_function_hash(get(n, asNamespace("LakeEnsemblR"))), character(1))
  .lw_write_csv(data.frame(function_name = funcs, source_sha256 = fingerprints), file.path(result_dir, "function_manifest.csv"))
  capture.output(utils::sessionInfo(), file = file.path(result_dir, "sessionInfo.txt"))
  for (nm in funcs) writeLines(c(paste0("# Runtime LakeEnsemblR function: ", nm),
    deparse(get(nm, asNamespace("LakeEnsemblR")), width.cutoff = 100L)),
    file.path(result_dir, paste0("runtime_", nm, ".R")))
  engine_pkgs <- c("FLakeR", "GLM3r", "GOTMr", "SimstratR", "MyLakeR",
                   "glmtools", "gotmtools", "configr", "ncdf4", "lubridate", "reshape2")
  package_state <- .lw_package_state(c("LakeEnsemblR", engine_pkgs, "digest", "yaml"))
  package_manifest <- package_state$packages
  .lw_write_csv(package_manifest, file.path(result_dir, "engine_packages.csv"))
  meta <- list(LakeEnsemblR = version, extension = .lw_version(), UTC = .lw_fmt(Sys.time()),
               function_hashes = fingerprints, package_manifest = package_manifest,
               package_files = package_state$files, external_engines = package_state$external, R = package_state$R,
               snapshot_files = .lw_file_manifest(snapshot),
               spin_up_days = spin_up, objective = "equal-window RMSE",
               aggregation = "model-specific contract, common explicit UTC windows")
  saveRDS(meta, file.path(result_dir, "metadata.rds"))
  list(base = cfg, config_file = config_file, snapshot = snapshot, result_dir = result_dir,
       control = control, models = models, contracts = contracts, windows = w, cal = cal,
       allowed_start = allowed_start, allowed_end = end, metadata = meta)
}

#' Small engine/reader/coverage probe. confirmed=FALSE contracts are allowed here only.
#' @export
# [LER-WINDOW NEW SECTION A001] Project probe and PSOCK worker
ler_window_probe <- function(config_file, window, model = .lw_models(), folder = ".",
                             spin_up = 0, out_dir = file.path(folder, "window_probe")) {
  ctx <- .lw_context(config_file, folder, model, window, out_dir, spin_up)
  res <- lapply(model, function(m) {
    sp <- .lw_specs(ctx$base, m)
    p <- as.data.frame(as.list(setNames(sp$initial, sp$name)), check.names = FALSE)
    p$par_id <- "initial"
    .lw_candidate(ctx, m, sp, p, ctx$contracts[ctx$contracts$model == m, , drop = FALSE],
                  work = file.path(ctx$result_dir, "_work", m), tag = "probe", windows = ctx$cal,
                  save_series = TRUE, keep_case = TRUE)
  })
  res <- do.call(rbind, res)
  .lw_write_csv(res, file.path(ctx$result_dir, "probe_summary.csv"))
  saveRDS(ctx, file.path(ctx$result_dir, "context.rds"))
  res
}
.lw_worker <- function(task, ctx) {
  m <- task$model; sp <- task$spec; p <- task$pool
  con <- ctx$contracts[ctx$contracts$model == m, , drop = FALSE]
  work <- file.path(ctx$result_dir, "_work", task$worker_id)
  on.exit(unlink(work, recursive = TRUE), add = TRUE)
  rows <- lapply(seq_len(nrow(p)), function(i) .lw_candidate(
    ctx, m, sp, p[i, , drop = FALSE], con, work, "calibration", ctx$cal,
    save_series = ctx$control$save_series, keep_case = FALSE))
  do.call(rbind, rows)
}

#' Dedicated window LHC route; no sparse observation-time filtering is used.
#' @export
# [LER-WINDOW NEW SECTION A001] Window LHC calibration
cali_window_ensemble <- function(config_file, window, num = 1000L, param_file = NULL,
                                 model = .lw_models(), folder = ".", spin_up = 0,
                                 out_f = "cali_window", parallel = FALSE, ncores = 1L) {
  if (is.null(ncores)) ncores <- max(1L, parallel::detectCores() - 1L)
  if (length(ncores) != 1L || !is.finite(ncores) || ncores < 1 || ncores != floor(ncores)) .lw_fail("Invalid ncores")
  .lw_contracts(window$contracts, model, require_confirmed = TRUE)
  path <- if (grepl("^(/|[A-Za-z]:[/\\\\])", out_f)) out_f else file.path(folder, out_f)
  ctx <- .lw_context(config_file, folder, model, window, path, spin_up)
  # Validate independent evaluation windows now, without looking at their model fit.
  .lw_select(ctx$windows, window$validation_split, ctx$allowed_start, ctx$allowed_end)
  pools <- specs <- list(); tasks <- list()
  if (!is.null(param_file) && (!is.list(param_file) || !all(model %in% names(param_file))))
    .lw_fail("Window mode param_file must be a named list: one CSV/data.frame per model")
  for (j in seq_along(model)) {
    m <- model[j]; specs[[m]] <- .lw_specs(ctx$base, m)
    seed <- .lw_seed(window$seed, m, "LHC")
    pools[[m]] <- if (is.null(param_file)) .lw_lhc(specs[[m]], num, seed) else .lw_parameter_pool(param_file[[m]], specs[[m]])
    .lw_write_csv(specs[[m]], file.path(ctx$result_dir, paste0("spec_", m, ".csv")))
    .lw_write_csv(pools[[m]], file.path(ctx$result_dir, paste0("params_", m, ".csv")))
    nchunks <- if (parallel) min(ncores, nrow(pools[[m]])) else 1L
    group <- rep(seq_len(nchunks), length.out = nrow(pools[[m]]))
    for (g in seq_len(nchunks)) tasks[[length(tasks) + 1L]] <- list(
      model = m, spec = specs[[m]], pool = pools[[m]][group == g, , drop = FALSE],
      worker_id = paste0(m, "_", sprintf("w%03d", g)))
  }
  ctx$pools <- pools; ctx$specs <- specs
  saveRDS(ctx, file.path(ctx$result_dir, "context.rds"))
  if (isTRUE(parallel)) {
    cl <- parallel::makePSOCKcluster(min(ncores, length(tasks)))
    on.exit(parallel::stopCluster(cl), add = TRUE)
    paths <- .libPaths()
    worker_checks <- parallel::clusterCall(cl, function(paths, ctx) {
      .libPaths(paths)
      suppressPackageStartupMessages(library("LakeEnsemblR", character.only = TRUE))
      get(".lw_initialize_runtime", asNamespace("LakeEnsemblR"))(paths)
      get(".lw_verify_runtime", asNamespace("LakeEnsemblR"))(ctx)
      TRUE
    }, paths, ctx)
    if (!all(vapply(worker_checks, isTRUE, logical(1)))) .lw_fail("Worker initialization failed")
    res <- parallel::parLapply(cl, tasks, function(task, ctx) {
      get(".lw_worker", asNamespace("LakeEnsemblR"))(task, ctx)
    }, ctx = ctx)
  } else res <- lapply(tasks, .lw_worker, ctx = ctx)
  all <- do.call(rbind, res)
  all <- all[order(match(all$model, model), all$par_id), , drop = FALSE]
  .lw_write_csv(all, file.path(ctx$result_dir, "calibration_summary.csv"))
  best <- lapply(model, function(m) {
    z <- all[all$model == m & all$status == "ok" & is.finite(all$objective), , drop = FALSE]
    if (!nrow(z)) .lw_fail("All candidates failed for ", m, "; inspect status.csv and warnings.txt")
    z[order(z$objective, z$par_id)[1], , drop = FALSE]
  })
  best <- do.call(rbind, best)
  .lw_write_csv(best, file.path(ctx$result_dir, "best_by_calibration_RMSE.csv"))
  record <- .lw_file_manifest(ctx$result_dir)
  record <- record[!grepl("^(_work|snapshot)/", record$file) & record$file != "context.rds", , drop = FALSE]
  rownames(record) <- NULL
  ctx$calibration_files <- record
  context_path <- file.path(ctx$result_dir, "context.rds")
  saveRDS(ctx, context_path)
  .lw_write_csv(data.frame(file = "context.rds", sha256 = .lw_sha256_file(context_path)),
                file.path(ctx$result_dir, "context_integrity.csv"))
  invisible(list(run_dir = ctx$result_dir, summary = all, best = best, parameters = pools))
}

#' Rerun selected parameters, compare calibration predictions, then score validation.
#' @export
# [LER-WINDOW NEW SECTION A001] Best-parameter rerun and split evaluation
evaluate_window_best <- function(run_dir, tolerance_celsius = 1e-6) {
  if (length(tolerance_celsius) != 1L || !is.finite(tolerance_celsius) || tolerance_celsius < 0)
    .lw_fail("tolerance_celsius must be finite and nonnegative")
  run_dir <- normalizePath(run_dir, winslash = "/", mustWork = TRUE)
  context_path <- file.path(run_dir, "context.rds")
  seal <- .lw_read_table(file.path(run_dir, "context_integrity.csv"))
  .lw_require_cols(seal, c("file", "sha256"), "context integrity record")
  if (nrow(seal) != 1L || !identical(seal$file, "context.rds") ||
      !identical(seal$sha256, .lw_sha256_file(context_path)))
    .lw_fail("Calibration context changed since selection; restore the original context.rds")
  ctx <- readRDS(context_path)
  .lw_initialize_runtime()
  .lw_verify_runtime(ctx)
  if (is.null(ctx$calibration_files)) .lw_fail("Missing completed-calibration integrity record")
  integrity <- ctx$calibration_files
  for (i in seq_len(nrow(integrity))) {
    file <- file.path(run_dir, integrity$file[i])
    if (!identical(.lw_sha256_file(file), integrity$sha256[i]))
      .lw_fail("Calibration result changed since selection: ", integrity$file[i])
  }
  if (!identical(ctx$result_dir, run_dir)) .lw_fail("Run directory was moved; restore it before this rerun")
  if (dir.exists(file.path(run_dir, "final"))) .lw_fail("final/ exists; use a fresh run rather than overwriting")
  best <- utils::read.csv(file.path(run_dir, "best_by_calibration_RMSE.csv"), stringsAsFactors = FALSE)
  val <- .lw_select(ctx$windows, ctx$control$validation_split, ctx$allowed_start, ctx$allowed_end)
  allw <- rbind(ctx$cal, val)
  allw <- allw[order(allw$window_start), , drop = FALSE]
  summaries <- list()
  for (m in ctx$models) {
    id <- best$par_id[best$model == m]
    row <- ctx$pools[[m]][ctx$pools[[m]]$par_id == id, , drop = FALSE]
    con <- ctx$contracts[ctx$contracts$model == m, , drop = FALSE]
    result <- .lw_candidate(ctx, m, ctx$specs[[m]], row, con,
      file.path(run_dir, "_final_work", m), "final", allw, save_series = TRUE, keep_case = TRUE)
    if (result$status != "ok") .lw_fail("Final rerun failed for ", m, ": ", result$message)
    dir <- file.path(run_dir, "final", m, id)
    native <- readRDS(file.path(dir, "native_surface.rds"))
    fc <- calc_fit_window(native, ctx$cal, con)
    old <- utils::read.csv(file.path(run_dir, "calibration", m, id, "pairs.csv"), stringsAsFactors = FALSE)
    old <- old[match(fc$pairs$window_id, old$window_id), , drop = FALSE]
    if (anyNA(old$window_id) || any(!is.finite(old$predicted)) ||
        any(abs(old$predicted - fc$pairs$predicted) > tolerance_celsius))
      .lw_fail("Calibration/rerun prediction mismatch for ", m, "; no validation result is accepted")
    fv <- calc_fit_window(native, val, con)
    .lw_write_csv(fc$pairs, file.path(dir, "pairs_calibration.csv"))
    .lw_write_csv(fv$pairs, file.path(dir, "pairs_validation.csv"))
    for (s in c("calibration", "validation")) {
      f <- if (s == "calibration") fc else fv
      summaries[[length(summaries) + 1L]] <- cbind(data.frame(model = m, par_id = id, split = s), f$metrics)
    }
    # params + snapshot + retained native case reproduce the exact final parameterization.
    unlink(file.path(run_dir, "_final_work", m), recursive = TRUE)
  }
  summaries <- do.call(rbind, summaries)
  .lw_write_csv(summaries, file.path(run_dir, "final_metrics.csv"))
  summaries
}

# Called only by the small source-level early-dispatch insertion in cali_ensemble().
# [LER-WINDOW NEW SECTION A001] Dispatch and restrictions for the new route
.lw_dispatch <- function(config_file, num, param_file, cmethod, qualfun_supplied,
                         parallel, job_supplied, model, folder, spin_up, out_f,
                         ncores, tmp_dir, window, dots) {
  if (!identical(cmethod, "LHC")) .lw_fail("Window mode currently supports LHC only")
  if (qualfun_supplied || job_supplied || length(dots) || !is.null(tmp_dir))
    .lw_fail("Window mode uses fixed metrics/RMSE and isolated workspaces; do not supply qualfun, job_name, tmp_dir or ...")
  if (is.null(num) && is.null(param_file)) .lw_fail("Supply num or model-specific param_file list")
  cali_window_ensemble(config_file = config_file, window = window, num = num,
    param_file = param_file, model = model, folder = folder, spin_up = spin_up,
    out_f = out_f, parallel = parallel, ncores = ncores)
}
# [LER-WINDOW NEW FILE END A001]
