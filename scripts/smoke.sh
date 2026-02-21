#!/bin/bash
set -euo pipefail

TMP_BASE="${TMPDIR:-/tmp}"
export CLANG_MODULE_CACHE_PATH="$TMP_BASE/clang-module-cache"
export SWIFTPM_BUILD_DIR="$TMP_BASE/swift-build"
mkdir -p "$CLANG_MODULE_CACHE_PATH" "$SWIFTPM_BUILD_DIR"

swift test
swift build
