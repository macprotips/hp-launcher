#!/bin/sh
# Builds, notarizes and packages HP Launcher for download: build/HP Launcher <version>.zip
#
# Notarization needs Apple credentials stored once on this Mac by the owner:
#   xcrun notarytool store-credentials HPLauncher --apple-id <email> --team-id MD83L42DNL
# (it asks for an app-specific password from account.apple.com). Without that profile this stops
# after building, and says so.
set -eu
cd "$(dirname "$0")/.."
PROFILE="${NOTARY_PROFILE:-HPLauncher}"
tools/test.sh
tools/build.sh
APP="build/HP Launcher.app"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")
ZIP="build/HP Launcher $VERSION.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
if ! xcrun notarytool history --keychain-profile "$PROFILE" >/dev/null 2>&1; then
  echo "Built and signed, but NOT notarized: no '$PROFILE' notary profile on this Mac (see the top of this script)." >&2
  exit 1
fi
xcrun notarytool submit "$ZIP" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$APP"
rm -f "$ZIP"; ditto -c -k --keepParent "$APP" "$ZIP"     # the download must carry the stapled ticket
spctl -a -vv "$APP"
echo "Ready to share: $ZIP"
