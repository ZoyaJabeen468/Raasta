import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../models/sign_detection.dart';
import '../models/traffic_sign.dart';

export '../models/sign_detection.dart';

/// Letterboxed model input plus the mapping back to the camera frame.
/// Plain data, so it can be built in a background isolate.
class SignPreparedFrame {
  const SignPreparedFrame({
    required this.flatIn,
    required this.gain,
    required this.padX,
    required this.padY,
    required this.frameW,
    required this.frameH,
  });
  final Float32List flatIn;
  final double gain;
  final double padX;
  final double padY;
  final int frameW;
  final int frameH;
}

/// Runs the M3 traffic-sign YOLOv8n TFLite model (24 classes, see
/// [TrafficSign] for the class order).
///
/// Uses the full frame: signs and lights sit high in the image, so the
/// lower-ROI crop used for road hazards would cut them off.
///
/// Supports:
/// - Legacy NHWC `[1, H, W, 3]`
/// - Ultralytics LiteRT NCHW `[1, 3, H, W]`
class SignInterpreter {
  /// [stillImage] is for picked photos (Sign test screen): close-ups and
  /// any position in the picture are allowed, unlike the live camera.
  SignInterpreter({this.stillImage = false});

  final bool stillImage;

  static const assetPath = 'assets/models/raasta_signs.tflite';
  static const numClasses = TrafficSign.numClasses;

  static const confThreshold = 0.62;
  static const iouThreshold = 0.45;

  /// Real signs are small in frame; a box this large is almost always a
  /// close-up false positive (dashboard, hand, wall).
  static const maxBoxAreaFraction = 0.22;
  static const minBoxAreaFraction = 0.0006;

  static const _knownClassCounts = {22, 24};

  Interpreter? _interpreter;
  bool _ready = false;
  bool _nchw = false;
  int _inputSize = 320;
  List<int> _inShape = const [];
  List<int> _outShape = const [];

  /// Float32 in and out: pass raw bytes. Nested lists allocate per value
  /// and froze the UI thread for seconds on every sign check.
  bool _rawFloatIo = false;

  IsolateInterpreter? _runner;

  double lastPeakScore = 0;
  String lastPeakLabel = '-';
  String lastDebug = 'not run';

  bool get isReady => _ready;
  int get inputSize => _inputSize;
  bool get isNchw => _nchw;

  Future<bool> load() async {
    if (_ready) return true;
    if (kIsWeb) return false;
    try {
      final options = InterpreterOptions()..threads = 1;
      _interpreter = await Interpreter.fromAsset(assetPath, options: options);
      _interpreter!.allocateTensors();
      final inTensor = _interpreter!.getInputTensor(0);
      final outTensor = _interpreter!.getOutputTensor(0);
      _inShape = List<int>.from(inTensor.shape);
      _outShape = List<int>.from(outTensor.shape);
      _rawFloatIo = inTensor.type == TensorType.float32 &&
          outTensor.type == TensorType.float32;
      _nchw = _inShape.length == 4 && _inShape[1] == 3;
      if (_nchw) {
        _inputSize = _inShape[2];
      } else if (_inShape.length == 4) {
        _inputSize = _inShape[1];
      }
      if (_rawFloatIo) {
        try {
          _runner = await IsolateInterpreter.create(
            address: _interpreter!.address,
            debugName: 'raasta-signs',
          );
        } catch (e) {
          debugPrint('SignInterpreter background runner unavailable: $e');
          _runner = null;
        }
      }
      _ready = true;
      lastDebug =
          'loaded in=$_inShape out=$_outShape size=$_inputSize '
          '${_nchw ? "NCHW" : "NHWC"}';
      debugPrint('SignInterpreter $lastDebug');
      return true;
    } catch (e, st) {
      lastDebug = 'load failed: $e';
      debugPrint('SignInterpreter load failed: $e\n$st');
      _ready = false;
      return false;
    }
  }

