#!/usr/bin/env bash
# Runs the unit tests: page scripts with node, the app with xcodebuild.
set -euo pipefail
cd "$(dirname "$0")/.."

for script in Resources/Scripts/*.js; do
  node --check "$script"
done
node --test Tests/js

xcodegen generate --quiet
xcodebuild \
  -project Messenger.xcodeproj \
  -scheme Messenger \
  -destination "platform=macOS,arch=$(uname -m)" \
  -derivedDataPath build/DerivedData \
  -quiet \
  test
