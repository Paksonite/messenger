#!/usr/bin/env bash
# Builds a Universal (arm64 + x86_64) Messenger.app into build/.
set -euo pipefail
cd "$(dirname "$0")/.."

configuration="${CONFIGURATION:-Release}"

xcodegen generate --quiet
xcodebuild \
  -project Messenger.xcodeproj \
  -scheme Messenger \
  -configuration "$configuration" \
  -destination 'generic/platform=macOS' \
  -derivedDataPath build/DerivedData \
  ARCHS="arm64 x86_64" \
  ONLY_ACTIVE_ARCH=NO \
  -quiet \
  build

rm -rf build/Messenger.app
cp -R "build/DerivedData/Build/Products/$configuration/Messenger.app" build/
echo "Built build/Messenger.app ($configuration)"
