#!/bin/bash
set -euo pipefail

DMG_PATH=""
KEYCHAIN_PROFILE=""

usage() {
  cat <<'USAGE'
Usage: scripts/notarize_dmg.sh --dmg <path> --keychain-profile <profile>

Description:
  Submit a DMG to Apple notarization service using `notarytool`,
  wait for completion, then staple and validate.

Required:
  --dmg <path>                 DMG file path
  --keychain-profile <name>    notarytool keychain profile name

Example:
  xcrun notarytool store-credentials "AC_NOTARY" \
    --apple-id "you@example.com" \
    --team-id "TEAMID1234" \
    --password "app-specific-password"

  scripts/notarize_dmg.sh \
    --dmg /path/to/CatCompanion-20260220-080059.dmg \
    --keychain-profile AC_NOTARY
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dmg)
      DMG_PATH="$2"
      shift 2
      ;;
    --keychain-profile)
      KEYCHAIN_PROFILE="$2"
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

if [[ -z "$DMG_PATH" || -z "$KEYCHAIN_PROFILE" ]]; then
  usage
  exit 64
fi

if [[ ! -f "$DMG_PATH" ]]; then
  echo "DMG not found: $DMG_PATH" >&2
  exit 66
fi

echo "Submitting for notarization: $DMG_PATH"
xcrun notarytool submit "$DMG_PATH" \
  --keychain-profile "$KEYCHAIN_PROFILE" \
  --wait

echo "Stapling notarization ticket..."
xcrun stapler staple "$DMG_PATH"

echo "Validating stapled ticket..."
xcrun stapler validate "$DMG_PATH"

echo "Gatekeeper assessment..."
spctl -a -vv -t open "$DMG_PATH"

echo "Notarization flow completed: $DMG_PATH"
