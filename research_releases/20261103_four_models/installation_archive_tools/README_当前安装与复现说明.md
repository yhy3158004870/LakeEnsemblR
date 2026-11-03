# 当前正在使用的安装版本与离线复现

当前正式研究使用 **LakeEnsemblR 1.2.9.9003**，不是 1.2.9.9004。四模型筛选、Simstrat 第三个率定参数、动态调度、12进程和 Puhu 输入修复均属于外部研究配置或启动器，不要求更换这个已验证的主包。

**继续剩余67湖时，沿用当前隔离库。不要为本次10→12进程改动重新安装包。** 目录中的安装工具用于存档、恢复或在另一独立目录复现。

## 1. 本包实际提供什么

| 文件 | 内容与用途 |
|---|---|
| `LakeEnsemblR_1.2.9.9003.tar.gz` | 2026-10-26交付并使用的原始9003源码安装包，包含窗口率定及Simstrat七列初始条件修复；GPL-2原作者信息保留 |
| `MyLakeR_0.0.1.9002.tar.gz` | 按当时固定提交和原安装器重新生成的精确排序修复源码包；本轮四模型不调用MyLake，保留包是为了环境与旧结果可核对 |
| `package_source_sha256.csv` | 上述两个源码安装包的SHA256 |
| `vendor/` | 原始交付中固定提交的FLakeR、GLM3r、GOTMr、SimstratR，以及adagio、rLakeAnalyzer、gotmtools、glmtools共8个原生模型／工具源码包；各包已逐一与原清单SHA256核对 |
| `Snapshot_CURRENT_WINDOWS_INSTALLATION.ipynb` | 在你的电脑生成实际Windows隔离库的完整、逐文件核验离线ZIP；不依赖聊天下载是否成功 |
| `Snapshot_current_Windows_LER.py` | 上述notebook的完整Python代码 |
| `Export_current_LER_runtime_inventory.R` | 导出当前运行库版本、文件哈希、函数哈希及R会话信息；只定义函数，不执行模型 |
| `Install_sources_to_NEW_library.R` | 必须明确调用才安装；克隆你已有依赖库，并只在一个不存在的新目录安装这两个固定源码包 |
| `reference_workflow/` | 原驱动搬盘前的参考源码、由已上传Step7脚本提取的两个辅助函数、当前路径的参考加载模板及历史说明；不替换你电脑上的实际工作文件 |

这里的源码包是可安装的R源码包，并非伪装成Windows二进制包的Linux库。vendor中保留了当时四模型源码包内附的多平台原生文件；你的实际安装结果和全部CRAN依赖存在电脑的隔离库中。**要保存与正在运行的环境完全相同的Windows安装原件，使用本机快照notebook。** 它会复制这些实际文件，不从网上寻找“最新版本”。固定的8个vendor源码包不等于全部104个依赖的Windows离线安装库；完整离线库由本机快照生成。

## 2. 已核验的代码身份

对原始9003源码包进行解析，并用统一的形参／函数体SHA256方法比较：

- 源码包中 **124个顶层函数**与此环境中匹配的9003校验安装库全部一致。
- 用户此前上传的Windows A0001上下文中，**57个被记录的运行函数**与同一源码包全部一致。
- 8个vendor源码包全部与原始交付清单的SHA256一致；四模型源码包中可与用户Windows清单对应的32个原生二进制／配置文件也全部一致，见`vendor_vs_uploaded_Windows_native_files.csv`。
- 原包的`R/window_calibration.R`和`R/export_init_cond.R`与当前工作源码文件逐字节一致。
- 原始源码包保留了当时构建元数据；这与工作树DESCRIPTION的排版、Packaged字段不同，不表示算法不同。

比较明细分别保存在：

`LakeEnsemblR_9003_source_vs_installed_functions.csv`

`LakeEnsemblR_9003_source_vs_uploaded_Windows_functions.csv`

用户此前上传的Windows记录为R **4.6.0 (2026-04-24 ucrt)**、`x86_64-w64-mingw32`。R包版本为：LakeEnsemblR 1.2.9.9003、FLakeR 0.0.9、GLM3r 3.1.17、GOTMr 0.0.0.10、SimstratR 0.0.9、MyLakeR 0.0.1.9002，见`uploaded_Windows_engine_packages.csv`。R包版本和引擎版本是不同字段，例如GLM3r 3.1.17不能写成GLM引擎3.1.17。

Windows GLM预设可执行文件是`extbin/glm-3.0.5_x64/glm.exe`；Linux短期检查使用的GLM3.1.1不能当成用户Windows引擎版本。实际研究中的版本横幅应从其`engine_console.log`确认。全部已记录的Windows依赖版本和构建哈希另存于`uploaded_Windows_all_recorded_packages.csv`。

