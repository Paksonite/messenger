# Releasing

Releases are free: no Apple Developer Program. The app is signed with a self-signed certificate (stable identity, not notarized), distributed as a DMG on GitHub Releases, installed with Homebrew and updated with Sparkle.

## Publish a release

```bash
git tag v1.2.3
git push origin v1.2.3
```

`.github/workflows/release.yml` then:

1. runs the tests,
2. builds a Universal app with `VERSION=1.2.3` and `CFBundleVersion` = commit count,
3. signs it with the release certificate (`scripts/sign.sh`),
4. packs `Messenger-1.2.3.dmg` (`scripts/package.sh`),
5. writes `appcast.xml` with the DMG's EdDSA signature (`scripts/appcast.sh`),
6. creates the GitHub release with the DMG and `appcast.xml`,
7. updates `Casks/messenger.rb` in Paksonite/homebrew-tap (`scripts/update-cask.sh`).

Tags with a hyphen (`v1.2.3-beta.1`) become pre-releases. Pre-releases skip the cask, and Sparkle ignores them because the feed URL points at the latest full release.

## How users get it

```bash
brew install --cask paksonite/tap/messenger
```

The cask removes the quarantine flag after install (`postflight_steps`), so Gatekeeper does not block the non-notarized app. A DMG downloaded by hand needs a one-time "Open Anyway" in System Settings → Privacy & Security.

Sparkle checks `https://github.com/Paksonite/messenger/releases/latest/download/appcast.xml` once a day. When an update is found while the app is in the background, it posts a "Messenger X is available" notification; clicking it opens Sparkle's update window. **Messenger → Check for Updates…** checks right away. The cask has `auto_updates true`, so `brew upgrade` leaves updating to Sparkle.

## Keys and secrets

| Secret | What | Local copy |
|--------|------|------------|
| `SIGNING_P12_BASE64` | Base64 of the self-signed code signing certificate + key (`.p12`) | `~/.config/paksonite-messenger/signing.p12` |
| `SIGNING_P12_PASSWORD` | Password of the `.p12` | `~/.config/paksonite-messenger/signing_p12_password` |
| `SPARKLE_ED_PRIVATE_KEY` | Sparkle EdDSA private key (base64 seed) | `~/.config/paksonite-messenger/sparkle_private_key` |
| `HOMEBREW_TAP_TOKEN` | Token with write access to Paksonite/homebrew-tap | same token as for gitnest |

**Back up the certificate and the Sparkle key** (e.g. in a password manager). Losing either means existing installs can no longer verify updates:

- Sparkle only installs updates whose DMG is signed with the private key matching `SUPublicEDKey` in `Config/Info.plist`.
- Sparkle and macOS (camera, microphone and notification permissions) expect the new app to have the same code signing identity: `certificate root = H"44865711719f34eee2a5c2e1e232abae5aa8266d"`.

The certificate is valid until October 2036.

Because the certificate has no Apple Team ID, `Config/Messenger.entitlements` disables library validation; otherwise the hardened runtime refuses to load Sparkle.framework.

## Local release build

```bash
VERSION=1.2.3 scripts/build.sh
scripts/sign.sh                 # uses ~/.config/paksonite-messenger/signing.p12
scripts/package.sh              # → build/Messenger-1.2.3.dmg
scripts/appcast.sh build/Messenger-1.2.3.dmg
```

### Testing an update locally

```bash
DOWNLOAD_BASE_URL=http://127.0.0.1:8765 scripts/appcast.sh build/Messenger-<new>.dmg
python3 -m http.server 8765 --bind 127.0.0.1 --directory build &
defaults write pl.paksonite.messenger SUFeedURL http://127.0.0.1:8765/appcast.xml
# launch an older build, use Check for Updates…, then:
defaults delete pl.paksonite.messenger SUFeedURL
```
