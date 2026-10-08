# Production Plan

## 0. 完了条件と現在地

| 段階 | 内容 | 状態 |
|---|---|---|
| P0 | 企画・タイムライン・Shot List・Storyboard・台本・予算・AE設計・JSX骨格 | **完了（本コミット範囲）** |
| P1 | UIフリーズ承認（`docs/v0.4-ui-review.md` の残チェック） | 未（オーナー判断） |
| P2 | Higgsfield Phase A（キーフレーム 16.5 cr） | **承認待ち** |
| P3 | 実UI撮影 UI_T01–T05 | P1後 |
| P4 | Higgsfield Phase B（i2v 37.5 cr） | P2レビュー後に承認 |
| P5 | AE組み立て（`ae/scripts/build_launch_film.jsx`）→ ラフカット | P3/P4後 |
| P6 | 音楽・SFX・ElevenLabs VO（標準語/関西弁）| VOは別途承認 |
| P7 | 仕上げ・書き出し（本編、X用、READMEループ） | — |

## 1. 実UI撮影（P3）

### 環境

- macOS ダークモード、アクセントカラー=ブルー（既定）、壁紙は単色黒、メニューバー/Dockは撮影領域外
- 表示: Retina内蔵ディスプレイ 2x。撮影領域はパネル周辺のみ（UIを最大200%まで寄れる解像度を確保）
- 録画: 60fps固定フレームレート。ScreenCaptureKitベースのツール（OBS「macOS Screen Capture」等）で ProRes 422 HQ。システムカーソル非表示（カーソルはAEで描く）
- **撮影専用プロファイル**: アプリの言語=日本語、作業ディレクトリ=`~/demo`（撮影用のこのリポジトリのクローン）、履歴は架空エントリのみ、クリップボードには撮影用文字列のみ
  - `--ui-fixture --film <scene>`（debugビルド専用）で実現済み。詳細は [`film-capture-mode.md`](film-capture-mode.md)
- 通知・Secure Event Input の影響を受けないよう、撮影中は他アプリを閉じる

### 撮影ルール

- 各テイク5回、カウント「3-2-1」後に操作。操作の速さは「熟練者が普段の速度で」。AEで速度は変えない
- 実行結果の `ms` は実測値をそのまま使う（盛らない）
- 危険コマンドは `rm -rf ./build` を **入力して確認ダイアログを出し、必ずキャンセル**。実行しない
- 個人情報（ユーザー名を含むパス、実履歴、実クリップボード）が映ったテイクは破棄

## 2. After Effects 設計

### プロジェクト構成（ビン）

```
Mini-Terminal_LaunchFilm.aep            ← ae/project/（Git管理外、JSXで再生成可能）
├── 00_OUTPUT
│   ├── MAIN_LaunchFilm_1920x1080_60      18.0s  本編
│   ├── MAIN_LaunchFilm_textless          18.0s  文字なし（差し替え・再編集用）
│   ├── README_LOOP_6s                     6.0s  3.5–9.5 テキストなし
│   └── README_LOOP_8_5s                   8.5s  3.5–12.0 テキストなし
├── 01_SHOTS                               S01_HOOK … S08_ENDCARD（各ショットの尺ちょうど）
├── 02_PRECOMPS
│   ├── PC_TYPE_*                          ショットごとのタイポ
│   ├── PC_KEYCHIP_{OptSpace,CmdC,CmdReturn}
│   ├── PC_CURSOR                          ベクターカーソル（default / pressed）
│   ├── PC_TEXTCARD                        S04のコピー元メモカード
│   └── PC_CALLOUT                         S05の下線コールアウト
├── 03_ASSETS
│   ├── UI       UI_T01–T05
│   ├── HF       HF_H1–H3
│   ├── AUDIO    music / sfx / vo_standard / vo_kansai
│   └── GFX      cursor_arrow.svg
└── 04_GUIDES    GUIDE_Grid12（ガイドレイヤー、書き出しに出ない）
```

