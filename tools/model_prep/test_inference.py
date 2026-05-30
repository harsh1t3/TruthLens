"""Sanity-check the quantized model on local images.

Mirrors the exact preprocessing Flutter is doing:
  - resize 224x224 bilinear
  - /255 rescale
  - ImageNet mean/std normalize
  - NCHW float32

Reports softmax probabilities for each image.
"""
import sys
from pathlib import Path

import numpy as np
import onnxruntime as ort
from PIL import Image

MEAN = np.array([0.485, 0.456, 0.406], dtype=np.float32)
STD = np.array([0.229, 0.224, 0.225], dtype=np.float32)


def preprocess(path):
    im = Image.open(path).convert("RGB").resize((224, 224), Image.BILINEAR)
    arr = np.asarray(im, dtype=np.float32) / 255.0
    arr = (arr - MEAN) / STD
    arr = arr.transpose(2, 0, 1)[None, :, :, :].astype(np.float32)
    return arr


def softmax(x):
    e = np.exp(x - x.max())
    return e / e.sum()


def main():
    model_path = Path(__file__).parent / "model.int8.onnx"
    sess = ort.InferenceSession(str(model_path), providers=["CPUExecutionProvider"])
    input_name = sess.get_inputs()[0].name
    print(f"Input name: {input_name}")
    print(f"Input shape: {sess.get_inputs()[0].shape}")
    print(f"Output shape: {sess.get_outputs()[0].shape}")
    print()
    for path in sys.argv[1:]:
        x = preprocess(path)
        out = sess.run(None, {input_name: x})[0]
        probs = softmax(out[0])
        print(f"{path}")
        print(f"  raw logits      : {out[0].tolist()}")
        print(f"  P(artificial)   : {probs[0]:.4f}")
        print(f"  P(human/real)   : {probs[1]:.4f}")
        verdict = "AI-GENERATED" if probs[0] > probs[1] else "REAL"
        print(f"  VERDICT         : {verdict}")
        print()


if __name__ == "__main__":
    main()
