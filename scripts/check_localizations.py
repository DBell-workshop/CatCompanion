#!/usr/bin/env python3
"""
Localization consistency checks for CatCompanion.

Checks:
1) Required locale folders exist.
2) Localizable.strings key sets are identical across locales.
3) InfoPlist.strings contains required keys for each locale.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path


REQUIRED_LOCALES = ("en", "ja", "zh-Hans", "zh-Hant")
REQUIRED_INFO_KEYS = ("CFBundleDisplayName", "CFBundleName", "NSMicrophoneUsageDescription")


PAIR_RE = re.compile(r'^\s*"((?:\\.|[^"\\])*)"\s*=\s*"((?:\\.|[^"\\])*)"\s*;\s*$')
BLOCK_COMMENT_RE = re.compile(r"/\*.*?\*/", re.S)


def parse_strings_file(path: Path) -> tuple[dict[str, str], list[str]]:
    content = path.read_text(encoding="utf-8")
    content = BLOCK_COMMENT_RE.sub("", content)

    data: dict[str, str] = {}
    errors: list[str] = []

    for lineno, raw_line in enumerate(content.splitlines(), start=1):
        line = raw_line.strip()
        if not line or line.startswith("//"):
            continue

        match = PAIR_RE.match(line)
        if not match:
            errors.append(f"{path}:{lineno} invalid .strings syntax: {raw_line}")
            continue

        key = match.group(1)
        value = match.group(2)
        if key in data and data[key] != value:
            errors.append(f"{path}:{lineno} duplicate key with different value: {key}")
            continue
        data[key] = value

    return data, errors


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    app_dir = root / "CatCompanionApp"

    errors: list[str] = []
    localizable_by_locale: dict[str, dict[str, str]] = {}

    for locale in REQUIRED_LOCALES:
        locale_dir = app_dir / f"{locale}.lproj"
        if not locale_dir.is_dir():
            errors.append(f"Missing locale directory: {locale_dir}")
            continue

        localizable_path = locale_dir / "Localizable.strings"
        info_plist_path = locale_dir / "InfoPlist.strings"

        if not localizable_path.is_file():
            errors.append(f"Missing file: {localizable_path}")
        else:
            parsed, parse_errors = parse_strings_file(localizable_path)
            localizable_by_locale[locale] = parsed
            errors.extend(parse_errors)

        if not info_plist_path.is_file():
            errors.append(f"Missing file: {info_plist_path}")
        else:
            info_data, parse_errors = parse_strings_file(info_plist_path)
            errors.extend(parse_errors)
            for key in REQUIRED_INFO_KEYS:
                if key not in info_data:
                    errors.append(f"Missing key '{key}' in {info_plist_path}")

    if localizable_by_locale:
        reference_locale = REQUIRED_LOCALES[0]
        reference_keys = set(localizable_by_locale.get(reference_locale, {}).keys())

        for locale in REQUIRED_LOCALES:
            keys = set(localizable_by_locale.get(locale, {}).keys())
            if not keys:
                continue

            missing = sorted(reference_keys - keys)
            extra = sorted(keys - reference_keys)

            if missing:
                errors.append(f"{locale}: missing keys in Localizable.strings: {', '.join(missing)}")
            if extra:
                errors.append(f"{locale}: extra keys in Localizable.strings: {', '.join(extra)}")

    if errors:
        print("Localization check failed:")
        for err in errors:
            print(f"- {err}")
        return 1

    key_count = len(next(iter(localizable_by_locale.values()))) if localizable_by_locale else 0
    print(
        "Localization check passed: "
        f"{len(REQUIRED_LOCALES)} locales, {key_count} Localizable keys, "
        f"{len(REQUIRED_INFO_KEYS)} InfoPlist keys required."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
