import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../models/hazard_type.dart';
import 'hazard_detector.dart';

class YoloPreProcessResult {
  const YoloPreProcessResult({
    required this.flatIn,
    required this.frameW,
    required this.frameH,
    required this.roiOffsetY,
    required this.gain,
    required this.padX,
    required this.padY,
  });
  final Float32List flatIn;
  final int frameW;
  final int frameH;
  final int roiOffsetY;
  final double gain;
  final double padX;
  final double padY;
}

class YoloPostProcessData {
  const YoloPostProcessData({
    required this.output,
    required this.outShape,
    required this.frameW,
    required this.frameH,
    required this.roiOffsetY,
    required this.gain,
    required this.padX,
    required this.padY,
    required this.inputSize,
  });
  final Float32List output;
  final List<int> outShape;
  final int frameW;
  final int frameH;
  final int roiOffsetY;
  final double gain;
  final double padX;
  final double padY;
  final int inputSize;
}

class YoloPostProcessResult {
  const YoloPostProcessResult({
    required this.hits,
    required this.peakScore,
    required this.peakLabel,
  });
  final List<HazardDetection> hits;
  final double peakScore;
  final String peakLabel;
}

class _RawParseResult {
  const _RawParseResult(this.dets, this.peakScore, this.peakLabel);
  final List<_Det> dets;
  final double peakScore;
  final String peakLabel;
}

class YoloM2Interpreter {
  YoloM2Interpreter();

  static const assetPath = 'assets/models/raasta_m2_m5.tflite';
  static const numClasses = 11;

  static const confThreshold = 0.50;
  static const speedBumpThreshold = 0.55;
  static const personThreshold = 0.50;
  static const animalThreshold = 0.72;
  static const iouThreshold = 0.45;

  /// Full frame. Cropping the top used to shift boxes off the real object.
  static const lowerRoiFraction = 1.0;
  static const maxBoxAreaFraction = 0.55;
  static const minBoxAreaFraction = 0.004;

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
    return confThreshold; 
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
  bool get isNchw => _nchw;
  List<int> get outShape => _outShape;

  IsolateInterpreter? _isolateRunner;

  InterpreterOptions _options() {
    // Keep creation on the platform thread. A delegate created here and then
    // invoked from another isolate can abort the process on some phones.
    return InterpreterOptions()..threads = 2;
  }

  void _captureShapes() {
    final interpreter = _interpreter;
    if (interpreter == null) return;
    _inShape = List<int>.from(interpreter.getInputTensor(0).shape);
    _outShape = List<int>.from(interpreter.getOutputTensor(0).shape);
    _nchw = _inShape.length == 4 && _inShape[1] == 3;
    if (_nchw) {
      _inputSize = _inShape[2];
    } else if (_inShape.length == 4) {
      _inputSize = _inShape[1];
    }
  }