  /// Letterbox and pack [rgb]. Pure function: safe in [Isolate.run].
  static SignPreparedFrame prepareFrame(img.Image rgb, int size, bool nchw) {
    final letterboxed = _letterbox(rgb, size);
    return SignPreparedFrame(
      flatIn: _packInput(letterboxed.image, size, nchw),
      gain: letterboxed.gain,
      padX: letterboxed.padX,
      padY: letterboxed.padY,
      frameW: rgb.width,
      frameH: rgb.height,
    );
  }

  /// Runs a frame built by [prepareFrame]. The network runs on a background
  /// isolate so the camera preview keeps painting.
  Future<List<SignDetection>> detectPrepared(SignPreparedFrame frame) async {
    final interpreter = _interpreter;
    if (interpreter == null || !_ready) return const [];
    final runner = _runner;
    if (runner == null || !_rawFloatIo) return _detectPacked(frame);

    try {
      final outElements = _outShape.fold<int>(1, (a, b) => a * b);
      final flatIn = frame.flatIn;
      await runner.run(
        flatIn.buffer.asUint8List(flatIn.offsetInBytes, flatIn.lengthInBytes),
        Uint8List(outElements * 4),
      );
      if (!_ready) return const [];
      final view = interpreter.getOutputTensor(0).data;
      final output =
          Uint8List.fromList(view).buffer.asFloat32List(0, outElements);
      return _decode(output, frame);
    } catch (e, st) {
      lastDebug = 'detect error: $e';
      debugPrint('SignInterpreter async detect failed: $e\n$st');
      return const [];
    }
  }

  /// Returns NMS-filtered detections at or above [confThreshold].
  List<SignDetection> detect(img.Image rgb) =>
      _detectPacked(prepareFrame(rgb, _inputSize, _nchw));

  List<SignDetection> _detectPacked(SignPreparedFrame frame) {
    final interpreter = _interpreter;
    if (interpreter == null || !_ready) return const [];

    try {
      final flatIn = frame.flatIn;
      final outElements = _outShape.fold<int>(1, (a, b) => a * b);
      final Float32List output;
      if (_rawFloatIo) {
        interpreter.run(
          flatIn.buffer.asUint8List(flatIn.offsetInBytes, flatIn.lengthInBytes),
          Uint8List(outElements * 4),
        );
        final view = interpreter.getOutputTensor(0).data;
        output = Uint8List.fromList(view).buffer.asFloat32List(0, outElements);
      } else {
        final inputNested = flatIn.reshape<double>(_inShape);
        final flatOut = List<double>.filled(outElements, 0.0);
        final outputNested = flatOut.reshape<double>(_outShape);
        interpreter.run(inputNested, outputNested);
        output = Float32List(outElements);
        _flattenDoubles(outputNested, output, 0);
      }
      return _decode(output, frame);
    } catch (e, st) {
      lastDebug = 'detect error: $e';
      debugPrint('SignInterpreter detect failed: $e\n$st');
      return const [];
    }
  }

  List<SignDetection> _decode(Float32List output, SignPreparedFrame frame) {
    final raw = _parseYoloOutput(
      output,
      gain: frame.gain,
      padX: frame.padX,
      padY: frame.padY,
      frameW: frame.frameW,
      frameH: frame.frameH,
    );
    if (raw.isEmpty) return const [];
    return _nms(
      raw,
      frameW: frame.frameW.toDouble(),
      frameH: frame.frameH.toDouble(),
    );
  }

  void close() {
    _ready = false;
    final runner = _runner;
    _runner = null;
    if (runner != null) unawaited(runner.close());
    _interpreter?.close();
    _interpreter = null;
  }

  static Float32List _packInput(img.Image image, int size, bool nchw) {
    final floats = Float32List(1 * 3 * size * size);
    if (nchw) {
      var ri = 0;
      var gi = size * size;
      var bi = 2 * size * size;
      for (var y = 0; y < size; y++) {
        for (var x = 0; x < size; x++) {
          final p = image.getPixel(x, y);
          floats[ri++] = p.r / 255.0;
          floats[gi++] = p.g / 255.0;
          floats[bi++] = p.b / 255.0;
        }
      }
    } else {
      var i = 0;
      for (var y = 0; y < size; y++) {
        for (var x = 0; x < size; x++) {
          final p = image.getPixel(x, y);
          floats[i++] = p.r / 255.0;
          floats[i++] = p.g / 255.0;
          floats[i++] = p.b / 255.0;
        }
      }
    }
    return floats;
  }

