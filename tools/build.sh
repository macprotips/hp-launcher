#!/bin/sh
# Builds "build/HP Launcher.app", signed with the Developer ID certificate.
#
# The Remastered engines are built in their own projects. When Vendor/Remastered holds them, each is
# embedded with its open-source notices; without it, the app builds with Remastered unavailable.
set -eu
cd "$(dirname "$0")/.."
ENGINES=Vendor/Remastered
IDENTITY="Developer ID Application"

xcodegen generate --quiet
xcodebuild -project HPLauncher.xcodeproj -scheme HPLauncher -configuration Release \
  -derivedDataPath .local/DerivedData build -quiet
APP="build/HP Launcher.app"
rm -rf "$APP"; mkdir -p build
ditto ".local/DerivedData/Build/Products/Release/HP Launcher.app" "$APP"

if [ -d "$ENGINES" ]; then
  # A release must never go out without an engine it used to have.
  [ -d "$ENGINES/HP2.app" ] || { echo "error: $ENGINES has no HP2.app." >&2; exit 1; }
  mkdir -p "$APP/Contents/Helpers"
  for ENGINE in "$ENGINES"/*.app; do
    HELPER="$APP/Contents/Helpers/$(basename "$ENGINE")"
    ditto "$ENGINE" "$HELPER"
    [ -d "$HELPER/Contents/Resources" ] && cp "$ENGINES/Licenses.md" "$HELPER/Contents/Resources/Licenses.md"
    # Inside out: the engine's libraries, then the engine.
    for lib in "$HELPER"/Contents/Frameworks/*; do
      [ -e "$lib" ] && codesign --force --sign "$IDENTITY" --options runtime --timestamp "$lib"
    done
    codesign --force --sign "$IDENTITY" --options runtime --timestamp "$HELPER"
    echo "Embedded $(basename "$ENGINE")"
  done
  cp "$ENGINES/Licenses.md" "$APP/Contents/Resources/Licenses.md"
  codesign --force --sign "$IDENTITY" --options runtime --timestamp --preserve-metadata=entitlements,requirements,flags "$APP"
else
  echo "Note: no $ENGINES folder, so Remastered isn't included in this build."
fi

codesign --verify --deep --strict --verbose=1 "$APP"
echo "Built $APP"