新完成的两湖文件尚未上传，本说明没有声称读取了它们的最新运行清单。本机快照和运行清单导出可记录你现在的实际文件。

## 3. 在自己电脑生成“正在使用的安装包”

在原Jupyter环境打开`Snapshot_CURRENT_WINDOWS_INSTALLATION.ipynb`，依次运行两个代码单元。默认读取：

```text
D:/Geography/R/dissertation_LakeEnsemblR/LER_window/
MyLake_v121_ordering_isolated_20261029/
library_R4_6_mylake_v121_order9002
```

默认把备份生成到`C:/LER9003_archives`。脚本使用纯Python标准库，支持Windows路径和WSL路径转换。它会：

1. 确认LakeEnsemblR为9003、MyLakeR为9002，并检查安装锁。
2. 把整个隔离库复制到新建且不覆盖的目录，包含原生Windows模型文件及其依赖。
3. 复制实际的LER69、setup_helpers、Restart、启动环境文件和批准的输出时间契约。
4. 对每个源文件和复制后的文件核验SHA256，并检查源文件在复制期间没有改变。
5. 生成ZIP64离线ZIP、逐文件清单、包版本表和ZIP自身的SHA256。

成功标志：

```text
CURRENT_WINDOWS_LER9003_LOCAL_ARCHIVE_VERIFIED_NO_MODELS_STARTED
```

这一步只读原环境，不运行模型、不更改任何包。它不归档69湖原始气象、测深、初温或MODIS观测，也不归档研究结果。因此安装库归档和完整研究数据归档是两个不同对象。保留原研究输入与结果目录，恢复实验时二者都需要。

生成的Windows库ZIP只保存在你的电脑；它可能较大，且包含本机路径信息，**本工具不会把它上传到GitHub或任何外部服务**。代码／文档发布与本机安装库原件备份分开。

最稳妥的恢复方式是在相同Windows、相同R4.6架构下，把快照恢复到其记录的原ISO路径；先保留原有目录，再核验清单。若改盘符或路径，需要重新核对启动器和保存的配置，并为新输入建立新的研究目录，不能把旧的签名直接视作新环境的验收。

## 4. 可选：导出当前运行时清单

在已经通过原`Restart_LER_window.R`加载正确隔离库的RStudio中：

```r
source("你保存此文件的路径/Export_current_LER_runtime_inventory.R",
       encoding = "UTF-8")
export_current_ler_runtime_inventory()
```

输出默认位于`C:/LER9003_archives/runtime_inventory_<北京时间>`。函数会核对当前加载的LakeEnsemblR确实来自指定隔离库，随后导出版本、实际引擎包文件及函数哈希；不执行模型。

## 5. 仅在需要独立重装时使用源码安装工具

以下函数不会覆盖工作库，目标必须是一个不存在的新目录。它需要当前已有的完整依赖库作为来源，所以不会从CRAN/GitHub临时抓取不同版本的依赖。

```r
source("你保存此文件的路径/Install_sources_to_NEW_library.R",
       encoding = "UTF-8")

install_ler9003_sources_to_new_library(
    delivery = "这份install_repro文件夹的绝对路径",
    new_library = "C:/LER9003_reproduced_library"
)
```

该操作先校验源码包，再复制原库，最后用干净子R进程安装8个固定vendor包和两个当前源码包，核对10个版本，并比对全部124个LakeEnsemblR函数。安装日志和成功回执保存在新库旁。它不会切换当前研究会话，也不会让任何模型自动运行。

这是恢复／复现工具，不是剩余67湖的启动步骤。当前9003库已经完成两湖正式研究，剩余67湖应继续使用它。

## 6. 关于原参考驱动

`reference_workflow/LER69_before_relocation.R`是搬盘前的原驱动源码，原始路径保留用于溯源。MyLake隔离安装器后来会复制它并替换ISO／library路径。你电脑上的实际复制版本、实际`setup_helpers.R`以及实际`records/research_cfg_template.rds`由本机快照保存。

不要把参考文件直接覆盖到已完成两湖研究的环境。剩余67湖使用本次发布的独立四模型入口，不使用旧驱动中“五模型、每模型两参数”的`run_stage("research")`入口。

## 7. 固定的MyLake历史源信息

MyLakeR基础提交：`ff73fd0da38b9d372f3ff9a940d59a121aa12b88`。

官方排序修复依据提交：`d882070870bd0bd541376ee8b627282d3ae8d329`。

原安装器生成的`R/Rlake_main.R` SHA256：

`15eb7179c62be43412a433a5639e42fb54e48993541f66d93aaebd10bd89acc0`

本包的MyLake9002源码由该固定安装器重新生成，已通过上述逐字节校验；未把早期9001原型或同版本不同排版的测试原型当成当前原件。保留MyLake源包用于旧结果复现，不表示本轮四模型又会执行MyLake。
