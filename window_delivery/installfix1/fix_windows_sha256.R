# [LER-WINDOW NEW SUPPORT FILE] Installer-only fix; no package/library changes.
.ler_fix1_source <- local({
  x<-unlist(lapply(sys.frames(),function(f)if(!is.null(f$ofile))f$ofile else NULL))
  if(!length(x))stop("Use source(..., encoding='UTF-8') to load this repair script")
  tail(x,1L)
})
.ler_fix1_dir <- normalizePath(dirname(.ler_fix1_source),winslash="/",mustWork=TRUE)

.ler_fix1_hash <- function(path) {
  if(!file.exists(path)||dir.exists(path))stop("Missing checksum file: ",path)
  if(requireNamespace("digest",quietly=TRUE))
    return(tolower(digest::digest(file=path,algo="sha256",serialize=FALSE)))
  if(.Platform$OS.type=="windows") {
    exe<-Sys.which("certutil")
    if(!nzchar(exe))stop("Windows certutil is unavailable")
    out<-system2(exe,c("-hashfile",shQuote(path),"SHA256"),stdout=TRUE,stderr=TRUE)
  } else {
    exe<-Sys.which("sha256sum")
    if(!nzchar(exe))stop("Need digest or sha256sum to verify the repair")
    out<-system2(exe,shQuote(path),stdout=TRUE,stderr=TRUE)
  }
  if(!is.null(attr(out,"status"))&&attr(out,"status")!=0L)stop("Checksum tool failed")
  candidate<-if(.Platform$OS.type=="windows")
    gsub("[ \t\r\n]","",out,useBytes=TRUE) else sub(" .*","",out,useBytes=TRUE)
  hit<-candidate[grepl("^[0-9A-Fa-f]{64}$",candidate,useBytes=TRUE)]
  if(length(hit)!=1L)stop("Expected exactly one ASCII SHA256")
  tolower(hit)
}

ler_apply_install_fix1 <- function(bundle_dir,patch_dir=.ler_fix1_dir) {
  root<-normalizePath(bundle_dir,winslash="/",mustWork=TRUE)
  patch_dir<-normalizePath(patch_dir,winslash="/",mustWork=TRUE)
  helper<-file.path(root,"tools","windows_helpers.R")
  manifest<-file.path(root,"SHA256SUMS.txt")
  fixed<-file.path(patch_dir,"windows_helpers.R")
  old_sha<-"1d27300f70859e2517cdd055b79c283e07630e3d9c9dcac0da04035bfabe9f80"
  new_sha<-"14a215e5f795374db52c31c0598eed760198156fce60a1575c29f27c6d493934"
  if(!file.exists(file.path(root,"install_windows.R")))stop("Wrong bundle directory")
  if(!identical(.ler_fix1_hash(fixed),new_sha))stop("Repair helper checksum mismatch")
  actual<-.ler_fix1_hash(helper)
  if(!actual %in% c(old_sha,new_sha))stop("Helper is a different/custom version; no files changed")
  lines<-readLines(manifest,encoding="UTF-8",warn=FALSE)
  if(!length(lines)||any(!grepl("^[0-9A-Fa-f]{64}  .+$",lines)))stop("Invalid release manifest")
  paths<-substring(lines,67L)
  if(anyDuplicated(paths))stop("Duplicate release checksum entries")
  at<-which(paths=="tools/windows_helpers.R")
  if(length(at)!=1L||!substring(lines[at],1L,64L) %in% c(old_sha,new_sha))
    stop("Unexpected helper record; no files changed")
  if(actual==new_sha&&substring(lines[at],1L,64L)==new_sha) {
    cat("Installer fix 1 is already applied.\n")
    return(invisible(TRUE))
  }
  backup<-file.path(dirname(root),"records",paste0("sha256_fix1_",format(Sys.time(),"%Y%m%d_%H%M%S")))
  if(dir.exists(backup))stop("Backup directory already exists; retry with a new timestamp")
  dir.create(backup,recursive=TRUE)
  backup_helper<-file.path(backup,"windows_helpers.R.before")
  backup_manifest<-file.path(backup,"SHA256SUMS.txt.before")
  if(!file.copy(helper,backup_helper)||!file.copy(manifest,backup_manifest))
    stop("Could not preserve original files; repair not started")
  success<-FALSE
  on.exit(if(!success) {
    file.copy(backup_helper,helper,overwrite=TRUE)
    file.copy(backup_manifest,manifest,overwrite=TRUE)
  },add=TRUE)
  if(!file.copy(fixed,helper,overwrite=TRUE))stop("Could not update helper")
  if(!identical(.ler_fix1_hash(helper),new_sha))stop("Updated helper checksum mismatch")
  lines[at]<-paste0(new_sha,"  tools/windows_helpers.R")
  staged<-file.path(backup,"SHA256SUMS.txt.updated")
  writeLines(enc2utf8(lines),staged,useBytes=TRUE)
  if(!file.copy(staged,manifest,overwrite=TRUE))stop("Could not update release manifest")
  if(!identical(readLines(manifest,encoding="UTF-8",warn=FALSE),lines))
    stop("Updated manifest verification failed")
  success<-TRUE
  writeLines(c("Installer fix 1: byte-safe localized SHA256 output.",
    paste0("old_helper_sha256=",old_sha),paste0("new_helper_sha256=",new_sha),
    "Only tools/windows_helpers.R and its SHA256SUMS entry changed."),
    file.path(backup,"repair_record.txt"))
  cat("Installer fix 1 applied successfully.\nBackup: ",backup,
      "\nNo installed packages or startup configuration were changed.\n",sep="")
  invisible(TRUE)
}
