# Mini-Terminal

<p align="center">
  <a href="README.md">English</a> ·
  <strong>日本語</strong> ·
  <a href="README.zh-Hans.md">简体中文</a> ·
  <a href="README.zh-Hant.md">繁體中文</a> ·
  <a href="README.ko.md">한국어</a> ·
  <a href="README.es.md">Español</a> ·
  <a href="README.fr.md">Français</a> ·
  <a href="README.de.md">Deutsch</a> ·
  <a href="README.pt.md">Português</a>
</p>

Terminalを開くほどではない。でもShellを1回だけ実行したい。Mini-Terminalは、その数秒のために作ったmacOSアプリです。

グローバルショートカットで呼び出し、コマンドを入力して実行する。必要なら、開いた瞬間にクリップボードの内容を貼り付け、そのまま実行し、結果までクリップボードへ戻せます。

## できること

- AppKit + SwiftUIによるネイティブmacOSアプリ
- 設定可能なグローバルショートカット
- Spotlightのように呼び出せるフローティングUI
- 起動時のクリップボード自動貼り付け
- クリップボード内容の起動時自動実行
- 実行結果の自動コピー
- コピー時に約1秒のフィードバック表示
- INPUT / OUTPUTの左右分割
- 最大100件の実行履歴をローカル保存
- ↑ / ↓による過去コマンドの呼び出し
- exit codeと実行時間の表示
- Shellパスと作業ディレクトリの設定
- 危険な可能性があるコマンドと複数行コマンドの実行前確認
- System言語追従と、英語・日本語・簡体字中国語・繁体字中国語・韓国語・スペイン語・フランス語・ドイツ語・ポルトガル語

## すぐ試す

必要環境はmacOS 14以降とXcode / Swift toolchainです。

```bash
git clone https://github.com/uniplanck/Mini-Terminal.git
cd Mini-Terminal
bash scripts/build-app.sh
open dist/Mini-Terminal.app
```

初期ショートカットは次のとおりです。

```text
⌥ Space
```

ショートカットは設定から変更できます。

## クリップボードだけで完結させる

Mini-Terminalの利点は、入力欄を小さくしたことではありません。短いShell操作で発生していた「Terminalを開く、貼る、実行する、結果を選択してコピーする」という往復そのものを減らせます。

```text
コマンドをコピー
      ↓
Mini-Terminalを呼び出す
      ↓
自動貼り付け（任意）
      ↓
自動実行（任意）
      ↓
結果を自動コピー（任意）
```

上部の稲妻ボタンから、起動時のクリップボード即実行だけをすぐON / OFFできます。

## 履歴

実行が完了したコマンドは、最大100件までローカルに保存します。

時計ボタンを押すと履歴を一覧でき、項目を選ぶとコマンド、出力、exit code、実行時間を復元できます。入力欄で↑ / ↓を押せば、通常のTerminalに近い感覚で過去のコマンドを呼び出せます。

保存した履歴は履歴画面から消去できます。

## 言語

初期設定は**System**です。macOSに設定された優先言語を上から確認し、Mini-Terminalが対応している最初の言語を使います。対応言語が見つからない場合は英語になります。

対応しているUI言語は次の9言語です。

- English
- 日本語
- 简体中文
- 繁體中文
- 한국어
- Español
- Français
- Deutsch
- Português

設定から言語を固定することもできます。

## 自動実行は便利だが、無条件に安全ではない

クリップボードの自動実行をONにすると、コピーした文字列がそのままShellへ渡る可能性があります。Webページやチャットからコピーした内容を毎回人間が確認する設計ではないため、速度と引き換えに実行リスクが上がります。

Mini-Terminalは、`rm`、`sudo`、`git reset --hard`、再帰的な権限変更、複数行コマンドなどを検出し、安全設定がONなら実行前に確認します。

ただし、この判定はサンドボックスではありません。コマンドが安全であることを保証する仕組みでもありません。出所を信用できないコマンドは、実行前に内容を確認してください。

Mini-Terminal自身の設定と履歴はローカルに保存します。一方、実行したコマンドは、その内容とmacOS上の権限に応じてファイル、プロセス、ネットワークへアクセスできます。

## なぜすぐ開くのか

ショートカットを押すたびにアプリを起動しているわけではありません。Mini-Terminalはメニューバー常駐アプリとして動き、ショートカットが押されたら既存プロセスのフローティングパネルを表示します。

そのため、狙っているのは「小さいTerminal」ではなく、短いShell操作だけを素早く終わらせるランチャーです。

## 開発

直接起動:

```bash
swift run Mini-Terminal
```

テスト:

```bash
swift test
```

ローカルの.appを生成:

```bash
bash scripts/build-app.sh
```

生成先:

```text
dist/Mini-Terminal.app
```

## 現在の状態

Mini-Terminalは公開初期版です。現在のローカルアプリ版は**0.3.0**です。

現時点では、一発のShell実行、クリップボード自動化、履歴、多言語化、macOSネイティブの軽い操作感に範囲を絞っています。
