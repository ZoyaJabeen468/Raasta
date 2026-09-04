import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../models/hazard_type.dart';
import 'hazard_detector.dart';

/// Runs the M2+M5 YOLOv8n TFLite model (11 classes).
///
/// Classes: pothole, crack, speed_bump, person, cow, buffalo, dog, cat,
/// horse, donkey, goat.
///
/// Supports:
/// - Legacy NHWC `[1, H, W, 3]`
/// - Ultralytics LiteRT NCHW `[1, 3, H, W]`
class YoloM2Interpreter {
  YoloM2Interpreter();

  static const assetPath = 'assets/models/raasta_m2_m5.tflite';
  static const numClasses = 11;

  /// Phone-demo thresholds. Animals look alike in the model — keep them strict.
  /// Person is strict too: laptop-screen / room clutter often false-triggers.
  static const confThreshold = 0.32;
  static const speedBumpThreshold = 0.42;
  static const personThreshold = 0.58;
  static const animalThreshold = 0.68;
  static const iouThreshold = 0.45;
  /// Keep the lower portion of the frame (road ahead). Top sky / ceiling
  /// often causes false person/animal hits indoors and on laptop demos.
  static const lowerRoiFraction = 0.68;
  static const maxBoxAreaFraction = 0.70;

  static bool isAnimal(HazardType type) {
    return type == HazardType.cow ||
        type == HazardType.buffalo ||
        type == HazardType.dog ||
        type == HazardType.cat ||
        type == HazardType.horse ||
        type == HazardType.donkey ||
        type == HazardType.goat;
  }

  static double thresholdFor(HazardType type) {
    if (type == HazardType.speedBump) return speedBumpThreshold;
    if (isAnimal(type)) return animalThreshold;
    if (type == HazardType.person) return personThreshold;
    return confThreshold; // pothole / crack
  }

