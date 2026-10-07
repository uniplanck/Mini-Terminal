# Mini-Terminal

<p align="center"><a href="README.md">English</a> · <a href="README.ja.md">日本語</a> · <a href="README.zh-Hans.md">简体中文</a> · <a href="README.zh-Hant.md">繁體中文</a> · <a href="README.ko.md">한국어</a> · <a href="README.es.md">Español</a> · <a href="README.fr.md">Français</a> · <a href="README.de.md">Deutsch</a> · <strong>Português</strong></p>

Um lançador Shell nativo e leve para macOS, pensado para comandos rápidos que não justificam abrir uma janela completa do Terminal.

## Recursos

- App nativo em AppKit + SwiftUI
- Atalho global configurável, padrão `⌥ Space`
- Painel flutuante no estilo Spotlight
- Colagem, execução e cópia de saída opcionais via área de transferência
- Visualização INPUT / OUTPUT
- Histórico local de até 100 execuções e navegação com ↑ / ↓
- exit code e duração da execução
- Shell e diretório de trabalho configuráveis
- Confirmação de comandos potencialmente perigosos ou multilinha
- Modo System e suporte a EN, JA, ZH-Hans, ZH-Hant, KO, ES, FR, DE e PT

## Instalação

```bash
git clone https://github.com/uniplanck/Mini-Terminal.git
cd Mini-Terminal
bash scripts/build-app.sh
open dist/Mini-Terminal.app
```

Requer macOS 14 ou posterior e Xcode / Swift toolchain.

## Segurança

A detecção de comandos de risco é heurística, não um sandbox. Revise comandos vindos de fontes não confiáveis antes de executá-los.

Versão atual: **0.3.0**.
