# Mini-Terminal

<p align="center"><a href="README.md">English</a> · <a href="README.ja.md">日本語</a> · <strong>简体中文</strong> · <a href="README.zh-Hant.md">繁體中文</a> · <a href="README.ko.md">한국어</a> · <a href="README.es.md">Español</a> · <a href="README.fr.md">Français</a> · <a href="README.de.md">Deutsch</a> · <a href="README.pt.md">Português</a></p>

一个轻量、原生的 macOS Shell 命令启动器。按下全局快捷键，输入一条命令并执行；也可以在打开时自动粘贴剪贴板、立即执行，并将输出复制回剪贴板。

## 主要功能

- AppKit + SwiftUI 原生 macOS 应用
- 可配置全局快捷键，默认 `⌥ Space`
- Spotlight 风格浮动窗口
- 可选的剪贴板自动粘贴 / 自动执行 / 输出自动复制
- INPUT / OUTPUT 分栏与复制反馈
- 最多 100 条本地执行历史，支持 ↑ / ↓ 调用
- exit code 与执行时间
- Shell 路径与工作目录设置
- 危险或多行命令的确认保护
- System 语言模式，以及英语、日语、简体中文、繁体中文、韩语、西班牙语、法语、德语、葡萄牙语

## 安装

```bash
git clone https://github.com/uniplanck/Mini-Terminal.git
cd Mini-Terminal
bash scripts/build-app.sh
open dist/Mini-Terminal.app
```

需要 macOS 14 或更高版本以及 Xcode / Swift toolchain。

## 安全

剪贴板自动执行很方便，但安全检查只是启发式保护，不是沙箱。来自网页、聊天或不可信来源的命令应在执行前检查。

Mini-Terminal 的设置和历史保存在本机。你执行的命令仍可按照自身行为和 macOS 权限访问文件、进程或网络。

## 开发

```bash
swift test
bash scripts/build-app.sh
```

当前版本：**0.3.0**。
