#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

PROJECT="CatCompanion.xcodeproj"
SCHEME="CatCompanionApp"
CONFIGURATION="Debug"
BUNDLE_ID="com.hakimi.catcompanion"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-${TMPDIR:-/tmp}/catcompanion-e2e-derived-data}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
OUTPUT_DIR="$ROOT_DIR/dist/e2e-startup-diagnostics-$TIMESTAMP"
SCREENSHOT_DIR=""
RESULTS_FILE=""
APP_PATH=""
SKIP_BUILD=0
SKIP_RESET=0

usage() {
  cat <<'EOF'
Usage:
  scripts/manual_startup_diagnostics_e2e.sh [options]

Options:
  --app <path>             Existing .app bundle to use.
  --output-dir <path>      Output folder for screenshots and checklist results.
  --bundle-id <id>         Bundle identifier used by defaults (default: com.hakimi.catcompanion).
  --skip-build             Skip xcodebuild and use --app or derived-data app path.
  --skip-reset             Do not clear startup/settings defaults.
  --help                   Show this help.

Examples:
  scripts/manual_startup_diagnostics_e2e.sh

  scripts/manual_startup_diagnostics_e2e.sh \
    --app /Applications/CatCompanion.app \
    --skip-build
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app)
      APP_PATH="$2"
      shift 2
      ;;
    --output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --bundle-id)
      BUNDLE_ID="$2"
      shift 2
      ;;
    --skip-build)
      SKIP_BUILD=1
      shift
      ;;
    --skip-reset)
      SKIP_RESET=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

mkdir -p "$OUTPUT_DIR"
SCREENSHOT_DIR="$OUTPUT_DIR/screenshots"
RESULTS_FILE="$OUTPUT_DIR/checklist_results.md"
mkdir -p "$SCREENSHOT_DIR"

confirm_or_abort() {
  local prompt="$1"
  local answer=""
  while true; do
    read -r -p "$prompt [y/N]: " answer
    case "${answer,,}" in
      y|yes) return 0 ;;
      n|no|"") echo "Aborted."; exit 1 ;;
      *) echo "Please answer y or n." ;;
    esac
  done
}

ask_yes_no() {
  local prompt="$1"
  local answer=""
  while true; do
    read -r -p "$prompt [y/N]: " answer
    case "${answer,,}" in
      y|yes) return 0 ;;
      n|no|"") return 1 ;;
      *) echo "Please answer y or n." ;;
    esac
  done
}

quit_running_app() {
  osascript -e "tell application id \"$BUNDLE_ID\" to quit" >/dev/null 2>&1 || true
  pkill -f "/CatCompanion.app/Contents/MacOS/CatCompanion" >/dev/null 2>&1 || true
  sleep 1
}

build_if_needed() {
  if [[ "$SKIP_BUILD" -eq 0 ]]; then
    echo "Building app..."
    xcodebuild \
      -project "$PROJECT" \
      -scheme "$SCHEME" \
      -configuration "$CONFIGURATION" \
      -destination 'platform=macOS,arch=arm64' \
      -derivedDataPath "$DERIVED_DATA_PATH" \
      build >"$OUTPUT_DIR/xcodebuild.log"
  fi
}

resolve_app_path() {
  if [[ -n "$APP_PATH" ]]; then
    return
  fi
  APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/CatCompanion.app"
}

clear_defaults_if_needed() {
  if [[ "$SKIP_RESET" -eq 1 ]]; then
    return
  fi

  cat <<EOF
This script can delete app defaults to force first-run diagnostics:
  defaults delete $BUNDLE_ID CatCompanion.StartupDiagnosticsSeen
  defaults delete $BUNDLE_ID CatCompanion.Settings
EOF
  confirm_or_abort "Continue and clear these defaults?"

  defaults delete "$BUNDLE_ID" "CatCompanion.StartupDiagnosticsSeen" >/dev/null 2>&1 || true
  defaults delete "$BUNDLE_ID" "CatCompanion.Settings" >/dev/null 2>&1 || true
}

