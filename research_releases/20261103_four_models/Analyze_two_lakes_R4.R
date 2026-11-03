# Read-only analysis of completed four-model runs. No engines or model inputs are changed.
.a4_need <- function(ok, ...) if (!isTRUE(ok)) stop(..., call. = FALSE)
.a4_read <- function(p) {
  .a4_need(file.exists(p), "Missing analysis input: ", p)
  utils::read.csv(p, stringsAsFactors = FALSE, check.names = FALSE, fileEncoding = "UTF-8-BOM")
}
.a4_sha <- function(p) digest::digest(file = p, algo = "sha256", serialize = FALSE)
.a4_csv <- function(x, p) utils::write.csv(x, p, row.names = FALSE, fileEncoding = "UTF-8", na = "NA")
.a4_receipt <- function(p) {
  .a4_need(file.exists(p) && file.exists(paste0(p, ".sha256")), "Missing receipt/seal: ", p)
  .a4_need(identical(readLines(paste0(p, ".sha256"), warn = FALSE), .a4_sha(p)), "Receipt hash differs: ", p)
  readRDS(p)
}
.a4_report_check <- function(lake_dir) {
  record <- .a4_receipt(file.path(lake_dir, "report.rds"))
  root <- file.path(lake_dir, "report")
  expected <- record$files
  current <- sort(list.files(root, recursive = TRUE, all.files = TRUE, no.. = TRUE))
  .a4_need(!anyDuplicated(expected$file) && setequal(current, as.character(expected$file)), "Report file list changed: ", root)
  for (i in seq_len(nrow(expected))) {
    p <- file.path(root, expected$file[i])
    .a4_need(file.info(p)$size == expected$bytes[i] && identical(.a4_sha(p), expected$sha256[i]),
      "Report artifact changed: ", p)
  }
  invisible(record)
}
.a4_metrics <- function(x) {
  e <- x$predicted - x$observed
  data.frame(N = nrow(x), RMSE = sqrt(mean(e^2)), MAE = mean(abs(e)), bias = mean(e),
    NSE = if (sum((x$observed - mean(x$observed))^2) > 0) 1 - sum(e^2)/sum((x$observed - mean(x$observed))^2) else NA_real_,
    r = if (nrow(x) >= 2L && stats::sd(x$observed) > 0 && stats::sd(x$predicted) > 0) stats::cor(x$observed, x$predicted) else NA_real_)
}
.a4_figure <- function(out, name, draw, width = 1800, height = 1100) {
  for (ext in c("png", "pdf")) {
    p <- file.path(out, paste0(name, ".", ext))
    if (ext == "png") grDevices::png(p, width = width, height = height, res = 160)
    else grDevices::pdf(p, width = width/160, height = height/160, useDingbats = FALSE)
    tryCatch(draw(), finally = grDevices::dev.off())
  }
}

