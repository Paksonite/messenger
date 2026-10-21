#!/usr/bin/env bash
# Builds a Universal (arm64 + x86_64) Messenger.app into build/.
#
# VERSION sets CFBundleShortVersionString (default: MARKETING_VERSION in project.yml).
# BUILD_NUMBER sets CFBundleVersion, which Sparkle compares (default: commit count, always increasing on main).
set -euo pipefail
cd "$(dirname "$0")/.."

configuration="${CONFIGURATION:-Release}"
build_number="${BUILD_NUMBER:-$(git rev-list --count HEAD)}"
version_args=(CURRENT_PROJECT_VERSION="$build_number")
[[ -n "${VERSION:-}" ]] && version_args+=(MARKETING_VERSION="$VERSION")

xcodegen generate --quiet
xcodebuild \
  -project Messenger.xcodeproj \
  -scheme Messenger \
  -configuration "$configuration" \
  -destination 'generic/platform=macOS' \
  -derivedDataPath build/DerivedData \
  ARCHS="arm64 x86_64" \
  ONLY_ACTIVE_ARCH=NO \
  "${version_args[@]}" \
  -quiet \
  build

# Move rather than copy so only one Messenger.app with this bundle ID stays registered with Launch Services.
rm -rf build/Messenger.app
mv "build/DerivedData/Build/Products/$configuration/Messenger.app" build/
echo "Built build/Messenger.app ($configuration, build $build_number)"
