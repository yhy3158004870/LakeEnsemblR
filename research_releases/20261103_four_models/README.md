# 69湖四模型：两湖分析、其余67湖12进程正式运行

发布日期：2026-11-03（北京时间）。本目录为完整可执行交付，不含用户原始强迫、观测或研究结果。

## 运行顺序

1. **继续使用现有隔离环境，不必重新安装。** LakeEnsemblR为当前研究使用的1.2.9.9003；没有切换到未使用的9004。
2. 如先分析已完成两湖：打开`Analyze_and_collect_two_lakes_20261103.ipynb`，按说明生成R分析脚本，在RStudio执行它；输出新目录中的PNG/PDF、指标表、参数及耗时表。最后单元导出小ZIP供进一步核对。
3. 在原Jupyter环境打开`Prepare_and_START_remaining67_12_COMPLETE_20261103.ipynb`，核对第一单元C盘项目、D盘隔离库路径，顺序运行全部代码单元。完整Python、R运行器和恢复helper均已嵌入，不需另找脚本。
4. 配置输出到`C:/Geography/R/dissertation_LakeEnsemblR/yaml/r4_ice_20261103_core12`。必须看到`REMAINING67_CONFIG_READY_NO_MODELS_STARTED`及`REMAINING67_RUNNER_FILES_READY_NO_MODELS_STARTED`。此时未启动模型。
5. 在原隔离项目RStudio选择Session → Restart R，再运行notebook打印的命令：

```r
source("C:/Geography/R/dissertation_LakeEnsemblR/yaml/r4_ice_20261103_core12/START_remaining67_core12.R", encoding="UTF-8")
```

它将只读复核已完成的akesaiqin、namco（原10进程结果），审计其余67湖，检测并验证12个本地PSOCK工作进程，然后逐湖正式率定与评价。单湖失败记录后继续；共享运行时或来源改变则停止。

结果：`D:/LER4_ice_20261103/n500_c12`。进度：`remaining_lake_run_index.csv`；失败：`remaining_failed_lakes.csv`。全部通过后：

```
REMAINING_67_FOUR_MODELS_CALIBRATION_EVALUATION_PASSED
ALL_69_FOUR_MODELS_CALIBRATION_EVALUATION_PASSED
```

生成`combined_69_lake_run_index.csv`，指向原两湖及新67湖的实际目录。中断后保持输入、代码、包、500套及12进程不变，重新运行同一入口，复用已完成候选。

## 科学设置

- 模型：FLake、GLM、GOTM、Simstrat；每模型500套LHC。
- 公共参数：wind_speed 0.5–2、swr 0.5–1.5；Simstrat额外ModelParameters/p_sw_ice 0.9–3。初值1、线性采样。冰参数是用户指定探索区间，不是官方推荐范围。
- 模拟1979-01-01至2016-01-01；率定2001–2010，验证2011–2015；保持原窗口、批准时间契约、原始NAME_ID种子和固定物理设置。
- Puhu已编辑测深底深70m、底面积0：同步新YAML的depth/init_depth；去除旧GLM H/A/bsn_vals覆盖；初温只保留已有0–70m行的新副本。原文件不改。
- 12进程只用于新67湖；旧2湖仍标记10进程。实际种子和LHC池不依赖工作进程数。
- 不自动执行δ/S1 bootstrap；参数响应散点不是全局敏感性结果。

## 已完成与尚待取得的数据

用户报告两湖21:30至次日04:15，共6小时45分，并出现完整完成标志。当前未上传新两湖指标，因而交付报告没有虚构新RMSE、最优参数或零失败结论。

12进程其余67湖当前预算约6–8天，点估计6.7天；10→12理论同量工作用时最多减少16.7%，实际取决于I/O和串行开销。详见RUNTIME.md及可复算CSV。

## 安装原件与复现

本工作流包包括当前Windows安装的本地快照工具。它在用户电脑生成实际依赖库、DLL、脚本和批准契约的字节核对备份，研究输入和结果不纳入该备份。

另一个完整安装复现包`LER_window_9003_source_and_local_archive_tools_20261103.zip`含9003、MyLake9002及8个固定依赖源包、参考驱动、新库安装器与说明。新电脑依赖安装不等于当前Windows库逐字节复制；精确原件以本机快照为准。继续67湖不需重装。

## 验证与来源

已完成69/67/2名单、配置保护、Puhu70m、实际12进程通信、输入与快照、500参数池、续算及67湖批次控制的软件测试。模型完整运行在用户Windows主机执行。

9003源码124个函数与校验安装库匹配、57个函数与用户历史Windows运行指纹匹配，32个vendor原生文件与其Windows清单匹配。GLM3r接口版本3.1.17不等于引擎版本；Windows归档路径glm-3.0.5_x64/glm.exe，准确横幅版本仍待新日志核对。Linux短测GLM3.1.1不称为用户Windows引擎版本。

发布目标为用户现有公开仓库`yhy3158004870/LakeEnsemblR`的独立分支`codex/research4-20261103`；不改主分支。本目录只发布代码、源码依赖、实验设计与测试证据，不发布用户原始湖泊数据或完整结果。
