# Mini-Terminal

<p align="center"><a href="README.md">English</a> · <a href="README.ja.md">日本語</a> · <a href="README.zh-Hans.md">简体中文</a> · <a href="README.zh-Hant.md">繁體中文</a> · <a href="README.ko.md">한국어</a> · <strong>Español</strong> · <a href="README.fr.md">Français</a> · <a href="README.de.md">Deutsch</a> · <a href="README.pt.md">Português</a></p>

Un lanzador Shell nativo y ligero para macOS, pensado para ejecutar comandos cortos sin abrir una ventana completa de Terminal.

## Funciones

- App nativa con AppKit + SwiftUI
- Atajo global configurable, por defecto `⌥ Space`
- Panel flotante tipo Spotlight
- Pegado, ejecución y copia de salida desde el portapapeles, todos opcionales
- Vista INPUT / OUTPUT
- Historial local de hasta 100 ejecuciones y navegación con ↑ / ↓
- exit code y duración
- Shell y directorio de trabajo configurables
- Confirmación para comandos potencialmente peligrosos o multilínea
- Modo System y soporte para EN, JA, ZH-Hans, ZH-Hant, KO, ES, FR, DE y PT

## Instalación

```bash
git clone https://github.com/uniplanck/Mini-Terminal.git
cd Mini-Terminal
bash scripts/build-app.sh
open dist/Mini-Terminal.app
```

Requiere macOS 14 o posterior y Xcode / Swift toolchain.

## Seguridad

La detección de comandos peligrosos es heurística, no un sandbox. Revisa cualquier comando copiado desde una fuente que no sea de confianza antes de ejecutarlo.

Versión actual: **0.3.0**.
