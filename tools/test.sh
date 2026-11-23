#!/bin/sh
# Runs the unit tests. The real-file and snapshot tests skip unless their environment variables are set.
set -eu
set -o pipefail   # a failing test run must fail this script, and with it tools/release.sh
cd "$(dirname "$0")/.."
xcodegen generate --quiet
xcodebuild -project HPLauncher.xcodeproj -scheme HPLauncher -configuration Debug \
  -derivedDataPath .local/DerivedData -destination 'platform=macOS,arch=arm64' \
  test CODE_SIGN_IDENTITY=- 2>&1 | grep -E "error:|warning: .*\.swift|Test Case .* (passed|failed)|Executed|TEST (SUCCEEDED|FAILED)" | grep -v "\[Connection\]" | tail -40
