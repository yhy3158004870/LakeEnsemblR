# v0.2.0 验证报告

日期：2026-10-13。固定官方提交 `9f3135df691aa6b162c86b795c4f517d616f6efb`；派生包 `1.2.9.9002`，扩展 `0.2.0`。执行环境为 Debian 13、R 4.5.3、Linux x86_64；不是 Win11 实机。

## 已实际执行

| 检查 | 结果 |
|---|---|
| 安装器、完整源码 R 解析、包构建与安装 | 通过 |
| 发行入口的 71 个 R 脚本最终解析、固定官方源重建与完整源码 187 文件对照 | 通过；源版本变更在创建目标前被拒绝 |
| 原有窗口数学、指标、LHC 测试 | 47/47 通过 |
| YAML、指纹、快照、RNG、MyLake caller 对象、PSOCK、FLake 时间回归 | 34/34 通过 |
| Wan 预处理与审核合约 | 35/35 通过 |
| 失败候选配置/参数/日志永久审计与陈旧证据拒绝 | 10/10 通过（实际配置导出，故障注入的假引擎；不是物理模型测试） |
| 合成串行/PSOCK | 通过 |
| 所有原 R 文件、原 cali_ensemble body/defaults 与旧位置参数保留 | 通过 |
| 五模型真实参考案例 probe | 五模型通过 |
| 五模型各 20 候选串行 LHC | 100/100 成功 |
| 相同参数表五模型并行 LHC | 100/100 成功 |
| 逐模型、逐参数、逐窗口串并行预测对照 | 1e-6 °C 容差内通过 |
| 五模型最佳参数重跑与率定预测一致性、两期指标 | 通过 |
| 最终源归档安装到独立 release library 后五模型各 3 候选完整验收 | 串行 15/15、并行 15/15、最佳重跑与对照通过 |
| 原版 1.2.9 与新包旧模拟路径的五模型温度 data.frame | 在相同参考输入/随机种子下逐对象完全相同 |
| 实际上传 Wan NAME_ID=201 的六套表处理 | 690 主表窗口，空审核批准 0；未改变原摄氏数值 |
| Windows 安装代码 source/CLI、归档、摘要、路径和依赖排序 | Linux R 实际执行通过 |
| 九个 vendor 固定源归档 | SHA256、包名/版本与固定提交核验通过 |
| Windows 求解器 PE 静态检查 | 已识别随包 x86/x64 文件；FLake 为 x86、GLM 为 x64 |
| Windows R 4.5 CRAN 二进制依赖计划 | 94 个普通依赖、版本约束和排序检查通过 |
| R CMD check（不运行内置全模型测试/手册/文章） | 0 ERROR、2 WARNING、6 NOTE |

126 项具编号的数值/缺陷/数据/失败审计检查，以及另外的合成并行和源码保留检查均完成。物理模型验证另列，不用合成测试替代。

20 候选验收之后的最后核心变更仅增加失败候选的提前参数记录和 debug_config，不改变数学或引擎计算；最终交付归档又在新库完成各 3 候选验收。请按真实日志解读范围，不把多个版本的测试记录误认为同一个包构建物。

参考湖泊是 Feeagh 的 2010-01-01 至 2010-02-03。使用两个率定窗和一个评价窗，目标 4.8/4.2/4.5 °C 为**人工验收值**，不是 Wan 观测。这些评分不能用于模型科学排名或论文。原气象为日尺度，FLake 使用日状态 sample_mean；其他亚日模型采用明确的 3 小时 point 规则，MyLake 保留每日状态。这不是对用户实际模型输出语义的自动批准。

## 包检查中的剩余项目

两个 WARNING 是原版数据字典缺少独立帮助页、`met_input` 数据中包含原有的度数单位字符。NOTE 涉及原版启动输出、旧帮助页空节/参数说明、保留的未用 import 等，详见 `package_check_linux.log`。未更改原字典或旧函数来掩盖这些项目。检查中的原内置 tests 和 vignettes 是明确跳过的；综合数值与物理验收由本交付另行实际执行。

原版旧模拟路径在参考输入仅输出 temp 的某种组合下触发上游 create_netcdf_output 错误；用于数值兼容对照的是官方通常使用的 temp/ice_height/w_level 三变量配置。没有把这个上游缺陷归咎为窗口模块，也没有修改旧函数去绕过它。

## Win11 和科研范围

本环境没有 Win11，尚未在你的 R 版本执行 Windows 安装、DLL 加载或 Windows 求解器运行。Windows package version 不等于 engine version，例如本固定 GLM3r 3.1.17 的 Windows 程序为 GLM 3.0.5。不同平台的结果不能直接声称逐位相同。

先在你的电脑运行 `windows_preflight.R` 和 `examples/00_reference_acceptance.R`，再核验真实项目五模型、native time/depth 与 approved windows。若发生失败，程序保留日志并停止，不放宽完整性或忽略 NA 来制造通过。

未执行真实 TPMFD/所有研究湖泊的正式 2000 候选率定；未认证每条 Wan 记录无冰或 QC 合格；未验证全水柱、分层、盐度或冰过程精度。依赖包内文件与引擎做强校验，R build 信息记录；没有冻结所有操作系统共享库。有限测试不能证明源码零错误或适用于所有物理配置。

## 原代码一致性的准确含义

所有原 R 源码保留，cali_ensemble 只在入口增加 named-only window 分派；window=NULL 的原 body 与 defaults 保留。五模型参考旧路径的数值结果已对照相同。窗口模式改用新的观测算子和 RMSE，最佳参数与旧时点流程可以不同；这是需求的目标，而不是需要消除的差异。

## 证据文件

- `all_tests_linux.log`：所有 helper 回归及故障审计。
- `five_models_linux.log`、`reference_20_counts.csv`、`reference_20_final_metrics.csv`：主要真实模型检查。
- `release_five_models_linux.log`、`release_3_counts.csv`：最终归档检查。
- `legacy_numeric_comparison_linux.log`：旧路径五模型精确对照。
- `installer_linux.log`、`build_linux.log`、`install_release_linux.log`、`package_check_linux.log`：构建与包检查。
- `windows-helper-validation.txt`、`windows-binary-install-plan.csv`、`windows_main_archive_linux.log`：Windows 交付静态/安装计划检查。
- `wan_real_data_linux.log`：真实数据预处理检查。
- `patch_rebuild_linux.log`、`release_integrity_linux.log`：固定源重建、源版本拒绝与发行文件核对。

安装和正式运行后还应在本机保存自己的 sessionInfo、依赖与引擎摘要、输入和窗口版本、参数表、失败候选及最终分期指标；本报告不能代替那些实际研究证据。

## 标注版补充验收

标注版重新构建并在独立库安装成功，完整 126 项 helper 测试、合成 PSOCK、官方源码保留检查通过。70 个既有 R 脚本的执行表达式与未标注 v0.2.0 完全相同，NAMESPACE/Rd 可见内容不变，DESCRIPTION 仅增加合法标注元数据。唯一改变生成器逻辑的 apply_patch.R 新增注释生成步骤；187 文件重建对照和 git apply --check 通过。73 个发行 R 文件解析通过。新增证据在 annotation_*_linux.log。既有五模型物理日志仍属于此前列出的构建物，未冒充重新执行的 Win11 实机验证。
