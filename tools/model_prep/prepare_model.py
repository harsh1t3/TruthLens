"""Fetch the AI detector ONNX from Hugging Face and dynamically quantize it
to int8 so the bundled APK stays under ~100 MB.

Run once before `flutter build`:
    python tools/model_prep/prepare_model.py

Output: assets/models/ai_detector.onnx (~91 MB).
"""
from __future__ import annotations

import urllib.request
from pathlib import Path

from onnxruntime.quantization import QuantType, quantize_dynamic

ROOT = Path(__file__).resolve().parents[2]
PREP_DIR = ROOT / "tools" / "model_prep"
ASSET_DIR = ROOT / "assets" / "models"

# Organika/sdxl-detector — Swin-Tiny fine-tuned on Wikimedia ↔ SDXL pairs.
# id2label: 0 = artificial, 1 = human.
MODEL_URL = (
    "https://huggingface.co/Organika/sdxl-detector/resolve/"
    "refs%2Fpr%2F3/onnx/model.onnx?download=true"
)
RAW = PREP_DIR / "model.onnx"
QUANT = PREP_DIR / "model.int8.onnx"
TARGET = ASSET_DIR / "ai_detector.onnx"


def _download(url: str, dst: Path) -> None:
    if dst.exists() and dst.stat().st_size > 100 * 1024 * 1024:
        print(f"[skip] {dst.name} already present ({dst.stat().st_size / 1e6:.1f} MB)")
        return
    print(f"[get ] {url}")
    with urllib.request.urlopen(url) as r, dst.open("wb") as f:
        while chunk := r.read(1 << 16):
            f.write(chunk)
    print(f"[ok  ] saved {dst} ({dst.stat().st_size / 1e6:.1f} MB)")


def main() -> None:
    PREP_DIR.mkdir(parents=True, exist_ok=True)
    ASSET_DIR.mkdir(parents=True, exist_ok=True)

    _download(MODEL_URL, RAW)

    if not QUANT.exists():
        print(f"[quant] dynamic int8 → {QUANT.name}")
        quantize_dynamic(
            model_input=str(RAW),
            model_output=str(QUANT),
            weight_type=QuantType.QUInt8,
            per_channel=False,
            reduce_range=False,
        )
    print(f"[ok   ] quantized: {QUANT.stat().st_size / 1e6:.1f} MB")

    TARGET.write_bytes(QUANT.read_bytes())
    print(f"[copy ] {TARGET}")


if __name__ == "__main__":
    main()
