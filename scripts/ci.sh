#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

scripts/smoke.sh
python3 scripts/check_localizations.py

if [[ "${RUN_REMINDER_FLOW_SMOKE:-1}" == "1" ]]; then
  scripts/smoke_reminder_interactions.sh
fi

xcodebuild \
  -project CatCompanion.xcodeproj \
  -scheme CatCompanionApp \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  build

if [[ "${RUN_LOCALE_SMOKE:-1}" == "1" ]]; then
  scripts/smoke_locales.sh
fi

xcodebuild \
  -project CatCompanion.xcodeproj \
  -scheme CatCompanionCoreTests \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  test

if [[ "${RUN_UI_SMOKE:-1}" == "1" ]]; then
  scripts/smoke_ui.sh
fi
