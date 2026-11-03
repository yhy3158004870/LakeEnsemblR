"""Collect small completed-run evidence without running R or editing any result."""
from pathlib import Path
import csv
import datetime as dt
import hashlib
import io
import json
import os
import zipfile

def local_path(value):
    text = str(value).replace("\\", "/")
    if os.name != "nt" and len(text) >= 3 and text[1:3] == ":/":
        text = "/mnt/" + text[0].lower() + text[2:]
    return Path(text)

def collect_two_lake_results(
    run_root="D:/LER4_ice_20261102/n500",
    config_root="C:/Geography/R/dissertation_LakeEnsemblR/yaml/r4_ice_20261102",
    include_ice=True,
):
    root, config = local_path(run_root), local_path(config_root)
    index_file = root / "two_lake_run_index.csv"
    with index_file.open(encoding="utf-8-sig", newline="") as handle:
        rows = list(csv.DictReader(handle))
    selected = {row["name"]: row for row in rows}
    lakes = ("akesaiqin", "namco")
    if any(name not in selected or selected[name]["calibration_status"] != "ok" or
           selected[name]["evaluation_status"] != "ok" for name in lakes):
        raise ValueError("两湖率定与评价尚未全部完成；未打包。")
    files, skipped = {}, []

    def add(path, archive_name, required=False, max_mb=8):
        if not path.is_file():
            if required:
                raise FileNotFoundError(path)
            return
        if path.stat().st_size > max_mb * 1024**2:
            if required:
                raise ValueError(f"必要文件超过{max_mb}MB，请保留原文件并核对: {path}")
            skipped.append({"file": str(path), "reason": f"larger than {max_mb}MiB"})
            return
        if path.is_symlink():
            raise ValueError(f"不接受符号链接: {path}")
        files[str(archive_name).replace("\\", "/")] = path

    add(index_file, index_file.name, required=True)
    report_names = ("model_metrics.csv", "ensemble4_metrics.csv", "selected_parameters.csv",
                    "parameter_response.csv", "pairs_models_ensemble4.csv", "RMSE_by_split.png", "READ_ME.txt")
    for lake in lakes:
        base = root / lake
        for filename in report_names:
            add(base / "report" / filename, f"{lake}/report/{filename}", required=True)
        add(base / "phase_times.csv", f"{lake}/phase_times.csv", required=True)
        for receipt in ("request.rds", "preflight.rds", "calibration.rds", "evaluation.rds", "report.rds"):
            for ending in ("", ".sha256"):
                name = receipt + ending
                add(base / name, f"{lake}/{name}", required=True)
        for name in ("serial_status.csv", "parallel_status.csv", "workers.log"):
            add(base / "v" / name, f"{lake}/v/{name}")
        small = ("final_metrics.csv", "best_by_calibration_RMSE.csv", "candidate_success_fractions.csv",
                 "calibration_summary.csv", "context.rds", "context_integrity.csv", "metadata.rds",
                 "engine_packages.csv", "function_manifest.csv", "sessionInfo.txt", "workflow_sources.csv",
                 "live_input_files.csv", "workflow_R4ice.R", "recovery_helper_rev3.R")
        for name in small:
            add(base / "c" / name, f"{lake}/c/{name}")
        for model in ("FLake", "GLM", "GOTM", "Simstrat"):
            for prefix in ("params_", "spec_"):
                name = prefix + model + ".csv"
                add(base / "c" / name, f"{lake}/c/{name}", required=True)
        if include_ice:
            sim = base / "c" / "final" / "Simstrat"
            for path in sorted(sim.rglob("*")):
                if not path.is_file():
                    continue
                name = path.name.lower()
                ice = path.suffix.lower() == ".dat" and ("iceh" in name or "snowh" in name)
                metadata = name in {"simstrat.par", "native_config.par", "native_surface.rds", "status.csv",
                                    "contract.csv", "engine_console.log", "warnings.txt"}
                if ice or metadata:
                    add(path, path.relative_to(root).as_posix(), max_mb=5)
    for name in ("selected_lakes.csv", "selected_parameter_design.csv", "_yaml_settings.json",
                 "_puhu_geometry_audit.json", "_runner_sha256.json"):
        add(config / name, "configuration/" + name)
    for lake in lakes:
        name = lake + "_LakeEnsemblR.yaml"
        add(config / name, "configuration/" + name)
    # Include the most recent optional derived analysis, if already created.
    analyses = sorted(p for p in root.parent.glob("analysis_two_lakes_*") if p.is_dir())
    if analyses:
        for path in sorted(analyses[-1].glob("*")):
            if path.is_file():
                add(path, "derived_analysis/" + path.name)
    target_dir = root.parent / "deliveries"
    target_dir.mkdir(parents=True, exist_ok=True)
    stamp = dt.datetime.now().strftime("%Y%m%dT%H%M%S")
    target = target_dir / f"two_lake_results_{stamp}.zip"
    manifest = []
    with zipfile.ZipFile(target, "x", compression=zipfile.ZIP_DEFLATED) as archive:
        for name, path in sorted(files.items()):
            data = path.read_bytes()
            archive.writestr(name, data)
            manifest.append({"file": name, "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()})
        text = io.StringIO(newline="")
        writer = csv.DictWriter(text, fieldnames=("file", "bytes", "sha256"), lineterminator="\n")
        writer.writeheader(); writer.writerows(manifest)
        archive.writestr("COLLECTION_SHA256.csv", text.getvalue().encode("utf-8-sig"))
        archive.writestr("COLLECTION_NOTES.json", json.dumps({"run_root": str(root), "lakes": lakes,
            "skipped": skipped, "scope": "read-only small result evidence; no forcing, executable, or full candidate folders"},
            ensure_ascii=False, indent=2).encode("utf-8"))
    print("TWO_LAKE_RESULTS_ZIP_READY")
    print(target)
    print(f"{target.stat().st_size / 1024**2:.2f} MB; {len(files)} files")
    return target

if __name__ == "__main__":
    collect_two_lake_results()
