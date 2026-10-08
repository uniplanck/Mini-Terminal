# After Effects

状態: **2026-10-09 に After Effects 26.5（日本語版）で全 8 ショットを組み上げ、18 秒プレビューを書き出し済み**（[`../planning/preview-v1-status.md`](../planning/preview-v1-status.md)）。S02 押下リグの検証は [`../planning/h2-redesign.md`](../planning/h2-redesign.md) §7。

| ファイル | 役割 |
|---|---|
| [`scripts/build_launch_film.jsx`](scripts/build_launch_film.jsx) | AEプロジェクトを新規作成し、ビン・コンポ・マーカー・テキスト・プレースホルダーを組む |
| [`scripts/verify_s02.jsx`](scripts/verify_s02.jsx) | ヘッドレスでビルド → S02 リグの構造・評価値をレポート → `project/verify_S02.aep` に保存 → S02 を `../preview/verify_s02/` に TIFF 連番でレンダー。レポートは AE の環境設定（`Settings_MiniTerminalVerify`）に書く（スクリプトのファイル書き込みが無効な設定でも動くため） |
| [`scripts/render_preview.jsx`](scripts/render_preview.jsx) | ヘッドレスでビルド → 全コンプの欠落フッテージ・エクスプレッションエラー・代替フォントを検査 → `project/LaunchFilm_preview.aep` に保存 → MAIN と README_LOOP_6s を H.264 で `../preview/` に書き出し |
| [`scripts/make-temp-audio.py`](scripts/make-temp-audio.py) | 仮 BGM/SFX（ローカル合成、timeline.json のイベント時刻に同期）→ `../assets/audio/temp/temp_mix.wav` |
| [`scripts/build-animatic.mjs`](scripts/build-animatic.mjs) | `timeline.json` の検証と、ffmpegによるタイミング確認用アニマティック（`preview/animatic_v1.mp4`）の生成 |
| `project/` | 保存先（`.aep` は再生成できるためGit管理外） |

データの正は [`../planning/timeline.json`](../planning/timeline.json)（尺・ショット・コピー・ナレーション窓・ループ・音声版）と [`../assets/manifest.json`](../assets/manifest.json)（素材のパス）。JSXはこの2つを読むだけで、値を持たない。

## 1. JSX骨格の処理順

| # | 処理 | 関数 / 箇所 | 備考 |
|---|---|---|---|
| 1 | `timeline.json` と `manifest.json` を読む | `readJSON` | ExtendScriptにJSONがないため、信頼できるローカルファイルを `eval` |
| 2 | 新規プロジェクト作成 | `app.newProject()` | 開いているプロジェクトには触らない |
| 3 | ビン作成 | `folder` | 00_OUTPUT / 01_SHOTS / 02_PRECOMPS / 03_ASSETS(UI, HF, AUDIO, GFX) / 04_GUIDES |
| 4 | ショットごとにpre-compを作成 | ループ本体 | `S0x_NAME`。尺は start–end ちょうど |
| 5 | BG平面 | `addSolid` | `#0A0A0B` |
| 6 | BASE素材 | `importAsset` / `placeholder` | manifestのパスにファイルがあれば読み込み、なければ「PLACEHOLDER <素材ID>」平面。Higgsfield素材にはPixel Motionを設定（60fps化）。`press` を持つショット（S02）は `buildS02Rig` で押下リグ `PC_H2R_RIG` を組み、`finishS02` でプッシュと露出パルスを付ける |
| 7 | CAM | `addCamera` | BASEだけが3D。テキストは2Dでグリッドに固定 |
| 8 | タイポpre-comp | `addText` / `revealIn` | `PC_TYPE_S0x`。ラベル（JetBrains Mono 18px）とコピー。上方向24px＋フェードのexpo-out登場 |
| 9 | MAINへ配置 | — | ショットとタイポを start に配置。textless版はショットのみ |
| 10 | マーカー | `addMarker` | 0.5秒ごとのビート（`b1`…`b36`、4拍ごと `bar`）、ショット境界、VOキュー（標準語/関西弁の2本のヌル。既定はどちらも無効） |
| 11 | 調整レイヤー / グリッド | `ADJ_Grade` / `gridGuide` | 12カラムのガイドレイヤー（書き出されない） |
| 12 | READMEループ | `loops` | textless版をネストしてループ区間にオフセット |

### TODO（骨格に残している部分）

- 音声の読み込み（`assets/audio/vo/{standard,kansai}/N*.wav` をキュー位置に、音楽、SFX）
- READMEループの最後0.3秒を UI_T02 のEsc閉じテイクに差し替え（最終フレーム＝最初のフレーム）
- カメラのプッシュ／パン、HUD（キーチップ・カーソル・コールアウト）、S07のディスプレイスメントは、素材が揃ってから手作業で詰める
- S02: `PC_H2R_RIG` の CAP / FILL / MATTE マスクは仮の矩形。プレート到着後に実キー輪郭でトレースし、`travel px` を参照写真Bで実測して上書き（[`../planning/h2-redesign.md`](../planning/h2-redesign.md) §4）
- レンダーキューのテンプレート登録

