# Brosw — ブラウザプロファイル選択 URL ルーター 仕様書

## 背景と目的

Mac で Terminal や Slack などのアプリから URL を開くと、Chrome のどのウィンドウ(=どのプロファイル)で開かれるか予測しにくい。特に複数プロファイル・マルチスクリーン環境では、意図しないプロファイル(仕事用/個人用)で開いてしまう。

Brosw は **macOS のデフォルトブラウザとして登録される仲介アプリ**である。URL オープンを横取りし、マウス位置にプロファイル選択ポップアップ(以下、**ピッカー**)を出して開き先のブラウザプロファイルをユーザーに選択させる。

### スコープ

- 選択単位は **プロファイルのみ**(既存ウィンドウ単位の選択はスコープ外)
- 開き先は**毎回ユーザーがピッカーで選択**する(URL パターンによる自動振り分けは持たない)
- 対象ブラウザは **Chromium 系**(Chrome / Brave / Vivaldi)。いずれも `Local State` の `profile.info_cache` によるプロファイル列挙と `--profile-directory` 起動が共通。インストール済みのものだけ候補に出す
- 選択 UI は **マウスカーソル位置へのポップアップ**

## 1. 概要

| 項目 | 内容 |
|---|---|
| アプリ名 | Brosw |
| 形態 | メニューバー常駐エージェント(`LSUIElement = true`、Dock 非表示) |
| 役割 | デフォルトブラウザとして http/https URL のオープンをすべて受け取り、選択されたプロファイルのブラウザで開く |
| 対象 OS | macOS 13+ |

## 2. コア動作フロー

1. 任意のアプリが URL を開く → macOS が Brosw を起動(未起動なら自動起動)し、`application(_:open:)` に URL が渡る
2. Brosw は `NSEvent.mouseLocation` を含むスクリーン上、カーソル近傍にピッカーパネルを表示する
3. ユーザーがプロファイルを選択 → 次のコマンドを `Process`(引数配列で渡す。シェル経由なし)で実行する

   ```
   /usr/bin/open -na "<アプリ名>" --args --profile-directory="<dir>" "<url>"
   ```

   - `<アプリ名>` は選択されたプロファイルのブラウザ(`Google Chrome` / `Brave Browser` / `Vivaldi`)
   - 起動済みの場合、各ブラウザのシングルトン機構により既存プロセスへ転送され、該当プロファイルの最前面ウィンドウ(なければ新規ウィンドウ)で開く
   - 転送先の使い捨てインスタンスではなく本体を前面化するため、起動後に本体プロセスを明示的に activate する
4. パネルを閉じる

## 3. プロファイル列挙

- インストール済みの各対応ブラウザのデータディレクトリ配下 `Local State`(JSON)の `profile.info_cache` を読む
  - データディレクトリ: Chrome=`~/Library/Application Support/Google/Chrome`、Brave=`~/Library/Application Support/BraveSoftware/Brave-Browser`、Vivaldi=`~/Library/Application Support/Vivaldi`
  - キー: プロファイルディレクトリ名(`Default`, `Profile 1`, …)
  - 値: 表示名 `name` / `gaia_name`、アカウントメール相当の `user_name`
  - プロファイルはブラウザ横断で `"<browser>:<dir>"`(例 `chrome:Profile 1`)を id とする。設定の hide/並び順キーもこの id を使う(v0.2 までの素のディレクトリ名は Chrome のものとして読み替える)
  - Local State が読めないインストール済みブラウザは、プロファイル未指定の 1 件として候補に出す(新規インストール対策)
- アバター: Chrome 本体(`ProfileAttributesEntry::IsUsingGAIAPicture()`)と同じ優先順位で解決する
  1. 「Google アカウントのアイコンを使う」状態(`use_gaia_picture == true`、またはアバター未カスタマイズ `is_using_default_avatar == true`)→ プロファイルディレクトリ内の Google アカウント写真(`gaia_picture_file_name`、既定は `Google Profile Picture.png`)
  2. それ以外(プリセットアバター選択中)→ `avatar_icon` のインデックスを `Avatars/` のキャッシュ画像にマップして表示(対応表は Chromium `profile_avatar_icon_util.cc` 由来)
  3. どちらも解決できなければ、プロファイルカラー(`default_avatar_fill_color` / `stroke_color`)の丸+イニシャル

  注意: `use_gaia_picture` はプリセット選択後にアカウントアイコンへ戻した場合にも立つ(このとき `avatar_icon` と `is_using_default_avatar == false` が残る)ため、`is_using_default_avatar` だけで判定するとプリセットを誤表示する
- 並び順: 各プロファイルの `active_time` の降順(最近使った順)。同値なら名前順
- ピッカー表示のたびに再読込する(ファイル更新日時チェック+キャッシュで十分軽い)
- **App Sandbox は無効**とする(Local State 読み取りのため。個人配布前提であり、App Store 配布は将来課題)

## 4. ピッカー UI

- `NSPanel`(borderless / `.nonactivatingPanel`。ただしキー入力は受け付ける)+ SwiftUI コンテンツ
- 表示位置: マウスカーソル近傍。画面端でははみ出さないよう補正する

### 表示内容

- 上部: 開こうとしている URL(ホスト名を強調表示。長い場合は中間省略)
- プロファイル行: アバター / 表示名 / アカウントメール。行頭に `1`〜`9` のキーヒント
- 複数ブラウザがインストールされている場合、アバター右下に該当ブラウザのアプリアイコンをバッジ表示し、Chrome の "Work" と Brave の "Work" を区別する(単一ブラウザ時はバッジなし)

### 操作

