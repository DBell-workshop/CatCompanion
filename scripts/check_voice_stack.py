#!/usr/bin/env python3
"""
Offline voice stack readiness check for CatCompanion.

Required components:
1) STT: whisper.cpp CLI (whisper-cli or main)
2) TTS: Python 3 + CosyVoice runtime deps (modelscope, torch, torchaudio)

Optional components:
- ffmpeg (audio conversion/playback helper)
"""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from pathlib import Path


def find_first_executable(names: list[str]) -> str | None:
    for name in names:
        path = shutil.which(name)
        if path:
            return path
    return None


def python_module_available(module_name: str) -> bool:
    command = [
        sys.executable,
        "-c",
        (
            "import importlib.util,sys;"
            f"sys.exit(0 if importlib.util.find_spec('{module_name}') else 1)"
        ),
    ]
    result = subprocess.run(command, check=False)
    return result.returncode == 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Return non-zero when required components are missing.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    root = Path(__file__).resolve().parents[1]
    cosy_script = root / "scripts" / "cosyvoice_tts.py"

    whisper_path = find_first_executable(["whisper-cli", "main"])
    ffmpeg_path = find_first_executable(["ffmpeg"])
    modelscope_ready = python_module_available("modelscope")
    torch_ready = python_module_available("torch")
    torchaudio_ready = python_module_available("torchaudio")

    missing_required: list[str] = []
    if not whisper_path:
        missing_required.append("whisper.cpp CLI (whisper-cli/main)")
    if not modelscope_ready:
        missing_required.append("Python module: modelscope")
    if not torch_ready:
        missing_required.append("Python module: torch")
    if not torchaudio_ready:
        missing_required.append("Python module: torchaudio")
    if not cosy_script.is_file():
        missing_required.append(f"Missing bridge script: {cosy_script}")

    print("Voice stack check:")
    print(f"- STT whisper.cpp: {'OK' if whisper_path else 'MISSING'}")
    if whisper_path:
        print(f"  path: {whisper_path}")

    print(
        "- TTS CosyVoice modules: "
        f"{'OK' if (modelscope_ready and torch_ready and torchaudio_ready) else 'MISSING'}"
    )
    print(f"  modelscope: {'OK' if modelscope_ready else 'MISSING'}")
    print(f"  torch: {'OK' if torch_ready else 'MISSING'}")
    print(f"  torchaudio: {'OK' if torchaudio_ready else 'MISSING'}")
    print(f"- CosyVoice bridge script: {'OK' if cosy_script.is_file() else 'MISSING'}")
    print(f"- Optional ffmpeg: {'OK' if ffmpeg_path else 'MISSING'}")
    if ffmpeg_path:
        print(f"  path: {ffmpeg_path}")

    if missing_required:
        print("")
        print("Missing required components:")
        for item in missing_required:
            print(f"- {item}")
        print("")
        print("Suggested setup:")
        print("- Build/install whisper.cpp CLI and ensure it is in PATH.")
        print("- Install CosyVoice runtime dependencies into the current Python environment:")
        print("  pip install modelscope")
        print("  pip install torch torchaudio")
        return 1 if args.strict else 0

    print("")
    print("Offline voice stack is ready.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
