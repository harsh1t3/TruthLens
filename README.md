# TruthLens

> *Know what made your image.*

TruthLens is a **fully offline** Flutter app that decides whether a photo was
captured by a person, edited, or synthesized by an image generator. Every
analysis runs on the device — no uploads, no network calls, no API keys.

## What it does

Capture or pick an image and TruthLens returns:

- A **trust score** (0–100) and a verdict: **Authentic**, **AI-Generated**,
  **Edited**, or **Inconclusive**.
- A **spectral heatmap** highlighting regions whose frequency profile is
  inconsistent with natural photography.
- A breakdown of detectors, each independent:

  | Detector | What it looks for |
  |---|---|
  | **AI classifier** | On-device Swin Transformer (int8 quantized, ~91 MB) trained on real-photo vs SDXL pairs. Runs locally via ONNX Runtime. The dominant signal. |
  | **Generator signature** | EXIF Software / Processing Software fields, PNG `tEXt` and `iTXt` chunks (Automatic1111 `parameters`, ComfyUI `prompt` / `workflow`), and known generator names — Midjourney, DALL-E, Stable Diffusion, Flux, Firefly, Imagen, Sora, Leonardo, Ideogram, Runway, and more. A direct hit overrides the classifier. |
  | **C2PA provenance** | Detects whether the file carries a C2PA manifest — the JUMBF box in JPEG APP11 or the `caBX` chunk in PNG. Presence ≠ AI on its own, but C2PA without camera Make/Model is a soft AI lean. |
  | **Spectral fingerprint** | Subtracts a Gaussian blur from the luminance plane, then measures high-frequency residual per patch versus local contrast. Produces the per-region heatmap shown on the result screen. |
  | **Compression coherence** | Gradient ratio across JPEG 8×8 block boundaries vs. block interiors. |
  | **Metadata integrity** | EXIF DateTime field consistency and missing Make/Model. Editor / generator software tags raise the score sharply. |

The classifier-blended AI signal and the heuristics are weighted into the final trust score:

```dart
trust = (100 - (aiSignal * 55 + spectral * 12 + metadata * 18 + compression * 15))
        .clamp(0.0, 100.0);
```

## Tech stack

| Concern | Choice |
|---|---|
| Framework | Flutter 3.41, Material 3, Impeller renderer |
| Storage | Hive 2 (`hive_flutter`) — schema v2 box `scans_v2` |
| ML runtime | ONNX Runtime via `onnxruntime: ^1.4.1` (Android arm32/arm64) |
| Classifier | Swin-Tiny `Organika/sdxl-detector`, dynamic int8 quantization → ~91 MB |
| Heuristics | `image` package, pure Dart, run in a background isolate via `compute()` |
| Metadata | `exif` package + a hand-written PNG `tEXt`/`iTXt` parser |
| Pickers | `image_picker` (Photo Picker on Android 13+) |
| UI | Liquid-glass — `BackdropFilter(blur 22)` over ambient color blobs, hairline borders, refined typography |
| Typography | Google Fonts — Syne for display, Inter for body |

## Architecture

```
lib/
├── main.dart                              # Hive init, theme, entry
├── models/
│   └── scan_result.dart                   # @HiveType v2 record
├── services/
│   ├── ai_classifier_service.dart         # Swin-Tiny ONNX, main-thread async
│   ├── generator_signature_service.dart   # EXIF + PNG chunk parser
│   ├── c2pa_service.dart                  # JUMBF / caBX detector
│   ├── spectral_service.dart              # high-freq residual + heatmap
│   ├── metadata_service.dart              # EXIF integrity
│   ├── compression_service.dart           # 8-pixel block boundary ratio
│   └── analysis_orchestrator.dart         # classifier + heuristics in parallel
├── screens/
│   ├── splash_screen.dart
│   ├── home_screen.dart
│   ├── analysis_screen.dart
│   ├── result_screen.dart
│   └── history_screen.dart
├── widgets/
│   ├── ambient_background.dart            # warm neutral + 3 diffuse color blobs
│   ├── glass_card.dart                    # BackdropFilter-based glass surfaces
│   ├── trust_score_gauge.dart
│   ├── heatmap_overlay.dart
│   ├── scan_step_pill.dart
│   ├── result_breakdown_card.dart
│   └── history_tile.dart
└── utils/
    ├── color_utils.dart
    └── constants.dart
```

