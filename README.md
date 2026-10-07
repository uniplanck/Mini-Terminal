# Mini-Terminal

<p align="center">
  <strong>English</strong> ·
  <a href="README.ja.md">日本語</a> ·
  <a href="README.zh-Hans.md">简体中文</a> ·
  <a href="README.zh-Hant.md">繁體中文</a> ·
  <a href="README.ko.md">한국어</a> ·
  <a href="README.es.md">Español</a> ·
  <a href="README.fr.md">Français</a> ·
  <a href="README.de.md">Deutsch</a> ·
  <a href="README.pt.md">Português</a>
</p>

A lightweight, native macOS command launcher for the moments when opening a full Terminal window is overkill.

Press a global shortcut, type one shell command, run it, and get the result. Mini-Terminal can also paste the current clipboard automatically, execute it immediately, and copy the output back to the clipboard.

## What it does

- Native macOS app built with AppKit + SwiftUI
- Global shortcut, configurable from Settings
- Fast Spotlight-style floating command panel
- Optional clipboard paste when the panel opens
- Optional clipboard auto-run on open
- Optional automatic output copy
- One-second copy confirmation feedback
- Split INPUT / OUTPUT view
- Persistent execution history, up to 100 entries
- ↑ / ↓ command history recall
- Exit code and execution duration
- Configurable shell path and working directory
- Confirmation guard for potentially destructive or multi-line commands
- System-language mode plus English, Japanese, Simplified Chinese, Traditional Chinese, Korean, Spanish, French, German, and Portuguese

## Quick start

Requirements: macOS 14 or later, Xcode / Swift toolchain.

```bash
git clone https://github.com/uniplanck/Mini-Terminal.git
cd Mini-Terminal
bash scripts/build-app.sh
open dist/Mini-Terminal.app
```

The default shortcut is:

```text
⌥ Space
```

You can change it in Settings.

## Typical workflow

```text
Copy a command
      ↓
Press the Mini-Terminal shortcut
      ↓
Paste automatically (optional)
      ↓
Run automatically (optional)
      ↓
Copy output automatically (optional)
```

The lightning button in the launcher toggles clipboard auto-run without opening Settings.

## History

Every completed command is stored locally in a rolling history of up to 100 entries.

- Click the clock button to browse history.
- Click an entry to restore its command, output, exit code, and duration.
- Use ↑ / ↓ in the command field to recall previous commands.
- Clear the saved history from the history panel.

## Languages

The default language mode is **System**. Mini-Terminal checks the preferred languages configured in macOS and uses the first supported language. If none match, it falls back to English.

Supported UI languages:

- English
- 日本語
- 简体中文
- 繁體中文
- 한국어
- Español
- Français
- Deutsch
- Português

The language can also be selected manually in Settings.

## Safety

Clipboard auto-run is powerful and should be treated accordingly.

Mini-Terminal detects several risky patterns such as `rm`, `sudo`, `git reset --hard`, recursive permission changes, and multi-line commands, then asks for confirmation before execution when the safety option is enabled.

This guard is heuristic, not a sandbox. It cannot prove that a command is safe. Review commands you do not trust, especially commands copied from websites, chats, documentation, or generated text.

Mini-Terminal itself keeps settings and history locally. Commands you run may access files, processes, or the network according to their own behavior and your macOS permissions.

## Why it opens quickly

Mini-Terminal is designed as a resident menu-bar application. The process stays alive while the app is running, so the global shortcut does not cold-start the entire application every time. It only shows the existing floating panel.

That is the important distinction: this is not a smaller Terminal window. It is a fast launcher for short shell interactions.

## Development

Run directly:

```bash
swift run Mini-Terminal
```

Run tests:

```bash
swift test
```

Build the local app bundle:

```bash
bash scripts/build-app.sh
```

The generated app is:

```text
dist/Mini-Terminal.app
```

## Current status

Mini-Terminal is an early public build. The current local app version is **0.3.0**.

The project currently focuses on one-command shell execution, clipboard automation, command history, localization, and low-friction native macOS interaction.
