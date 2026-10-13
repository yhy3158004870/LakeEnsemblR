<!-- [LER-WINDOW NEW SUPPORT FILE] Entire guide added relative to official LER. -->
# LakeEnsemblR 窗口率定完整交付 v0.2.0（Win11 x64）
这是 **v0.2.0 标注版**：用 `[LER-WINDOW ...]` 标出相对官方的新增和修改；执行逻辑不变。详见 `docs/相对官方代码的修改清单.md` 与 `diff/official_to_window.patch`。注释/元数据会改变安装文件摘要，旧率定目录须用原构建库重跑；新标注版应创建新率定目录，不能混用构建物来绕过审计校验。

派生 R 包版本：**1.2.9.9002**。固定上游：`aemon-j/LakeEnsemblR` 1.2.9，提交 `9f3135df691aa6b162c86b795c4f517d616f6efb`。许可仍为 GPL-2；保留原作者和模型依赖各自许可。本交付不是 LER 官方发布。

本包提供完整派生源码和可直接安装的源归档，不需要自己寻找代码片段拼接。五模型依赖的九个固定提交源归档也随包提供。CRAN 的 Windows 二进制依赖需要首次联网下载；安装器保留实际版本、归档摘要与缓存，不会使用 Linux 安装库替代 Windows DLL。

## 使用顺序

1. 完整解压 ZIP，保留目录结构，例如 `D:/LER_window_v0.2.0`。R 至少 4.1、64 位；建议当前仍有 CRAN Windows 二进制支持的版本。不是 Windows ARM64 验收版本。
2. 在一个新的 R/RStudio 会话安装到**新的空库**：

```r
bundle <- "D:/LER_window_v0.2.0"
lib <- "D:/LER/library_window_v020"
source(file.path(bundle,"install_windows.R"), encoding="UTF-8")
ler_install_windows(lib=lib, bundle_dir=bundle)
```

3. 重启 R，加载专用库并自检：

```r
bundle <- "D:/LER_window_v0.2.0"
lib <- "D:/LER/library_window_v020"
.libPaths(c(lib,.libPaths()))
library(LakeEnsemblR)
stopifnot(as.character(packageVersion("LakeEnsemblR"))=="1.2.9.9002")
source(file.path(bundle,"windows_preflight.R"), encoding="UTF-8")
ler_windows_preflight(lib=lib,bundle_dir=bundle)
```

4. 在本机完成真正的五模型参考验收：

```r
source(file.path(bundle,"examples","00_reference_acceptance.R"), encoding="UTF-8")
test <- ler_reference_acceptance(lib,"D:/LER/reference_001",num=3,ncores=2)
test$counts
```

结果目录必须全新。该参考案例使用人工目标，仅验证代码链路；不能把其评分写成 Wan 研究精度。通过后可以在另一个全新目录用 `num=20` 扩大串并行检查。

5. 使用 `tools/prepare_wan_windows.R` 处理自己的 Wan 发布宽表，完成具有依据的 QC/非冰期审核和整年率定/留出分期。详见 `docs/Wan_数据与科研配置.md`。空审核不会批准任何观测。
6. 准备实际湖泊标准 LER 输入、逐模型 `output_contracts.csv`，执行真实项目 probe，核对时间和层深后再批准 contracts。运行示例在 `examples/01_project_workflow.R`。先小样本、同参数串并行和最佳重跑，全部通过后再进行正式搜索。

如没有 D 盘，换成实际存在且可写的目录。建议模型项目目录和专用库用短英文路径；安装和观测预处理代码支持中文/空格，但旧 Fortran 求解器不保证任意 Unicode 路径都能读取。

## 实际修改与兼容范围

- 修复原安装器源引用属性误判，并将 `window` 放在 `...` 后作为**只按名称匹配**的参数，保留旧位置参数与默认值。
- 修复 YAML/legacy-reader 互操作、FLake 亚日时间偏移、真实 PSOCK 初始化和测试脚本。
- 使用稳定源码 SHA256、全部依赖包构建文件及引擎摘要、输入快照和关键结果完整性校验；每个候选独立确定性随机种子，保护调用者 RNG/环境变量及 MyLake 全局对象。
- Windows 窗口分支直接调用依赖原来提供的同一 `.exe`，避免现代 R 的子架构字符串限制，检查退出码并保留日志。没有改模型方程、求解器二进制或原 `get_output` 解析器。
- `window=NULL` 的原函数体、原参数默认值及其他原 R 文件保持不变，代表性旧流程回归结果见验证报告。旧第三方 Windows wrapper 的所有接口还需要本机检验；这里没有声称重写所有 LER 功能。
- 窗口模式只支持 LHC、指定近表层温度与固定窗口 RMSE；提供 N、RMSE、MAE、bias、NSE、r。旧 `load_LHC_results()` 不用于新目录，新结构不冒充旧结构。

**窗口目标与原时点目标本来不同，参数与精度结果可以改变。** 修复旧错误也可能改变 v0.1.0 的结果；不应以复现错误为兼容要求。

## 科研输入和解释

窗口日期匹配不会消除 MODIS 晴空/过境采样、填补滤波、皮肤温度与模型近表层温度差异。Wan 六套发布温度已经是 °C；无需再次 MODIS 缩放。MyLake 每日状态不等于从真实小时变化积分而来的日均值。非冰期与质量依据不能由软件批准标志自动证明。

初始剖面应是两列 `Depth_meter,Water_Temperature_celsius` 的独立输入，不是把三列时间观测文件原样当成初始剖面。湖盆、Kw、流量、盐度/冰过程、TPMFD 驱动的单位与时间定义及各模型参数范围，需要实际研究资料。代码不生成这些缺失的科学数据。

正式论文至少存档源码和依赖校验、实际引擎版本、气象/湖盆/初始条件、窗口主表及审核规则、LHC 参数表与随机种子、失败候选、串并行/重跑证据、独立时期指标和搜索稳定性。不要把同一遥感产品时间留出说成另一观测系统的独立验证。

## 文件入口

| 文件 | 用途 |
|---|---|
| `install_windows.R`、`WINDOWS_INSTALL_中文.md` | Win11 安装与故障定位 |
| `windows_preflight.R` | 包、真实 PE 文件和完整数值回归自检 |
| `src/LakeEnsemblR-window/` | 完整修改源码 |
| `src/LakeEnsemblR_1.2.9.9002.tar.gz` | 同一源码的直接安装归档 |
| `vendor/` | 九个固定提交依赖源归档与 SHA256 清单 |
| `R/window_calibration.R`、`apply_patch.R` | 模块源与可审计补丁重建工具 |
| `tools/prepare_wan_windows.R` | 纯 R Wan 数据处理与审核导出 |
| `examples/` | 参考验收、真实项目流程及输入模板 |
| `tests/run_tests.R` | 全部数值、缺陷回归、观测合约、合成并行与源码保留检查 |
| `reports/VALIDATION_STATUS.md` | 已执行的结果和未执行的范围 |
| `provenance/`、`SHA256SUMS.txt` | 上游来源、原文件摘要和发行文件完整性 |

Linux 上的通过结果见报告。本交付环境没有 Win11，**不把 Windows PE 静态检查或 Linux 模型运行写成 Win11 实机通过**。本机预检与参考验收脚本会在实际失败时停止并保存线索，不会降低完整性要求继续评分。
