# Mini-Terminal

<p align="center"><a href="README.md">English</a> · <a href="README.ja.md">日本語</a> · <a href="README.zh-Hans.md">简体中文</a> · <strong>繁體中文</strong> · <a href="README.ko.md">한국어</a> · <a href="README.es.md">Español</a> · <a href="README.fr.md">Français</a> · <a href="README.de.md">Deutsch</a> · <a href="README.pt.md">Português</a></p>

一個輕量、原生的 macOS Shell 命令啟動器。按下全域快速鍵，輸入一條命令並執行；也能在開啟時自動貼上剪貼簿、立即執行，再把輸出複製回剪貼簿。

## 主要功能

- AppKit + SwiftUI 原生 macOS App
- 可設定全域快速鍵，預設 `⌥ Space`
- Spotlight 風格浮動視窗
- 可選的剪貼簿自動貼上 / 自動執行 / 輸出自動複製
- INPUT / OUTPUT 分割檢視與複製回饋
- 最多 100 筆本機執行記錄，支援 ↑ / ↓ 呼叫
- exit code 與執行時間
- Shell 路徑與工作目錄設定
- 危險或多行命令的執行前確認
- System 語言模式，以及英文、日文、簡體中文、繁體中文、韓文、西班牙文、法文、德文、葡萄牙文

## 安裝

```bash
git clone https://github.com/uniplanck/Mini-Terminal.git
cd Mini-Terminal
bash scripts/build-app.sh
open dist/Mini-Terminal.app
```

需要 macOS 14 以上與 Xcode / Swift toolchain。

## 安全

剪貼簿自動執行很方便，但安全檢查只是啟發式保護，不是沙箱。從網頁、聊天或不可信來源複製的命令，應先確認內容再執行。

設定與歷史保存在本機；實際執行的命令仍可依照自身行為與 macOS 權限存取檔案、程序或網路。

## 開發

```bash
swift test
bash scripts/build-app.sh
```

目前版本：**0.3.0**。
