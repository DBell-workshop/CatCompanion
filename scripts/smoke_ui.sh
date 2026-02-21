#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-${TMPDIR:-/tmp}/catcompanion-derived-data}"
SCHEME="CatCompanionApp"
PROJECT="CatCompanion.xcodeproj"
CONFIGURATION="Debug"

xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  build >/tmp/catcompanion-smoke-ui-build.log

# Keep this path deterministic to avoid extra xcodebuild queries and scheme/target mismatch errors.
APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/CatCompanion.app"

if [[ ! -d "$APP_PATH" ]]; then
  echo "UI smoke failed: app bundle not found at $APP_PATH"
  exit 1
fi

APP_EXECUTABLE="$APP_PATH/Contents/MacOS/CatCompanion"
if [[ ! -x "$APP_EXECUTABLE" ]]; then
  echo "UI smoke failed: executable not found at $APP_EXECUTABLE"
  exit 1
fi

"$APP_EXECUTABLE" >/tmp/catcompanion-smoke-ui-app.log 2>&1 &
APP_PID=$!

sleep 3

if ! kill -0 "$APP_PID" >/dev/null 2>&1; then
  echo "UI smoke failed: app process exited early"
  exit 1
fi

kill "$APP_PID"
wait "$APP_PID" || true

echo "UI smoke passed"
