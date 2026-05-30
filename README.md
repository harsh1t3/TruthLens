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
- A breakdown of **four detectors**, each independent:

  | Detector | What it looks for |
  |---|---|
  | **Generator signature** | EXIF Software / Processing Software fields, PNG `tEXt` and `iTXt` chunks (Automatic1111 `parameters`, ComfyUI `prompt` / `workflow`), and known generator names — Midjourney, DALL-E, Stable Diffusion, Flux, Firefly, Imagen, Sora, Leonardo, Ideogram, Runway, and more. A direct hit names the tool. |
  | **C2PA provenance** | Detects whether the file carries a C2PA manifest — the JUMBF box in JPEG APP11 or the `caBX` chunk in PNG. Presence ≠ AI on its own, but C2PA without camera Make/Model is a soft AI lean. |
  | **Spectral fingerprint** | Subtracts a Gaussian blur from the luminance plane, then measures high-frequency residual per patch versus local contrast. Diffusion-decoded images suppress micro-texture in contentful regions — that's what this scores. |
  | **Compression coherence** | Gradient ratio across JPEG 8×8 block boundaries vs. block interiors. Reveals heavy or repeated compression. |
  | **Metadata integrity** | EXIF DateTime field consistency and missing Make/Model. Editor / generator software tags from any source raise the score sharply. |

The four detector scores are weighted into the final trust score:

```dart
trust = (100 - (aiSignal * 40 + spectral * 25 + metadata * 20 + compression * 15))
        .clamp(0.0, 100.0);
```

## Tech stack

| Concern | Choice |
|---|---|
| Framework | Flutter 3.41, Material 3, Impeller renderer |
| Storage | Hive 2 (`hive_flutter`) — schema v2 box `scans_v2` |
| Image processing | `image` package, pure Dart, run in a background isolate via `compute()` |
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
├── services/                              # All run as top-level functions
│   ├── generator_signature_service.dart   # EXIF + PNG chunk parser
│   ├── c2pa_service.dart                  # JUMBF / caBX detector
│   ├── spectral_service.dart              # high-freq residual analysis + heatmap
│   ├── metadata_service.dart              # EXIF integrity
│   ├── compression_service.dart           # 8-pixel block boundary ratio
│   └── analysis_orchestrator.dart         # runs all 5 in one isolate
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

### Isolate boundary

Image bytes go in, primitives + one heatmap PNG come out — no raw RGBA
buffers ever cross the isolate boundary. The image is decoded once,
downscaled to a 1024-px long edge, and shared across all five detectors
sequentially.

## Running locally

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run                       # connected Android device or emulator
```

Minimum Android SDK: API 21 (Lollipop). Permissions: CAMERA on first
capture; gallery uses the platform Photo Picker (no permission needed on
API 33+).

## Honest limitations

- **Generator signatures** are by far the strongest signal but only present
  when the producing tool didn't strip metadata (Midjourney and Adobe
  Firefly usually keep theirs; many forums and chat apps strip everything).
- **Spectral analysis** is a heuristic — a real photograph passed through a
  noise-reducing filter can score high; a high-fidelity GAN trained to
  preserve micro-texture can score low. Pair it with the other signals
  rather than reading it alone.
- **C2PA detection** here checks for *presence* of a manifest, not
  cryptographic validity — that requires the full C2PA SDK and trust list.
- The five animated step pills on the analysis screen are paced on a timer
  for UX; the orchestrator is one isolate call.

## License

Personal project.