  int _flattenDoubles(dynamic node, Float32List out, int index) {
    if (node is num) {
      out[index] = node.toDouble();
      return index + 1;
    }
    if (node is List) {
      var i = index;
      for (final child in node) {
        i = _flattenDoubles(child, out, i);
      }
      return i;
    }
    return index;
  }

  static _Letterbox _letterbox(img.Image src, int size) {
    final scale = math.min(size / src.width, size / src.height);
    final nw = (src.width * scale).round().clamp(1, size);
    final nh = (src.height * scale).round().clamp(1, size);
    final resized = (nw == src.width && nh == src.height)
        ? src
        : img.copyResize(
            src,
            width: nw,
            height: nh,
            interpolation: img.Interpolation.linear,
          );
    final canvas = img.Image(width: size, height: size);
    img.fill(canvas, color: img.ColorRgb8(114, 114, 114));
    final dx = ((size - nw) / 2).round();
    final dy = ((size - nh) / 2).round();
    img.compositeImage(canvas, resized, dstX: dx, dstY: dy);
    return _Letterbox(
      image: canvas,
      gain: scale,
      padX: dx.toDouble(),
      padY: dy.toDouble(),
    );
  }

  List<_Det> _parseYoloOutput(
    Float32List output, {
    required double gain,
    required double padX,
    required double padY,
    required int frameW,
    required int frameH,
  }) {
    final dims = _outShape.where((d) => d > 1).toList();
    if (dims.length < 2) {
      lastDebug = 'bad out shape $_outShape';
      return <_Det>[];
    }

    // YOLOv8 head: [1, 4 + C, anchors] (default) or [1, anchors, 4 + C].
    // Some LiteRT exports squeeze the batch dim to [4 + C, anchors].
    final d1 = dims[dims.length - 2];
    final d2 = dims[dims.length - 1];
    var classCount = 0;
    var hasObjectness = false;
    var channelsFirst = false;
    for (final n in _knownClassCounts) {
      if (d1 == 4 + n || d1 == 5 + n) {
        classCount = n;
        hasObjectness = d1 == 5 + n;
        channelsFirst = true;
        break;
      }
      if (d2 == 4 + n || d2 == 5 + n) {
        classCount = n;
        hasObjectness = d2 == 5 + n;
        channelsFirst = false;
        break;
      }
    }
    if (classCount < 1) {
      lastDebug = 'bad channels d1=$d1 d2=$d2 shape=$_outShape';
      return <_Det>[];
    }
    final channels = hasObjectness ? 5 + classCount : 4 + classCount;
    final anchors = channelsFirst ? d2 : d1;

    double at(int c, int a) {
      final index = channelsFirst ? (c * anchors + a) : (a * channels + c);
      return output[index];
    }

    var peak = 0.0;
    var peakCls = -1;
    final dets = <_Det>[];
    final frameArea = frameW * frameH;

    for (var i = 0; i < anchors; i++) {
      var bestCls = 0;
      var bestScore = -1.0;
      final obj = hasObjectness ? _probability(at(4, i)) : 1.0;
      final scoreOffset = hasObjectness ? 5 : 4;
      for (var c = 0; c < classCount; c++) {
        final s = _probability(at(scoreOffset + c, i)) * obj;
        if (s > bestScore) {
          bestScore = s;
          bestCls = c;
        }
      }
      if (bestScore > peak) {
        peak = bestScore;
        peakCls = bestCls;
      }
      if (bestScore < confThreshold) continue;

      var cx = at(0, i);
      var cy = at(1, i);
      var w = at(2, i);
      var h = at(3, i);

      // Ultralytics TFLite exports normalized xywh; older exports use pixels.
      if (cx <= 1.5 && cy <= 1.5 && w <= 1.5 && h <= 1.5) {
        cx *= _inputSize;
        cy *= _inputSize;
        w *= _inputSize;
        h *= _inputSize;
      }

      var x1 = (cx - w / 2 - padX) / gain;
      var y1 = (cy - h / 2 - padY) / gain;
      var x2 = (cx + w / 2 - padX) / gain;
      var y2 = (cy + h / 2 - padY) / gain;

      x1 = x1.clamp(0, frameW - 1.0);
      x2 = x2.clamp(0, frameW - 1.0);
      y1 = y1.clamp(0, frameH - 1.0);
      y2 = y2.clamp(0, frameH - 1.0);
      if (x2 - x1 < 2 || y2 - y1 < 2) continue;

      final boxArea = (x2 - x1) * (y2 - y1);
      if (frameArea <= 0) continue;
      final areaFrac = boxArea / frameArea;
      if (areaFrac < minBoxAreaFraction) continue;
      if (!stillImage) {
        if (areaFrac > maxBoxAreaFraction) continue;
        final centerY = ((y1 + y2) / 2) / frameH;
        if (centerY < 0.04 || centerY > 0.78) continue;
      }

      final sign = TrafficSign.fromModel(bestCls, classCount);
      if (sign == null) continue;

      dets.add(
        _Det(
          sign: sign,
          confidence: bestScore,
          x1: x1,
          y1: y1,
          x2: x2,
          y2: y2,
        ),
      );
    }

    lastPeakScore = peak;
    lastPeakLabel =
        TrafficSign.fromModel(peakCls, classCount)?.classLabel ?? '-';
    lastDebug = 'peak=${peak.toStringAsFixed(2)} ($lastPeakLabel) '
        'raw=${dets.length} shape=$_outShape C=$classCount';
    return dets;
  }

