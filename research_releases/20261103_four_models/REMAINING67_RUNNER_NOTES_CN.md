# 其余67湖：12工作进程正式入口

运行前提：原四模型两湖方案已经显示 `TWO_LAKES_FOUR_MODELS_CALIBRATION_EVALUATION_PASSED`，旧结果位于 `D:/LER4_ice_20261102/n500`；使用原隔离库中的 LakeEnsemblR 1.2.9.9003，原 rev3 helper 原文 SHA256 为 `74cfbe6a90da76df42c80b168edb45d4a1e78ba08dceac4976ffff84516e5afa`。

新配置根目录：`C:/Geography/R/dissertation_LakeEnsemblR/yaml/r4_ice_20261103_core12`。

新结果根目录：`D:/LER4_ice_20261103/n500_c12`。

将以下文件保存到新配置根目录：

- `Run_remaining67_R4ice_12.R`；
- 未修改的 `Resume_interrupted_calibration_9003_rev3.R`；
- `START_remaining67_core12.R`。

在原隔离项目的 RStudio 中选择 Session → Restart R，然后执行：

```r
source("C:/Geography/R/dissertation_LakeEnsemblR/yaml/r4_ice_20261103_core12/START_remaining67_core12.R", encoding = "UTF-8")
```

入口只定义并调用新环境 R4，不覆盖 R69，不调用旧的 `run_stage("research")`。它会：

1. 校验69/67登记表的真实 NAME_ID、spin-up 和新配置哈希。
2. 只读核验 akesaiqin、namco 的率定、评价、报表回执与实际输出；将旧封存快照中的输入/原生模板 SHA 与新方案比较，核对原种子和完整500套参数池。不会重新运行这两湖引擎。
3. 检查其余67湖全部输入，严格排除这两湖。
4. 选择可绑定的本机端口，先通过真实12工作进程通信测试，保留原 helper 和函数体不变。
5. 每湖依次执行新范围的配置导出和9次小规模探针/串并行复验，然后进行4×500候选率定、4模型最优参数复跑与评价、集合报表。
6. 记录单湖失败并继续其余湖；运行源文件、软件包/函数或共享配置改变会停止整个批次。

候选级中断续算沿用已有校验方式：同一入口、同一配置、同一12工作进程与500套设计可重试；完成候选保留，未完成目录先归档再重做；完成且封存的湖只验证、不重新模拟。不要在运行中编辑输入、模板、脚本或安装软件包。

进度表是 `remaining_lake_run_index.csv`，含 input、preflight、calibration、evaluation、report 五阶段状态以及错误信息；可用 PowerShell 的 Import-Csv 查看，避免用会锁定 CSV 的编辑方式。失败列表是 `remaining_failed_lakes.csv`。

全部67湖通过才显示：

```text
REMAINING_67_FOUR_MODELS_CALIBRATION_EVALUATION_PASSED
ALL_69_FOUR_MODELS_CALIBRATION_EVALUATION_PASSED
```

并生成 `combined_69_lake_run_index.csv`，其中旧两湖注明10进程，新增67湖注明12进程。若任一湖未通过，则不显示以上标志，保留已完成结果并给出失败列表。

软件验证已覆盖：真实69/67配置读入与67湖输入检查、快照路径归一化后输入/模板一致性、10与12核对应同一500套参数池、puhu70米配置、真实12进程握手、候选首次/中断/封存恢复、单湖预检查失败及审计后外部输入消失时继续其他湖、重试只补失败湖、共享运行代码改变时整体停止。

测试使用隔离的占位输入和明确的测试契约；这些软件测试不代表已经替用户在Windows运行了67湖37年完整模拟。两湖实际结果仍需用户上传报表/回执后才能远程分析数值表现。
