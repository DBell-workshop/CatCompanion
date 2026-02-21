#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

PROJECT="CatCompanion.xcodeproj"
SCHEME="CatCompanionApp"
CONFIGURATION="Debug"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-${TMPDIR:-/tmp}/catcompanion-e2e-auto-derived-data}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
OUTPUT_DIR="$ROOT_DIR/dist/e2e-startup-diagnostics-auto-$TIMESTAMP"
APP_PATH=""
SKIP_BUILD=0
LIVE_GATEWAY_URL=""
LIVE_GATEWAY_TOKEN=""
FAILED_COUNT=0
RESULTS_FILE=""

usage() {
  cat <<'EOF'
Usage:
  scripts/e2e_startup_diagnostics_auto.sh [options]

Options:
  --app <path>                 Existing .app bundle path to use.
  --skip-build                 Skip xcodebuild.
  --output-dir <path>          Output folder for json + report.
  --live-gateway-url <url>     Optional: run live pass case and expect gateway status=pass.
  --live-gateway-token <token> Optional: token for live gateway case.
  --help                       Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app)
      APP_PATH="$2"
      shift 2
      ;;
    --skip-build)
      SKIP_BUILD=1
      shift
      ;;
    --output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --live-gateway-url)
      LIVE_GATEWAY_URL="$2"
      shift 2
      ;;
    --live-gateway-token)
      LIVE_GATEWAY_TOKEN="$2"
      shift 2
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
RESULTS_FILE="$OUTPUT_DIR/report.md"

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

if [[ -z "$APP_PATH" ]]; then
  APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/CatCompanion.app"
fi

APP_EXEC="$APP_PATH/Contents/MacOS/CatCompanion"
if [[ ! -x "$APP_EXEC" ]]; then
  echo "App executable not found: $APP_EXEC"
  exit 1
fi

cat >"$RESULTS_FILE" <<'EOF'
# Startup Diagnostics Auto E2E Report

| Case | Expected | Actual | Result | Notes |
|---|---|---|---|---|
EOF

extract_gateway_status() {
  local json_path="$1"
  python3 - "$json_path" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as f:
    payload = json.load(f)

checks = payload.get("checks", [])
gateway = next((item for item in checks if item.get("id") == "gateway"), None)
if gateway is None:
    print("missing_gateway_check")
    sys.exit(0)

print(gateway.get("status", "missing_status"))
PY
}

run_case() {
  local case_id="$1"
  local expected="$2"
  local notes="$3"
  shift 3

  local json_file="$OUTPUT_DIR/${case_id}.json"
  ("$@" "$APP_EXEC" --dump-startup-diagnostics) >"$json_file"

  local actual
  actual="$(extract_gateway_status "$json_file")"

  local result="PASS"
  if [[ "$actual" != "$expected" ]]; then
    result="FAIL"
    FAILED_COUNT=$((FAILED_COUNT + 1))
  fi

  local clean_notes="${notes//|//}"
  echo "| $case_id | $expected | $actual | $result | $clean_notes |" >>"$RESULTS_FILE"
}

run_case \
  "assistant_disabled" \
  "warning" \
  "assistant disabled should not hard-fail gateway check" \
  env \
  CAT_DIAG_ASSISTANT_ENABLED=0 \
  CAT_DIAG_VOICE_ENABLED=0

run_case \
  "assistant_enabled_invalid_url" \
  "failed" \
  "invalid or unreachable gateway should fail" \
  env \
  CAT_DIAG_ASSISTANT_ENABLED=1 \
  CAT_DIAG_GATEWAY_URL=ws://127.0.0.1:1 \
  CAT_DIAG_VOICE_ENABLED=0

run_case \
  "assistant_enabled_empty_url" \
  "failed" \
  "empty gateway url should fail" \
  env \
  CAT_DIAG_ASSISTANT_ENABLED=1 \
  CAT_DIAG_GATEWAY_URL= \
  CAT_DIAG_VOICE_ENABLED=0

if [[ -n "$LIVE_GATEWAY_URL" ]]; then
  run_case \
    "assistant_enabled_live_gateway" \
    "pass" \
    "live gateway reachable check" \
    env \
    CAT_DIAG_ASSISTANT_ENABLED=1 \
    CAT_DIAG_GATEWAY_URL="$LIVE_GATEWAY_URL" \
    CAT_DIAG_GATEWAY_TOKEN="$LIVE_GATEWAY_TOKEN" \
    CAT_DIAG_VOICE_ENABLED=0
fi

echo "Report: $RESULTS_FILE"
echo "JSON outputs: $OUTPUT_DIR"

if [[ "$FAILED_COUNT" -gt 0 ]]; then
  echo "Auto diagnostics E2E failed: $FAILED_COUNT case(s)."
  exit 1
fi

echo "Auto diagnostics E2E passed."
