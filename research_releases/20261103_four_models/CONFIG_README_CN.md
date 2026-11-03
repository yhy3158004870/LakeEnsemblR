# 完整配置生成：剩余67湖，12进程方案

在原Jupyter环境打开 `Prepare_CONFIG_remaining67_20261103.ipynb`，核对第一个代码单元的C盘项目、D盘隔离环境和登记表路径，然后顺序运行三个代码单元。完整Python代码已经嵌入notebook，不依赖另外下载 `.py` 文件。若当前Python环境缺少PyYAML，先执行 `%pip install pyyaml`。

输入来源为当前电脑上的原始69湖YAML、测深、初温、强迫及原生模板。登记表自动查找：

- `C:/Geography/R/dissertation_LakeEnsemblR/lake_joinWan_pts_70L.csv`
- `C:/Geography/GLM_model/simstratdata/sim1_input/lake_joinWan_pts_70L.csv`

若两个位置同时存在而湖名/NAME_ID不同，需要在第一个代码单元明确填写 `LAKES_CSV`。编码支持UTF-8及GB18030。

新输出目录为 `C:/Geography/R/dissertation_LakeEnsemblR/yaml/r4_ice_20261103_core12`。旧的 `yaml/r4_ice_20261102` 和已完成两湖的 `D:/LER4_ice_20261102/n500` 保留。

生成内容：

| 文件 | 内容 |
|---|---|
| 69个 `*_LakeEnsemblR.yaml` | 四模型主配置；时间和其他物理设置沿用原方案 |
| `all_lakes.csv` | 69湖实际NAME_ID、原始登记表字段、spin_up_days、配置湖深 |
| `remaining_lakes.csv` | 剩余67湖，严格排除akesaiqin、namco |
| `selected_lakes.csv` | 已完成两湖登记记录，用于核对；不是本轮运行清单 |
| `parameter_design.csv` | 四模型每湖2+2+2+3项，共621行 |
| `remaining_parameter_design.csv` | 剩余67湖参数设计，共603行 |
| `_yaml_manifest.csv` | 新YAML路径、NAME_ID、实际湖深及输入路径；保留original_*路径列 |
| `_puhu_geometry_audit.json` | Puhu70m测深/初温/GLM几何覆盖修正证据 |
| `_completed_two_config_identity.json` | 已完成两湖与新配置的主设置及输入/原生模板内容同一性检查 |
| `_source_sha256.csv` | 检查过的原配置、登记表和模板等来源文件SHA256 |
| `_generated_sha256.csv` | 本轮所有生成配置文件的SHA256；R入口会核对 |

四模型为FLake、GLM、GOTM和Simstrat。前三者各率定wind_speed(0.5–2)和swr(0.5–1.5)；Simstrat再增加ModelParameters/p_sw_ice(0.9–3)，初值均1、线性采样。p_sw_ice范围是用户指定经验探索范围。LHC500或2000、12进程由单独的R入口设置；本notebook不会启动任何模型。

Puhu必须使用用户已经删除70.2m重复零面积行的CSV：底深70m、底面积0。生成器在新配置中同步depth/init_depth=70，删除旧GLM H/A/bsn_vals覆盖；原初温若有70.2m行，则在新目录生成只保留原有0–70m数据的副本。原测深和初温文件不修改。

存在旧四模型配置目录时，对akesaiqin和namco的主设置、实际输入内容及原生模板内容做核对。正式运行入口还会对照已封存两湖运行中的输入快照，避免仅凭当前可变原文件判断一致性。

成功标志：`REMAINING67_CONFIG_READY_NO_MODELS_STARTED`。此时只生成配置，尚未正式模拟。继续使用本次发布的剩余67湖R入口，模型名单、参数范围和评价定义不变，工作进程改为12。

同内容重复运行不会覆盖文件；目标已有不同内容或检查发现科学设置改变时，代码会停止并保留现有文件。
