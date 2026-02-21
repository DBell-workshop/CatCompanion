#!/usr/bin/env python3
"""
Generate speech audio with CosyVoice using ModelScope AutoModel.

This script is designed to be called by CatCompanion app.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--text", required=True, help="Input text to synthesize.")
    parser.add_argument("--output", required=True, help="Output wav path.")
    parser.add_argument(
        "--model",
        default="iic/CosyVoice2-0.5B",
        help="Model ID or local model path (default: iic/CosyVoice2-0.5B).",
    )
    parser.add_argument(
        "--speaker",
        default="",
        help="Speaker name for inference_sft. If empty, the first available speaker will be used.",
    )
    return parser.parse_args()


def fail(message: str) -> int:
    print(message, file=sys.stderr)
    return 1


def resolve_speaker(requested: str, available: list[str]) -> str:
    if not available:
        raise RuntimeError("no_available_speaker")
    if requested and requested in available:
        return requested
    if requested and requested not in available:
        raise RuntimeError(f"speaker_not_found:{requested}")
    return available[0]


def main() -> int:
    args = parse_args()

    output_path = Path(args.output).expanduser().resolve()
    output_path.parent.mkdir(parents=True, exist_ok=True)

    text = args.text.strip()
    if not text:
        return fail("empty_text")

    try:
        import torch
        import torchaudio
        from modelscope import AutoModel
    except Exception as exc:  # pylint: disable=broad-except
        return fail(f"dependency_error:{exc}")

    try:
        model = AutoModel(
            model=args.model,
            trust_remote_code=True,
            disable_update=True,
        )
    except Exception as exc:  # pylint: disable=broad-except
        return fail(f"model_init_error:{exc}")

    if not hasattr(model, "list_available_spks"):
        return fail("model_missing_list_available_spks")
    if not hasattr(model, "inference_sft"):
        return fail("model_missing_inference_sft")

    try:
        speakers = list(model.list_available_spks())
    except Exception as exc:  # pylint: disable=broad-except
        return fail(f"speaker_list_error:{exc}")

    try:
        speaker = resolve_speaker(args.speaker.strip(), speakers)
    except Exception as exc:  # pylint: disable=broad-except
        return fail(str(exc))

    chunks = []
    sample_rate = int(getattr(model, "sample_rate", 22050))

    try:
        for item in model.inference_sft(text, speaker, stream=False):
            speech = item.get("tts_speech")
            if speech is None:
                continue
            if isinstance(speech, torch.Tensor):
                tensor = speech
            else:
                tensor = torch.tensor(speech)
            if tensor.dim() == 1:
                tensor = tensor.unsqueeze(0)
            chunks.append(tensor.detach().cpu())
    except Exception as exc:  # pylint: disable=broad-except
        return fail(f"inference_error:{exc}")

    if not chunks:
        return fail("empty_audio")

    wav = torch.cat(chunks, dim=-1)

    try:
        torchaudio.save(str(output_path), wav, sample_rate)
    except Exception as exc:  # pylint: disable=broad-except
        return fail(f"save_error:{exc}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
