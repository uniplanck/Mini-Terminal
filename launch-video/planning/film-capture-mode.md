# 撮影用モード（Film Capture Mode）改修方針

状態: **実装済み（2026-10-08）。debugビルド専用。** `Sources/MiniTerminal/FilmCapture.swift`（`#if FILM_CAPTURE`）、`main.swift` の `--ui-fixture` 分岐に数行、`Package.swift` で `FILM_CAPTURE` をdebug構成のみ定義。テストは `Tests/MiniTerminalTests/FilmCaptureTests.swift`（10件）。

本番利用からの隔離: release構成（`scripts/build-app.sh` の `swift build -c release`）では撮影コードがコンパイルされない（release バイナリに film 関連シンボル・`--film` 文字列が0件であることを確認済み）。`--ui-fixture` を付けない起動、および `--film` を付けない `--ui-fixture` 起動の挙動は従来どおり。
データ: [`assets/ui/fixtures/film-fixture.json`](../assets/ui/fixtures/film-fixture.json)
作業ディレクトリ生成: [`assets/ui/fixtures/make-film-workspace.sh`](../assets/ui/fixtures/make-film-workspace.sh)（実装済み・2回実行して同一ハッシュ `4cb2e96` を確認）

## 1. 現行 `--ui-fixture` と撮影要件の差

| 要件 | 現行 `--ui-fixture`（`Sources/MiniTerminal/main.swift`） | 不足 |
|---|---|---|
| 隔離 | UUID付きUserDefaults suite、専用名前付きPasteboard、起動時に自動実行しない | なし（このまま流用） |
| 日本語表示 | `settings.language = .en` 固定 | 言語指定ができない |
| Auto Run制御 | `pasteClipboardOnOpen = false` / `autoRunAfterPaste = false` 固定 | ON/OFFを切り替えられない |
| クリップボード演出 | 専用Pasteboardを起動時に空にする | S04で「コピー済みの1行」を用意できない |
| 履歴 | 空から開始 | S06用の架空履歴を固定日時で並べられない |
| 初期状態 | コマンド `printf 'Mini-Terminal v0.4 ready\n'`、分割表示、起動時にパネル表示 で固定 | シーンごとの初期状態がない |
| Dark mode | `--dark` で指定可 | なし |
| 日時表示 | 履歴の日時はプロセスのロケール/タイムゾーンで整形 | 撮影機の設定で表示が変わる |
| 出力の再現性 | 実行するコマンドに依存 | 決定的な作業ディレクトリがない → 作成済み |

## 2. 提案するインターフェース

```bash
swift build
```

```bash
.build/debug/Mini-Terminal --ui-fixture --film S04 --film-fixture "$PWD/launch-video/assets/ui/fixtures/film-fixture.json" -AppleLanguages '(ja)' -AppleLocale ja_JP
```

`dist/Mini-Terminal.app`（release）には撮影モードが含まれないため、撮影はdebugバイナリで行う。

| 引数 | 動作 |
|---|---|
| `--film <scene>` | `--ui-fixture` 時のみ有効。`scenes.<scene>` を適用する。`--ui-fixture` なしでは無視（通常起動に影響させない） |
| `--film-fixture <path>` | データセットのパス。省略時・シーン不明・JSON不正のときはエラーを表示して終了コード2で終了（素のfixtureに黙って戻らない） |
| `--film-autorun on\|off` | シーンの `autoRun` を上書き（撮り直し時に便利） |
| `--dark` | 既存。撮影モードでは `environment.appearance: dark` により常にdark |

日時とロケールは**アプリを改修せず**起動引数で固定する:

```bash
TZ=Asia/Tokyo .build/debug/Mini-Terminal --ui-fixture --film S06 --film-fixture "$PWD/launch-video/assets/ui/fixtures/film-fixture.json" -AppleLanguages '(ja)' -AppleLocale ja_JP
```

## 3. シーン適用ロジック（実装）

新規 `Sources/MiniTerminal/FilmFixture.swift`（Decodable + `apply`）と、`main.swift` の fixture 分岐への数行の追加だけで実現する。`AppModel` / `LauncherView` / `HistoryStore` は変更しない。

