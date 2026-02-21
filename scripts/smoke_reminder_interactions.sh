#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

# Focused regression suite for reminder bubble interaction flows:
# - complete
# - snooze
# - auto-dismiss
LOG_FILE="$(mktemp /tmp/catcompanion-reminder-flow.XXXXXX.log)"
trap 'rm -f "$LOG_FILE"' EXIT

swift test --filter 'ReminderEngineTests' | tee "$LOG_FILE"

required_tests=(
  'testCompleteActiveReminderRecordsCompletionTime'
  'testSnoozeActiveReminderUsesPlanAndClearsActiveReminder'
  'testActiveReminderBlocksOtherTriggersUntilHandled'
  'testAutoDismissSnoozesAfterTimeout'
  'testCompleteActiveReminderDoesNotImmediatelyRetrigger'
  'testZeroCooldownAllowsImmediateNextReminder'
  'testDisablingCooldownDuringWindowAllowsImmediateTrigger'
)

for test_name in "${required_tests[@]}"; do
  if ! grep -q "$test_name" "$LOG_FILE"; then
    echo "Reminder interaction smoke failed: missing test execution for $test_name"
    exit 1
  fi
done

echo "Reminder interaction smoke passed (${#required_tests[@]} checks)"
