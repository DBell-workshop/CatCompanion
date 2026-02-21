#!/usr/bin/env python3
"""
Runtime localization smoke check for CatCompanion app binary.

It launches the built app executable in a debug dump mode:
  <app_executable> -AppleLanguages "(<locale>)" --dump-localization

The app exits immediately and prints a JSON snapshot. This script validates:
1) resolved app language matches expected locale mapping.
2) selected localized string values match Localizable.strings for that locale.
3) minutes format text matches per-language expectations.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

from check_localizations import REQUIRED_LOCALES, parse_strings_file


CHECK_KEYS = (
    "appName",
    "menuSettings",
    "menuPauseReminders",
    "reminderHydrateName",
    "reminderHydratePrompt",
    "actionComplete",
    "actionSnooze",
    "settingsPauseAllReminders",
    "settingsReminderCooldown",
    "settingsReminderCooldownHelp",
    "settingsReminderCooldownOff",
)

EXPECTED_LANGUAGE = {
    "en": "en",
    "ja": "ja",
    "zh-Hans": "zh-Hans",
    "zh-Hant": "zh-Hant",
}

EXPECTED_MINUTES_TEXT_15 = {
    "en": "15 min",
    "ja": "15分",
    "zh-Hans": "15 分钟",
    "zh-Hant": "15 分鐘",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--app-executable", required=True, help="Path to built CatCompanion executable")
    parser.add_argument(
        "--project-root",
        default=str(Path(__file__).resolve().parents[1]),
        help="Project root path (default: repo root)",
    )
    return parser.parse_args()


def load_expected_values(project_root: Path, locale: str) -> dict[str, str]:
    strings_path = project_root / "CatCompanionApp" / f"{locale}.lproj" / "Localizable.strings"
    parsed, parse_errors = parse_strings_file(strings_path)
    if parse_errors:
        joined = "\n".join(parse_errors)
        raise RuntimeError(f"Failed to parse {strings_path}:\n{joined}")

    missing = [key for key in CHECK_KEYS if key not in parsed]
    if missing:
        raise RuntimeError(f"Missing keys in {strings_path}: {', '.join(missing)}")

    return {key: parsed[key] for key in CHECK_KEYS}


def extract_snapshot(stdout_text: str) -> dict[str, object]:
    for line in reversed(stdout_text.splitlines()):
        line = line.strip()
        if not line:
            continue
        if not (line.startswith("{") and line.endswith("}")):
            continue
        try:
            payload = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(payload, dict):
            return payload
    raise RuntimeError(f"Unable to parse JSON snapshot from output:\n{stdout_text}")


def run_locale_snapshot(app_executable: Path, locale: str) -> dict[str, object]:
    command = [
        str(app_executable),
        "-AppleLanguages",
        f"({locale})",
        "--dump-localization",
    ]
    proc = subprocess.run(
        command,
        capture_output=True,
        text=True,
        timeout=10,
        check=False,
    )
    if proc.returncode != 0:
        raise RuntimeError(
            f"Command failed for locale {locale} (exit {proc.returncode}).\n"
            f"stdout:\n{proc.stdout}\n"
            f"stderr:\n{proc.stderr}"
        )
    return extract_snapshot(proc.stdout)


def validate_locale(
    locale: str,
    snapshot: dict[str, object],
    expected_values: dict[str, str],
    errors: list[str],
) -> None:
    resolved_language = snapshot.get("resolvedLanguage")
    expected_language = EXPECTED_LANGUAGE[locale]
    if resolved_language != expected_language:
        errors.append(
            f"{locale}: resolvedLanguage mismatch: expected '{expected_language}', got '{resolved_language}'"
        )

    minutes_text = snapshot.get("minutesText15")
    expected_minutes_text = EXPECTED_MINUTES_TEXT_15[locale]
    if minutes_text != expected_minutes_text:
        errors.append(
            f"{locale}: minutesText15 mismatch: expected '{expected_minutes_text}', got '{minutes_text}'"
        )

    values = snapshot.get("values")
    if not isinstance(values, dict):
        errors.append(f"{locale}: values field is missing or invalid")
        return

    for key, expected in expected_values.items():
        actual = values.get(key)
        if actual != expected:
            errors.append(f"{locale}: key '{key}' mismatch: expected '{expected}', got '{actual}'")


def main() -> int:
    args = parse_args()
    project_root = Path(args.project_root).resolve()
    app_executable = Path(args.app_executable).resolve()

    if not app_executable.is_file():
        print(f"Runtime localization check failed: app executable not found: {app_executable}")
        return 1

    errors: list[str] = []

    for locale in REQUIRED_LOCALES:
        try:
            expected_values = load_expected_values(project_root, locale)
            snapshot = run_locale_snapshot(app_executable, locale)
            validate_locale(locale, snapshot, expected_values, errors)
        except Exception as exc:  # pylint: disable=broad-except
            errors.append(f"{locale}: {exc}")

    if errors:
        print("Runtime localization check failed:")
        for err in errors:
            print(f"- {err}")
        return 1

    print("Runtime localization check passed for locales: " + ", ".join(REQUIRED_LOCALES))
    return 0


if __name__ == "__main__":
    sys.exit(main())
