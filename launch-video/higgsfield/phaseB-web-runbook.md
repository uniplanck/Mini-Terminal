# Phase B — Higgsfield Web 手動生成ランブック（3本 first pass）

CLI生成はトライアル制限で不可（2026-10-08 再確認: `only_website_usage_on_trial_is_available`、消費0）。Higgsfield **Web版** で3本を手動生成する。
Prompt は [`jobs.json`](jobs.json) Phase B から機械的に転記（一字一句同じ）。コードブロックの中身をそのまま貼る。

## 共通設定

| 項目 | 値 |
|---|---|
| モデル | **Kling 3.0 Omni (Frames)**（CLI名 `kling_o3_flf`）。Webで名称が異なる場合は Kling 3.0 Omni の「開始フレーム（Start frame / First frame）」指定モード |
| 入力 | **Start frame（開始フレーム）のみ**。End frame は指定しない |
| Duration | **5秒** |
| Mode / Quality | **Pro** |
| Sound / Audio | **OFF（音声なし）** |
| Aspect Ratio | **16:9** |
| Multi-shot | **OFF** |
| 生成数 | **各1本**（リトライ・追加生成は承認範囲外） |
| 想定credit | **6.25 / 本、3本で18.75**（2026-10-08 CLI見積もり、採用画像を入力に指定済み）。Webの生成ボタンの表示が異なる場合は生成せず止める |
| 合計上限 | **18.75 credits** |
| 保存先 | `launch-video/higgsfield/outputs/phaseB/`（Git管理外）。ダウンロードした原寸のMP4のまま |

## チェックリスト

| ID | 入力画像 | モデル | 尺 / Mode / 音声 | credit | 保存ファイル名 | 済 |
|---|---|---|---|---|---|---|
| V1-H1 | `H1-A_obsidian.png` | Kling 3.0 Omni (Frames) | 5秒 / Pro / OFF | 6.25 | `V1-H1_obsidian_plate.mp4` | ☐ |
| V2-H2 | `H2-B_keycap.png` | Kling 3.0 Omni (Frames) | 5秒 / Pro / OFF | 6.25 | `V2-H2_keycap_press.mp4` | ☐ |
| V3-H3 | `H3-A_ribbon.png` | Kling 3.0 Omni (Frames) | 5秒 / Pro / OFF | 6.25 | `V3-H3_light_ribbon.mp4` | ☐ |

---

## V1-H1（jobs.json: `V1-1`）

用途: S01 HOOK 背景（2.0秒使用）

| 項目 | 値 |
|---|---|
| 入力画像（Start frame） | `launch-video/higgsfield/outputs/phaseA/H1-A_obsidian.png` |
| モデル | Kling 3.0 Omni (Frames) |
| 尺 | 5秒 |
| Mode | Pro |
| 音声 | なし（OFF） |
| Aspect Ratio | 16:9 |
| 想定credit | 6.25 |
| 保存ファイル名 | `launch-video/higgsfield/outputs/phaseB/V1-H1_obsidian_plate.mp4` |

Prompt:

```text
Locked-off camera with an almost imperceptible slow push-in. The thin slit of light drifts very slowly across the smoked black glass and the reflection breathes softly. Calm, silent, minimal, no new objects appear, no text.
```

生成後に見るポイント:

- 光のスリットがゆっくり流れ、新しい物体・文字が出てこない
- 左側の黒い余白が保たれている
- ガラス面のちらつき・床の質感の破綻がない


## V2-H2（jobs.json: `V2-1`）— ❌ 2026-10-09 不採用・退役

> 生成指が不自然 / option 相当しか押していない / 入力H2が非Mac配列（command 無し）。**再生成・V2-2 は実行しない。** S02 は実物撮影 + AE（[`../planning/h2-redesign.md`](../planning/h2-redesign.md)）。

用途: S02 KEYS 打鍵（押下前後の1.5秒使用）

| 項目 | 値 |
|---|---|
| 入力画像（Start frame） | `launch-video/higgsfield/outputs/phaseA/H2-B_keycap.png` |
| モデル | Kling 3.0 Omni (Frames) |
| 尺 | 5秒 |
| Mode | Pro |
| 音声 | なし（OFF） |
| Aspect Ratio | 16:9 |
| 想定credit | 6.25 |
| 保存ファイル名 | `launch-video/higgsfield/outputs/phaseB/V2-H2_keycap_press.mp4` |

Prompt:

```text
Static macro shot, very slow parallax drift. At around two seconds the small modifier key and the space bar are pressed down together once, quickly and decisively, travel about two millimetres and stay down; the rim light glints along the key edges as they move. No hands, no fingers, nothing else moves, keycaps stay blank.
```

生成後に見るポイント:

- 小さいキーとスペースバーが同時に1回だけ沈み、戻らない（または自然に止まる）
- 手・指が出てこない、キートップに文字が出ない
- キー形状が変形しない


## V3-H3（jobs.json: `V3-1`）

用途: S07 RIBBON 転換（1.5秒使用）

| 項目 | 値 |
|---|---|
| 入力画像（Start frame） | `launch-video/higgsfield/outputs/phaseA/H3-A_ribbon.png` |
| モデル | Kling 3.0 Omni (Frames) |
| 尺 | 5秒 |
| Mode | Pro |
| 音声 | なし（OFF） |
| Aspect Ratio | 16:9 |
| 想定credit | 6.25 |
| 保存ファイル名 | `launch-video/higgsfield/outputs/phaseB/V3-H3_light_ribbon.mp4` |

Prompt:

```text
The ribbon of light sweeps smoothly from bottom-left to top-right across the whole frame, briefly flooding the frame with soft luminous grey light at its brightest moment, then recedes to black. Slow, elegant, continuous motion, slight camera drift, no text, no objects.
```

生成後に見るポイント:

- リボンが左下→右上に流れ、画面全体が明るくなる瞬間がある
- 文字・物体が出ない
- 動きが滑らかで途切れない


## 生成後

1. 3ファイルが `outputs/phaseB/` に上の名前で揃っていることを確認
2. Web の履歴で消費creditの合計を控える（18.75以下）
3. チャットで「Phase B 保存完了」と伝える → 3本のレビュー（採用可否、60fps化・AE合成の可否）を行う