  Future<bool> load() async {
    if (_ready) return true;
    if (kIsWeb) return false;
    try {
      _interpreter = await Interpreter.fromAsset(assetPath, options: _options());
      _interpreter!.allocateTensors();
      _captureShapes();
      try {
        _isolateRunner = await IsolateInterpreter.create(
          address: _interpreter!.address,
          debugName: 'raasta-yolo',
        );
      } catch (e) {
        debugPrint('YoloM2 background runner unavailable: $e');
        _isolateRunner = null;
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

  /// Loads a model already read from assets. Safe inside a background isolate,
  /// where [Interpreter.fromAsset] cannot see the Flutter asset bundle.
  bool loadFromBytes(Uint8List bytes) {
    if (_ready) return true;
    try {
      _interpreter = Interpreter.fromBuffer(bytes, options: _options());
      _interpreter!.allocateTensors();
      _captureShapes();
      _ready = true;
      lastDebug =
          'loaded in=$_inShape out=$_outShape size=$_inputSize '
          '${_nchw ? "NCHW" : "NHWC"}';
      debugPrint('YoloM2 $lastDebug');
      return true;
    } catch (e, st) {
      lastDebug = 'load failed: $e';
      debugPrint('YoloM2Interpreter loadFromBytes failed: $e\n$st');
      _ready = false;
      return false;
    }
  }

  Float32List? runModel(Float32List flatIn) {
    final interpreter = _interpreter;
    if (interpreter == null || !_ready) return null;

    try {
      final prepared = _prepareRun(flatIn);
      interpreter.run(prepared.input, prepared.output);
      return _finishRun(prepared.output);
    } catch (e, st) {
      lastDebug = 'detect error: $e';
      debugPrint('YoloM2 detect failed: $e\n$st');
      return null;
    }
  }

  /// Runs the network off the UI isolate. The interpreter itself stays the one
  /// created on the platform thread.
  Future<Float32List?> runModelAsync(Float32List flatIn) async {
    final runner = _isolateRunner;
    if (runner == null || !_ready) return runModel(flatIn);
    try {
      final prepared = _prepareRun(flatIn);
      await runner.run(prepared.input, prepared.output);
      return _finishRun(prepared.output);
    } catch (e, st) {
      lastDebug = 'detect error: $e';
      debugPrint('YoloM2 async detect failed: $e\n$st');
      return null;
    }
  }

  ({Object input, Object output}) _prepareRun(Float32List flatIn) {
    final inputNested = flatIn.reshape<double>(_inShape);
    final outElements = _outShape.fold<int>(1, (a, b) => a * b);
    final flatOut = List<double>.filled(outElements, 0.0);
    final outputNested = flatOut.reshape<double>(_outShape);
    return (input: inputNested, output: outputNested);
  }

  Float32List _finishRun(Object outputNested) {
    final outElements = _outShape.fold<int>(1, (a, b) => a * b);
    final output = Float32List(outElements);
    _flattenDoubles(outputNested, output, 0);
    var absSum = 0.0;
    for (final v in output) {
      absSum += v.abs();
    }
    lastDebug = 'outSum=${absSum.toStringAsFixed(2)} n=${output.length}';
    return output;
  }

  void close() {
    final runner = _isolateRunner;
    _isolateRunner = null;
    if (runner != null) {
      unawaited(runner.close());
    }
    _interpreter?.close();
    _interpreter = null;
    _ready = false;
  }

  static YoloPreProcessResult preprocessStatic(img.Image rgb, int inputSize, bool isNchw) {
    final roi = _lowerRoi(rgb);
    final letterboxed = _letterbox(roi.image, inputSize);
    final flatIn = _packInput(letterboxed.image, inputSize, isNchw);

    return YoloPreProcessResult(
      flatIn: flatIn,
      frameW: rgb.width,
      frameH: rgb.height,
      roiOffsetY: roi.offsetY,
      gain: letterboxed.gain,
      padX: letterboxed.padX,
      padY: letterboxed.padY,
    );
  }

  static YoloPostProcessResult postprocessStatic(YoloPostProcessData data) {
    final raw = _parseYoloOutput(
      data.output,
      outShape: data.outShape,
      inputSize: data.inputSize,
      gain: data.gain,
      padX: data.padX,
      padY: data.padY,
      roiOffsetY: data.roiOffsetY,
      frameW: data.frameW,
      frameH: data.frameH,
    );
    final hits = _nms(
      raw.dets,
      frameW: data.frameW.toDouble(),
      frameH: data.frameH.toDouble(),
    );
    return YoloPostProcessResult(
      hits: hits,
      peakScore: raw.peakScore,
      peakLabel: raw.peakLabel,
    );
  }

  static Float32List _packInput(img.Image image, int size, bool isNchw) {
    final floats = Float32List(1 * 3 * size * size);
    if (isNchw) {
      var ri = 0;
      var gi = size * size;
      var bi = 2 * size * size;
      for (var y = 0; y < size; y++) {
        for (var x = 0; x < size; x++) {
          final p = image.getPixel(x, y);
          floats[ri++] = (p.r as num) / 255.0;
          floats[gi++] = (p.g as num) / 255.0;
          floats[bi++] = (p.b as num) / 255.0;
        }
      }
    } else {
      var i = 0;
      for (var y = 0; y < size; y++) {
        for (var x = 0; x < size; x++) {
          final p = image.getPixel(x, y);
          floats[i++] = (p.r as num) / 255.0;
          floats[i++] = (p.g as num) / 255.0;
          floats[i++] = (p.b as num) / 255.0;
        }
      }
    }
    return floats;
  }

  static int _flattenDoubles(dynamic node, Float32List out, int index) {
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

  static _Roi _lowerRoi(img.Image src) {
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

  static _Letterbox _letterbox(img.Image src, int size) {
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

  static _RawParseResult _parseYoloOutput(
    Float32List output, {
    required List<int> outShape,
    required int inputSize,
    required double gain,
    required double padX,
    required double padY,
    required int roiOffsetY,
    required int frameW,
    required int frameH,
  }) {
    if (outShape.length < 3) {
      return const _RawParseResult([], 0, '-');
    }

    final d1 = outShape[1];
    final d2 = outShape[2];
    final currentChannels = 4 + numClasses;
    const legacyChannels = 12;
    final channelsFirst = d1 == currentChannels || d1 == legacyChannels;
    final channelsLast = d2 == currentChannels || d2 == legacyChannels;
    if (!channelsFirst && !channelsLast) {
      return const _RawParseResult([], 0, '-');
    }
    final channels = channelsFirst ? d1 : d2;
    final anchors = channelsFirst ? d2 : d1;
    final classCount = channels - 4;

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
      for (var c = 0; c < classCount; c++) {
        final s = _probability(at(4 + c, i));
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
        cx *= inputSize;
        cy *= inputSize;
        w *= inputSize;
        h *= inputSize;
      }

      var x1 = (cx - w / 2 - padX) / gain;
      var y1 = (cy - h / 2 - padY) / gain;
      var x2 = (cx + w / 2 - padX) / gain;
      var y2 = (cy + h / 2 - padY) / gain;
      y1 += roiOffsetY;
      y2 += roiOffsetY;

      x1 = x1.clamp(0.0, frameW - 1.0);
      x2 = x2.clamp(0.0, frameW - 1.0);
      y1 = y1.clamp(0.0, frameH - 1.0);
      y2 = y2.clamp(0.0, frameH - 1.0);
      if (x2 - x1 < 2 || y2 - y1 < 2) continue;

      final type = _typeForClass(bestCls, classCount);
      if (type == null) continue;
      if (bestScore < thresholdFor(type)) continue;

      final boxArea = (x2 - x1) * (y2 - y1);
      final frameArea = frameW * frameH;
      if (frameArea <= 0) continue;
      final areaFrac = boxArea / frameArea;
      if (areaFrac > maxBoxAreaFraction || areaFrac < minBoxAreaFraction) {
        continue;
      }

      // Road damage on the sky/ceiling is a false positive. People and
      // animals can stand higher, but not in the top strip of the frame.
      final centerY = ((y1 + y2) / 2) / frameH;
      final road = type == HazardType.pothole ||
          type == HazardType.crack ||
          type == HazardType.speedBump;
      if (road && centerY < 0.38) continue;
      if (!road && centerY < 0.08) continue;

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

    final peakType = peakCls >= 0 ? _typeForClass(peakCls, classCount) : null;
    return _RawParseResult(dets, peak, peakType?.name ?? '-');
  }

  /// Class scores are probabilities in [0, 1]. Some exports emit logits.
  static double _probability(double raw) {
    if (raw.isNaN) return 0;
    if (raw >= 0 && raw <= 1) return raw;
    final x = raw.clamp(-12.0, 12.0);
    return 1 / (1 + math.exp(-x));
  }

  /// Current 11-class model, or the older 8-class export.
  /// Unknown ids are dropped so they are not reported as potholes.
  static HazardType? _typeForClass(int id, int classCount) {
    if (classCount == 11) {
      return switch (id) {
        0 => HazardType.pothole,
        1 => HazardType.crack,
        2 => HazardType.speedBump,
        3 => HazardType.person,
        4 => HazardType.cow,
        5 => HazardType.buffalo,
        6 => HazardType.dog,
        7 => HazardType.cat,
        8 => HazardType.horse,
        9 => HazardType.donkey,
        10 => HazardType.goat,
        _ => null,
      };
    }
    if (classCount == 8) {
      return switch (id) {
        0 => HazardType.pothole,
        1 => HazardType.crack,
        2 => HazardType.speedBump,
        3 => HazardType.person,
        4 => HazardType.cow,
        5 => HazardType.dog,
        6 => HazardType.goat,
        7 => HazardType.horse,
        _ => null,
      };
    }
    return null;
  }

  static List<HazardDetection> _nms(
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

  static double _estimateDistanceMeters(_Det d, double frameW, double frameH) {
    final boxW = math.max(1.0, d.x2 - d.x1);
    final boxH = math.max(1.0, d.y2 - d.y1);
    final areaFrac = (boxW * boxH) / math.max(1.0, frameW * frameH);
    final cy = ((d.y1 + d.y2) / 2).clamp(0.0, frameH);
    final yNorm = frameH <= 0 ? 0.5 : cy / frameH;

    final isRoadSurface = d.type == HazardType.pothole ||
        d.type == HazardType.crack ||
        d.type == HazardType.speedBump;
    if (isRoadSurface && areaFrac > 0.10) {
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

  static double _iou(_Det a, _Det b) {
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
