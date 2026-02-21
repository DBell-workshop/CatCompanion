#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

PROJECT="CatCompanion.xcodeproj"
SCHEME="CatCompanionApp"
CONFIGURATION="Debug"
DESTINATION="platform=macOS,arch=arm64"

BUILD_SETTINGS_LOG="$(mktemp /tmp/catcompanion-build-settings.XXXXXX.log)"
trap 'rm -f "$BUILD_SETTINGS_LOG"' EXIT

xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "$DESTINATION" \
  -showBuildSettings >"$BUILD_SETTINGS_LOG"

BUILT_PRODUCTS_DIR="$(awk -F ' = ' '/^[[:space:]]*BUILT_PRODUCTS_DIR = / {print $2; exit}' "$BUILD_SETTINGS_LOG")"
if [[ -z "$BUILT_PRODUCTS_DIR" ]]; then
  echo "Locale smoke failed: unable to determine BUILT_PRODUCTS_DIR"
  exit 1
fi

APP_EXECUTABLE="$BUILT_PRODUCTS_DIR/CatCompanion.app/Contents/MacOS/CatCompanion"
if [[ ! -x "$APP_EXECUTABLE" ]]; then
  echo "Locale smoke failed: executable not found at $APP_EXECUTABLE"
  echo "Tip: run app build first."
  exit 1
fi

python3 scripts/check_runtime_localization.py --app-executable "$APP_EXECUTABLE" --project-root "$ROOT_DIR"

echo "Locale smoke passed"
