"""Create a local, byte-verified archive of the user's installed Windows library.

Run in the existing Windows/WSL notebook. No models or installers are launched.
The resulting archive stays on the user's computer; it is not uploaded anywhere.
"""
from pathlib import Path
import csv
import datetime as dt
import hashlib
import json
import os
import re
import shutil
import zipfile


def host_path(value):
    s = str(value).replace("\\", "/")
    if os.name != "nt" and re.match(r"^[A-Za-z]:/", s):
        s = "/mnt/" + s[0].lower() + s[2:]
    return Path(s)


def sha256_file(path):
    h = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def read_dcf(path):
    result = {}
    key = None
    for line in Path(path).read_text(encoding="utf-8-sig", errors="replace").splitlines():
        if line[:1].isspace() and key:
            result[key] += " " + line.strip()
        elif ":" in line:
            key, value = line.split(":", 1)
            result[key] = value.strip()
    return result


def snapshot_current_ler(
    iso="D:/Geography/R/dissertation_LakeEnsemblR/LER_window/"
        "MyLake_v121_ordering_isolated_20261029",
    archive_parent="C:/LER9003_archives",
):
    iso, archive_parent = host_path(iso).resolve(), host_path(archive_parent).resolve()
    library_name = "library_R4_6_mylake_v121_order9002"
    library = iso / library_name
    if not library.is_dir():
        raise FileNotFoundError(f"原隔离库不存在: {library}")
    if any(p.name.startswith("00LOCK") for p in library.iterdir()):
        raise RuntimeError("隔离库包含安装锁，请待包安装完成后再备份")
    if iso == archive_parent or iso in archive_parent.parents:
        raise ValueError("备份目标必须位于原隔离环境之外")
    expected = {"LakeEnsemblR": "1.2.9.9003", "MyLakeR": "0.0.1.9002"}
    packages = []
    for package in sorted(library.iterdir()):
        description = package / "DESCRIPTION"
        if description.is_file():
            meta = read_dcf(description)
            packages.append({"package": meta.get("Package", package.name),
                             "version": meta.get("Version", ""),
                             "built": meta.get("Built", "")})
    versions = {p["package"]: p["version"] for p in packages}
    for package, version in expected.items():
        if versions.get(package) != version:
            raise RuntimeError(f"{package}应为{version}，实际{versions.get(package)!r}；未创建备份")
    timestamp = dt.datetime.now(dt.timezone(dt.timedelta(hours=8))).strftime("%Y%m%dT%H%M%S_BJT")
    archive_parent.mkdir(parents=True, exist_ok=True)
    snapshot = archive_parent / ("LER_window_9003_" + timestamp)
    snapshot.mkdir(exist_ok=False)
    planned = [(p, Path(library_name) / p.relative_to(library))
               for p in sorted(library.rglob("*")) if p.is_file()]
    driver_names = ["LER69.R", "setup_helpers.R", "Restart_LER_window.R",
                    "LER_window_open_env.R", "MyLake_v121_ordering.Rproj"]
    for name in driver_names:
        p = iso / name
        if not p.is_file():
            raise FileNotFoundError(f"安装环境文件缺失，未完成备份: {p}")
        planned.append((p, Path(name)))
    for name in ["research_cfg_template.rds", "window_paths.rds",
                 "contracts69_manifest.csv", "isolated_install_receipt.rds",
                 "installed_verification.rds", "source_provenance.rds"]:
        p = iso / "records" / name
        if p.is_file():
            planned.append((p, Path("records") / name))
    contracts = iso / "output_contracts"
    if not contracts.is_dir():
        raise FileNotFoundError(f"原时间契约目录缺失: {contracts}")
    planned += [(p, Path("output_contracts") / p.relative_to(contracts))
                for p in sorted(contracts.rglob("*")) if p.is_file()]
    manifest = []
    for i, (source, relative) in enumerate(planned, 1):
        if source.is_symlink():
            raise RuntimeError(f"发现符号链接，停止以避免不完整备份: {source}")
        before = sha256_file(source)
        target = snapshot / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
        if sha256_file(target) != before or sha256_file(source) != before:
            raise RuntimeError(f"复制期间源文件改变或副本不一致: {source}")
        manifest.append({"relative_path": relative.as_posix(),
                         "bytes": source.stat().st_size, "sha256": before})
        if i % 1000 == 0:
            print(f"已核验复制 {i}/{len(planned)} 个文件")
    def write_csv(name, rows):
        with (snapshot / name).open("w", encoding="utf-8-sig", newline="") as stream:
            writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
            writer.writeheader()
            writer.writerows(rows)
    write_csv("snapshot_files_sha256.csv", manifest)
    write_csv("installed_packages.csv", packages)
    metadata = {"schema": "LER9003-Windows-local-snapshot-v1", "original_iso": str(iso),
                "library_directory": library_name, "timestamp_BJT": timestamp,
                "files": len(manifest), "models_started": False,
                "contains_research_results": False, "contains_user_lake_inputs": False,
                "restore": "Restore to the recorded original ISO path on Windows with the same R 4.6 architecture; preserve existing directories."}
    (snapshot / "snapshot_metadata.json").write_text(
        json.dumps(metadata, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    archive = snapshot.with_suffix(".zip")
    with zipfile.ZipFile(archive, "x", zipfile.ZIP_DEFLATED,
                         allowZip64=True, strict_timestamps=False) as output:
        for path in sorted(snapshot.rglob("*")):
            if path.is_file():
                output.write(path, path.relative_to(snapshot.parent).as_posix())
    with zipfile.ZipFile(archive) as check:
        for row in manifest:
            h = hashlib.sha256()
            member = snapshot.name + "/" + row["relative_path"]
            with check.open(member) as stream:
                for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                    h.update(chunk)
            if h.hexdigest() != row["sha256"]:
                raise RuntimeError(f"压缩包内容与核验清单不一致: {member}")
    archive.with_suffix(".zip.sha256").write_text(sha256_file(archive) + "\n", encoding="utf-8")
    print("CURRENT_WINDOWS_LER9003_LOCAL_ARCHIVE_VERIFIED_NO_MODELS_STARTED")
    print("本机安装包:", archive)
    print("未压缩的已核验副本:", snapshot)
    return archive


if __name__ == "__main__":
    snapshot_current_ler()
