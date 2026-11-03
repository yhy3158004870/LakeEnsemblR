"""Clone the current, repaired 69-lake YAMLs into an independent experiment.

Run in Windows Python or WSL. This file does not run R or any lake model.
"""
from pathlib import Path
import copy
import csv
import hashlib
import io
import json
import math
import os
import re
import yaml

MODELS = ("FLake", "GLM", "GOTM", "Simstrat")
SELECTED = ("akesaiqin", "namco")
VARIANT = "r4_ice_20261103_core12"
ICE_SPEC = {"lower": 0.9, "upper": 3.0, "initial": 1.0, "log": False}
MET_SPEC = {
    "wind_speed": {"lower": 0.5, "upper": 2.0, "initial": 1.0, "log": False},
    "swr": {"lower": 0.5, "upper": 1.5, "initial": 1.0, "log": False},
}
NATIVE = {
    "FLake": ("FLakeR", "flake.nml"), "GLM": ("GLM3r", "glm3.nml"),
    "GOTM": ("GOTMr", "gotm.yaml"), "Simstrat": ("SimstratR", "simstrat.par"),
}


class LERLoader(yaml.SafeLoader):
    pass


LERLoader.yaml_implicit_resolvers = {
    k: [(tag, rule) for tag, rule in rules if tag != "tag:yaml.org,2002:timestamp"]
    for k, rules in yaml.SafeLoader.yaml_implicit_resolvers.items()
}


def require(ok, message):
    if not ok:
        raise ValueError(message)


def host_path(value):
    """Interpret an existing Windows/WSL path on the current Python host."""
    s = str(value).replace("\\", "/")
    if os.name != "nt" and re.match(r"^[A-Za-z]:/", s):
        s = "/mnt/" + s[0].lower() + s[2:]
    elif os.name == "nt" and re.match(r"^/mnt/[A-Za-z]/", s):
        s = s[5].upper() + ":/" + s[7:]
    return Path(s).expanduser()


def windows_text(path):
    s = Path(path).as_posix()
    return s[5].upper() + ":/" + s[7:] if re.match(r"^/mnt/[A-Za-z]/", s) else s


def sha(data):
    return hashlib.sha256(data).hexdigest()


def csv_read(path):
    raw = Path(path).read_bytes()
    for enc in ("utf-8-sig", "gb18030"):
        try:
            return list(csv.DictReader(io.StringIO(raw.decode(enc))))
        except UnicodeError:
            continue
    raise ValueError(f"CSV编码无法识别: {path}")


def csv_bytes(rows):
    require(bool(rows), "CSV不能为空")
    fields = list(dict.fromkeys(k for row in rows for k in row))
    out = io.StringIO(newline="")
    writer = csv.DictWriter(out, fields, lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
    return out.getvalue().encode("utf-8-sig")


def yaml_text(cfg):
    """Match the three-space layout required by the installed LER text reader."""
    def scalar(value):
        if isinstance(value, bool):
            return "true" if value else "false"
        if isinstance(value, (int, float)):
            require(math.isfinite(value), "YAML数值不是有限值")
            return re.sub(r"^(-?\d+)(e[+-]\d+)$", r"\1.0\2", format(value, ".17g"))
        require(isinstance(value, str), f"不支持的YAML值: {value!r}")
        if re.fullmatch(r"\d{4}-\d\d-\d\d \d\d:\d\d:\d\d", value):
            return value
        if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_./-]*", value) and value.lower() not in {
            "null", "true", "false", "yes", "no", "on", "off"
        }:
            return value
        return json.dumps(value, ensure_ascii=False)

    lines = []
    def emit(mapping, depth=0):
        for key, value in mapping.items():
            require(bool(re.fullmatch(r"[A-Za-z_][A-Za-z0-9_./-]*", key)), f"非法YAML键: {key}")
            prefix = " " * depth + key + ":"
            if isinstance(value, dict):
                lines.append(prefix + ("" if value else " {}"))
                if value:
                    emit(value, depth + 3)
            elif isinstance(value, list):
                require(bool(value), f"空列表: {key}")
                lines.append(prefix)
                lines.extend(" " * (depth + 3) + "- " + scalar(v) for v in value)
            else:
                lines.append(prefix + " " + scalar(value))
    emit(cfg)
    text = "\n".join(lines) + "\n"
    require(yaml.load(text, Loader=LERLoader) == cfg, "YAML读回不一致")
    return text.encode("utf-8")


