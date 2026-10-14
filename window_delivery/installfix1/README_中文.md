# LER 窗口版安装修复 1

适用：完整 v0.2.0 标注版。R 包版本仍为 1.2.9.9002，模型科学代码和源安装归档不变。

用户日志显示，在 UTF-8 R 中读取中文 Windows `certutil` 输出时，旧字符正则因非 UTF-8 字节失败。本修复只在摘要解析时按字节识别 ASCII 十六进制，不改变系统语言、R locale、官方包库或启动配置。非零退出码、唯一 64 位摘要及归档摘要一致性检查保留。

## 应用小补丁

将补丁 ZIP 解压到：

`C:/Geography/R/dissertation_LakeEnsemblR/LER_window`

解压后应存在 `LER_installfix1/fix_windows_sha256.R` 和 `LER_installfix1/windows_helpers.R`。

在当前 R 中运行：

```r
local({
  root <- "C:/Geography/R/dissertation_LakeEnsemblR/LER_window"
  source(file.path(root,"LER_installfix1","fix_windows_sha256.R"),
         local=TRUE,encoding="UTF-8")
  ler_apply_install_fix1(file.path(root,"LER_window_v0.2.0"))
})
```

脚本核对原 helper 和补丁 helper 的固定 SHA256，备份原文件到 `records/sha256_fix1_时间戳`，只更新解压交付包的 `tools/windows_helpers.R` 及 `SHA256SUMS.txt` 中该文件的对应记录。其他摘要记录不变。未知自定义 helper 会被拒绝。重复应用已修复版本不会再次更改文件。

这不是关闭校验：代码文件作合法修复后，其发行摘要必须同步反映新代码。主包归档、九个依赖归档及科研源文件的原摘要均保留。

修复成功后重跑原安装步骤 3；本次错误发生在目标包库创建及安装包之前，若库仍不存在或为空，可以使用原目录 `library_R4_6_v020`。若该目录已非空，则另选新空目录并保留旧目录，不删除官方环境记录。

## 已执行检查

12 项 SHA256 编码和拒绝条件回归通过，包括非法 UTF-8 中文头尾、空格分组摘要、错误长度、重复摘要、非零退出码和真正的摘要不一致。补丁应用、备份、幂等、未知本地编辑及损坏补丁拒绝检查通过。执行环境为 Linux R，使用模拟外部工具输出；没有声称已在用户 Win11 执行成功。

本小补丁针对现有解压包，只更新两个文件。新的完整 installfix1 交付 ZIP 另外包含上述回归测试；二者使用同一固定 helper，科学包和模型代码相同。
