#!/usr/bin/env bash
# Signs build/Messenger.app, including Sparkle's helpers, with the self-signed release certificate.
#
# The certificate comes from SIGNING_P12_BASE64 + SIGNING_P12_PASSWORD (CI) or from
# ~/.config/paksonite-messenger/signing.p12 + signing_p12_password (local). Without either,
# the app is signed ad-hoc, which works locally but changes the app's identity on every build.
set -euo pipefail
cd "$(dirname "$0")/.."

app=build/Messenger.app
identity="Paksonite Messenger Code Signing"
config_dir="$HOME/.config/paksonite-messenger"
keychain="$PWD/build/signing.keychain-db"

p12=""
if [[ -n "${SIGNING_P12_BASE64:-}" ]]; then
  p12="$PWD/build/signing.p12"
  base64 --decode <<<"$SIGNING_P12_BASE64" >"$p12"
  password="$SIGNING_P12_PASSWORD"
elif [[ -f "$config_dir/signing.p12" ]]; then
  p12="$config_dir/signing.p12"
  password="$(cat "$config_dir/signing_p12_password")"
fi

sign_args=(--force --timestamp=none --options runtime)
if [[ -n "$p12" ]]; then
  keychain_password="$(openssl rand -hex 16)"
  rm -f "$keychain"
  security create-keychain -p "$keychain_password" "$keychain"
  cleanup() {
    security delete-keychain "$keychain" 2>/dev/null || true
    rm -f "$PWD/build/signing.p12"
  }
  trap cleanup EXIT
  security set-keychain-settings -lut 3600 "$keychain"
  security unlock-keychain -p "$keychain_password" "$keychain"
  security import "$p12" -k "$keychain" -P "$password" -T /usr/bin/codesign >/dev/null
  security set-key-partition-list -S apple-tool:,apple: -k "$keychain_password" "$keychain" >/dev/null
  sign_args+=(--sign "$identity" --keychain "$keychain")
else
  echo "warning: no signing certificate found, signing ad-hoc" >&2
  sign_args+=(--sign -)
fi

# Inside out, in the order documented by Sparkle.
sparkle="$app/Contents/Frameworks/Sparkle.framework/Versions/B"
codesign "${sign_args[@]}" "$sparkle/XPCServices/Installer.xpc"
codesign "${sign_args[@]}" --preserve-metadata=entitlements "$sparkle/XPCServices/Downloader.xpc"
codesign "${sign_args[@]}" "$sparkle/Autoupdate"
codesign "${sign_args[@]}" "$sparkle/Updater.app"
codesign "${sign_args[@]}" "$app/Contents/Frameworks/Sparkle.framework"
codesign "${sign_args[@]}" --entitlements Config/Messenger.entitlements "$app"

codesign --verify --deep --strict "$app"
codesign --display --requirements - "$app" 2>&1 | grep designated
echo "Signed $app"
