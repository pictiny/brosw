<p align="center">
  <img src="docs/icon.png" width="128" alt="Brosw app icon">
</p>

# Brosw

[English](README.md) | [日本語](README.ja.md)

A macOS menu bar app that lets you choose which browser profile opens each URL — in a popup right at your mouse cursor.

When you open a link from Terminal, Slack, or any other app, it's hard to predict which Chrome profile it will land in, and it often ends up in the wrong one (work vs. personal). Brosw registers itself as your default browser, intercepts every URL, and asks you where it should go — across every profile of your installed Chromium browsers (Chrome, Brave, Vivaldi).

## Features

Most browser-routing apps decide *which browser* opens a URL, driven by URL-pattern rules. Brosw is smaller and sharper:

- **Profile-level, not just browser** — pick the exact profile of Chrome, Brave, or Vivaldi
- **No rules — just pick** — no config files or URL patterns; a picker at your cursor, one keypress
- **Native and lightweight** — a small menu bar app built with Swift + AppKit

## Requirements

- macOS 13 (Ventura) or later
- At least one of: Google Chrome, Brave, or Vivaldi

## Installation

### Homebrew

```sh
brew install --cask pictiny/tap/brosw
```

The app is ad-hoc signed (not notarized), so macOS quarantines the download and may refuse to open it. Either install with quarantine disabled:

```sh
brew install --cask --no-quarantine pictiny/tap/brosw
```

or clear the attribute afterwards: `xattr -d com.apple.quarantine /Applications/Brosw.app`

### Build from source

Requires Xcode Command Line Tools:

```sh
git clone https://github.com/pictiny/brosw.git
cd brosw
make install   # installs to /Applications/Brosw.app and launches it
```

After installing, choose **Set as Default Browser** from the Brosw menu bar icon; macOS will show a confirmation dialog. From then on, every URL opened by any app goes through Brosw and the profile picker appears.

## Usage

When a URL opens, the picker appears next to your mouse cursor, listing every profile across your installed Chromium browsers, with the same avatars and colors the browsers use. When more than one browser is installed, each row carries a small browser badge. Pick with the mouse or the keyboard:

| Action | Result |
|---|---|
| Click / `1`-`9` | Open with that profile |
| `↑` `↓` + `Enter` | Select and open |
| `Esc` / click outside | Cancel (URLs are discarded) |
| `⌘C` | Copy the URLs and close |

- If you have only one Chrome profile, the picker is skipped and the URL opens immediately
- URLs arriving while the picker is open are bundled into the same session and all open in the chosen profile
- Opening an `.html` file from Finder shows the picker just like a URL
- If Chrome cannot be found, the URLs are copied to the clipboard and an alert is shown

## Settings

Open the settings window from **Settings…** in the menu bar menu, or the gear button at the bottom right of the picker.

- **Profiles shown in picker**: unchecked profiles disappear from the candidates (if you hide all of them, all are shown again). If only one profile remains visible, it opens immediately without confirmation
- **Show account email addresses**: turn off to remove email addresses from the picker rows
- **Sort order**: defaults to most recently used first. Choose **Custom** to reorder profiles freely with the ↑↓ buttons (newly added profiles are appended at the end)
- **Show icon in the menu bar**: turn off to remove the status icon. To open settings while the icon is hidden, launch Brosw again from Spotlight or Finder (a running instance opens settings on reopen; a fresh launch opens them right away)
- **Set Chrome as Default Browser**: a button that hands the default browser role back to Chrome (macOS asks for confirmation). Recommended before uninstalling Brosw

## Language

The UI is available in English and Japanese and follows the system language. To pin a specific language, assign one to Brosw in System Settings > General > Language & Region > Applications, or run:

```sh
defaults write io.github.pictiny.Brosw AppleLanguages -array en
```

## Uninstall

Use **Set Chrome as Default Browser** in the settings window first, so URLs don't point at a missing app after removal.

```sh
brew uninstall --cask brosw   # Homebrew installs (add --zap to wipe settings too)
make uninstall                # source builds: quits the app and removes it from /Applications
```

To wipe the settings by hand, run `defaults delete io.github.pictiny.Brosw`.

## Development

```sh
make dev        # development build (debug configuration, includes a test menu)
make run        # development build and launch
make build      # release build: produces build/Brosw.app (ad-hoc signed)
```

Development builds add a **Test: Show Picker** item to the menu bar menu so you can try the picker without setting Brosw as the default browser (not included in release builds).

See [SPEC.md](SPEC.md) for the full specification (Japanese).

### `swift build` fails with `Invalid manifest ... Undefined symbols`

On machines where the Command Line Tools were updated in place, a stale private
swiftinterface from the Swift 5.10 era of `PackageDescription` can be left
behind and clash with the newer dylib. Deleting the leftovers fixes it:

```sh
sudo rm /Library/Developer/CommandLineTools/usr/lib/swift/pm/ManifestAPI/PackageDescription.swiftmodule/*.private.swiftinterface
```

(Newer CLT releases no longer ship private swiftinterfaces, so they are safe to
delete. To verify they are leftovers, check that their file dates differ
significantly from the other interface files.)

## License

[MIT](LICENSE)
