import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:onnxruntime/onnxruntime.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Status of the classifier session.
///   - [warming]  : not yet attempted or in progress
///   - [ready]    : session is live, inference will run
///   - [failed]   : session creation failed; [error] explains why
enum ClassifierStatus { warming, ready, failed }

/// On-device AI image classifier.
///
/// Wraps the Swin-Tiny `sdxl-detector` ONNX model (int8 quantized, ~91 MB)
/// originally trained on Wikimedia-vs-SDXL pairs.
///   - Input  : [1, 3, 224, 224] float32, ImageNet mean/std normalized.
///   - Output : [1, 2] logits, index 0 = "artificial", index 1 = "human".
class AiClassifierService {
  AiClassifierService._();
  static final instance = AiClassifierService._();

  OrtSession? _session;
  bool _envInited = false;
  Future<void>? _sessionFuture;

  ClassifierStatus _status = ClassifierStatus.warming;
  String? _error;
  String? _lastOutputType;

  /// Public diagnostics — read these from UI to surface state to the user.
  ClassifierStatus get status => _status;
  String? get error => _error;
  String? get lastOutputType => _lastOutputType;
  bool get isReady => _status == ClassifierStatus.ready;

  /// ImageNet normalization.
  static const _mean = [0.485, 0.456, 0.406];
  static const _std = [0.229, 0.224, 0.225];
  static const _modelAsset = 'assets/models/ai_detector.onnx';

  Future<void> warmUp() {
    _sessionFuture ??= _ensureSession();
    return _sessionFuture!;
  }

  Future<void> _ensureSession() async {
    if (_session != null) return;
    try {
      if (!_envInited) {
        debugPrint('[ai-classifier] initializing OrtEnv');
        OrtEnv.instance.init();
        _envInited = true;
      }

      final docs = await getApplicationDocumentsDirectory();
      final modelFile = File(p.join(docs.path, 'ai_detector.onnx'));
      if (!await modelFile.exists()) {
        debugPrint('[ai-classifier] extracting model from asset bundle');
        final data = await rootBundle.load(_modelAsset);
        await modelFile.writeAsBytes(data.buffer.asUint8List(), flush: true);
      }
      final bytes = await modelFile.readAsBytes();
      debugPrint('[ai-classifier] model bytes loaded: ${bytes.length}');

      final opts = OrtSessionOptions()
        ..setIntraOpNumThreads(2)
        ..setInterOpNumThreads(1);
      _session = OrtSession.fromBuffer(bytes, opts);
      _status = ClassifierStatus.ready;
      debugPrint('[ai-classifier] session ready');
    } catch (e, st) {
      _status = ClassifierStatus.failed;
      _error = e.toString();
      debugPrint('[ai-classifier] session init FAILED: $e\n$st');
    }
  }

  /// Classify the given (already-decoded) image.
  ///
  /// Returns `{aiProbability, humanProbability}` — probabilities sum to 1.
  /// Throws with a descriptive message when anything goes wrong. Callers
  /// should catch and propagate the message to the UI.
  Future<Map<String, double>> classify(img.Image src) async {
    await warmUp();
    if (_session == null) {
      throw StateError('Classifier session unavailable: ${_error ?? "unknown"}');
    }
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
    } catch (e) {
      _error = 'runAsync threw: $e';
      debugPrint('[ai-classifier] $_error');
      rethrow;
    } finally {
      tensor.release();
      runOpts.release();
    }

    if (outputs == null || outputs.isEmpty || outputs.first == null) {
      throw StateError('ONNX model returned no output');
    }

    final raw = outputs.first!.value;
    outputs.first!.release();
    _lastOutputType = raw.runtimeType.toString();
    debugPrint('[ai-classifier] raw output type: $_lastOutputType');

    final logits = _flattenToDoubles(raw);
    if (logits.length != 2) {
      throw StateError(
        'Expected 2 logits, got ${logits.length} from $_lastOutputType',
      );
    }
    debugPrint('[ai-classifier] logits: $logits');

    final probs = _softmax(logits);
    return {
      'aiProbability': probs[0],
      'humanProbability': probs[1],
    };
  }

  /// Walk a nested list/tensor of any depth and extract numeric leaves into a
  /// flat List<double>. Handles every shape the onnxruntime plugin might
  /// return: nested Lists, Float32List, Iterable<dynamic>, etc.
  List<double> _flattenToDoubles(Object? node) {
    final out = <double>[];
    void walk(Object? v) {
      if (v == null) return;
      if (v is num) {
        out.add(v.toDouble());
      } else if (v is List) {
        for (final e in v) {
          walk(e);
        }
      } else if (v is Iterable) {
        for (final e in v) {
          walk(e);
        }
      }
    }
    walk(node);
    return out;
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