def simstrat_json(data):
    # Simstrat .par uses JSON with ! comments and occasionally trailing commas.
    text = data.decode("utf-8-sig")
    out, quoted, escaped, comment = [], False, False, False
    for c in text:
        if comment:
            if c == "\n":
                comment = False
                out.append(c)
            continue
        if not quoted and c == "!":
            comment = True
            continue
        out.append(c)
        if c == '"' and not escaped:
            quoted = not quoted
        escaped = c == "\\" and not escaped
    return json.loads(re.sub(r",\s*([}\]])", r"\1", "".join(out)))


def glm_evap_is_disabled(data):
    text = data.decode("utf-8-sig")
    # Remove Fortran comments outside quoted strings, then read the exact group.
    text = re.sub(r"(?m)!.*$", "", text)
    group = re.search(r"(?is)&debugging\b(.*?)(?:^\s*/|&end\b)", text, re.M)
    return bool(group and re.search(r"(?i)\bdisable_evap\s*=\s*(?:\.true\.|true\b|t\b)", group[1]))


def build_variant(project, registry, library, destination=None):
    project, registry, library = map(lambda p: host_path(p).resolve(), (project, registry, library))
    source = project / "yaml"
    target = host_path(destination).resolve() if destination else source / VARIANT
    require(source.is_dir() and target != source, "原YAML目录缺失或目标等于原目录")
    require(registry.is_file(), f"湖泊登记表不存在: {registry}")
    source_files = sorted(source.glob("*_LakeEnsemblR.yaml"))
    require(len(source_files) == 69, f"原目录应有69个YAML，实际{len(source_files)}")
    old_manifest = csv_read(source / "_yaml_manifest.csv")
    manifest_by_name = {r["name"]: r for r in old_manifest}
    registry_rows = csv_read(registry)
    registry_by_name = {r["name"].strip(): r for r in registry_rows}
    require(len(registry_by_name) == len(registry_rows) == 69, "登记表应为69个不重名湖泊")
    require(all(n in registry_by_name for n in SELECTED), "登记表缺少目标两湖")
    require(len(manifest_by_name) == len(old_manifest) == 69,
            "原YAML清单应为69个不重名湖泊")
    for name, row in manifest_by_name.items():
        try:
            spin = float(row["spin_up_days"])
        except (ValueError, TypeError, KeyError) as error:
            raise ValueError(f"无效的spin_up_days: {name}") from error
        require(math.isfinite(spin) and spin >= 0, f"spin_up_days必须为非负数: {name}")
    ids = []
    for name, row in registry_by_name.items():
        try:
            identifier = float(row.get("NAME_ID", ""))
        except (ValueError, TypeError) as error:
            raise ValueError(f"无效的NAME_ID: {name}") from error
        require(math.isfinite(identifier) and identifier > 0 and identifier == math.floor(identifier),
                f"NAME_ID必须为正整数: {name}")
        ids.append(int(identifier))
    require(len(set(ids)) == 69, "69湖NAME_ID不唯一")
    source_bytes = {str(p): p.read_bytes() for p in (registry, source / "_yaml_manifest.csv")}
    source_hashes = {p: sha(data) for p, data in source_bytes.items()}
    planned, designs, new_manifest, input_records = {}, [], [], []
    puhu_geometry = None
    previous_root = source / "r4_ice_20261102"
    previous_identity = {
        "previous_config_root": windows_text(previous_root),
        "checked": previous_root.is_dir(), "lakes": [],
        "comparison": "Master settings and actual input/native-template content SHA256; output filenames remain labels",
        "historical_snapshot_check": "The remaining-lakes R runner separately verifies the completed two sealed snapshots",
    }

    def remember(path):
        key = str(path)
        if key not in source_bytes:
            data = Path(path).read_bytes()
            source_bytes[key] = data
            source_hashes[key] = sha(data)
        return source_bytes[key]

    def plan(relative, data):
        relative = Path(relative).as_posix()
        require(relative not in planned or planned[relative] == data, f"文件冲突: {relative}")
        planned[relative] = data

    def rebase(value, label):
        if not isinstance(value, str) or value.upper() == "NULL" or value == "":
            return value
        p = host_path(value)
        p = (p if p.is_absolute() else source / p).resolve()
        require(p.is_file(), f"输入文件不存在 ({label}): {p}")
        drive = lambda path: re.match(r"^([A-Za-z]):/", windows_text(path))
        p_drive, target_drive = drive(p), drive(target)
        cross_drive = p_drive and target_drive and p_drive[1].lower() != target_drive[1].lower()
        if cross_drive:
            # Also needed under WSL: ../../d/... would be invalid in Windows R.
            data = remember(p)
            basename = re.sub(r"[^A-Za-z0-9_.-]", "_", p.name)
            relative = "_inputs/" + sha(data) + "_" + basename
            plan(relative, data)
        else:
            try:
                relative = os.path.relpath(p, target).replace("\\", "/")
            except ValueError as error:
                raise ValueError(f"无法生成输入相对路径 ({label}): {p}") from error
        require(not re.match(r"^[A-Za-z]:", relative), "禁止写入含盘符的YAML路径")
        input_records.append({"field": label, "path": windows_text(p), "bytes": p.stat().st_size,
                              "mtime_ns": p.stat().st_mtime_ns})
        return relative

    def rebase_files(node, label):
        if isinstance(node, dict):
            for k, v in node.items():
                node[k] = rebase(v, label + "/" + k) if k == "file" else rebase_files(v, label + "/" + k)
        elif isinstance(node, list):
            node = [rebase_files(v, label) for v in node]
        return node

    def content_sha(base, value):
        if not isinstance(value, str) or value.upper() == "NULL" or value == "":
            return value
        relative = Path(value.replace("\\", "/")).as_posix()
        if base == target and relative in planned:
            return sha(planned[relative])
        path = host_path(value)
        path = (path if path.is_absolute() else base / path).resolve()
        require(path.is_file(), f"已完成两湖配置对比缺少输入: {path}")
        key = str(path)
        if key not in source_hashes:
            digest = hashlib.sha256()
            with path.open("rb") as handle:
                for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                    digest.update(chunk)
            source_hashes[key] = digest.hexdigest()
        return source_hashes[key]

    def canonical_config(cfg, base):
        result = copy.deepcopy(cfg)
        def fingerprint(value):
            digest = content_sha(base, value)
            return "sha256=" + digest if isinstance(digest, str) and len(digest) == 64 else digest
        def files(node):
            if isinstance(node, dict):
                for key, value in node.items():
                    node[key] = fingerprint(value) if key == "file" else files(value)
            elif isinstance(node, list):
                node = [files(value) for value in node]
            return node
        result["location"]["hypsograph"] = fingerprint(result["location"]["hypsograph"])
        for section in ("input", "observations", "inflows", "outflows"):
            if section in result:
                result[section] = files(result[section])
        kw = result.get("input", {}).get("light", {}).get("Kw")
        if isinstance(kw, dict):
            for key, value in kw.items():
                if isinstance(value, str) and not value.startswith("sha256="):
                    kw[key] = fingerprint(value)
        elif isinstance(kw, str):
            result["input"]["light"]["Kw"] = fingerprint(kw)
        for model, value in result["config_files"].items():
            result["config_files"][model] = fingerprint(value)
        return result

    for source_yaml in source_files:
        cfg = yaml.load(remember(source_yaml).decode("utf-8-sig"), Loader=LERLoader)
        name = cfg["location"]["name"]
        require(name in registry_by_name and name in manifest_by_name, f"登记表/清单缺湖: {name}")
        require(source_yaml.name == f"{name}_LakeEnsemblR.yaml", "YAML文件名与湖名不一致")
        require(str(cfg["time"]["start"]) == "1979-01-01 00:00:00" and
                str(cfg["time"]["stop"]) == "2016-01-01 00:00:00" and
                float(cfg["time"]["time_step"]) == 3600 and float(cfg["output"]["time_step"]) == 86400,
                f"模拟时段或时间步长与已完成两湖方案不一致: {name}")
        require(cfg["input"]["ice"]["use"] is True, f"原配置未开启湖冰: {name}")
        require(set(cfg["calibration"]).issubset({"met", *MODELS, "MyLake"}),
                f"发现本方案未定义的率定参数组，停止以免误删: {name}")
        require(cfg["calibration"]["met"] == MET_SPEC, f"原公共率定范围已变化: {name}")
        require(all(not cfg["calibration"].get(m, {}) for m in (*MODELS, "MyLake")),
                f"发现原生率定参数，需先核对，防止误删: {name}")
        cfg = copy.deepcopy(cfg)
        puhu_profile_relative = None
        if name == "puhu":
            # The user already removed the redundant 70.2 m / zero-area row.
            # Only the NEW master YAML is adjusted; never edit the original CSV.
            hyp_path = host_path(cfg["location"]["hypsograph"])
            hyp_path = (hyp_path if hyp_path.is_absolute() else source / hyp_path).resolve()
            require(hyp_path.is_file(), f"Puhu湖盆CSV不存在: {hyp_path}")
            remember(hyp_path)
            bathy = csv_read(hyp_path)
            require(bool(bathy) and {"Depth_meter", "Area_meterSquared"}.issubset(bathy[0]),
                    "Puhu湖盆CSV必须有Depth_meter/Area_meterSquared")
            depths = [float(r["Depth_meter"]) for r in bathy]
            areas = [float(r["Area_meterSquared"]) for r in bathy]
            require(all(math.isfinite(x) for x in depths + areas), "Puhu湖盆数据含缺失/无穷")
            require(depths[0] == 0 and abs(depths[-1] - 70.0) < 1e-8 and areas[-1] == 0,
                    "Puhu湖盆应从0m开始、在70m结束且底面积为0；不要自动删除或改写原CSV")
            require(all(a < b for a, b in zip(depths, depths[1:])) and
                    all(a > b >= 0 for a, b in zip(areas, areas[1:])),
                    "Puhu深度必须严格递增，面积必须严格递减至唯一零底面积")
            old_depth, old_init = cfg["location"]["depth"], cfg["location"]["init_depth"]
            require(abs(float(old_init) - float(old_depth)) < 1e-8,
                    "Puhu原init_depth与depth不一致，需先核对水位设置")
            cfg["location"]["depth"] = cfg["location"]["init_depth"] = 70.0
            glm = cfg["model_parameters"]["GLM"]
            removed = []
            for key in list(glm):
                if key in ("morphometry/H", "morphometry/A", "morphometry/bsn_vals"):
                    removed.append(key)
                    del glm[key]
                elif key.endswith("/lake_depth"):
                    glm[key] = 70.0
                elif key == "morphometry/crest_elev":
                    glm[key] = float(cfg["location"]["elevation"])
            puhu_geometry = {
                "name": name, "source_csv": windows_text(hyp_path),
                "source_csv_sha256": source_hashes[str(hyp_path)],
                "previous_depth_m": old_depth, "previous_init_depth_m": old_init,
                "depth_m": 70, "init_depth_m": 70, "bottom_area_m2": 0,
                "hypsograph_rows": len(depths), "removed_stale_GLM_overrides": removed,
                "native_geometry_source": "Official export_location regenerates H,A,bsn_vals from unchanged CSV",
                "expected_GLM_bottom_H": float(cfg["location"]["elevation"]) - 70,
                "expected_GLM_crest_H": float(cfg["location"]["elevation"]),
            }
            profile_path = host_path(cfg["input"]["init_temp_profile"]["file"])
            profile_path = (profile_path if profile_path.is_absolute() else source / profile_path).resolve()
            require(profile_path.is_file(), f"Puhu初温CSV不存在: {profile_path}")
            remember(profile_path)
            profile = csv_read(profile_path)
            require(bool(profile) and {"Depth_meter", "Water_Temperature_celsius"}.issubset(profile[0]),
                    "Puhu初温CSV必须有Depth_meter/Water_Temperature_celsius")
            profile_depth = [float(r["Depth_meter"]) for r in profile]
            profile_temp = [float(r["Water_Temperature_celsius"]) for r in profile]
            require(all(math.isfinite(x) for x in profile_depth + profile_temp) and profile_depth[0] == 0 and
                    all(a < b for a, b in zip(profile_depth, profile_depth[1:])),
                    "Puhu初温剖面必须从0m开始、深度严格递增且数值完整")
            kept = [r for r, d in zip(profile, profile_depth) if d <= 70.0]
            removed_depths = [d for d in profile_depth if d > 70.0]
            require(bool(kept) and float(kept[-1]["Depth_meter"]) == 70.0,
                    "Puhu初温必须已有70m层；不进行温度插值或外推")
            require(all(abs(d - 70.2) < 1e-8 for d in removed_depths),
                    "Puhu初温70m以下发现非70.2m层，需核对后再改")
            if removed_depths:
                profile_data = csv_bytes(kept)
                puhu_profile_relative = "_inputs/puhu_init_depth70_" + sha(profile_data) + ".csv"
                plan(puhu_profile_relative, profile_data)
            puhu_geometry.update(
                original_init_profile=windows_text(profile_path),
                original_init_profile_sha256=source_hashes[str(profile_path)],
                init_profile_removed_depths_m=removed_depths,
                init_profile_retained_rows=len(kept),
                init_profile_retained_values_unchanged=True,
                new_init_profile_relative=puhu_profile_relative,
            )
        cfg["config_files"] = {m: cfg["config_files"][m] for m in MODELS}
        for section in ("model_parameters", "scaling_factors"):
            cfg.get(section, {}).pop("MyLake", None)
        light_kw = cfg.get("input", {}).get("light", {}).get("Kw")
        if isinstance(light_kw, dict):
            light_kw.pop("MyLake", None)
            for k, value in light_kw.items():
                if isinstance(value, str) and value.upper() != "NULL":
                    light_kw[k] = rebase(value, name + "/input/light/Kw/" + k)
        elif isinstance(light_kw, str):
            cfg["input"]["light"]["Kw"] = rebase(light_kw, name + "/input/light/Kw")
        cfg["location"]["hypsograph"] = rebase(cfg["location"]["hypsograph"], name + "/hypsograph")
        for section in ("input", "observations", "inflows", "outflows"):
            if section in cfg:
                cfg[section] = rebase_files(cfg[section], name + "/" + section)
        if puhu_profile_relative:
            cfg["input"]["init_temp_profile"]["file"] = puhu_profile_relative
        cfg["calibration"] = {"met": copy.deepcopy(MET_SPEC), **{m: {} for m in MODELS}}
        cfg["calibration"]["Simstrat"]["ModelParameters/p_sw_ice"] = copy.deepcopy(ICE_SPEC)
        for model, relative in cfg["config_files"].items():
            rel = Path(str(relative).replace("\\", "/"))
            require(not rel.is_absolute() and ".." not in rel.parts and rel.parts[0] == model,
                    f"原生配置路径必须位于{model}/: {relative}")
            native = source / rel
            if not native.is_file():
                package, basename = NATIVE[model]
                require(model != "GLM", "必须保留已修复的yaml/GLM配置，禁止回退官方默认模板")
                require(rel.as_posix() == model + "/" + basename, f"定制模板缺失: {native}")
                native = library / package / "extdata" / basename
            require(native.is_file(), f"缺少原生模板: {native}")
            data = remember(native)
            if model == "GLM":
                require(glm_evap_is_disabled(data), f"GLM未确认debugging.disable_evap=TRUE: {native}")
            elif model == "Simstrat":
                native_cfg = simstrat_json(data)
                require(native_cfg["ModelConfig"]["IceModel"] == 1, "Simstrat模板IceModel必须为1")
                require(native_cfg["ModelConfig"]["Forcing"] == 5, "Simstrat模板Forcing必须为5")
                require(native_cfg["ModelParameters"]["p_sw_ice"] == 1, "原Simstrat p_sw_ice初值必须为1")
            plan(rel, data)
            for parameter, spec in MET_SPEC.items():
                designs.append({"name": name, "model": model, "category": "met", "parameter": parameter, **spec})
            if model == "Simstrat":
                designs.append({"name": name, "model": model, "category": "Simstrat",
                                "parameter": "ModelParameters/p_sw_ice", **ICE_SPEC})
        plan(source_yaml.name, yaml_text(cfg))
        if previous_root.is_dir() and name in SELECTED:
            previous_file = previous_root / source_yaml.name
            require(previous_file.is_file(), f"旧四模型配置缺少已完成湖: {previous_file}")
            previous_cfg = yaml.load(remember(previous_file).decode("utf-8-sig"), Loader=LERLoader)
            require(canonical_config(previous_cfg, previous_root) == canonical_config(cfg, target),
                    f"新配置与已完成两湖方案存在实际设置或输入内容差异: {name}；保留现状，不修改旧目录")
            previous_identity["lakes"].append({"name": name, "passed": True})
        row = dict(manifest_by_name[name])
        row.update(variant=VARIANT, native_parameters_enabled="True", parameter_count="9",
                   NAME_ID=registry_by_name[name]["NAME_ID"],
                   yaml_file=windows_text(target / source_yaml.name))
        row["depth_m"] = format(float(cfg["location"]["depth"]), ".17g")
        configured_paths = {
            "meteo_file": cfg["input"]["meteo"]["file"],
            "hypsograph_file": cfg["location"]["hypsograph"],
            "init_temp_file": cfg["input"]["init_temp_profile"]["file"],
        }
        for key, relative in configured_paths.items():
            row["original_" + key] = row.get(key, "")
            row[key] = windows_text((target / relative).resolve())
        new_manifest.append(row)
    require(len(designs) == 69 * 9, "参数设计应为69×9行")
    require({r["name"] for r in new_manifest} == set(registry_by_name), "69湖登记表不一致")
    all_rows = []
    manifest_new_by_name = {r["name"]: r for r in new_manifest}
    for original in registry_rows:
        name = original["name"].strip()
        row = dict(original)
        row["name"] = name
        row["spin_up_days"] = manifest_by_name[name]["spin_up_days"]
        row["configured_depth_m"] = manifest_new_by_name[name]["depth_m"]
        all_rows.append(row)
    all_by_name = {r["name"]: r for r in all_rows}
    selected_rows = [all_by_name[name] for name in SELECTED]
    remaining_rows = [r for r in all_rows if r["name"] not in SELECTED]
    require(len(remaining_rows) == 67 and len(all_rows) == 69,
            "运行清单应严格排除已完成两湖，剩余67湖")
    plan("all_lakes.csv", csv_bytes(all_rows))
    plan("remaining_lakes.csv", csv_bytes(remaining_rows))
    plan("selected_lakes.csv", csv_bytes(selected_rows))
    plan("_yaml_manifest.csv", csv_bytes(new_manifest))
    plan("parameter_design.csv", csv_bytes(designs))
    plan("selected_parameter_design.csv", csv_bytes([r for r in designs if r["name"] in SELECTED]))
    plan("remaining_parameter_design.csv", csv_bytes([r for r in designs if r["name"] not in SELECTED]))
    plan("_input_inventory.csv", csv_bytes(input_records))
    plan("_completed_two_config_identity.json",
         (json.dumps(previous_identity, ensure_ascii=False, indent=2) + "\n").encode("utf-8"))
    require(puhu_geometry is not None, "未找到Puhu湖盆审计")
    plan("_puhu_geometry_audit.json", (json.dumps(puhu_geometry, ensure_ascii=False, indent=2) + "\n").encode("utf-8"))
    metadata = {
        "variant": VARIANT, "yaml_root": windows_text(target), "original_yaml_root": windows_text(source),
        "models": MODELS, "selected_lakes": SELECTED, "generated_lakes": 69,
        "completed_lakes_excluded_from_remaining_run": SELECTED,
        "remaining_lakes": [r["name"] for r in remaining_rows], "remaining_lake_count": 67,
        "remaining_run_ncores": 12,
        "spin_up_days_preserved": True, "met_calibration": MET_SPEC,
        "Simstrat_calibration": {"ModelParameters/p_sw_ice": ICE_SPEC},
        "model_parameter_counts": {"FLake": 2, "GLM": 2, "GOTM": 2, "Simstrat": 3},
        "calibration_counts_configured_in_R": [500, 2000],
        "puhu_depth_m": 70, "puhu_original_hypsograph_preserved": True,
        "note": "User-specified p_sw_ice search domain; keep ice physics and other settings unchanged. No models started.",
    }
    plan("_yaml_settings.json", (json.dumps(metadata, ensure_ascii=False, indent=2) + "\n").encode("utf-8"))
    plan("_source_sha256.csv", csv_bytes([{"path": windows_text(p), "sha256": digest}
                                         for p, digest in sorted(source_hashes.items())]))
    plan("_generated_sha256.csv", csv_bytes([{"relative_path": p, "sha256": sha(data)}
                                            for p, data in sorted(planned.items())]))
    # Precheck every destination before creating or changing any file.
    for relative, data in planned.items():
        path = target / relative
        require(not path.exists() or (path.is_file() and path.read_bytes() == data),
                f"目标已有不同内容，停止以免覆盖: {path}")
    for path, digest in source_hashes.items():
        require(sha(Path(path).read_bytes()) == digest, f"生成期间原文件发生变化: {path}")
    for relative, data in planned.items():
        path = target / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        if not path.exists():
            with path.open("xb") as handle:
                handle.write(data)
    print("REMAINING67_CONFIG_READY_NO_MODELS_STARTED")
    print("YAML:", windows_text(target))
    print("Generated lakes: 69; remaining: 67; excluded completed: akesaiqin, namco")
    print("Design rows: all 621; remaining 603; completed two 18")
    return metadata
