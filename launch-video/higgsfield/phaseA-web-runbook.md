# Phase A — Higgsfield Web 手動生成ランブック

Phase A（静止キーフレーム6枚）を Higgsfield **Web版** で手動生成するための手順。CLI はトライアル中のため生成不可（`only_website_usage_on_trial_is_available`）。
Prompt は [`jobs.json`](jobs.json) の Phase A から機械的に転記したもの（一字一句同じ）。コードブロックの中身をそのまま貼る。

## 共通設定

| 項目 | 値 |
|---|---|
| モデル | **GPT Image 2.5**（CLI名 `gpt_image_2_5`） |
| Aspect Ratio | **16:9** |
| Quality | **High** |
| Resolution | **2K** |
| 枚数（Batch / Images） | **1**（1 IDにつき1枚。複数枚設定だとcreditが倍になる） |
| 参照画像 | なし（Image reference / Style / Preset はすべて未使用） |
| Prompt enhance / Magic prompt 等の自動補正 | **OFF**（UIにある場合） |
| Variant（UIにある場合） | flare（CLI既定値） |
| 想定credit | **2.75 / 枚、6枚で16.5**（2026-10-08 CLI見積もり。Webの生成ボタンに表示される値を必ず確認し、異なれば生成せず止める） |
| 保存先 | `launch-video/higgsfield/outputs/phaseA/`（Git管理外） |
| 保存形式 | ダウンロードした原寸のまま（PNG推奨。JPEGしか選べない場合は拡張子 `.jpg`） |

上限は Phase A 合計 **16.5 credits**。リトライ（再生成）は Phase A の承認範囲外なので、気に入らなくても再生成せず、6枚揃った時点で止める。

## チェックリスト

| ID | モデル | AR | Quality / Res | credit | 保存ファイル名 | 済 |
|---|---|---|---|---|---|---|
| H1-A | GPT Image 2.5 | 16:9 | High / 2K | 2.75 | `H1-A_obsidian.png` | ☐ |
| H1-B | GPT Image 2.5 | 16:9 | High / 2K | 2.75 | `H1-B_obsidian.png` | ☐ |
| H2-A | GPT Image 2.5 | 16:9 | High / 2K | 2.75 | `H2-A_keycap.png` | ☐ |
| H2-B | GPT Image 2.5 | 16:9 | High / 2K | 2.75 | `H2-B_keycap.png` | ☐ |
| H3-A | GPT Image 2.5 | 16:9 | High / 2K | 2.75 | `H3-A_ribbon.png` | ☐ |
| H3-B | GPT Image 2.5 | 16:9 | High / 2K | 2.75 | `H3-B_ribbon.png` | ☐ |

---

## H1-A（jobs.json: `K1a`）

用途: S01 HOOK 背景（黒いスモークガラス＋光のスリット、左2/3は文字用の余白）

| 項目 | 値 |
|---|---|
| 使用モデル | GPT Image 2.5 |
| Aspect Ratio | 16:9 |
| Quality / Resolution | High / 2K |
| その他 | 枚数1、参照画像なし、Prompt自動補正OFF |
| 想定credit | 2.75 |
| 保存ファイル名 | `launch-video/higgsfield/outputs/phaseA/H1-A_obsidian.png` |

Prompt:

```text
Ultra-minimal dark product-film background plate. A large sheet of smoked black glass in a pitch-dark studio, a single thin horizontal slit of cool white light grazing across the glass from the right edge, falling off to pure black. Extremely shallow depth of field, very fine film grain, near-black tones (#0A0A0B) with soft blue-grey highlights. The left two-thirds of the frame is empty dark negative space reserved for typography. No text, no letters, no logos, no devices, no people. Photographic, high-end technology commercial, 16:9.
```

生成後に見るポイント:

- 左2/3に物体・光・文字がない（タイポを置く余白）
- 黒が潰れすぎず、ハイライトが青みのグレー
- ガラス以外の物体・文字・ロゴがない


## H1-B（jobs.json: `K1b`）

用途: S01 HOOK 背景（黒いスモークガラス＋光のスリット、左2/3は文字用の余白）

| 項目 | 値 |
|---|---|
| 使用モデル | GPT Image 2.5 |
| Aspect Ratio | 16:9 |
| Quality / Resolution | High / 2K |
| その他 | 枚数1、参照画像なし、Prompt自動補正OFF |
| 想定credit | 2.75 |
| 保存ファイル名 | `launch-video/higgsfield/outputs/phaseA/H1-B_obsidian.png` |

Prompt:

```text
Ultra-minimal dark product-film background plate. A large sheet of smoked black glass in a pitch-dark studio with a soft vertical band of cool white light reflected on the glass in the right third of the frame, faint caustic shimmer, everything else falling off to pure black. Extremely shallow depth of field, very fine film grain, near-black tones (#0A0A0B) with soft blue-grey highlights. The left two-thirds of the frame is empty dark negative space reserved for typography. No text, no letters, no logos, no devices, no people. Photographic, high-end technology commercial, 16:9.
```

生成後に見るポイント:

- 左2/3に物体・光・文字がない（タイポを置く余白）
- 黒が潰れすぎず、ハイライトが青みのグレー
- ガラス以外の物体・文字・ロゴがない


## H2-A（jobs.json: `K2a`）

用途: S02 KEYS キーキャップのマクロ（刻印なし。⌥ / Space はAEで合成）

| 項目 | 値 |
|---|---|
| 使用モデル | GPT Image 2.5 |
| Aspect Ratio | 16:9 |
| Quality / Resolution | High / 2K |
| その他 | 枚数1、参照画像なし、Prompt自動補正OFF |
| 想定credit | 2.75 |
| 保存ファイル名 | `launch-video/higgsfield/outputs/phaseA/H2-A_keycap.png` |

Prompt:

```text
Macro product photograph in near darkness of a low-profile aluminium keyboard: one small square modifier key next to the left end of a long space bar, matte black keycaps with completely blank tops (no legends, no symbols, no letters), thin cool rim light tracing the key edges, razor-thin depth of field focused on the small key, background falling off to black. Generic keyboard with no brand marks or logos, no hands. Premium technology commercial lighting, 16:9.
```

生成後に見るポイント:

- キートップに文字・記号・ロゴが一切ない（AEで刻印を合成するため必須）
- 小さいキーとスペースバーの位置関係が自然（キー形状の破綻なし）
- 手・指・ブランドの意匠がない


## H2-B（jobs.json: `K2b`）

用途: S02 KEYS キーキャップのマクロ（刻印なし。⌥ / Space はAEで合成）

| 項目 | 値 |
|---|---|
| 使用モデル | GPT Image 2.5 |
| Aspect Ratio | 16:9 |
| Quality / Resolution | High / 2K |
| その他 | 枚数1、参照画像なし、Prompt自動補正OFF |
| 想定credit | 2.75 |
| 保存ファイル名 | `launch-video/higgsfield/outputs/phaseA/H2-B_keycap.png` |

Prompt:

```text
Macro product photograph in near darkness of a low-profile aluminium keyboard, camera angle almost level with the keycaps: a small square modifier key sharp in the lower-left third, the long space bar beside it running diagonally out of focus toward the right. Matte black keycaps with completely blank tops (no legends, no symbols, no letters), a single cool blue-white rim light from behind tracing the key edges, background falling off to black. Generic keyboard with no brand marks or logos, no hands. Premium technology commercial lighting, 16:9.
```

生成後に見るポイント:

- キートップに文字・記号・ロゴが一切ない（AEで刻印を合成するため必須）
- 小さいキーとスペースバーの位置関係が自然（キー形状の破綻なし）
- 手・指・ブランドの意匠がない


## H3-A（jobs.json: `K3a`）

用途: S07 RIBBON 光のリボン（S08へのルミナンスワイプ用）

| 項目 | 値 |
|---|---|
| 使用モデル | GPT Image 2.5 |
| Aspect Ratio | 16:9 |
| Quality / Resolution | High / 2K |
| その他 | 枚数1、参照画像なし、Prompt自動補正OFF |
| 想定credit | 2.75 |
| 保存ファイル名 | `launch-video/higgsfield/outputs/phaseA/H3-A_ribbon.png` |

Prompt:

```text
Abstract light ribbon: a single smooth, wide ribbon of soft cool-white light with a faint blue edge sweeping diagonally from bottom-left to top-right through a black void, refracted as if through frosted glass, gently motion-blurred edges, elegant and minimal, mostly black frame. No text, no logos, no objects. 16:9.
```

生成後に見るポイント:

- 画面の大半が黒で、リボンが1本（B案は2本）の滑らかな形
- 文字・物体がない
- 動画化したとき画面を横切れる向き（左下→右上）


## H3-B（jobs.json: `K3b`）

用途: S07 RIBBON 光のリボン（S08へのルミナンスワイプ用）

| 項目 | 値 |
|---|---|
| 使用モデル | GPT Image 2.5 |
| Aspect Ratio | 16:9 |
| Quality / Resolution | High / 2K |
| その他 | 枚数1、参照画像なし、Prompt自動補正OFF |
| 想定credit | 2.75 |
| 保存ファイル名 | `launch-video/higgsfield/outputs/phaseA/H3-B_ribbon.png` |

Prompt:

```text
Abstract light: two thin parallel ribbons of soft cool-white light with a faint blue edge forming a gentle S-curve across a black void, glassy refraction and a subtle chromatic edge, softly motion-blurred, elegant and minimal, mostly black frame. No text, no logos, no objects. 16:9.
```

生成後に見るポイント:

- 画面の大半が黒で、リボンが1本（B案は2本）の滑らかな形
- 文字・物体がない
- 動画化したとき画面を横切れる向き（左下→右上）


## 生成後

1. 6ファイルが `outputs/phaseA/` に上の名前で揃っていることを確認
2. Higgsfield Web の履歴で消費creditの合計を控える（16.5を超えていないこと）
3. チャットで「Phase A 保存完了」と伝える → 採用/不採用レビューと Phase B の再見積もり（採用画像を `--start-image` にして `generate cost`）を行う