### Concurrency model

The classifier runs on the main thread via ONNX Runtime's `runAsync` (the
native session uses its own threads, so the UI stays responsive) while the
heuristics run in parallel inside a `compute()` isolate. Image bytes go in,
primitives + one heatmap PNG come out — no raw RGBA buffers ever cross the
isolate boundary.

## Running locally

The classifier model is too large to commit, so a one-time prepare step
downloads and quantizes it into `assets/models/`:

```bash
pip install onnx onnxruntime pillow numpy
python tools/model_prep/prepare_model.py    # ~340 MB download → ~91 MB int8

flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run                                 # connected Android device or emulator
```

Minimum Android SDK: API 21 (Lollipop). Permissions: CAMERA on first
capture; gallery uses the platform Photo Picker (no permission needed on
API 33+).

### Note on the `onnxruntime` Flutter plugin

The plugin's bindings call `DynamicLibrary.open("libonnxruntime.so")` via
FFI. On modern Android the app's native-lib directory is not always on
`dlopen`'s default search path, so two things are required for the
classifier to load on a real device:

1. `MainActivity` force-loads the lib via `System.loadLibrary("onnxruntime")`
   in a static initializer, before the Flutter engine starts. The JVM
   class loader always knows the app's native-lib dir, and once the
   symbol is in the process, the plugin's later FFI `dlopen` resolves
   from the in-memory linker cache.
2. The AndroidManifest carries `android:extractNativeLibs="true"` and
   `build.gradle.kts` opts into `useLegacyPackaging = true`. Together
   they force the installer to extract the libs to disk.

If your APK is built without (1), the classifier will silently fall
back to heuristics and obvious AI images will score 90+. Watch for the
red "AI detector unavailable" banner on home in that case.

### Running on an x86_64 emulator

The plugin ships native libs only for arm32 / arm64. To run the
classifier inside an x86_64 Android emulator, drop the matching
`libonnxruntime.so` from Microsoft's `onnxruntime-android-1.15.1.aar`
into `android/app/src/main/jniLibs/x86_64/`. That path is gitignored —
it's a dev convenience, no real-device build needs it.

## Measured behavior

Small sanity-check on the x86_64 emulator with the on-device classifier
loaded — six images, all picked through the Photo Picker:

| Image                            | Source           | Verdict             | Trust |
|----------------------------------|------------------|---------------------|-------|
| Astronaut riding horse           | Flux             | Likely AI-Generated | 43    |
| Red-haired portrait              | Flux             | Likely AI-Generated | 42    |
| Misty mountain landscape         | Flux             | Likely AI-Generated | 40    |
| Anime girl with cherry blossoms  | Flux             | Likely AI-Generated | 43    |
| Cyberpunk neon city              | Flux             | Likely Authentic ✗  | 98    |
| Coffee cup (2003 Sony Cybershot) | Real photo       | Likely Authentic    | 98    |

5 of 6 AI images flagged, real photo correctly authenticated. The
cyberpunk image is a known failure mode — photorealistic neon styles
mimic genuine photography too well for the classifier to disambiguate.

## Honest limitations

- **The classifier was fine-tuned on Wikimedia photos vs SDXL images.** It
  generalizes well to other diffusion outputs (DALL-E 3, Flux, Midjourney
  v6+) in practice but is biased toward the styles in its training set. New
  generators with unfamiliar fingerprints can slip through.
- **Int8 quantization** trades a few percentage points of accuracy for the
  4× size reduction. The full-precision float32 model is more accurate but
  weighs 337 MB.
- **C2PA detection** checks for *presence* of a manifest, not cryptographic
  validity — that requires the full C2PA SDK and trust list.
- The five animated step pills on the analysis screen are paced on a timer
  for UX; the orchestrator is two parallel paths, not five sequential steps.

## License

Personal project.
