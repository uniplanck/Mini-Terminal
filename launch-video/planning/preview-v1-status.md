# Launch Film — 18秒プレビュー v1 状態（2026-10-09）

**プレビュー:** `launch-video/preview/LaunchFilm_preview_v1_18s.mp4`（1920×1080 / 60fps / 1080フレーム / 18.000秒 / AAC 256k、ナレーションなし・仮BGM/SFX）
README ループ: `launch-video/preview/README_loop_6s_preview_v1.mp4`（3.5–9.5秒、文字なし、無音）

画面右上のオレンジ文字（`WIP_NOTES` レイヤー）は、仮素材・再構成箇所の明示。本番書き出しでは無効にする。

## 作り方（再現手順）

```bash
bash launch-video/assets/ui/fixtures/make-film-workspace.sh
```

```bash
MINI_TERMINAL_FILM_FRAMES_DIR=$PWD/launch-video/assets/ui/stills/film MINI_TERMINAL_FILM_FIXTURE=$PWD/launch-video/assets/ui/fixtures/film-fixture.json swift test --filter FilmFrameRenderTests
```

```bash
python3 -I launch-video/ae/scripts/make-temp-audio.py
```

```bash
osascript -e 'tell application "Adobe After Effects 2026" to DoScriptFile "'"$PWD"'/launch-video/ae/scripts/render_preview.jsx"'
```

```bash
ffmpeg -y -i launch-video/preview/launch_film_preview.mp4 -i launch-video/assets/audio/temp/temp_mix.wav -map 0:v -map 1:a -c:v copy -c:a aac -b:a 256k -shortest -movflags +faststart launch-video/preview/LaunchFilm_preview_v1_18s.mp4
```

最後の ffmpeg は、AE の H.264 書き出しが AAC の先頭遅延（約 22 ms ≒ 1.3 フレーム）を補正しないため。映像は AE のストリームをそのままコピーし、音だけ元の WAV から入れ直す。

## ショット別の完成度

| Shot | 時間 | 内容 | 完成度 | 仮・未完了 |
|---|---|---|---|---|
| S01 HOOK | 0.0–2.0 | V1 黒ガラス（1.0–3.0秒区間、Pixel Motion で 60fps 化、100→103% プッシュ）+ 単語単位リビール 2 行、1.75 秒から上へ退場 | 構成・タイミングは完成 | V1 は 1280×720/24fps を 1.5 倍拡大（やや甘い） |
| S02 KEYS | 2.0–3.5 | H2 完成プレート + 押下リグ（option/space 同時、command 静止）、⌥ Space チップが同じフレームで 2px 沈む、f177 露出パルス | 構成・同期は完成 | H2 仮採用。押下の隙間・マスクの微調整は後回し（指示どおり） |
| S03 SUMMON | 3.5–6.0 | パネル即時表示 → 1 文字ずつの入力（26 状態）→ 5.0 秒実行 → `exit 0 · N ms` +「出力をコピーしました」、⌘↩ チップ、104→100% | 構成完成 | UI はオフスクリーン描画（画面録画ではない）。打鍵間隔は 2 フレーム/字の再構成 |
| S04 CLIPBOARD | 6.0–9.5 | テキストカード選択（AE カーソル）→ ⌘C / ⌥ Space チップ → 自動貼付・実行・コピー（実際の 1 フレーム以内の挙動）→ アクセントリング、横パン → 108% プッシュ、「貼る。実行。コピー。」を拍で点灯 | 構成完成 | 同上（オフスクリーン描画）。カード・カーソルは AE 製 |
| S05 SPLIT | 9.5–12.0 | 分割ボタンをクリック → 実ウィンドウの拡張 → ⌘↩ 実行 → `wc -l` 実出力 + `exit 0`/`ms` の下線コールアウト、104% プッシュ | 構成完成 | 同上 |
| S06 TRUST | 12.0–14.0 | 履歴クリック → 9 件の実履歴 → 13.0 秒ハードカットで `rm -rf ./build` の実行確認、カーソルは「キャンセル」にホバーで終わる | 構成完成・**確認ダイアログは再構成** | ダイアログの文字は実描画、枠とボタンは再構成（下記）。コピー「履歴100件。」と画面の「9件」の不一致は要判断 |
| S07 RIBBON | 14.0–15.5 | H3-A 静止画にリニアワイプでの光の通過・ドリフト・露出上昇、S06 最終状態のパネルが 100→38% で光に吸い込まれる、反転ルミナンスワイプで S08 へ | 構成完成 | 動画ではなく静止画ベースの動き |
| S08 ENDCARD | 15.5–18.0 | ワードマーク / 一行コピー / URL / macOS 14+、待機中パネル + ⌥ Space、0.15 秒スタッガー、17.6–18.0 秒で黒 | 構成完成 | ワードマークは Inter 未導入のため Noto Sans JP SemiBold |

