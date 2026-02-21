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
SIGN_IDENTITY=""

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
    --sign)
      SIGN_IDENTITY="$2"
      shift 2
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
  --sign <identity>                 Code-sign identity (e.g. "Developer ID Application: ...")
  -h, --help                        Show this help message

Steps:
  1. Build CatCompanionApp via xcodebuild (Release)
  2. Build CatCompanionAgent via swift build (Release)
  3. Bundle Agent into .app/Contents/Helpers/
  4. Optionally code-sign with --sign
  5. Package into DMG
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

# ── Step 1: Build main app ──
if [[ "$SKIP_BUILD" -eq 0 ]]; then
  echo "==> Building CatCompanionApp (xcodebuild, $CONFIGURATION)..."
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

# ── Step 2: Build Agent via SPM ──
if [[ "$SKIP_BUILD" -eq 0 ]]; then
  echo "==> Building CatCompanionAgent (swift build, release)..."
  swift build \
    --package-path "$ROOT_DIR" \
    --product CatCompanionAgent \
    -c release
fi

AGENT_PATH="$ROOT_DIR/.build/release/CatCompanionAgent"
if [[ ! -f "$AGENT_PATH" ]]; then
  # Fallback: try arm64 path
  AGENT_PATH="$ROOT_DIR/.build/arm64-apple-macosx/release/CatCompanionAgent"
fi
if [[ ! -f "$AGENT_PATH" ]]; then
  echo "CatCompanionAgent binary not found. Tried:" >&2
  echo "  $ROOT_DIR/.build/release/CatCompanionAgent" >&2
  echo "  $ROOT_DIR/.build/arm64-apple-macosx/release/CatCompanionAgent" >&2
  exit 66
fi

# ── Step 3: Bundle Agent into .app ──
echo "==> Bundling CatCompanionAgent into app..."
HELPERS_DIR="$APP_PATH/Contents/Helpers"
mkdir -p "$HELPERS_DIR"
cp "$AGENT_PATH" "$HELPERS_DIR/CatCompanionAgent"
chmod +x "$HELPERS_DIR/CatCompanionAgent"

echo "Agent bundled at: $HELPERS_DIR/CatCompanionAgent"

# ── Step 4: Code-sign (optional) ──
if [[ -n "$SIGN_IDENTITY" ]]; then
  echo "==> Code-signing Agent..."
  codesign --force --options runtime --sign "$SIGN_IDENTITY" "$HELPERS_DIR/CatCompanionAgent"

  echo "==> Code-signing app bundle..."
  codesign --force --deep --options runtime --sign "$SIGN_IDENTITY" "$APP_PATH"

  echo "==> Verifying code signature..."
  codesign --verify --verbose "$APP_PATH"
fi

# ── Step 5: Create DMG ──
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

echo ""
echo "==> DMG created: $DMG_PATH"
echo ""

# ── Summary ──
echo "Bundle contents:"
echo "  App:   $(du -sh "$APP_PATH" | cut -f1) $APP_PATH"
echo "  Agent: $(du -sh "$HELPERS_DIR/CatCompanionAgent" | cut -f1) (bundled)"
echo "  DMG:   $(du -sh "$DMG_PATH" | cut -f1) $DMG_PATH"

if [[ -n "$SIGN_IDENTITY" ]]; then
  echo "  Signed: YES ($SIGN_IDENTITY)"
else
  echo "  Signed: NO (pass --sign to enable)"
fi
