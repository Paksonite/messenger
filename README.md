# messenger

Native Facebook Messenger for macOS: a lightweight AppKit + `WKWebView` wrapper around messenger.com with native notifications and a Dock badge.

Not affiliated with or endorsed by Meta.

## Install

```bash
brew install --cask paksonite/tap/messenger
```

Or download the DMG from [Releases](https://github.com/Paksonite/messenger/releases). The app is not notarized, so a manually downloaded copy needs a one-time **Open Anyway** in System Settings → Privacy & Security. The app updates itself (Messenger → Check for Updates…).

## Requirements

- macOS 15 Sequoia or later (Apple Silicon and Intel)
- To build: Xcode 16+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Build

```bash
scripts/build.sh   # Universal Release build → build/Messenger.app
scripts/test.sh    # unit tests
```

`Messenger.xcodeproj` is generated from `project.yml` and is not committed; run `xcodegen generate` to open it in Xcode.

The app icon is rendered from `design/AppIcon.svg` with `scripts/make-icon.sh` (needs `brew install resvg`).

## Layout

| Path | Contents |
|------|----------|
| `App/` | Swift sources (app delegate, windows, WebView, notifications) |
| `Resources/Scripts/` | JavaScript injected into the page |
| `Resources/Assets.xcassets` | App icon |
| `Config/` | Info.plist and entitlements |
| `Tests/` | Unit tests (Swift Testing) |
| `packaging/` | Homebrew cask template |
| `scripts/` | Build, test, sign, package and release scripts |
| `docs/` | [Releasing](docs/releasing.md), phase 0 spike checklist |