### MAIN のレイヤー構成（上から）

| # | レイヤー | 種別 | 備考 |
|---|---|---|---|
| 1 | GUIDE_Grid12 | シェイプ（ガイド） | 12カラム / マージン96 / ガター24 |
| 2 | ADJ_Grade | 調整レイヤー | Lumetri: 黒を `#0A0A0B` に締める、グレイン微量 |
| 3 | TYPE_* | テキスト（各ショットpre-comp内） | 画面内テキストは `timeline.json` から生成 |
| 4 | S01…S08 | ショットpre-comp | in/outは `timeline.json` の start/end |
| 5 | AUD_VO_standard / AUD_VO_kansai | 音声 | どちらか一方のみ有効。書き出し時に切り替え |
| 6 | AUD_SFX | 音声 | |
| 7 | AUD_Music | 音声 | |

マーカー: 0.5秒ごとのビート（`b1`…`b36`、4拍ごとに `bar`）、ナレーション窓（`N1`…`N6`）、ショット境界。

### ショットpre-compの標準構成

```
S0x_NAME
├── CAM            3Dカメラ（1ノード、ズームは50mm相当）。プッシュは z 位置のキーフレーム
├── TYPE_LABEL     01 — 呼ぶ（JetBrains Mono 18px muted）
├── TYPE_COPY      ショットのコピー（Noto Sans JP）
├── HUD_*          キーチップ / カーソル / コールアウト
├── BASE           UI録画 または HF素材（3D layer）
└── BG             #0A0A0B 平面
```

### 60fps 方針

- 実UI: 60fps録画をネイティブで使用
- HF素材（24/30fps出力想定）: レイヤーの「時間補間 → Pixel Motion」＋必要に応じて Timewarp。破綻時のみ `fps_boost` を見積もり→承認

### 書き出し

| 出力 | 仕様 | 先 |
|---|---|---|
| マスター | ProRes 422 HQ, 1920×1080, 60fps, 48kHz/24bit | `renders/master/` |
| X投稿用 | H.264 High, 1920×1080, 60fps, 16–20 Mbps VBR 2-pass, AAC 320kbps, faststart | `renders/x/`（ffmpeg） |
| GitHub公開用 | H.264, 1920×1080, 60fps, < 10MB目標（READMEに直接添付する場合の容量対策） | `renders/github/` |
| READMEループ | MP4 H.264 1280×720 30fps 無音 + GIF 960px 15fps（palettegen） | `renders/readme/` |
| VO差し替え版 | 標準語版 / 関西弁版を同じ映像で2本 | `renders/x/` |

`renders/` と `preview/` はGit管理外。

## 3. スケジュール目安（承認待ち時間を除く）

| 作業 | 目安 |
|---|---|
| Phase A 生成・レビュー | 0.5日 |
| 実UI撮影（5テイク × 5種） | 0.5日 |
| Phase B 生成・選定 | 0.5日 |
| AEラフカット（JSX→手作業） | 1日 |
| 音・VO・仕上げ・書き出し | 1日 |

## 4. リスクと対策

| リスク | 対策 |
|---|---|
| UIが撮影後に変わる | P1（UIフリーズ）を撮影の前提条件にする |
| 生成キーキャップの刻印が崩れる | 刻印なしで生成し、AEで ⌥ / Space を4点トラック合成 |
| 生成素材の60fps化で破綻 | 生成素材の画面時間を1.5–2.0秒に限定、Pixel Motion。HF由来の動きは遅いものに限る |
| 残高100 < 上限150 | 計画は78.25（予備込み）で残高内に収める |
| 関西弁が「演技」に聞こえる | 本人による読み上げチェック項目を `script-ja.md` に定義、行単位で生成 |
| フォントライセンス | 映像内タイポはOFL書体のみ（Noto Sans JP / Inter / JetBrains Mono）。UI録画内のシステム書体は加工しない |
| 安全機能の過大表現 | 台本は「確認」まで。README Safety節と照合済み |
