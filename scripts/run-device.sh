#!/usr/bin/env bash
#
# Build, install, and launch HeartBeatStream on a connected iPhone.
#
# Usage:
#   ./scripts/run-device.sh
#   ./scripts/run-device.sh "Aurélien's iPhone"
#   DEVICE_ID=00008110-001234567890801E ./scripts/run-device.sh
#
# The optional argument / DEVICE_ID can be a device name, UDID, serial number,
# or any other identifier accepted by `xcrun devicectl --device`.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PROJECT="$REPO_ROOT/src/ios/HeartBeatStream/HeartBeatStream/HeartBeatStream.xcodeproj"
SCHEME="HeartBeatStream"
BUNDLE_ID="com.aurelienfache.HeartBeatStream"
BUILD_ROOT="$REPO_ROOT/build/device"
DERIVED_DATA_PATH="$BUILD_ROOT/DerivedData"
SOURCE_PACKAGES_PATH="$BUILD_ROOT/SourcePackages"
DEVICE_JSON="$BUILD_ROOT/devices.json"

DEVICE="${1:-${DEVICE_ID:-}}"

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "error: required tool '$1' was not found in PATH" >&2
    exit 1
  fi
}

select_device() {
  if [[ -n "$DEVICE" ]]; then
    printf "%s\n" "$DEVICE"
    return
  fi

  echo "==> Looking for a connected iPhone..." >&2
  mkdir -p "$BUILD_ROOT"

  if ! xcrun devicectl --timeout 30 list devices --json-output "$DEVICE_JSON" >/dev/null; then
    echo "error: devicectl could not list devices." >&2
    echo "       Connect/unlock your iPhone, trust this Mac, then retry." >&2
    echo "       You can also pass it explicitly: ./scripts/run-device.sh \"My iPhone\"" >&2
    exit 1
  fi

  DEVICE="$(python3 - "$DEVICE_JSON" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = json.load(fh)

def walk(value):
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from walk(child)
    elif isinstance(value, list):
        for child in value:
            yield from walk(child)

def get_path(value, path):
    for part in path.split("."):
        if not isinstance(value, dict) or part not in value:
            return None
        value = value[part]
    return value

devices = []
for item in walk(data):
    name = item.get("name") or get_path(item, "deviceProperties.name")
    identifier = (
        item.get("identifier")
        or item.get("udid")
        or get_path(item, "identifier.identifier")
        or get_path(item, "deviceProperties.identifier")
    )
    platform = (
        get_path(item, "hardwareProperties.platform")
        or get_path(item, "deviceProperties.platform")
        or item.get("platform")
        or ""
    )
    connection = item.get("connectionProperties") or {}
    transport = str(connection.get("transportType") or "").lower()
    tunnel_state = str(connection.get("tunnelState") or "").lower()
    is_connected = bool(transport) or tunnel_state not in ("", "unavailable")
    if name and identifier and "simulator" not in str(platform).lower():
        if "iphone" in str(name).lower() or "ios" in str(platform).lower():
            devices.append((str(identifier), str(name), is_connected))

seen = set()
unique = []
for identifier, name, is_connected in devices:
    if identifier not in seen:
        seen.add(identifier)
        unique.append((identifier, name, is_connected))

connected = [device for device in unique if device[2]]
choices = connected or unique

if len(choices) == 1:
    print(choices[0][0])
elif len(unique) > 1:
    print("error: multiple iOS devices found:", file=sys.stderr)
    for identifier, name, is_connected in unique:
        status = "connected" if is_connected else "not connected"
        print(f"  {identifier}  {name}  ({status})", file=sys.stderr)
    print("Pass one explicitly, for example:", file=sys.stderr)
    print(f"  ./scripts/run-device.sh {choices[0][0]!r}", file=sys.stderr)
    sys.exit(2)
else:
    print("error: no connected iPhone found in devicectl output", file=sys.stderr)
    sys.exit(1)
PY
)"
  printf "%s\n" "$DEVICE"
}

require_tool xcodebuild
require_tool xcrun
require_tool python3

if [[ ! -d "$PROJECT" ]]; then
  echo "error: Xcode project not found at $PROJECT" >&2
  exit 1
fi

DEVICE="$(select_device)"
mkdir -p "$BUILD_ROOT" "$DERIVED_DATA_PATH" "$SOURCE_PACKAGES_PATH"

echo "==> Building $SCHEME for device '$DEVICE'..."
xcodebuild -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "generic/platform=iOS" \
  -configuration Debug \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -clonedSourcePackagesDirPath "$SOURCE_PACKAGES_PATH" \
  -allowProvisioningUpdates \
  CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM=3KVD49BW46 \
  build

APP_PATH="$(find "$DERIVED_DATA_PATH/Build/Products/Debug-iphoneos" -maxdepth 1 -name "$SCHEME.app" -print -quit)"
if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
  echo "error: built app was not found under $DERIVED_DATA_PATH/Build/Products/Debug-iphoneos" >&2
  exit 1
fi

echo "==> Installing $APP_PATH..."
xcrun devicectl --timeout 120 device install app --device "$DEVICE" "$APP_PATH"

echo "==> Launching $BUNDLE_ID..."
xcrun devicectl --timeout 60 device process launch --device "$DEVICE" "$BUNDLE_ID" --terminate-existing

echo "==> Done. HeartBeatStream is installed and running on '$DEVICE'."