  Interpreter? _interpreter;
  bool _ready = false;
  bool _nchw = false;
  int _inputSize = 640;
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
      // 1 thread: less CPU fight with the camera pipeline on mid-range phones.
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
      debugPrint('YoloM2 $lastDebug');
      return true;
    } catch (e, st) {
      lastDebug = 'load failed: $e';
      debugPrint('YoloM2Interpreter load failed: $e\n$st');
      _ready = false;
      return false;
    }
  }

  List<HazardDetection> detect(img.Image rgb) {
    final interpreter = _interpreter;
    if (interpreter == null || !_ready) return const [];

    try {
      final roi = _lowerRoi(rgb);
      final letterboxed = _letterbox(roi.image, _inputSize);
      final flatIn = _packInput(letterboxed.image);

      final inputNested = flatIn.reshape<double>(_inShape);
      final outElements = _outShape.fold<int>(1, (a, b) => a * b);
      final flatOut = List<double>.filled(outElements, 0.0);
      final outputNested = flatOut.reshape<double>(_outShape);

      interpreter.run(inputNested, outputNested);

      final output = Float32List(outElements);
      _flattenDoubles(outputNested, output, 0);

      var absSum = 0.0;
      for (final v in output) {
        absSum += v.abs();
      }
      lastDebug = 'outSum=${absSum.toStringAsFixed(2)} n=${output.length}';

      final raw = _parseYoloOutput(
        output,
        gain: letterboxed.gain,
        padX: letterboxed.padX,
        padY: letterboxed.padY,
        roiOffsetY: roi.offsetY,
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
      debugPrint('YoloM2 detect failed: $e\n$st');
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

  _Roi _lowerRoi(img.Image src) {
    if (lowerRoiFraction >= 0.999) {
      return _Roi(image: src, offsetY: 0);
    }
    final h = src.height;
    final y0 = (h * (1.0 - lowerRoiFraction)).floor().clamp(0, h - 1);
    final crop = img.copyCrop(
      src,
      x: 0,
      y: y0,
      width: src.width,
      height: h - y0,
    );
    return _Roi(image: crop, offsetY: y0);
  }

  _Letterbox _letterbox(img.Image src, int size) {
    final scale = math.min(size / src.width, size / src.height);
    final nw = (src.width * scale).round().clamp(1, size);
    final nh = (src.height * scale).round().clamp(1, size);
    final resized = img.copyResize(
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
    required int roiOffsetY,
    required int frameW,
    required int frameH,
  }) {
    if (_outShape.length < 3) {
      lastDebug = 'bad out shape $_outShape';
      return const [];
    }

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
      y1 += roiOffsetY;
      y2 += roiOffsetY;

      x1 = x1.clamp(0, frameW - 1.0);
      x2 = x2.clamp(0, frameW - 1.0);
      y1 = y1.clamp(0, frameH - 1.0);
      y2 = y2.clamp(0, frameH - 1.0);
      if (x2 - x1 < 2 || y2 - y1 < 2) continue;

      final type = HazardType.fromClassId(bestCls);
      if (bestScore < thresholdFor(type)) continue;

      final boxArea = (x2 - x1) * (y2 - y1);
      final frameArea = frameW * frameH;
      if (frameArea > 0 && boxArea / frameArea > maxBoxAreaFraction) {
        continue;
      }

      dets.add(
        _Det(
          type: type,
          confidence: bestScore,
          x1: x1,
          y1: y1,
          x2: x2,
          y2: y2,
        ),
      );
    }

    lastPeakScore = peak;
    lastPeakLabel = (peakCls >= 0 && peakCls < HazardType.classLabels.length)
        ? HazardType.classLabels[peakCls]
        : '-';
    return dets;
  }

  List<HazardDetection> _nms(
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
        if (dets[i].type != dets[j].type) continue;
        if (_iou(dets[i], dets[j]) > iouThreshold) suppressed[j] = true;
      }
    }
    return [
      for (final d in kept)
        HazardDetection(
          type: d.type,
          confidence: d.confidence,
          distanceMeters: _estimateDistanceMeters(d, frameW, frameH),
          left: (d.x1 / frameW).clamp(0.0, 1.0),
          top: (d.y1 / frameH).clamp(0.0, 1.0),
          right: (d.x2 / frameW).clamp(0.0, 1.0),
          bottom: (d.y2 / frameH).clamp(0.0, 1.0),
        ),
    ];
  }

  double _estimateDistanceMeters(_Det d, double frameW, double frameH) {
    final boxW = math.max(1.0, d.x2 - d.x1);
    final boxH = math.max(1.0, d.y2 - d.y1);
    final areaFrac = (boxW * boxH) / math.max(1.0, frameW * frameH);
    final cy = ((d.y1 + d.y2) / 2).clamp(0.0, frameH);
    final yNorm = frameH <= 0 ? 0.5 : cy / frameH;

    // Road-damage photos on a laptop fill the frame but mean "ahead", not
    // "under the bumper". Prefer a driver-style distance band for demos.
    final isRoadSurface = d.type == HazardType.pothole ||
        d.type == HazardType.crack ||
        d.type == HazardType.speedBump;
    if (isRoadSurface && areaFrac > 0.10) {
      // Large on-screen hazard → still announce as ahead (FYP demo friendly).
      return 80;
    }

    final realWidthM = switch (d.type) {
      HazardType.pothole => 0.9,
      HazardType.speedBump => 2.4,
      HazardType.crack => 1.6,
      HazardType.person => 0.55,
      HazardType.cow => 1.8,
      HazardType.buffalo => 2.0,
      HazardType.dog => 0.5,
      HazardType.cat => 0.3,
      HazardType.horse => 1.6,
      HazardType.donkey => 1.3,
      HazardType.goat => 0.7,
      HazardType.roadSign => 0.7,
      HazardType.wrongWay => 1.0,
    };

    const fovRad = 70 * math.pi / 180;
    final focalPx = (frameW / 2) / math.tan(fovRad / 2);
    final sizeBased = realWidthM * focalPx / boxW;
    final posBased = 40 + (1.0 - yNorm) * 80;
    final sizeWeight = areaFrac > 0.02 ? 0.55 : 0.35;
    var meters = sizeWeight * sizeBased + (1 - sizeWeight) * posBased;
    meters = meters.clamp(20.0, 120.0);
    return ((meters / 10).round() * 10).toDouble();
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

class _Roi {
  const _Roi({required this.image, required this.offsetY});
  final img.Image image;
  final int offsetY;
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
    required this.type,
    required this.confidence,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
  });
  final HazardType type;
  final double confidence;
  final double x1, y1, x2, y2;
  double get area => math.max(0, x2 - x1) * math.max(0, y2 - y1);
}
