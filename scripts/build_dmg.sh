#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/CatCompanion.xcodeproj"
SCHEME="CatCompanionApp"
CONFIGURATION="Release"
DERIVED_DATA_PATH="$ROOT_DIR/.build/dmg-derived-data"
OUTPUT_DIR="$ROOT_DIR/dist"
DMG_BASENAME="CatCompanion"
VOLUME_NAME="CatCompanion"
SKIP_BUILD=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --configuration)
      CONFIGURATION="$2"
      shift 2
      ;;
    --derived-data)
      DERIVED_DATA_PATH="$2"
      shift 2
      ;;
    --output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --name)
      DMG_BASENAME="$2"
      VOLUME_NAME="$2"
      shift 2
      ;;
    --skip-build)
      SKIP_BUILD=1
      shift
      ;;
    -h|--help)
      cat <<'USAGE'
Usage: scripts/build_dmg.sh [options]

Options:
  --configuration <Debug|Release>   Build configuration (default: Release)
  --derived-data <path>             DerivedData output path
  --output-dir <path>               DMG output directory (default: dist)
  --name <name>                     DMG base name and mounted volume name
  --skip-build                      Skip xcodebuild and package existing app
  -h, --help                        Show this help message
USAGE
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 64
      ;;
  esac
done

mkdir -p "$OUTPUT_DIR"

if [[ "$SKIP_BUILD" -eq 0 ]]; then
  xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "platform=macOS" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    build
fi

APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/CatCompanion.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "App not found at $APP_PATH" >&2
  echo "Hint: run build first or pass matching --configuration/--derived-data." >&2
  exit 65
fi

STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/catcompanion-dmg.XXXXXX")"
cleanup() {
  rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
DMG_PATH="$OUTPUT_DIR/${DMG_BASENAME}-${TIMESTAMP}.dmg"

hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "DMG created: $DMG_PATH"
