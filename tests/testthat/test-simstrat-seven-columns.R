# Regression for the positional Simstrat 3.0.1 initialization protocol.
test_that("Simstrat export preserves temperature and writes seven freshwater fields", {
  project <- tempfile("simstrat-seven-")
  dir.create(project)
  on.exit(unlink(project, recursive = TRUE), add = TRUE)
  dir.create(file.path(project, "Simstrat"))
  writeLines(c("location:", "   depth: 50", "time:",
               '   start: "2010-01-01 00:00:00"', "init_temp_profile:",
               "   file: init.csv", "config_files:",
               "   Simstrat: Simstrat/simstrat.par"),
             file.path(project, "LakeEnsemblR.yaml"))
  writeLines(c('{', '  "Input": {', '    "Initial conditions": "unused.dat",',
               '    "Grid": 10', '  }', '}'),
             file.path(project, "Simstrat", "simstrat.par"))
  target <- file.path(project, "Simstrat", "init_cond.dat")
  original_wd <- getwd()
  original_tz <- Sys.getenv("TZ")
  for (depths in list(c(0, 2.5, 40), c(0.9, 2.5, 40))) {
    temperatures <- c(12.3456, 9.87654, 4.01234)
    write.csv(data.frame(Depth_meter = depths,
                         Water_Temperature_celsius = temperatures),
              file.path(project, "init.csv"), row.names = FALSE)
    export_init_cond("LakeEnsemblR.yaml", model = "Simstrat", print = FALSE,
                     folder = project)
    expect_identical(getwd(), original_wd)
    expect_identical(Sys.getenv("TZ"), original_tz)
    header <- strsplit(readLines(target, n = 1L), "\t", fixed = TRUE)[[1L]]
    expect_identical(header, c("Depth [m]", "U [m/s]", "V [m/s]", "T [deg C]",
                               "S [ppt]", "k [J/kg]", "eps [W/kg]"))
    fields <- count.fields(target, sep = "\t", skip = 1L, quote = "")
    expect_true(all(fields == 7L))
    x <- read.table(target, skip = 1L, header = FALSE, sep = "\t")
    z <- signif(depths, 4)
    t <- signif(temperatures, 4)
    if (depths[1L] > 0.001) { z <- c(0, z); t <- c(t[1L], t) }
    expect_equal(nrow(x), length(z))
    expect_equal(x[[1L]], -z)
    expect_equal(x[[2L]], rep(0, length(z)))
    expect_equal(x[[3L]], rep(0, length(z)))
    expect_equal(x[[4L]], t)
    expect_equal(x[[5L]], rep(0, length(z)))
    expect_equal(x[[6L]], rep(3e-6, length(z)))
    expect_equal(x[[7L]], rep(5e-10, length(z)))
    par <- configr::read.config(file.path(project, "Simstrat", "simstrat.par"))
    expect_identical(par$Input[["Initial conditions"]], "init_cond.dat")
    before <- readBin(target, "raw", n = file.info(target)$size)
    export_init_cond("LakeEnsemblR.yaml", model = "Simstrat", print = FALSE,
                     folder = project)
    expect_identical(readBin(target, "raw", n = file.info(target)$size), before)
  }
})
