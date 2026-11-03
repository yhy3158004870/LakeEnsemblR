# Copy this complete cell into a Windows or WSL notebook; no downloads required.
from pathlib import Path
import os, datetime, zipfile

run = "D:/LER4_ice_20261102/n500"
if os.name != "nt" and run[1:3] == ":/":
    run = "/mnt/" + run[0].lower() + run[2:]
root = Path(run)
files = [root / "two_lake_run_index.csv"]
for lake in ("akesaiqin", "namco"):
    base = root / lake
    files.append(base / "phase_times.csv")
    for name in ("request.rds", "preflight.rds", "calibration.rds", "evaluation.rds", "report.rds"):
        files.extend([base / name, base / (name + ".sha256")])
    files.extend(p for p in (base / "report").glob("*") if p.is_file())
    for name in ("final_metrics.csv", "best_by_calibration_RMSE.csv", "candidate_success_fractions.csv",
                 "engine_packages.csv", "function_manifest.csv", "sessionInfo.txt", "workflow_sources.csv"):
        files.append(base / "c" / name)
    files.extend((base / "c").glob("params_*.csv"))
    files.extend((base / "c").glob("spec_*.csv"))
missing = [str(p) for p in files if not p.is_file()]
if missing:
    raise FileNotFoundError("缺少结果文件：\n" + "\n".join(missing))
out = root.parent / ("two_lake_results_" + datetime.datetime.now().strftime("%Y%m%dT%H%M%S_%f") + ".zip")
with zipfile.ZipFile(out, "x", compression=zipfile.ZIP_DEFLATED) as archive:
    for path in sorted(set(files)):
        archive.write(path, path.relative_to(root).as_posix())
print("TWO_LAKE_RESULTS_ZIP_READY\n" + str(out))
