#!/usr/bin/env bash
# Renders design/AppIcon.svg into the AppIcon asset catalog. Requires resvg (brew install resvg).
set -euo pipefail
cd "$(dirname "$0")/.."

out=Resources/Assets.xcassets/AppIcon.appiconset
for size in 16 32 128 256 512; do
  resvg -w "$size" -h "$size" design/AppIcon.svg "$out/icon_${size}x${size}.png"
  resvg -w $((size * 2)) -h $((size * 2)) design/AppIcon.svg "$out/icon_${size}x${size}@2x.png"
done
echo "Icons written to $out"
