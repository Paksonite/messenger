#!/usr/bin/env bash
# Writes Casks/messenger.rb in the Homebrew tap for a release DMG and pushes it.
# Usage: scripts/update-cask.sh build/Messenger-<version>.dmg
# Needs HOMEBREW_TAP_TOKEN with write access to Paksonite/homebrew-tap. DRY_RUN=1 skips the push.
set -euo pipefail
cd "$(dirname "$0")/.."

dmg="$1"
# Checked up front: a ${VAR:?} error inside a command lets the EXIT trap below turn the exit status into 0.
if [[ -z "${HOMEBREW_TAP_TOKEN:-}" ]]; then
  echo "error: HOMEBREW_TAP_TOKEN is not set" >&2
  exit 1
fi
version="$(basename "$dmg" .dmg)"
version="${version#Messenger-}"
sha256="$(shasum -a 256 "$dmg" | cut -d' ' -f1)"

tap="$(mktemp -d)"
trap 'rm -rf "$tap"' EXIT
git clone --quiet --depth 1 "https://x-access-token:$HOMEBREW_TAP_TOKEN@github.com/Paksonite/homebrew-tap.git" "$tap"

mkdir -p "$tap/Casks"
sed -e "s/@VERSION@/$version/" -e "s/@SHA256@/$sha256/" packaging/messenger.rb >"$tap/Casks/messenger.rb"

cd "$tap"
git add Casks/messenger.rb
if git diff --cached --quiet; then
  echo "Cask already at $version"
  exit 0
fi
git -c user.name="github-actions[bot]" -c user.email="41898282+github-actions[bot]@users.noreply.github.com" \
  commit --quiet -m "messenger v$version"
if [[ -n "${DRY_RUN:-}" ]]; then
  git show --stat HEAD
else
  git push --quiet
  echo "Pushed messenger v$version to Paksonite/homebrew-tap"
fi
