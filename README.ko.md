# Mini-Terminal

<p align="center"><a href="README.md">English</a> · <a href="README.ja.md">日本語</a> · <a href="README.zh-Hans.md">简体中文</a> · <a href="README.zh-Hant.md">繁體中文</a> · <strong>한국어</strong> · <a href="README.es.md">Español</a> · <a href="README.fr.md">Français</a> · <a href="README.de.md">Deutsch</a> · <a href="README.pt.md">Português</a></p>

전체 Terminal 창을 열 필요가 없는 짧은 작업을 위한 가벼운 네이티브 macOS Shell 런처입니다. 전역 단축키로 열고 한 줄 명령을 실행하거나, 클립보드를 자동으로 붙여넣고 실행한 뒤 결과를 다시 복사할 수 있습니다.

## 주요 기능

- AppKit + SwiftUI 네이티브 macOS 앱
- 설정 가능한 전역 단축키, 기본값 `⌥ Space`
- Spotlight 스타일 플로팅 패널
- 클립보드 자동 붙여넣기 / 자동 실행 / 출력 자동 복사
- INPUT / OUTPUT 분할 보기와 복사 피드백
- 최대 100개의 로컬 실행 기록과 ↑ / ↓ 호출
- exit code 및 실행 시간 표시
- Shell 경로와 작업 디렉터리 설정
- 위험하거나 여러 줄인 명령의 실행 전 확인
- System 모드와 영어, 일본어, 중국어 간체/번체, 한국어, 스페인어, 프랑스어, 독일어, 포르투갈어

## 설치

```bash
git clone https://github.com/uniplanck/Mini-Terminal.git
cd Mini-Terminal
bash scripts/build-app.sh
open dist/Mini-Terminal.app
```

macOS 14 이상과 Xcode / Swift toolchain이 필요합니다.

## 안전

클립보드 자동 실행의 안전 검사는 휴리스틱이며 샌드박스가 아닙니다. 웹이나 채팅 등 신뢰할 수 없는 곳에서 복사한 명령은 실행 전에 확인하세요.

설정과 기록은 로컬에 저장됩니다. 실행한 명령 자체는 macOS 권한에 따라 파일, 프로세스, 네트워크에 접근할 수 있습니다.

현재 버전: **0.3.0**.
