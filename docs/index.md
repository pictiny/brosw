<p align="center">
  <img src="icon.png" width="128" alt="Brosw app icon">
</p>

Brosw is a macOS menu bar app that registers as your default browser and asks, right at your mouse cursor, which browser profile should open each URL — across every profile of your installed Chromium browsers (Chrome, Brave, Vivaldi).

Opening a link from Terminal, Slack, or any other app usually lands in an unpredictable Chrome profile — often the wrong one (work vs. personal). With Brosw, every link pauses for one keypress: `1`–`9` or a click, and it opens exactly where you meant.

## Why Brosw

- **Profile-level, not just browser** — pick the exact profile of Chrome, Brave, or Vivaldi
- **No rules — just pick** — no config files or URL patterns; a picker at your cursor, one keypress
- **Native and lightweight** — a small menu bar app built with Swift + AppKit

## Install

Requires macOS 13+ and at least one of Chrome, Brave, or Vivaldi:

```sh
brew install --cask pictiny/tap/brosw
```

Then choose **Set as Default Browser** from the Brosw menu bar icon. Prefer building from source? See the [README](https://github.com/pictiny/brosw#readme).

## Learn more

- [README (English)](https://github.com/pictiny/brosw#readme)
- [README(日本語)](https://github.com/pictiny/brosw/blob/main/README.ja.md)
