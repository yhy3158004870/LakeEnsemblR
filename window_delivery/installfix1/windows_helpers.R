# [LER-WINDOW NEW SUPPORT FILE] This entire support script is absent from official LER.
# Shared installer/preflight helpers. No credentials or environment values are logged.
.ler_stop <- function(...) stop(..., call. = FALSE)
.ler_path <- function(path, must_work = TRUE) {
  if (length(path) != 1L || is.na(path) || !nzchar(path)) .ler_stop("路径必须是非空文本。")
  path <- path.expand(path)
  if (grepl("^[A-Za-z]:[^/\\\\]", path)) .ler_stop("不接受磁盘相对路径，请使用 D:/folder。")
  if (!grepl("^[/\\\\]|^[A-Za-z]:[/\\\\]", path)) path <- file.path(getwd(), path)
  normalizePath(path, winslash = "/", mustWork = must_work)
}
.ler_relative_file <- function(root, path, must_work = TRUE) {
  if (length(path) != 1L || is.na(path) || !nzchar(path) ||
      grepl("^(?:[/\\\\]|[A-Za-z]:)", path, perl = TRUE) ||
      any(strsplit(gsub("\\\\", "/", path), "/", fixed = TRUE)[[1L]] == ".."))
    .ler_stop("不安全的包内相对路径: ", path)
  result <- .ler_path(file.path(root, path), must_work)
  prefix <- paste0(.ler_path(root), "/")
  if (!startsWith(tolower(result), tolower(prefix))) .ler_stop("路径超出代码包: ", path)
  result
}
.ler_sha256 <- function(path) {
  if (!file.exists(path) || dir.exists(path)) .ler_stop("摘要对象不是文件: ", path)
  if (requireNamespace("digest", quietly = TRUE))
    return(tolower(digest::digest(file = path, algo = "sha256", serialize = FALSE)))
  if (.Platform$OS.type == "windows") {
    exe <- Sys.which("certutil")
    if (!nzchar(exe)) .ler_stop("缺少 Windows certutil，无法校验 SHA256；请恢复系统工具后重试。")
    output <- system2(exe, c("-hashfile", shQuote(.ler_path(path)), "SHA256"), stdout = TRUE, stderr = TRUE)
  } else if (nzchar(Sys.which("sha256sum"))) {
    output <- system2(Sys.which("sha256sum"), shQuote(.ler_path(path)), stdout = TRUE, stderr = TRUE)
  } else if (nzchar(Sys.which("shasum"))) {
    output <- system2(Sys.which("shasum"), c("-a", "256", shQuote(.ler_path(path))), stdout = TRUE, stderr = TRUE)
  } else .ler_stop("没有可用的 SHA256 工具。")
  if (!is.null(attr(output, "status")) && attr(output, "status") != 0L)
    .ler_stop("SHA256 工具执行失败。")
  # [LER-WINDOW INSTALL FIX 1] certutil can emit legacy-code-page Chinese
  # bytes in a UTF-8 R process. Hashes are ASCII; inspect bytes without decoding
  # localized headings. Do not change the locale or discard invalid bytes.
  candidates <- if (.Platform$OS.type == "windows")
    gsub("[ \t\r\n]", "", output, useBytes = TRUE) else
    sub(" .*", "", output, useBytes = TRUE)
  hit <- candidates[grepl("^[0-9A-Fa-f]{64}$", candidates, useBytes = TRUE)]
  if (length(hit) != 1L) .ler_stop("不能可靠解析 SHA256 工具输出。")
  tolower(hit)
}
.ler_verify_file <- function(path, expected) {
  if (length(expected) != 1L || !grepl("^[[:xdigit:]]{64}$", expected)) .ler_stop("manifest 缺少有效 SHA256。")
  actual <- .ler_sha256(path)
  if (!identical(actual, tolower(expected))) .ler_stop("SHA256 不一致，停止使用归档: ", basename(path))
  invisible(actual)
}
.ler_vendor_manifest <- function(root) {
  file <- file.path(root, "vendor", "manifest.csv")
  if (!file.exists(file)) .ler_stop("缺少 vendor/manifest.csv。")
  x <- read.csv(file, stringsAsFactors = FALSE, check.names = FALSE, fileEncoding = "UTF-8")
  required <- c("package", "version", "repository", "commit", "archive", "url", "sha256", "needs_compilation")
  if (!all(required %in% names(x)) || !nrow(x) || anyNA(x[, required])) .ler_stop("vendor manifest 字段不完整。")
  if (anyDuplicated(x$package) || any(!grepl("^[A-Za-z][A-Za-z0-9.]*$", x$package)) ||
      any(!grepl("^[[:xdigit:]]{40}$", x$commit)) || any(!grepl("^[[:xdigit:]]{64}$", x$sha256)) ||
      any(!x$needs_compilation %in% c("yes", "no"))) .ler_stop("vendor manifest 的包名、提交或摘要无效。")
  for (i in seq_len(nrow(x))) {
    expected_url <- paste0("https://codeload.github.com/", x$repository[i], "/tar.gz/", x$commit[i])
    if (!identical(x$url[i], expected_url)) .ler_stop("依赖 URL 未指向固定提交: ", x$package[i])
    .ler_relative_file(root, x$archive[i], must_work = FALSE)
  }
  x
}
.ler_read_description <- function(path) {
  d <- read.dcf(path)
  if (nrow(d) != 1L || !all(c("Package", "Version") %in% colnames(d))) .ler_stop("DESCRIPTION 缺少 Package/Version: ", path)
  as.list(d[1L, ])
}
.ler_archive_description <- function(path, dest) {
  entries <- utils::untar(path, list = TRUE)
  normalized <- gsub("\\\\", "/", entries)
  if (any(grepl("^(?:/|[A-Za-z]:)", normalized, perl = TRUE)) ||
      any(vapply(strsplit(normalized, "/", fixed = TRUE), function(z) any(z == ".."), logical(1))))
    .ler_stop("源归档含不安全路径。")
  desc <- entries[grepl("^[^/]+/DESCRIPTION$", normalized)]
  if (length(desc) != 1L) .ler_stop("源归档不是单一 R 包: ", basename(path))
  dir.create(dest, recursive = TRUE, showWarnings = FALSE)
  utils::untar(path, files = desc, exdir = dest)
  .ler_read_description(file.path(dest, desc))
}
.ler_dependencies <- function(description) {
  text <- unlist(description[intersect(c("Depends", "Imports", "LinkingTo"), names(description))], use.names = FALSE)
  text <- text[!is.na(text)]
  text <- paste(text, collapse = ",")
  if (!nzchar(text)) return(data.frame(package = character(), operator = character(), version = character()))
  entries <- trimws(strsplit(text, ",", fixed = TRUE)[[1L]])
  parsed <- lapply(entries[nzchar(entries)], function(x) {
    match <- regmatches(x, regexec("^([A-Za-z][A-Za-z0-9.]*)[[:space:]]*(?:\\(([<>=]+)[[:space:]]*([0-9][0-9A-Za-z.-]*)\\))?$", x, perl = TRUE))[[1L]]
    if (length(match) != 4L) .ler_stop("不能解析依赖声明: ", x)
    data.frame(package = match[2L], operator = match[3L], version = match[4L], stringsAsFactors = FALSE)
  })
  do.call(rbind, parsed)
}
.ler_version_satisfies <- function(actual, operator, required) {
  if (!nzchar(operator)) return(TRUE)
  cmp <- utils::compareVersion(as.character(actual), required)
  switch(operator, ">=" = cmp >= 0, ">" = cmp > 0, "<=" = cmp <= 0,
         "<" = cmp < 0, "==" = cmp == 0, "=" = cmp == 0, .ler_stop("不支持版本比较符: ", operator))
}
.ler_topological_order <- function(descriptions, external = character()) {
  done <- external; pending <- names(descriptions); answer <- character()
  while (length(pending)) {
    ready <- pending[vapply(pending, function(p) all(.ler_dependencies(descriptions[[p]])$package %in% done), logical(1))]
    if (!length(ready)) .ler_stop("包依赖存在缺项或循环: ", paste(pending, collapse = ", "))
    answer <- c(answer, ready); done <- c(done, ready); pending <- setdiff(pending, ready)
  }
  answer
}
.ler_cli_options <- function(args) {
  result <- list(); i <- 1L
  while (i <= length(args)) {
    arg <- args[i]
    if (arg %in% c("--offline", "--allow-source-cran", "--help")) {
      result[[sub("^--", "", arg)]] <- TRUE; i <- i + 1L
    } else if (arg %in% c("--lib", "--bundle", "--cran", "--cran-cache", "--report")) {
      if (i == length(args)) .ler_stop("选项缺少值: ", arg)
      result[[sub("^--", "", arg)]] <- args[i + 1L]; i <- i + 2L
    } else .ler_stop("未知选项: ", arg)
  }
  result
}
