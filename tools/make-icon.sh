#!/bin/sh
# Renders the app icon (Tests/IconRenderTests.swift) and builds App/Resources/AppIcon.icns.
set -eu
cd "$(dirname "$0")/.."
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
xcodegen generate --quiet
TEST_RUNNER_HPL_ICON="$WORK/icon.png" xcodebuild -project HPLauncher.xcodeproj -scheme HPLauncher \
  -derivedDataPath .local/DerivedData -destination 'platform=macOS,arch=arm64' test \
  -only-testing:HPLauncherTests/IconRenderTests CODE_SIGN_IDENTITY=- >/dev/null 2>&1
SET="$WORK/AppIcon.iconset"; mkdir "$SET"
for size in 16 32 128 256 512; do
  sips -z $size $size "$WORK/icon.png" --out "$SET/icon_${size}x${size}.png" >/dev/null
  sips -z $((size * 2)) $((size * 2)) "$WORK/icon.png" --out "$SET/icon_${size}x${size}@2x.png" >/dev/null
done
mkdir -p App/Resources docs
iconutil -c icns "$SET" -o App/Resources/AppIcon.icns
cp "$SET/icon_256x256@2x.png" docs/icon.png
echo "Wrote App/Resources/AppIcon.icns"
