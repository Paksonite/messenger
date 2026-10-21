#!/usr/bin/env bash
# Runs the unit tests.
set -euo pipefail
cd "$(dirname "$0")/.."

xcodegen generate --quiet
xcodebuild \
  -project Messenger.xcodeproj \
  -scheme Messenger \
  -destination "platform=macOS,arch=$(uname -m)" \
  -derivedDataPath build/DerivedData \
  -quiet \
  test
