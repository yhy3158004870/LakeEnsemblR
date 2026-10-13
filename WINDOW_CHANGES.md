# 相对官方 LakeEnsemblR 的修改标注

对比基准是官方 `aemon-j/LakeEnsemblR` 的 **1.2.9**，固定提交 `9f3135df691aa6b162c86b795c4f517d616f6efb`；不是你的 fork 当前可能变化的最新提交，也不是 v0.1.0 补丁包。

本交付为 v0.2.0 的**标注版**，R 包版本仍为 `1.2.9.9002`。添加注释和元数据，没有修改窗口科学执行表达式。搜索 `[LER-WINDOW` 可以定位标记。`window_delivery/diff/official_to_window.patch` 是可在固定官方源码上应用的完整统一差异；`window_delivery/diff/file_changes.csv` 列出每个变更文件及变更前后 SHA256。

## 修改了官方已有文件

| 文件 | 标记 | 具体变化 |
|---|---|---|
| `R/cali_ensemble.R` | M001、M002 | 在 `...` 后增加只按名称匹配的 `window=NULL`；入口增加窗口分派。标记 `UPSTREAM BODY BEGIN/END` 之间是保留的官方原函数体。文本由 deparse 重排，执行表达式和原默认参数保留，不声称全文件逐字不变。 |
| `NAMESPACE` | M003 | 新增八个窗口接口的 export，原指令保留。 |
| `DESCRIPTION` | M004 | 版本改为派生版本；R 下限为 4.1；Imports 补充 digest 和原代码已使用但未声明的 purrr；许可证表达式规范为 GPL-2 + file LICENSE，不改变 GPL-2 条款和原作者。DCF 文件不能随意插入 `#`，所以使用合法 `X-LER-Modification:` 字段说明。 |
| `man/cali_ensemble.Rd` | M005 | 补充新 window 参数和使用签名，以 `%` 注释标注。 |

## 相对官方整文件新增

| 文件 | 标注方式 | 用途 |
|---|---|---|
| `R/window_calibration.R` | A001 头尾 NEW FILE，内部 NEW SECTION | 全部新增：窗口日历、观测算子、合约、LHC、YAML、快照、运行适配器、近表层读取、候选失败审计、PSOCK、probe、最佳重跑与分期评价。它不是官方旧函数的一段改写。 |
| `man/window_calibration.Rd` | A002，`%` 注释 | 全部新增的接口帮助。 |
| `inst/window_patch/README_window.md` | 文件头 NEW SUPPORT FILE | 扩展使用说明。 |
| `inst/window_patch/VERSION.txt` | Annotation 字段 | 来源提交和扩展版本。 |
| `inst/window_patch/source_manifest.csv` | 本清单及 file_changes.csv | 来源文件摘要；保持合法机器可读 CSV，不插入会破坏读取的注释行。 |

交付目录中的安装器、Windows 预检、Wan 预处理、示例、回归测试、补丁重建器和注释生成器都是官方没有的支持文件，R/Python 文件头以 `NEW SUPPORT FILE` 标明。`provenance/upstream_cali_ensemble.R` 是原始证据副本，不添加注释；其他官方原 R 文件也不添加注释，保持逐字 SHA256 一致。九个 vendor 依赖归档原样保留。

## 标注后的再次检查

`window_delivery/reports/annotation_identity_linux.log` 记录与未标注 v0.2.0 的比较：70 个原有 R 脚本的执行表达式完全相同；NAMESPACE 指令与 Rd 可见内容相同；DESCRIPTION 仅增加标注字段；九个依赖归档相同。`apply_patch.R` 是唯一有意改变执行逻辑的既有支持脚本，增加对注释生成器的调用，作用是输出带标注源码，不涉及科学计算。重建出的 187 个源码文件与交付源码逐字相同，差异补丁也已通过 `git apply --check`。

标注版在独立 R 库重新构建和安装，并重新执行全部 126 项 helper 回归以及合成串并行、原源码保留检查。详见对应 annotation 日志。此前五模型物理测试的实际构建物和范围仍按 `window_delivery/reports/VALIDATION_STATUS.md` 的说明解读；不把旧日志改称新的 Win11 实机结果。

注释和元数据会改变构建文件 SHA256。运行审计因此会拒绝把旧率定目录与新标注构建混用，这是预期的完整性行为。已有研究记录应使用当时保存的原构建库重跑；标注版使用新的结果目录。不要修改旧记录里的摘要来制造通过。

模型方程、预编译求解器和官方原输出读取器没有改动；本次标注不新增精度承诺，也不替代真实 Win11、本湖泊输入和观测 QC 验收。
