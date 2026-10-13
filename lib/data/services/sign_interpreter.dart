import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../models/traffic_sign.dart';

/// One decoded sign from a single frame.
class SignDetection {
  const SignDetection({
    required this.sign,
    required this.confidence,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.at,
  });

  final TrafficSign sign;
  final double confidence;

  /// Normalized box in the full camera frame (0–1).
  final double left;
  final double top;
  final double right;
  final double bottom;

  final DateTime at;
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
  SignInterpreter();

  static const assetPath = 'assets/models/raasta_signs.tflite';
  static const numClasses = TrafficSign.numClasses;

  static const confThreshold = 0.5;
  static const iouThreshold = 0.45;

  /// Real signs are small in frame; a box this large is almost always a
  /// close-up false positive (dashboard, hand, wall).
  static const maxBoxAreaFraction = 0.60;

  Interpreter? _interpreter;
  bool _ready = false;
  bool _nchw = false;
  int _inputSize = 320;
  List<int> _inShape = const [];
  List<int> _outShape = const [];

  double lastPeakScore = 0;
  String lastPeakLabel = '-';
  String lastDebug = 'not run';

  bool get isReady => _ready;
  int get inputSize => _inputSize;

  Future<bool> load() async {
    if (_ready) return true;
    if (kIsWeb) return false;
    try {
      final options = InterpreterOptions()..threads = 1;
      _interpreter = await Interpreter.fromAsset(assetPath, options: options);
      _interpreter!.allocateTensors();
      _inShape = List<int>.from(_interpreter!.getInputTensor(0).shape);
      _outShape = List<int>.from(_interpreter!.getOutputTensor(0).shape);
      _nchw = _inShape.length == 4 && _inShape[1] == 3;
      if (_nchw) {
        _inputSize = _inShape[2];
      } else if (_inShape.length == 4) {
        _inputSize = _inShape[1];
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

  /// Returns NMS-filtered detections at or above [confThreshold].
  List<SignDetection> detect(img.Image rgb) {
    final interpreter = _interpreter;
    if (interpreter == null || !_ready) return const [];

    try {
      final letterboxed = _letterbox(rgb, _inputSize);
      final flatIn = _packInput(letterboxed.image);

      final inputNested = flatIn.reshape<double>(_inShape);
      final outElements = _outShape.fold<int>(1, (a, b) => a * b);
      final flatOut = List<double>.filled(outElements, 0.0);
      final outputNested = flatOut.reshape<double>(_outShape);

      interpreter.run(inputNested, outputNested);

      final output = Float32List(outElements);
      _flattenDoubles(outputNested, output, 0);

      final raw = _parseYoloOutput(
        output,
        gain: letterboxed.gain,
        padX: letterboxed.padX,
        padY: letterboxed.padY,
        frameW: rgb.width,
        frameH: rgb.height,
      );
      return _nms(
        raw,
        frameW: rgb.width.toDouble(),
        frameH: rgb.height.toDouble(),
      );
    } catch (e, st) {
      lastDebug = 'detect error: $e';
      debugPrint('SignInterpreter detect failed: $e\n$st');
      return const [];
    }
  }

  void close() {
    _interpreter?.close();
    _interpreter = null;
    _ready = false;
  }

  Float32List _packInput(img.Image image) {
    final size = _inputSize;
    final floats = Float32List(1 * 3 * size * size);
    if (_nchw) {
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

  _Letterbox _letterbox(img.Image src, int size) {
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
    if (_outShape.length < 3) {
      lastDebug = 'bad out shape $_outShape';
      return const [];
    }

    // YOLOv8 head: [1, 4 + C, anchors] (default) or [1, anchors, 4 + C].
    final d1 = _outShape[1];
    final d2 = _outShape[2];
    final channelsFirst = d1 == 4 + numClasses;
    final channels = channelsFirst ? d1 : d2;
    final anchors = channelsFirst ? d2 : d1;

    if (channels != 4 + numClasses) {
      lastDebug = 'bad channels=$channels shape=$_outShape';
      return const [];
    }

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
      for (var c = 0; c < numClasses; c++) {
        final s = at(4 + c, i);
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
      if (frameArea > 0 && boxArea / frameArea > maxBoxAreaFraction) {
        continue;
      }

      final sign = TrafficSign.fromClassId(bestCls);
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
    lastPeakLabel = TrafficSign.fromClassId(peakCls)?.classLabel ?? '-';
    lastDebug = 'peak=${peak.toStringAsFixed(2)} ($lastPeakLabel) '
        'raw=${dets.length}';
    return dets;
  }

  List<SignDetection> _nms(
    List<_Det> dets, {
    required double frameW,
    required double frameH,
  }) {
    dets.sort((a, b) => b.confidence.compareTo(a.confidence));
    final kept = <_Det>[];
    final suppressed = List<bool>.filled(dets.length, false);
    for (var i = 0; i < dets.length; i++) {
      if (suppressed[i]) continue;
      kept.add(dets[i]);
      for (var j = i + 1; j < dets.length; j++) {
        if (suppressed[j]) continue;
        if (dets[i].sign != dets[j].sign) continue;
        if (_iou(dets[i], dets[j]) > iouThreshold) suppressed[j] = true;
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
