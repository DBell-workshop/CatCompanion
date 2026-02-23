#!/bin/bash
set -euo pipefail

DIST_DIR=""

usage() {
  cat <<'USAGE'
Usage: scripts/generate_appcast.sh --dist <directory>

Description:
  Generate an appcast.xml from DMG files in the given directory
  using Sparkle's generate_appcast tool.

  The tool reads EdDSA private key from your login Keychain
  (stored by generate_keys) and signs each DMG automatically.

Required:
  --dist <directory>    Directory containing .dmg files

Example:
  scripts/generate_appcast.sh --dist dist/
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dist)
      DIST_DIR="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 64
      ;;
  esac
done

if [[ -z "$DIST_DIR" ]]; then
  usage
  exit 64
fi

if [[ ! -d "$DIST_DIR" ]]; then
  echo "Directory not found: $DIST_DIR" >&2
  exit 66
fi

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Locate Sparkle's generate_appcast tool from SPM checkout
GENERATE_APPCAST=""
for candidate in \
  "$ROOT_DIR/.build/artifacts/sparkle/Sparkle/bin/generate_appcast" \
  "$ROOT_DIR/.build/checkouts/Sparkle/bin/generate_appcast"; do
  if [[ -x "$candidate" ]]; then
    GENERATE_APPCAST="$candidate"
    break
  fi
done

if [[ -z "$GENERATE_APPCAST" ]]; then
  echo "generate_appcast tool not found. Run 'swift package resolve' first." >&2
  exit 69
fi

echo "Using generate_appcast: $GENERATE_APPCAST"
echo "Processing DMGs in: $DIST_DIR"

"$GENERATE_APPCAST" "$DIST_DIR"

APPCAST_PATH="$DIST_DIR/appcast.xml"
if [[ -f "$APPCAST_PATH" ]]; then
  echo "Appcast generated: $APPCAST_PATH"
else
  echo "Warning: appcast.xml was not created. Check that DMG files exist in $DIST_DIR." >&2
  exit 1
fi