  List<SignDetection> _nms(
    List<_Det> dets, {
    required double frameW,
    required double frameH,
  }) {
    if (dets.isEmpty) return const [];
    final ranked = List<_Det>.of(dets)
      ..sort((a, b) => b.confidence.compareTo(a.confidence));
    final kept = <_Det>[];
    final suppressed = List<bool>.filled(ranked.length, false);
    for (var i = 0; i < ranked.length; i++) {
      if (suppressed[i]) continue;
      kept.add(ranked[i]);
      for (var j = i + 1; j < ranked.length; j++) {
        if (suppressed[j]) continue;
        if (ranked[i].sign != ranked[j].sign) continue;
        if (_iou(ranked[i], ranked[j]) > iouThreshold) suppressed[j] = true;
      }
    }
    final now = DateTime.now();
    return [
      for (final d in kept)
        SignDetection(
          sign: d.sign,
          confidence: d.confidence,
          left: (d.x1 / frameW).clamp(0.0, 1.0),
          top: (d.y1 / frameH).clamp(0.0, 1.0),
          right: (d.x2 / frameW).clamp(0.0, 1.0),
          bottom: (d.y2 / frameH).clamp(0.0, 1.0),
          at: now,
        ),
    ];
  }

  double _iou(_Det a, _Det b) {
    final x1 = math.max(a.x1, b.x1);
    final y1 = math.max(a.y1, b.y1);
    final x2 = math.min(a.x2, b.x2);
    final y2 = math.min(a.y2, b.y2);
    final inter = math.max(0, x2 - x1) * math.max(0, y2 - y1);
    final union = a.area + b.area - inter;
    return union <= 0 ? 0 : inter / union;
  }

  /// Class scores are probabilities in [0, 1]. Some exports emit logits.
  double _probability(double raw) {
    if (raw.isNaN) return 0;
    if (raw >= 0 && raw <= 1) return raw;
    final x = raw.clamp(-12.0, 12.0);
    return 1 / (1 + math.exp(-x));
  }
}

class _Letterbox {
  const _Letterbox({
    required this.image,
    required this.gain,
    required this.padX,
    required this.padY,
  });
  final img.Image image;
  final double gain;
  final double padX;
  final double padY;
}

class _Det {
  const _Det({
    required this.sign,
    required this.confidence,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
  });
  final TrafficSign sign;
  final double confidence;
  final double x1, y1, x2, y2;
  double get area => math.max(0, x2 - x1) * math.max(0, y2 - y1);
}