## 実機（After Effects 26.5 日本語版）での検証結果

| 項目 | 結果 |
|---|---|
| ビルド | ✅ 114 アイテム、8 ショット + MAIN / textless / README ループ 2 本 |
| 欠落フッテージ | ✅ なし |
| エクスプレッション | ✅ 8 本、エラー 0 |
| フォント | ✅ テキスト 41 レイヤー、代替フォント 0（Inter / JetBrains Mono 未導入を検出 → Noto Sans JP SemiBold / Source Code Pro に変更済み） |
| 書き出し仕様 | ✅ 1920×1080、60fps、1080 フレーム、18.000 秒 |
| 黒コマ・欠落 | ✅ フェード前に黒コマなし（全 1080 フレームの輝度を走査）。大きな輝度変化はハードカット（2.0 / 3.5 / 12.0 秒）と S05 の実ウィンドウ拡張（9.9 秒）のみ |
| 音と画の同期 | ✅ 打鍵 2.950 秒（S02 f177）・S03 実行 5.000 秒・S06 カット 13.000 秒が、書き出したファイル上で一致（AE 単体書き出しでは +22 ms ずれるため音を入れ直し） |
| 日本語 | ✅ 全ショットで文字化けなし（目視、29 フレームの抜き出し + 修正後の再確認） |
| アプリのテスト | ✅ `swift test` 39 件中 0 失敗（2 件は環境変数指定時のみ実行する描画テストでスキップ） |

## UI について（UI Freeze 前であることの区別）

- S03–S06・S08 の UI は **アプリ自身の `LauncherView` を実際の `AppModel` / `ShellRunner` で動かしてオフスクリーン描画した静止画の連続**（`FilmFrameRenderTests`）。コマンドは撮影用ワークスペースで実際に実行しており、`4cb2e96`・`2026-09-21 14:13 UTC`・`wc -l` の出力・`exit` コード・ms は実測値。
- **画面録画ではない**: この作業環境には画面収録の権限がない（システム設定の変更はしていない）。そのため、デスクトップ越しの素材感（`.regularMaterial` は暗い単色になる）、ウィンドウの影、テキストキャレットは出ていない。
- アクセント色は macOS 既定の青に固定して描画（この Mac の設定は赤）。
- UI は v0.4 のレビュー候補の状態。**UI Freeze 前**なので、UI が変わったら `FilmFrameRenderTests` を再実行して描き直す（座標はレンダーから再計測が必要な箇所あり: リング・下線の位置は timeline.json の `rectPx`）。
- **S06 確認ダイアログ**: SwiftUI の `.alert` は別ウィンドウ（`_NSAlertPanel` シート）に出て、その背景・ボタンはオフスクリーンで描けなかった。文字（タイトル・本文・コマンド）は AppKit の実描画（PDF 経由）、**枠とボタンは再構成**。実機のボタン配置・配色は未確認。

## 本番映像として不足している素材

1. **実 UI の画面録画**（S03–S06・S08）: 画面収録の権限を付けた環境で、`--film S0x` の撮影モードを実録画する。少なくとも S06 の確認ダイアログは実録画が必要。
2. **本番 BGM・SFX**（ライセンス音源）: 現在は `make-temp-audio.py` の仮シンセ。
3. **V1 の高解像度版**（任意）: 現在 1280×720/24fps の拡大。
4. **H2 の押下の隙間・マスク微調整**（指示により後回し）。
5. **フォント**: Inter / JetBrains Mono を使うなら導入（無料・OFL）。導入しない場合は現行の代替で確定。
6. **README ループの終端**: Esc で閉じる尾（最終フレーム = 最初のフレーム）が未作成。現ループは 9.5 秒で切れる。
7. ナレーション（VO 版）: 生成禁止中のため未着手（既定の NOVO 版には不要）。

## 次の改善優先順位

1. S06 確認ダイアログを実画面の素材に差し替え（現状は唯一の「再構成 UI」）
2. 実 UI 録画テイクの取得（S03–S06・S08）→ オフスクリーン描画と差し替え
3. コピー「履歴100件。」と画面「9件」の整合（コピーを容量表現に変えるか、履歴を増やすか）
4. 本番 BGM/SFX の選定と差し替え、ミックス
5. README ループの終端（Esc 閉じ）
6. H2 の押下の隙間・マスク微調整、V1 の解像度
7. 最終書き出し時に `WIP_NOTES` を無効化
