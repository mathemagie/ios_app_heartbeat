#!/usr/bin/env bash
#
# Build, install, and launch HeartBeatStream on the iOS Simulator.
#
# Usage:
#   ./scripts/run-simulator.sh                 # uses default simulator
#   ./scripts/run-simulator.sh "iPhone 16"     # pick a specific simulator
#
# Note: the Simulator has no heart-rate sensor, so live BPM stays at "--".
# Use it to test the UI (Share ID, copy button, Pusher connection); use a real
# iPhone + Apple Watch for actual heart-rate data.

set -euo pipefail

# Resolve repo root from this script's location (works from any cwd).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PROJECT="$REPO_ROOT/src/ios/HeartBeatStream/HeartBeatStream/HeartBeatStream.xcodeproj"
SCHEME="HeartBeatStream"
BUNDLE_ID="com.aurelienfache.HeartBeatStream"
SIMULATOR="${1:-iPhone 17 Pro}"

echo "==> Building $SCHEME for '$SIMULATOR'…"
xcodebuild -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,name=$SIMULATOR" \
  build

echo "==> Locating built app…"
APP_PATH="$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,name=$SIMULATOR" \
  -showBuildSettings 2>/dev/null \
  | awk -F' = ' '/ TARGET_BUILD_DIR /{d=$2} / FULL_PRODUCT_NAME /{n=$2} END{print d"/"n}')"
echo "    $APP_PATH"

echo "==> Booting '$SIMULATOR'…"
xcrun simctl boot "$SIMULATOR" 2>/dev/null || true
open -a Simulator

echo "==> Installing and launching…"
xcrun simctl install booted "$APP_PATH"
xcrun simctl launch booted "$BUNDLE_ID"

echo "==> Done. App is running on '$SIMULATOR'."
echo "    Tip: check the copied Share ID with: xcrun simctl pbpaste booted"