analyze_two_lakes_r4 <- function(run_root = "D:/LER4_ice_20261102/n500", out_dir = NULL, old_akesaiqin_metrics = NULL) {
  .a4_need(requireNamespace("digest", quietly = TRUE), "Load the original isolated R library containing digest first")
  run_root <- normalizePath(run_root, winslash = "/", mustWork = TRUE)
  lakes <- c("akesaiqin", "namco")
  models <- c("FLake", "GLM", "GOTM", "Simstrat", "Ensemble4")
  colors <- setNames(c("#3686A0", "#E3A437", "#4D9D70", "#A06FAB", "#444444"), models)
  index <- .a4_read(file.path(run_root, "two_lake_run_index.csv"))
  index <- index[match(lakes, index$name), , drop = FALSE]
  .a4_need(identical(as.character(index$name), lakes) && all(index$calibration_status == "ok") &&
    all(index$evaluation_status == "ok"), "Both lakes must have completed calibration and evaluation")
  if (is.null(out_dir)) out_dir <- file.path(dirname(run_root), paste0("analysis_two_lakes_", format(Sys.time(), "%Y%m%dT%H%M%S")))
  .a4_need(!file.exists(out_dir), "Use a NEW analysis output directory: ", out_dir)
  .a4_need(dir.create(out_dir, recursive = TRUE), "Cannot create analysis output directory")
  out_dir <- normalizePath(out_dir, winslash = "/", mustWork = TRUE)
  metric_list <- pair_list <- param_list <- response_list <- timing_list <- list()
  for (lake in lakes) {
    root <- file.path(run_root, lake); report <- file.path(root, "report")
    .a4_report_check(root)
    metrics <- .a4_read(file.path(report, "model_metrics.csv"))
    ensemble <- .a4_read(file.path(report, "ensemble4_metrics.csv"))
    fields <- c("model", "split", "N", "RMSE", "MAE", "bias", "NSE", "r")
    metrics <- rbind(metrics[fields], ensemble[fields])
    .a4_need(nrow(metrics) == 10L && setequal(metrics$model, models), "Unexpected metrics/model design: ", lake)
    pairs <- .a4_read(file.path(report, "pairs_models_ensemble4.csv"))
    .a4_need(setequal(pairs$model, models) && all(is.finite(pairs$predicted)) && all(is.finite(pairs$observed)),
      "Expected finite four-model plus ensemble window pairs: ", lake)
    .a4_need(!anyDuplicated(paste(pairs$model, pairs$split, pairs$window_id)), "Duplicate model/split/window: ", lake)
    pairs$start_UTC <- as.POSIXct(pairs$window_start, tz = "UTC")
    pairs$end_UTC <- as.POSIXct(pairs$window_end, tz = "UTC")
    .a4_need(all(!is.na(pairs$start_UTC) & !is.na(pairs$end_UTC) & pairs$end_UTC > pairs$start_UTC), "Invalid window dates")
    pairs$midpoint_UTC <- pairs$start_UTC + as.numeric(difftime(pairs$end_UTC, pairs$start_UTC, units = "secs"))/2
    pairs$month <- as.integer(format(pairs$midpoint_UTC, "%m", tz = "UTC"))
    pairs$residual <- pairs$predicted - pairs$observed
    for (i in seq_len(nrow(metrics))) {
      z <- pairs[pairs$model == metrics$model[i] & pairs$split == metrics$split[i], , drop = FALSE]
      calc <- .a4_metrics(z)
      .a4_need(isTRUE(all.equal(as.numeric(unlist(metrics[i, names(calc)])), as.numeric(unlist(calc[1, ])), tolerance = 1e-9)),
        "Reported metrics do not reproduce from equal-weight window pairs: ", lake, "/", metrics$model[i], "/", metrics$split[i])
    }
    for (split in c("calibration", "validation")) {
      ref <- pairs[pairs$model == models[1] & pairs$split == split, , drop = FALSE]
      for (model in models[-1]) {
        z <- pairs[pairs$model == model & pairs$split == split, , drop = FALSE]
        .a4_need(setequal(z$window_id, ref$window_id) && isTRUE(all.equal(z$observed[match(ref$window_id, z$window_id)], ref$observed)),
          "Models do not share identical observed windows: ", lake)
      }
    }
    parameters <- .a4_read(file.path(report, "selected_parameters.csv"))
    .a4_need(nrow(parameters) == 9L && sum(parameters$model == "Simstrat") == 3L, "Expected 2+2+2+3 selected parameters")
    parameters$lower <- ifelse(parameters$parameter == "ModelParameters/p_sw_ice", 0.9, 0.5)
    parameters$upper <- ifelse(parameters$parameter == "wind_speed", 2, ifelse(parameters$parameter == "swr", 1.5, 3))
    parameters$fraction_of_range <- (parameters$value - parameters$lower)/(parameters$upper - parameters$lower)
    parameters$within_5pct_of_boundary <- parameters$fraction_of_range <= 0.05 | parameters$fraction_of_range >= 0.95
    response <- .a4_read(file.path(report, "parameter_response.csv"))
    metrics$lake <- pairs$lake <- parameters$lake <- response$lake <- lake
    metric_list[[lake]] <- metrics; pair_list[[lake]] <- pairs
    param_list[[lake]] <- parameters; response_list[[lake]] <- response
    timing <- .a4_read(file.path(root, "phase_times.csv")); timing$lake <- lake; timing_list[[lake]] <- timing
  }
  metrics <- do.call(rbind, metric_list); pairs <- do.call(rbind, pair_list)
  parameters <- do.call(rbind, param_list); response <- do.call(rbind, response_list)
  timing <- do.call(rbind, timing_list)
  .a4_csv(metrics, file.path(out_dir, "metrics_two_lakes.csv"))
  .a4_csv(pairs, file.path(out_dir, "matched_window_pairs_two_lakes.csv"))
  .a4_csv(parameters, file.path(out_dir, "selected_parameters_and_boundaries.csv"))
  .a4_csv(response, file.path(out_dir, "calibration_parameter_responses.csv"))
  .a4_csv(timing, file.path(out_dir, "phase_times_all_attempts.csv"))
  elapsed <- stats::aggregate(timing$elapsed_seconds, timing[c("lake", "phase", "status")], sum)
  names(elapsed)[ncol(elapsed)] <- "elapsed_seconds"
  .a4_csv(elapsed, file.path(out_dir, "phase_elapsed_summary.csv"))
  spans <- do.call(rbind, lapply(lakes, function(lake) {
    z <- timing[timing$lake == lake, ]; a <- as.POSIXct(z$start_UTC, tz = "UTC"); b <- as.POSIXct(z$end_UTC, tz = "UTC")
    data.frame(lake = lake, first_phase_start_UTC = format(min(a), "%Y-%m-%d %H:%M:%S", tz = "UTC"),
      last_phase_end_UTC = format(max(b), "%Y-%m-%d %H:%M:%S", tz = "UTC"),
      phase_span_seconds = as.numeric(difftime(max(b), min(a), units = "secs")),
      sum_phase_elapsed_seconds = sum(z$elapsed_seconds), phase_records = nrow(z))
  }))
  .a4_csv(spans, file.path(out_dir, "phase_wall_span_summary.csv"))
  groups <- split(pairs[pairs$split == "validation", ], interaction(pairs$lake[pairs$split == "validation"],
    pairs$model[pairs$split == "validation"], pairs$month[pairs$split == "validation"], drop = TRUE))
  monthly <- do.call(rbind, lapply(groups, function(z) cbind(data.frame(lake = z$lake[1], model = z$model[1],
    window_midpoint_month = z$month[1]), .a4_metrics(z))))
  .a4_csv(monthly, file.path(out_dir, "monthly_validation_errors.csv"))
  sim <- response[response$model == "Simstrat", ]
  triplets <- sim[sim$parameter == "wind_speed", c("lake", "par_id", "status", "RMSE", "value")]
  names(triplets)[names(triplets) == "value"] <- "wind_speed"
  for (parameter in c("swr", "ModelParameters/p_sw_ice")) {
    z <- sim[sim$parameter == parameter, c("lake", "par_id", "value")]
    names(z)[3] <- if (parameter == "swr") "swr" else "p_sw_ice"
    triplets <- merge(triplets, z, by = c("lake", "par_id"), all = TRUE)
  }
  .a4_need(all(is.finite(triplets$wind_speed) & is.finite(triplets$swr) & is.finite(triplets$p_sw_ice)),
    "Incomplete Simstrat parameter triplets")
  .a4_csv(triplets, file.path(out_dir, "simstrat_parameter_triplets.csv"))
  if (!is.null(old_akesaiqin_metrics)) {
    old <- .a4_read(old_akesaiqin_metrics)
    old <- old[old$model %in% models[1:4], fields]
    comparison <- merge(old, metrics[metrics$lake == "akesaiqin", fields], by = c("model", "split"),
      suffixes = c("_old_five_model_scheme", "_new_four_model_ice_scheme"))
    comparison$RMSE_new_minus_old <- comparison$RMSE_new_four_model_ice_scheme - comparison$RMSE_old_five_model_scheme
    .a4_csv(comparison, file.path(out_dir, "akesaiqin_old_vs_new_individual_models.csv"))
  }
  val <- metrics[metrics$split == "validation", ]; val <- val[order(val$lake, val$RMSE), ]
  val$descriptive_RMSE_rank <- ave(val$RMSE, val$lake, FUN = function(x) rank(x, ties.method = "min"))
  .a4_csv(val, file.path(out_dir, "validation_comparison.csv"))
  .a4_figure(out_dir, "01_RMSE_by_lake_and_split", function() {
    graphics::par(mfrow = c(1, 2), mar = c(7, 5, 3, 1))
    for (lake in lakes) {
      z <- metric_list[[lake]]
      # Explicit indexing avoids assuming report row order.
      a <- sapply(models, function(m) vapply(c("calibration", "validation"), function(s) z$RMSE[z$model == m & z$split == s], numeric(1)))
      graphics::barplot(a, beside = TRUE, names.arg = models, las = 2, col = c("#547E9D", "#CF8B4A"),
        ylab = "Equal-window RMSE (deg C)", main = lake)
      graphics::legend("topleft", c("Calibration", "Validation"), fill = c("#547E9D", "#CF8B4A"), bty = "n")
    }
  })
  .a4_figure(out_dir, "02_validation_observed_predicted", function() {
    graphics::par(mfrow = c(2, 5), mar = c(4, 4, 3, 1))
    for (lake in lakes) for (model in models) {
      z <- pairs[pairs$lake == lake & pairs$model == model & pairs$split == "validation", ]
      limits <- range(c(z$observed, z$predicted))
      graphics::plot(z$observed, z$predicted, xlim = limits, ylim = limits, asp = 1, pch = 16, cex = 0.5,
        col = grDevices::adjustcolor(colors[model], 0.55), xlab = "Observed window mean (deg C)", ylab = "Predicted window mean (deg C)", main = paste(lake, model))
      graphics::abline(0, 1, col = "grey40", lty = 2)
    }
  }, width = 2300, height = 1050)
  .a4_figure(out_dir, "03_validation_window_temperature", function() {
    graphics::par(mfrow = c(2, 1), mar = c(4, 5, 3, 1))
    for (lake in lakes) {
      z <- pairs[pairs$lake == lake & pairs$split == "validation", ]
      graphics::plot(as.Date(z$midpoint_UTC), z$predicted, type = "n", ylim = range(c(z$observed, z$predicted)),
        xlab = "Window midpoint (UTC)", ylab = "Window mean temperature (deg C)", main = lake)
      for (model in models) {
        x <- z[z$model == model, ]; graphics::points(as.Date(x$midpoint_UTC), x$predicted, col = colors[model], pch = 16, cex = 0.45)
      }
      x <- z[z$model == models[1], ]; graphics::points(as.Date(x$midpoint_UTC), x$observed, pch = 4, cex = 0.6)
      graphics::legend("topleft", c("Observed", models), col = c("black", colors), pch = c(4, rep(16, 5)), ncol = 3, cex = 0.7, bty = "n")
    }
  })
  .a4_figure(out_dir, "04_validation_residual_by_window_month", function() {
    graphics::par(mfrow = c(2, 5), mar = c(4, 4, 3, 1))
    for (lake in lakes) for (model in models) {
      z <- pairs[pairs$lake == lake & pairs$model == model & pairs$split == "validation", ]
      groups <- lapply(1:12, function(m) z$residual[z$month == m])
      graphics::boxplot(groups, names = 1:12, outline = FALSE, col = colors[model], xlab = "Window midpoint month",
        ylab = "Predicted - observed (deg C)", main = paste(lake, model))
      graphics::abline(h = 0, lty = 2, col = "grey40")
    }
  }, width = 2300, height = 1050)
  for (lake in lakes) .a4_figure(out_dir, paste0("05_parameter_responses_", lake), function() {
    graphics::par(mfrow = c(3, 3), mar = c(4, 4, 3, 1))
    pars <- param_list[[lake]]
    for (i in seq_len(nrow(pars))) {
      z <- response[response$lake == lake & response$model == pars$model[i] & response$parameter == pars$parameter[i] &
        response$status == "ok" & is.finite(response$RMSE), ]
      graphics::plot(z$value, z$RMSE, pch = 16, cex = 0.35, col = grDevices::adjustcolor(colors[pars$model[i]], 0.45),
        xlab = pars$parameter[i], ylab = "Calibration RMSE (deg C)", main = paste(lake, pars$model[i]))
      graphics::abline(v = pars$value[i], col = "#B51C29", lty = 2)
    }
  }, width = 1800, height = 1500)
  .a4_figure(out_dir, "06_simstrat_joint_parameter_responses", function() {
    graphics::par(mfrow = c(2, 2), mar = c(4, 4, 3, 1))
    palette <- c("#254D85", "#3389A5", "#72B9A0", "#DFBD62", "#BD624B")
    for (lake in lakes) for (parameter in c("wind_speed", "swr")) {
      z <- triplets[triplets$lake == lake & triplets$status == "ok" & is.finite(triplets$RMSE), ]
      bin <- pmax(1L, pmin(5L, ceiling(5 * rank(z$RMSE, ties.method = "average")/nrow(z))))
      graphics::plot(z[[parameter]], z$p_sw_ice, col = grDevices::adjustcolor(palette[bin], 0.65), pch = 16, cex = 0.55,
        xlab = parameter, ylab = "p_sw_ice", main = paste(lake, "Simstrat"))
      selected <- param_list[[lake]]; selected <- selected[selected$model == "Simstrat", ]
      graphics::points(selected$value[selected$parameter == parameter], selected$value[selected$parameter == "ModelParameters/p_sw_ice"], pch = 8, cex = 1.5, lwd = 2)
      graphics::legend("topleft", legend = c("Lowest 20% RMSE", "20-40%", "40-60%", "60-80%", "Highest 20% RMSE"),
        col = palette, pch = 16, bty = "n", cex = 0.6)
    }
  })
  note <- c("Two-lake four-model analysis. Report receipt and report-file SHA256 manifests verified.",
    "Metrics independently reproduced from equal-weight MODIS window pairs. Validation ranking is descriptive; parameter selection uses calibration only.",
    "Points represent matched window means, not daily observations. No continuous winter series is inferred across missing windows.",
    "Monthly residuals use window midpoint month. Temperature-proxy ice-free labels are not independent ice observations.",
    "p_sw_ice=0.9-3 is the requested exploratory range, not an official physical recommendation; simultaneous swr calibration may compensate.",
    "Parameter-response scatter is not Feldbauer delta/S1 sensitivity analysis. No new engine runs or bootstrap are performed.",
    "All original run artifacts are read-only. Existing full candidate/native integrity is not rehashed by this plotting script.")
  writeLines(note, file.path(out_dir, "READ_ME.txt"))
  cat("TWO_LAKE_ANALYSIS_AND_PLOTS_COMPLETE\n", out_dir, "\n", sep = "")
  invisible(out_dir)
}