## 2. コンポ構成

```
00_OUTPUT
  MAIN_LaunchFilm_1920x1080_60   18.0s  本編（既定はナレーションなし）
  MAIN_LaunchFilm_textless       18.0s  文字なし（READMEループの元）
  README_LOOP_6s                  6.0s  3.5–9.5s
  README_LOOP_8_5s                8.5s  3.5–12.0s
01_SHOTS
  S01_HOOK 2.0 · S02_KEYS 1.5 · S03_SUMMON 2.5 · S04_CLIPBOARD 3.5
  S05_SPLIT 2.5 · S06_TRUST 2.0 · S07_RIBBON 1.5 · S08_ENDCARD 2.5
02_PRECOMPS
  PC_TYPE_S01 … PC_TYPE_S08                     タイポ（MAINのみで使用）
  PC_H2R_RIG                                    S02 押下リグ（CTRL_Press / CAP / MATTE / FILL / SHADE / PLATE）
  PC_KEYCHIP_* / PC_CURSOR / PC_TEXTCARD / PC_CALLOUT   手作業で追加予定
03_ASSETS  UI / HF / PLATE / AUDIO / GFX
04_GUIDES  GUIDE_Grid12
```

MAINのレイヤー（上から）: `GUIDE_Grid12`（ガイド）→ `ADJ_Grade` → `VO_CUES_standard` / `VO_CUES_kansai`（無効）→ `TYPE_S0x` と `S0x_NAME` を時間順に → 音声。

ショットpre-compの中身: `CAM` → `BASE`（3D）→ `BG`。

音声の版（`audioVersions`）: `NOVO`（既定、音楽＋SFX）/ `VO_STANDARD` / `VO_KANSAI`。映像・テキストは3版共通で、VO版はVOトラックを有効にし、VO中は音楽を -6 dB ダッキングするだけ。

## 3. 必要素材一覧

| ID | 種類 | 使用ショット | 作り方 | 状態 |
|---|---|---|---|---|
| UI_T01_summon_run | 実UI録画 | S03 | 撮影モード `--film S03` | 撮影モード実装済み・撮影前 |
| UI_T02_clipboard_flow（＋Esc閉じテイク） | 実UI録画 | S04, READMEループ | `--film S04` | 同上 |
| UI_T03_split_view | 実UI録画 | S05 | `--film S05` | 同上 |
| UI_T04_history_safety | 実UI録画 | S06, S07 | `--film S06` | 同上 |
| UI_T05_endcard_idle | 実UI録画 | S08 | `--film S08` | 同上 |
| UI_STILLS_reference | 実UI静止画 | レイアウト参照 | レンダリングスモークテストの日本語版 | 未 |
| HF_H1_obsidian_plate | Higgsfield動画 | S01 | gpt_image_2_5 → kling_o3_flf | 生成不可（アカウント制限、下記） |
| ~~HF_H2_keycap_press~~ | Higgsfield動画 | — | 2026-10-09 不採用（指・片側押下・非Mac配列） | 退役 |
| PLATE_H2R_keyrow | 静止画（ChatGPT制作） | S02 | オーナー提供（[`../planning/h2-redesign.md`](../planning/h2-redesign.md) §3）→ AE押下リグ | 未着。仮プレート（実機写真）でリグ検証済み |
| HF_H3_light_ribbon | Higgsfield動画 | S07 | 同上 | 同上 |
| AE_text_card | AE（手作業） | S04 | シェイプ＋テキスト | 未 |
| AE_cursor | SVG | S04–S06 | [`../assets/typography/cursor_arrow.svg`](../assets/typography/cursor_arrow.svg) | 作成済み |
| AE_keychips | AE（手作業） | S02–S04 | シェイプ＋Inter | 未 |
| FONT_NotoSansJP / Inter / JetBrainsMono | フォント（OFL） | 全体 | ローカルにインストール | 未（ローカル導入状況は未確認） |
| AUDIO_music | 音楽 120 BPM | 全体 | ライセンス音源 | 未 |
| AUDIO_sfx | SFX | S02–S07 | ライブラリ | 未 |
| AUDIO_vo_standard / kansai | ElevenLabs | 任意（VO版のみ） | 承認後 | 未・生成禁止中 |

全体の状態とパスは `../assets/manifest.json` が正。

## 4. 実行方法

検証だけなら（AE を開いた状態で）:

```bash
osascript -e 'tell application "Adobe After Effects 2026" to DoScriptFile "'"$PWD"'/ae/scripts/verify_s02.jsx"'
```

手作業で組む場合:

1. フォント3種をインストール
2. After Effects 2026 > ファイル > スクリプト > スクリプトファイルを実行 > `scripts/build_launch_film.jsx`
3. `project/Mini-Terminal_LaunchFilm.aep` として保存（Git管理外）

素材が欠けていてもプレースホルダーで組み上がるため、撮影前でもタイミング確認のために実行できる。
