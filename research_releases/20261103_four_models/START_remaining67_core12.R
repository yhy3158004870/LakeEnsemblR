# Start or resume the 67 other lakes. The two completed lakes are checked, not rerun.
ISO <- paste0("D:/Geography/R/dissertation_LakeEnsemblR/LER_window/",
  "MyLake_v121_ordering_isolated_20261029")
source(file.path(ISO, "Restart_LER_window.R"), encoding = "UTF-8")
CONFIG4 <- "C:/Geography/R/dissertation_LakeEnsemblR/yaml/r4_ice_20261103_core12"
HELPER4 <- normalizePath(file.path(CONFIG4, "Resume_interrupted_calibration_9003_rev3.R"),
  winslash = "/", mustWork = TRUE)
RUNNER4 <- normalizePath(file.path(CONFIG4, "Run_remaining67_R4ice_12.R"),
  winslash = "/", mustWork = TRUE)
R4 <- new.env(parent = .GlobalEnv)
source(HELPER4, local = R4, encoding = "UTF-8")
source(RUNNER4, local = R4, encoding = "UTF-8")
# Explicit paths remain correct even when this START file is itself sourced.
R4$.rr_resume_source_file <- HELPER4
R4$.r4_source <- RUNNER4
stopifnot(identical(R4$.r4_sha(HELPER4),
  "74cfbe6a90da76df42c80b168edb45d4a1e78ba08dceac4976ffff84516e5afa"))
RESULT67 <- R4$run_remaining_lakes_r4(
  old_CFG = CFG,
  config_root = CONFIG4,
  results_root = "D:/LER4_ice_20261103/n500_c12",
  completed_root = "D:/LER4_ice_20261102/n500",
  num = 500L,
  ncores = 12L,
  continue_on_error = TRUE
)