write_results_header() {
  cat >"$RESULTS_FILE" <<'EOF'
# Startup Diagnostics Manual E2E Results

| ID | Checkpoint | Expected | Screenshot | Result | Notes |
|---|---|---|---|---|---|
EOF
}

append_result() {
  local id="$1"
  local title="$2"
  local expected="$3"
  local screenshot="$4"
  local result="$5"
  local notes="$6"
  local clean_notes="${notes//|//}"
  echo "| $id | $title | $expected | $screenshot | $result | $clean_notes |" >>"$RESULTS_FILE"
}

capture_checkpoint() {
  local id="$1"
  local slug="$2"
  local title="$3"
  local expected="$4"
  local instructions="$5"
  local shot_path="$SCREENSHOT_DIR/${id}_${slug}.png"
  local result=""
  local notes=""

  echo
  echo "[$id] $title"
  echo "$instructions"
  read -r -p "Press Enter when ready to capture screenshot..."
  screencapture -x "$shot_path"
  echo "Saved: $shot_path"

  while true; do
    read -r -p "Checkpoint result [p=pass/f=fail/s=skip]: " result
    case "${result,,}" in
      p) result="PASS"; break ;;
      f) result="FAIL"; break ;;
      s) result="SKIP"; break ;;
      *) echo "Enter p, f, or s." ;;
    esac
  done

  read -r -p "Notes (optional): " notes
  append_result "$id" "$title" "$expected" "$(basename "$shot_path")" "$result" "$notes"
}

launch_app() {
  open -n "$APP_PATH"
  sleep 2
}

if ! command -v screencapture >/dev/null 2>&1; then
  echo "Missing required command: screencapture"
  exit 1
fi

echo "Output directory: $OUTPUT_DIR"
build_if_needed
resolve_app_path

if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle not found: $APP_PATH"
  echo "Use --app <path> or run without --skip-build."
  exit 1
fi

quit_running_app
clear_defaults_if_needed
write_results_header
launch_app

capture_checkpoint \
  "CP01" \
  "first_launch_guide" \
  "Diagnostics guide auto-opens on first launch" \
  "Guide window appears without manual action." \
  "After launch, verify the startup diagnostics guide is visible."

capture_checkpoint \
  "CP02" \
  "assistant_disabled_gateway_warning" \
  "Gateway row reflects assistant-disabled state" \
  "Gateway check is warning and message indicates assistant is disabled." \
  "In the diagnostics list, locate the Gateway row and confirm assistant-disabled message."

capture_checkpoint \
  "CP03" \
  "gateway_invalid_url_failed" \
  "Gateway invalid URL returns failed status" \
  "Gateway check turns failed after assistant enabled + invalid URL + Run Again." \
  "Click Open Settings -> enable Assistant -> set Gateway URL to ws://127.0.0.1:1 -> return and click Run Again."

if ask_yes_no "Do you want to run the live gateway success check (requires local Gateway running)?"; then
  capture_checkpoint \
    "CP04" \
    "gateway_live_connected_pass" \
    "Gateway live probe passes when service is reachable" \
    "Gateway check is pass and message indicates connected." \
    "Set Gateway URL to your running Gateway (default ws://127.0.0.1:18789), keep token correct, then click Run Again."
fi

read -r -p "Click Done in diagnostics guide now, then press Enter to relaunch app..."
quit_running_app
launch_app

capture_checkpoint \
  "CP05" \
  "done_persists_no_auto_popup" \
  "Completing guide persists first-run state" \
  "After clicking Done and relaunching app, diagnostics guide does not auto-open." \
  "Before this step, click Done in diagnostics guide. App was relaunched automatically by script."

capture_checkpoint \
  "CP06" \
  "manual_open_from_menu" \
  "Diagnostics guide can still be opened manually" \
  "Diagnostics guide opens from menu bar Diagnostics item." \
  "Use menu bar cat icon -> Diagnostics and confirm the guide opens."

cat <<EOF

Manual E2E finished.
- Results: $RESULTS_FILE
- Screenshots: $SCREENSHOT_DIR

Remember to quit the app if no longer needed:
  osascript -e 'tell application id "$BUNDLE_ID" to quit'
EOF
