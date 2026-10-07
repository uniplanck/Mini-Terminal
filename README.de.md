# Mini-Terminal

<p align="center"><a href="README.md">English</a> · <a href="README.ja.md">日本語</a> · <a href="README.zh-Hans.md">简体中文</a> · <a href="README.zh-Hant.md">繁體中文</a> · <a href="README.ko.md">한국어</a> · <a href="README.es.md">Español</a> · <a href="README.fr.md">Français</a> · <strong>Deutsch</strong> · <a href="README.pt.md">Português</a></p>

Ein leichter nativer Shell-Launcher für macOS, gedacht für kurze Befehle, für die sich ein komplettes Terminalfenster nicht lohnt.

## Funktionen

- Native macOS-App mit AppKit + SwiftUI
- Konfigurierbares globales Tastenkürzel, standardmäßig `⌥ Space`
- Schwebendes Panel im Spotlight-Stil
- Optionales Einfügen, Ausführen und Kopieren über die Zwischenablage
- INPUT / OUTPUT-Ansicht
- Lokaler Verlauf mit bis zu 100 Einträgen und ↑ / ↓-Abruf
- exit code und Ausführungsdauer
- Konfigurierbare Shell und Arbeitsverzeichnis
- Bestätigung potenziell gefährlicher oder mehrzeiliger Befehle
- System-Modus sowie EN, JA, ZH-Hans, ZH-Hant, KO, ES, FR, DE und PT

## Installation

```bash
git clone https://github.com/uniplanck/Mini-Terminal.git
cd Mini-Terminal
bash scripts/build-app.sh
open dist/Mini-Terminal.app
```

Benötigt macOS 14 oder neuer und Xcode / Swift toolchain.

## Sicherheit

Die Erkennung riskanter Befehle ist heuristisch und keine Sandbox. Prüfen Sie Befehle aus nicht vertrauenswürdigen Quellen vor der Ausführung.

Aktuelle Version: **0.3.0**.
