#!/usr/bin/env bash
# Packs the signed build/Messenger.app into build/Messenger-<version>.dmg and prints its path.
set -euo pipefail
cd "$(dirname "$0")/.."

app=build/Messenger.app
version="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$app/Contents/Info.plist")"
dmg="build/Messenger-$version.dmg"

staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT
ditto "$app" "$staging/Messenger.app"
ln -s /Applications "$staging/Applications"

rm -f "$dmg"
hdiutil create -volname Messenger -srcfolder "$staging" -fs HFS+ -format UDZO -imagekey zlib-level=9 "$dmg" >/dev/null
echo "$dmg"
