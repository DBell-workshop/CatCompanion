# Startup Diagnostics E2E (Manual)

This document defines a repeatable first-run diagnostics verification for Cat Companion.

## Scope

- Startup diagnostics guide auto-open behavior on first run.
- Gateway row behavior for:
  - assistant disabled
  - invalid/unreachable gateway
  - reachable gateway (optional)
- "Done" persistence (guide should not auto-open after relaunch).
- Manual diagnostics entry from menu bar.

## Script

Use:

```bash
scripts/manual_startup_diagnostics_e2e.sh
```

Useful options:

```bash
scripts/manual_startup_diagnostics_e2e.sh --help
scripts/manual_startup_diagnostics_e2e.sh --skip-build --app /Applications/CatCompanion.app
scripts/manual_startup_diagnostics_e2e.sh --skip-reset
```

## Auto Script (Headless)

Use:

```bash
scripts/e2e_startup_diagnostics_auto.sh
```

Optional live gateway pass check:

```bash
scripts/e2e_startup_diagnostics_auto.sh \
  --live-gateway-url ws://127.0.0.1:18789 \
  --live-gateway-token '<token-if-needed>'
```

Auto script output:

- `report.md`: gateway status assertions per case
- `*.json`: raw diagnostics payload from app `--dump-startup-diagnostics`

## Outputs

The script creates a timestamped folder under `dist/`:

- `checklist_results.md`: pass/fail/skip records for each checkpoint
- `screenshots/*.png`: one screenshot per checkpoint
- `xcodebuild.log`: build log (unless `--skip-build`)

## Checkpoints

- `CP01`: startup diagnostics guide appears automatically on first launch.
- `CP02`: gateway row warns when assistant is disabled.
- `CP03`: gateway row fails when assistant is enabled with invalid URL.
- `CP04` (optional): gateway row passes when local gateway is reachable.
- `CP05`: after clicking `Done` and relaunching app, diagnostics guide does not auto-open.
- `CP06`: diagnostics guide can still be opened manually from menu bar.

## Notes

- By default, script clears:
  - `CatCompanion.StartupDiagnosticsSeen`
  - `CatCompanion.Settings`
- This is intentionally confirmation-gated in the script.
- If you need to preserve local settings, run with `--skip-reset`.
