# Mini-Terminal

<p align="center"><a href="README.md">English</a> · <a href="README.ja.md">日本語</a> · <a href="README.zh-Hans.md">简体中文</a> · <a href="README.zh-Hant.md">繁體中文</a> · <a href="README.ko.md">한국어</a> · <a href="README.es.md">Español</a> · <strong>Français</strong> · <a href="README.de.md">Deutsch</a> · <a href="README.pt.md">Português</a></p>

Un lanceur Shell natif et léger pour macOS, destiné aux commandes courtes qui ne justifient pas l’ouverture d’une fenêtre Terminal complète.

## Fonctions

- App macOS native en AppKit + SwiftUI
- Raccourci global configurable, `⌥ Space` par défaut
- Panneau flottant de style Spotlight
- Collage, exécution et copie automatique via le presse-papiers
- Vue INPUT / OUTPUT
- Historique local jusqu’à 100 commandes et rappel avec ↑ / ↓
- exit code et durée d’exécution
- Shell et dossier de travail configurables
- Confirmation des commandes potentiellement dangereuses ou multilignes
- Mode System et prise en charge de EN, JA, ZH-Hans, ZH-Hant, KO, ES, FR, DE et PT

## Installation

```bash
git clone https://github.com/uniplanck/Mini-Terminal.git
cd Mini-Terminal
bash scripts/build-app.sh
open dist/Mini-Terminal.app
```

Nécessite macOS 14 ou version ultérieure et Xcode / Swift toolchain.

## Sécurité

La détection des commandes à risque est heuristique et ne constitue pas un bac à sable. Vérifiez les commandes provenant d’une source non fiable avant de les exécuter.

Version actuelle : **0.3.0**.