| 操作 | 動作 |
|---|---|
| クリック / 数字キー `1`-`9` | 即選択して開く |
| `↑` `↓` + `Enter` | 選択して開く |
| `Esc` / パネル外クリック | キャンセル(URL は破棄) |
| `Cmd+C` | URL をコピーして閉じる |

### 複数 URL の扱い

複数 URL が連続で届いた場合(例: アプリが一度に複数リンクを開く)は同一セッションに束ね、件数を表示し、選択したプロファイルで全件開く。

## 5. メニューバー

ステータスアイコンのメニュー:

- 「デフォルトブラウザに設定」(未設定時のみ表示。`NSWorkspace.shared.setDefaultApplication(at:toOpenURLsWithScheme:)` で macOS の確認ダイアログを出す)
- 「テスト: ピッカーを表示」(開発ビルドのみ。`#if DEBUG`)
- 「設定…」(⌘,)
- バージョン表示
- 「終了」

ログイン項目は不要(デフォルトブラウザは URL オープン時に macOS が自動起動するため)。

## 6. 設定

`UserDefaults` に保存。設定ウィンドウ(`NSWindow` + SwiftUI)で編集する。

| 設定 | 内容 |
|---|---|
| プロファイル非表示リスト | ピッカーの候補から除外するプロファイル(id で記憶)。全件非表示にした場合は行き止まり防止のため全件表示にフォールバック。フィルタ後 1 件なら即オープン(§7)が適用される |
| メニューバーアイコン非表示 | ステータスアイコンを消す。URL 受信・ピッカー動作には影響しない |
| メールアドレス非表示 | ピッカーの各行からアカウントのメールアドレスを消す(設定画面のプロファイル一覧には表示したまま) |
| 並び順 | 「最近使った順」(既定)と「カスタム」を選択。カスタムは設定画面の ↑↓ ボタンで任意に並べ替え(id の配列で記憶。ブラウザ横断の 1 本の並び)。カスタム順に未登録の新規プロファイルは最近使った順で末尾に付く |

設定ウィンドウには「デフォルトブラウザを Chrome に戻す」ボタンも置く(設定値ではなくアクション)。`NSWorkspace.setDefaultApplication` で `http` のハンドラを Chrome に設定し、macOS の確認ダイアログが出る。Chrome 未インストール時は無効化。Brosw をやめる(アンインストールする)前の導線。

### 設定ウィンドウへの入口

- メニューバーの「設定…」
- ピッカー右下の歯車ボタン(ピッカーは閉じる)
- **アイコン非表示時**: Brosw を再度起動(Finder / Spotlight / `open -a Brosw`)すると reopen イベントで設定が開く。非常駐状態から URL なしで直接起動された場合も、アイコン非表示なら設定を開く

## 7. エッジケース

- 対応ブラウザが 1 つも入っていない / 起動失敗 → アラートでエラー表示し、URL をクリップボードへコピー
- 候補が 1 つだけ → ピッカーを出さず即オープン
- インストール済みだが Local State が読めないブラウザ → `--profile-directory` を付けずに開き、ブラウザ側の既定動作(初回起動フロー or 最後に使ったプロファイル)に任せる
- ピッカー表示中に再度 URL が届いた → 同一セッションへ追加(§4「複数 URL の扱い」)
- 対応スキームは `http` / `https` のみ(`mailto` 等は対象外)
- ローカル HTML(Finder で `.html` をダブルクリック)→ URL と同様にピッカーを表示し、選択したプロファイルのブラウザで `file://` URL として開く(デフォルトブラウザ化に伴い HTML ファイルの関連付けも Brosw に来るため)。ヘッダーにはホスト名の代わりにファイル名を表示する

## 8. 技術スタック / プロジェクト構成

- Swift 5.9+ / SwiftUI + AppKit、macOS 13+
- ローカライズ: 英語(ベース)+ 日本語。`Resources/{en,ja}.lproj/Localizable.strings` をメインバンドルに同梱し、キーは英語原文
- **SwiftPM executable + Makefile で .app バンドルを組み立てる**(Xcode プロジェクト不要、CLI 完結)
  - `make build` → `swift build` → `Brosw.app` に実行バイナリ + `Info.plist` を配置 → ad-hoc codesign
- `Info.plist` 要点: `CFBundleURLTypes` に `http` / `https`、`CFBundleDocumentTypes` に `public.html`(Finder からのローカル HTML 受け取り用)、`LSUIElement = true`

```
brosw/
├── SPEC.md
├── README.md
├── LICENSE
├── Package.swift
├── Makefile                  # .app バンドル組み立て・install / uninstall
├── scripts/
│   └── make-icon.swift       # AppIcon.png → AppIcon.icns 生成(make icon)
├── Resources/
│   ├── Info.plist
│   ├── AppIcon.icns          # アプリアイコン(生成物)
│   ├── AppIcon.png           # アプリアイコンのマスター画像
│   ├── MenuBarIcon.png       # メニューバー用テンプレート画像
│   ├── en.lproj/Localizable.strings
│   └── ja.lproj/Localizable.strings
└── Sources/Brosw/
    ├── BroswApp.swift         # NSApplicationDelegate、URL 受信、メニューバー
    ├── Browser.swift          # 対応ブラウザの定義(パス・bundle ID・アイコン)
    ├── AppSettings.swift      # UserDefaults 設定・ピッカー表示順ロジック
    ├── BrowserProfiles.swift  # Local State パース・アバター解決
    ├── BrowserLauncher.swift  # open -na 実行・本体の前面化
    ├── PickerPanel.swift      # NSPanel 制御・位置決め
    ├── PickerView.swift       # SwiftUI ピッカー UI
    ├── SettingsView.swift     # SwiftUI 設定画面
    ├── SettingsWindow.swift   # 設定ウィンドウ制御
    └── Localization.swift     # NSLocalizedString ヘルパー L()
```
