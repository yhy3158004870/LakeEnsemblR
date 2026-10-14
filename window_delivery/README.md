# Win11 完整交付包与修改标注

这是 v0.2.0 标注版，R 包为 1.2.9.9002，新增注释不改变科学执行表达式。来源与修改范围见仓库根目录 `WINDOW_CHANGES.md`；代码搜索 `[LER-WINDOW`，完整官方对比补丁在 `diff/official_to_window.patch`。

## 下载

打开本目录的 `LER_window_v0.2.0_Win11_annotated_installfix1.zip`，在 GitHub 文件页面点击 **Download raw file**（下载图标），或使用：

[完整 ZIP 下载](https://github.com/yhy3158004870/LakeEnsemblR/raw/refs/heads/ler-window-v020-annotated-20261013/window_delivery/LER_window_v0.2.0_Win11_annotated_installfix1.zip)

本分支也可用 GitHub 的 **Code → Download ZIP** 下载：该仓库 ZIP 中的 `window_delivery/` 内含上述完整交付 ZIP，再解压它即可。不要把仓库本身的 ZIP 当成普通 CRAN 二进制包安装。

完整交付 ZIP 中包含派生源码、源安装归档、九个固定依赖源归档、安装/预检/参考验收脚本、Wan 处理与审核工具、示例和验证证据。首次安装需联网下载当前 R 对应的 CRAN Windows 依赖。解压后先读 `00_先读我.md` 和 `WINDOWS_INSTALL_中文.md`。

## 校验

ZIP 的 SHA256 在旁边的 `.zip.sha256` 文件；Win11 PowerShell 可运行：

```powershell
Get-FileHash .\LER_window_v0.2.0_Win11_annotated_installfix1.zip -Algorithm SHA256
```

ZIP 内的 `SHA256SUMS.txt` 与 `verify_bundle.R` 用于逐文件检查。实际检查范围见 `reports/VALIDATION_STATUS.md`，Windows 求解器仍需在你的电脑实际验收。

## 中文 Windows SHA256 安装修复 1

当前完整 ZIP 已修复 certutil 输出的编码解析。已下载原标注版的用户无需重下完整 ZIP，可下载 [小补丁](https://github.com/yhy3158004870/LakeEnsemblR/raw/refs/heads/ler-window-v020-annotated-20261013/window_delivery/LER_window_v0.2.0_installfix1_patch.zip)，按 `installfix1/README_中文.md` 应用。官方包库、模型科学源代码和源安装归档均不改变。修复保留真实 SHA256 和退出状态检查。
