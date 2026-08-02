<p align="center">
  <img src="docs/icon.png" width="128" alt="Brosw アプリアイコン">
</p>

# Brosw

[English](README.md) | [日本語](README.ja.md)

URL を開くたびに、どのブラウザプロファイルで開くかをマウス位置のポップアップで選べる macOS メニューバーアプリ。

Terminal や Slack などのアプリでリンクを開いたとき、Chrome が仕事用・個人用どのプロファイルで開くかは予測しにくく、意図しない方で開いてしまいがちです。Brosw は macOS のデフォルトブラウザとして URL オープンを仲介し、プロファイル選択ポップアップ(以下、ピッカー)で開き先をその場で選ばせてくれます。インストール済みの Chromium 系ブラウザ(Chrome / Brave / Vivaldi)のプロファイルを横断して選べます。

## 特徴

Brosw は軽量なアプリケーションです:

- **ブラウザではなくプロファイル単位** — Chrome / Brave / Vivaldi の狙ったプロファイルを選べる
- **ルールなし、毎回選ぶだけ** — 設定ファイルも URL パターンも不要。カーソル位置のピッカーでキー 1 つ
- **ネイティブで軽量** — Swift + AppKit 製のメニューバー常駐アプリ

## 動作環境

- macOS 13 (Ventura) 以降
- Google Chrome / Brave / Vivaldi のいずれか

## インストール

### Homebrew

```sh
brew install --cask pictiny/tap/brosw
```

アプリは ad-hoc 署名(未 notarize)のため、ダウンロード物に quarantine 属性が付いて macOS が起動をブロックすることがあります。quarantine なしでインストールするか:

```sh
brew install --cask --no-quarantine pictiny/tap/brosw
```

インストール後に属性を外してください: `xattr -d com.apple.quarantine /Applications/Brosw.app`

### ソースからビルド

Xcode Command Line Tools が必要です:

```sh
git clone https://github.com/pictiny/brosw.git
cd brosw
make install   # /Applications/Brosw.app にインストールして起動
```

インストール後、メニューバーの Brosw アイコンから「デフォルトブラウザに設定」を選ぶと macOS の確認ダイアログが出ます。以降、各アプリから開いた URL はすべて Brosw が受け取り、ピッカーが表示されます。

## 使い方

URL を開くとマウスカーソルのそばにピッカーが現れ、インストール済みブラウザの全プロファイルが本体と同じアバター・カラーで並びます(複数ブラウザがある場合は各行にブラウザのバッジが付きます)。マウスでもキーボードでも選べます:

| 操作 | 動作 |
|---|---|
| クリック / `1`-`9` | そのプロファイルで開く |
| `↑` `↓` + `Enter` | 選択して開く |
| `Esc` / パネル外クリック | キャンセル(URL は破棄) |
| `⌘C` | URL をコピーして閉じる |

- 候補が 1 つしかない場合はピッカーを出さず即オープン
- ピッカー表示中に届いた URL は同一セッションに束ねられ、選択したプロファイルで全件開く
- Finder で `.html` ファイルを開いた場合も URL と同様にピッカーが表示される
- Chrome が見つからない場合は URL をクリップボードにコピーして通知する

## 設定

メニューバーの「設定…」またはピッカー右下の歯車ボタンから設定ウィンドウを開けます。

- **ピッカーに表示するプロファイル**: チェックを外したプロファイルは候補に出なくなる(全部外すと全件表示に戻る)。表示が 1 件だけになった場合は確認なしで即オープンされる
- **アカウントのメールアドレスを表示**: オフにするとピッカーの各行からメールアドレスが消える
- **並び順**: 既定は最近使った順。「カスタム」を選ぶと各行の ↑↓ ボタンで任意の順に並べ替えられる(新しく増えたプロファイルは末尾に付く)
- **メニューバーにアイコンを表示**: オフでステータスアイコンを消せる。アイコンがない状態で設定を開くには、Brosw を Spotlight や Finder からもう一度起動する(常駐中なら reopen で、未起動なら起動後に設定ウィンドウが開く)
- **デフォルトブラウザを Chrome に戻す**: デフォルトブラウザの役割を Chrome に返すボタン(macOS の確認ダイアログが出る)。Brosw をアンインストールする前に実行するのがおすすめ

## 言語

UI は英語と日本語に対応(システム言語に追随)。特定の言語に固定したい場合は
「システム設定 > 一般 > 言語と地域 > アプリケーション」で Brosw に言語を指定するか:

```sh
defaults write io.github.pictiny.Brosw AppleLanguages -array ja
```

## アンインストール

先に設定ウィンドウの「デフォルトブラウザを Chrome に戻す」でデフォルトブラウザを返しておくと、削除後に URL の開き先が宙に浮きません。

```sh
brew uninstall --cask brosw   # Homebrew の場合(設定ごと消すなら --zap を追加)
make uninstall                # ソースビルドの場合: 終了して /Applications から削除
```

設定を手動で消すには `defaults delete io.github.pictiny.Brosw` を実行します。

## 開発

```sh
make dev        # 開発ビルド(debug 構成。テスト用メニューあり)
make run        # 開発ビルドして起動
make build      # 製品ビルド: build/Brosw.app を生成(ad-hoc 署名)
```

開発ビルドではメニューバーに「テスト: ピッカーを表示」が追加され、デフォルトブラウザに設定しなくても動作確認できます(製品ビルドには含まれません)。

仕様の詳細は [SPEC.md](SPEC.md) を参照してください。

### `swift build` が `Invalid manifest ... Undefined symbols` で失敗する

Command Line Tools を上書きアップデートした環境では、古い Swift 5.10 時代の
`PackageDescription` の private swiftinterface が残骸として残り、新しい dylib と
シンボル不整合を起こすことがあります。残骸を削除すれば直ります:

```sh
sudo rm /Library/Developer/CommandLineTools/usr/lib/swift/pm/ManifestAPI/PackageDescription.swiftmodule/*.private.swiftinterface
```

(新しい CLT には private swiftinterface は同梱されないため、削除して問題ありません。
確認: ファイルの日付が他の interface と大きく異なっていれば残骸です。)

## ライセンス

[MIT](LICENSE)
