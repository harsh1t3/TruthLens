import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:onnxruntime/onnxruntime.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// On-device AI image classifier.
///
/// Wraps the Swin-Tiny `sdxl-detector` ONNX model (int8 quantized, ~91 MB)
/// originally trained on Wikimedia-vs-SDXL pairs.
///   - Input  : [1, 3, 224, 224] float32, ImageNet mean/std normalized.
///   - Output : [1, 2] logits, index 0 = "artificial", index 1 = "human".
///
/// The session is created lazily on the first call and kept alive for the
/// process. ORT requires `OrtEnv.instance.init()` once before any session.
class AiClassifierService {
  AiClassifierService._();
  static final instance = AiClassifierService._();

  OrtSession? _session;
  bool _envInited = false;
  Future<void>? _sessionFuture;

  /// ImageNet normalization.
  static const _mean = [0.485, 0.456, 0.406];
  static const _std = [0.229, 0.224, 0.225];
  static const _modelAsset = 'assets/models/ai_detector.onnx';

  /// Whether the model session is ready for inference.
  bool get isReady => _session != null;

  /// Fire-and-forget session preload. Safe to call multiple times — only the
  /// first call does any work. Call this once from splash/app startup so the
  /// 91 MB session-creation cost is paid in the background instead of
  /// blocking the user's first analysis.
  Future<void> warmUp() {
    _sessionFuture ??= _ensureSession();
    return _sessionFuture!;
  }

  Future<void> _ensureSession() async {
    if (_session != null) return;
    if (!_envInited) {
      OrtEnv.instance.init();
      _envInited = true;
    }

    // ORT needs the model bytes. Cache once to the app docs dir so we don't
    // re-extract from the asset bundle on every cold start.
    final docs = await getApplicationDocumentsDirectory();
    final modelFile = File(p.join(docs.path, 'ai_detector.onnx'));
    if (!await modelFile.exists()) {
      final data = await rootBundle.load(_modelAsset);
      await modelFile.writeAsBytes(data.buffer.asUint8List(), flush: true);
    }
    final bytes = await modelFile.readAsBytes();

    final opts = OrtSessionOptions()
      ..setIntraOpNumThreads(2)
      ..setInterOpNumThreads(1);
    // OrtSession.fromBuffer is synchronous and parses the graph on the
    // calling thread — that's why we want this called during splash, not
    // lazily on first analyze.
    _session = OrtSession.fromBuffer(bytes, opts);
  }

  /// Classify the given (already-decoded) image.
  ///
  /// Returns `{aiProbability, humanProbability}` — probabilities sum to 1.
  /// Throws if the model fails to load or inference errors out; callers
  /// should treat that as a soft failure and fall back to heuristic scores.
  Future<Map<String, double>> classify(img.Image src) async {
    await warmUp();
    final input = _preprocess(src);

    final tensor = OrtValueTensor.createTensorWithDataList(
      input,
      [1, 3, 224, 224],
    );
    final inputs = {'pixel_values': tensor};
    final runOpts = OrtRunOptions();

    List<OrtValue?>? outputs;
    try {
      outputs = await _session!.runAsync(runOpts, inputs);
    } finally {
      tensor.release();
      runOpts.release();
    }

    if (outputs == null || outputs.isEmpty || outputs.first == null) {
      throw StateError('ONNX model returned no output');
    }

    final raw = outputs.first!.value;
    outputs.first!.release();

    // ONNX gives a nested List<List<double>>: [[ai_logit, human_logit]].
    List<double> logits;
    if (raw is List<List<double>>) {
      logits = raw.first;
    } else if (raw is List<List<num>>) {
      logits = raw.first.map((e) => e.toDouble()).toList();
    } else if (raw is List<List<List<double>>>) {
      logits = raw.first.first;
    } else {
      throw StateError('Unexpected ONNX output shape: ${raw.runtimeType}');
    }

    final probs = _softmax(logits);
    return {
      'aiProbability': probs[0],
      'humanProbability': probs[1],
    };
  }

  /// Decode → resize 224×224 (bilinear) → ImageNet-normalize → NCHW float32.
  Float32List _preprocess(img.Image src) {
    final resized = img.copyResize(
      src,
      width: 224,
      height: 224,
      interpolation: img.Interpolation.linear,
    );
    final out = Float32List(1 * 3 * 224 * 224);
    final planeSize = 224 * 224;
    for (int y = 0; y < 224; y++) {
      for (int x = 0; x < 224; x++) {
        final px = resized.getPixel(x, y);
        final r = (px.r / 255.0 - _mean[0]) / _std[0];
        final g = (px.g / 255.0 - _mean[1]) / _std[1];
        final b = (px.b / 255.0 - _mean[2]) / _std[2];
        final i = y * 224 + x;
        out[0 * planeSize + i] = r;
        out[1 * planeSize + i] = g;
        out[2 * planeSize + i] = b;
      }
    }
    return out;
  }

  List<double> _softmax(List<double> xs) {
    final maxX = xs.reduce(math.max);
    final exps = xs.map((x) => math.exp(x - maxX)).toList();
    final sum = exps.reduce((a, b) => a + b);
    return exps.map((e) => e / sum).toList();
  }
}