1. 既存どおりUUID suiteを作る（毎回まっさら → 何度でも同じ状態）
2. `environment` を `SettingsStore` へ: `language=.ja`, `shellPath`, `workingDirectory`, `copyOutputAfterRun`, `confirmDangerousCommands`, `shortcut`
3. `autoRun`: `true` なら `pasteClipboardOnOpen = true` かつ `autoRunAfterPaste = true`（ランチャーの⚡トグルと同じ組み合わせ）。`false` なら両方 `false`
4. `seedHistory`: `history` をISO 8601でデコードし、`HistoryEntry` 配列（UUIDは連番から決定的に生成）をJSONEncoderでエンコードして suite の `executionHistory` キーへ書き込んでから `HistoryStore(defaults:)` を作る → `HistoryStore` の変更不要
5. `stageClipboard`: 既存fixtureの専用Pasteboard（`com.nao.mini-terminal.ui-fixture`）に文字列を置く（`.general` を渡すと precondition で停止）。`AppModel.lastResultClipboardChangeCount` は初期 `nil` なので、最初のショートカット押下で `prepareForPresentation()` が貼り付け→自動実行する。**一般クリップボード（`.general`）には一切触れない**
6. `command` / `view`（`compact` / `split`）を `AppModel` に設定
7. `panelVisibleAtLaunch`: 既存の `AppDelegate(showOnLaunch:)` に渡す。`false` ならメニューバー常駐のまま待機し、撮影者がショートカットでパネルを出す（S03/S04の「呼ぶ」瞬間を実録できる）

## 4. シーン定義（`film-fixture.json` の `scenes`）

| Scene | テイク | 起動時 | Auto Run | 操作 | 期待結果 |
|---|---|---|---|---|---|
| S03 | UI_T01 | 非表示 | OFF | ショートカット → `git rev-parse --short HEAD` を打鍵 → ⌘↩ | `4cb2e96`, exit 0 |
| S04 | UI_T02 | 非表示・Pasteboardに1行 | **ON** | ショートカットのみ | 自動貼付 → 自動実行 → `2026-09-21 14:13 UTC` → 「出力をコピーしました」 |
| S05 | UI_T03 | 表示（コンパクト、コマンド入力済み） | OFF | 分割ボタン → ⌘↩ | `wc -l` 14ファイル + `2133 total` |
| S06 | UI_T04 | 表示・履歴9件 | OFF | 履歴 → スクロール → Esc → `rm -rf ./build` → ⌘↩ → キャンセル | 「実行確認」ダイアログ |
| S08 | UI_T05 | 表示（空） | OFF | なし | 「待機中」 |

すべて実コマンドを実際に実行する（出力の偽装はしない）。結果が毎回同じになるのは、作業ディレクトリが決定的だからであり、`ms` 表示だけは実測値がテイクごとに数ms揺れる（そのまま使う）。

## 5. 撮影データの安全設計

- 作業ディレクトリは `/tmp/mini-terminal-film/demo` 固定。生成スクリプトはそれ以外のパスを拒否する
- S06の `rm -rf ./build` は必ずキャンセルする。誤って実行しても消えるのは `/tmp/mini-terminal-film/demo/build/` だけ
- 履歴・クリップボード・パスはすべて架空または撮影用ワークスペース由来。ユーザー名を含むパスは画面に出ない
- ショートカットは ⌃⌥⇧Space（通常インスタンスの ⌥Space と衝突させない）。画面の `⌥ Space` 表示はAEのHUD

## 6. テイク運用（実装後）

```bash
bash launch-video/assets/ui/fixtures/make-film-workspace.sh
```

各テイクの前に、撮影モードのアプリを終了→上記コマンドで起動し直す（UUID suiteにより状態が完全に戻る）。マウスは撮影するディスプレイに置いておく（パネルはマウスのある画面の上部中央に出る: `AppDelegate.positionLauncher`）。

## 7. テスト

`FilmCaptureTests`（10件、`swift test` で全38件中0失敗）:

- 引数: `--ui-fixture` なし／`--film` なしでは無効、`--film-autorun` の解析と不正値
- リポジトリのデータセットが全シーン（S03/S04/S05/S06/S08）と履歴9件でデコードできる
- S04: 日本語、Auto Run ON、専用Pasteboardへの1行の配置、`.general` の `changeCount` が不変、起動時は非表示
- `--film-autorun off` で自動貼り付け・自動実行が両方OFF
- S06: 履歴9件が固定ID・固定日時で、2回適用しても完全に同一
- S05: 履歴が空、コマンドとコンパクト表示が設定される
- `rm -rf ./build` が確認対象のまま
- 不明シーン・データセット未指定で失敗
- S04の実行: 自動貼り付け → 実行 → `2026-09-21 14:13 UTC` → 出力がクリップボードへ

手動スモーク: debugバイナリで不明シーン／データセット未指定が終了コード2になること、S08で起動し常駐することを確認（画面の目視確認は未実施）。

未実施: `NativeRenderingSmokeTests` の日本語・各シーン版（AEレイアウト参照用の静止画）。

## 8. 規模

`FilmCapture.swift` 179行、`main.swift` +11行、`Package.swift` +6行、テスト136行。UIコード（`LauncherView` / `AppModel` / `HistoryStore` / `AppDelegate`）は無変更。
