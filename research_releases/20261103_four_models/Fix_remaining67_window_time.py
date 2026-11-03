"""Update only the new remaining-67 runner after the midnight display bug."""
from pathlib import Path
import hashlib
import json
import os
import urllib.request

OLD_SHA = "8b757a08b79f3ef7889a228feb067dd7062c14582158bc433d3580a3f71c2a50"
NEW_SHA = "66957a5556f24dd99bb577d5d88d900f972845a82b09d60d4e7492c98ce2c989"
URL = ("https://raw.githubusercontent.com/yhy3158004870/LakeEnsemblR/"
       "codex/research4-20261103/research_releases/20261103_four_models/"
       "Run_remaining67_R4ice_12.R")

def local_path(s):
    s = str(s).replace("\\", "/")
    if os.name != "nt" and len(s) >= 3 and s[1:3] == ":/":
        s = "/mnt/" + s[0].lower() + s[2:]
    return Path(s)

def fix_remaining67_window_time(config_root, result_root, data=None):
    root = local_path(config_root)
    script = root / "Run_remaining67_R4ice_12.R"
    raw = script.read_bytes()
    canonical = raw.decode("utf-8-sig").replace("\r\n", "\n").encode("utf-8")
    assert hashlib.sha256(canonical).hexdigest() in (OLD_SHA, NEW_SHA), "脚本不是预期版本，未修改"
    if hashlib.sha256(raw).hexdigest() != NEW_SHA:
        requests = list(local_path(result_root).glob("*/request.rds"))
        if requests:
            raise RuntimeError("已有67湖研究请求，保留现状，未修改：" + str(requests))
        if data is None:
            with urllib.request.urlopen(URL, timeout=60) as response:
                data = response.read()
        assert hashlib.sha256(data).hexdigest() == NEW_SHA, "修复文件校验失败，未修改"
        backup = script.with_name(script.name + ".before_window_time_fix")
        if backup.exists() and backup.read_bytes() != raw:
            raise RuntimeError("已有不同备份，未修改：" + str(backup))
        if not backup.exists():
            backup.write_bytes(raw)
        temporary = script.with_name(script.name + ".windowfix.tmp")
        temporary.write_bytes(data)
        temporary.replace(script)
    manifest = root / "_runner_sha256.json"
    if manifest.exists():
        hashes = json.loads(manifest.read_text(encoding="utf-8-sig"))
        hashes[script.name] = NEW_SHA
        manifest.write_bytes((json.dumps(hashes, ensure_ascii=False, indent=2) + "\n").encode("utf-8"))
    print("REMAINING67_WINDOW_TIME_FIX_APPLIED_NO_MODELS_STARTED")

if __name__ == "__main__":
    fix_remaining67_window_time(
        "C:/Geography/R/dissertation_LakeEnsemblR/yaml/r4_ice_20261103_core12",
        "D:/LER4_ice_20261103/n500_c12",
    )
