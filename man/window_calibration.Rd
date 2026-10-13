% [LER-WINDOW NEW FILE A002] Entire help page added relative to official LER.
\name{window_calibration}
\alias{window_calibration}
\alias{ler_modis_windows}
\alias{ler_window_predict}
\alias{calc_fit_window}
\alias{ler_window_control}
\alias{ler_read_window_surface}
\alias{ler_window_probe}
\alias{cali_window_ensemble}
\alias{evaluate_window_best}
\title{Explicit-window LSWT calibration and evaluation}
\description{Research extension 0.2.0 to LakeEnsemblR 1.2.9. It uses explicit UTC
windows, complete output coverage, isolated cases, reproducible LHC candidates,
and the same observation operator for calibration and final evaluation.}
\usage{
ler_modis_windows(year, doy)
ler_window_predict(series, windows, contract)
calc_fit_window(series, windows, contract)
ler_window_control(windows, contracts, seed = 20261004L,
  calibration_split = "calibration", validation_split = "validation",
  save_series = TRUE, allow_constant_Kw_override = FALSE)
ler_read_window_surface(config_file, model, contract, folder = ".")
ler_window_probe(config_file, window, model = .lw_models(), folder = ".",
  spin_up = 0, out_dir = file.path(folder, "window_probe"))
cali_window_ensemble(config_file, window, num = 1000L, param_file = NULL,
  model = .lw_models(), folder = ".", spin_up = 0, out_f = "cali_window",
  parallel = FALSE, ncores = 1L)
evaluate_window_best(run_dir, tolerance_celsius = 1e-6)
}
\arguments{
\item{year, doy}{Equal-length integer vectors. DOY is 1,9,...,361;
the final window ends at the next January 1.}
\item{series}{A data frame with increasing unique UTC datetime and temperature
in Celsius. Required output must be finite and complete.}
\item{windows}{A table with window_id, window_start, window_end, observed,
split, use, ice_free and qc_pass; prediction alone needs the first three.
Approved observations have explicit quality and ice screening.}
\item{contract, contracts}{One model row or a table declaring actual cadence,
phase, timestamp meaning and near-surface column. Methods are sample_mean,
linear_time_mean or interval_mean. confirmed requires review of native semantics.
MyLake is daily-state sample_mean.}
\item{seed}{Positive integer. Candidate random streams depend on model and
parameter ID and are restored after each run.}
\item{calibration_split, validation_split}{Different split labels; approved
windows must be disjoint and within the allowed simulation period.}
\item{save_series}{Whether to retain complete candidate surface series.}
\item{allow_constant_Kw_override}{Explicit permission to replace a Kw time-series
input by a sampled positive constant. FALSE by default.}
\item{config_file}{Master YAML basename in folder. An explicit two-column
initial profile is required. Inputs are copied to a checksummed snapshot.}
\item{model}{One model for the reader, or model names for runs.
Defaults are FLake, GLM, GOTM, Simstrat and MyLake.}
\item{folder}{Existing prepared one-lake project directory.}
\item{window}{A ler_window_control object. The cali_ensemble argument is
named-only after ...; NULL retains the original route.}
\item{spin_up}{Days excluded from simulation start. Cross-boundary approved
windows cause an error rather than partial averaging.}
\item{out_dir, out_f}{New nonexistent result directories. Previous results are
never silently overwritten.}
\item{num}{LHC candidates per model, unless a parameter pool is supplied.}
\item{param_file}{Named list of CSVs/data frames per model, with exact parameter
names and unique filename-safe par_id values.}
\item{parallel, ncores}{PSOCK parallel execution and worker count.}
\item{run_dir}{Unmoved successful calibration directory with unchanged input,
runtime and recorded outputs.}
\item{tolerance_celsius}{Nonnegative calibration prediction reproduction tolerance.}
}
\value{Prediction returns one record per window. Fitting returns paired records
and N, RMSE, MAE, bias, NSE and correlation. Calibration returns the directory,
parameter pools, summary and best candidates. Best evaluation returns separate
calibration and validation metrics after prediction reproduction.}
\details{Source, dependency builds, native engines, input snapshots and records
are checked for changes. Model equations are unchanged. Satellite skin temperature
is not established to be identical to the model water layer. Windows uses original
bundled executables; DLL availability and actual physics require local acceptance.}
\seealso{\code{\link{cali_ensemble}}, \code{\link{get_output}}}

