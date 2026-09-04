import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import '../models/hazard_type.dart';
import 'hazard_detector.dart';
import 'yolo_m2_interpreter.dart';

/// Live-camera Module-2 detector. Falls back to [SimulatedHazardDetector]
/// on web / if the TFLite model cannot load.
class CameraYoloHazardDetector extends ChangeNotifier
    implements HazardDetector {
  CameraYoloHazardDetector({HazardDetector? fallback})
    : _fallback = fallback ?? SimulatedHazardDetector();

  final HazardDetector _fallback;
  final YoloM2Interpreter _yolo = YoloM2Interpreter();
  final _controller = StreamController<HazardDetection>.broadcast();

  CameraController? _camera;
  bool _running = false;
  bool _usingModel = false;
  bool _busy = false;
  DateTime? _lastInferAt;
  DateTime? _lastDebugLog;
  DateTime? _lastAnyAlertAt;
  final Map<String, DateTime> _lastAlertAt = {};
  final Map<String, int> _streak = {};

  /// Infer rarely enough that the camera preview stays fluid.
  /// Heavy YOLO on the image-stream path is what caused hangs.
  static const _minInferGap = Duration(milliseconds: 3000);

  /// Don't spam the same class.
  static const _classCooldown = Duration(seconds: 6);

  /// Gap between any spoken/visual alerts.
  static const _globalAlertGap = Duration(seconds: 4);

  /// Road damage: 2 hits. Person/animals: 3 (fewer false alerts on photos).
  static const _requiredStreak = 2;
  static const _animalStreak = 3;
  static const _personStreak = 3;

  /// Hold boxes after a miss (anti-flicker, RoadGuardian-style).
  static const _boxHold = Duration(milliseconds: 1600);

  /// Blend factor toward new box (0 = freeze old, 1 = jump to new).
  static const _boxSmooth = 0.42;

  /// Keep the UI calm while driving — only top priority hazards.
  static const _maxOverlayBoxes = 2;

  List<HazardDetection> _liveBoxes = const [];
  DateTime? _boxesSeenAt;
  Timer? _boxHoldTimer;

  bool get usingRealtimeModel => _usingModel;
  double get debugPeakScore => _yolo.lastPeakScore;
  String get debugPeakLabel => _yolo.lastPeakLabel;
  String get debugInfo => _yolo.lastDebug;

  /// Current boxes for the camera overlay (with short hold after last hit).
  List<HazardDetection> get liveBoxes {
    if (_liveBoxes.isEmpty || _boxesSeenAt == null) return const [];
    if (DateTime.now().difference(_boxesSeenAt!) > _boxHold) {
      return const [];
    }
    return _liveBoxes;
  }

  @override
  Stream<HazardDetection> get detections =>
      _usingModel ? _controller.stream : _fallback.detections;

  Future<void> attachCamera(CameraController? camera) async {
    _camera = camera;
    if (_running && _usingModel) {
      await _startStream();
    }
  }

  @override
  Future<void> start() async {
    if (_running) return;
    _running = true;

    final loaded = await _yolo.load();
    _usingModel = loaded && !kIsWeb;

    if (!_usingModel) {
      debugPrint('CameraYolo: using simulated detector');
      await _fallback.start();
      return;
    }

    await _startStream();
    notifyListeners();
  }

  Future<void> _startStream() async {
    final cam = _camera;
    if (cam == null || !cam.value.isInitialized) return;
    if (cam.value.isStreamingImages) return;

    try {
      // Non-async callback: never block the camera plugin waiting on YOLO.
      await cam.startImageStream(_onFrame);
    } catch (e) {
      debugPrint('startImageStream failed: $e');
      _usingModel = false;
      await _fallback.start();
      notifyListeners();
    }
  }

  void _onFrame(CameraImage frame) {
    if (!_running || !_usingModel || _busy) return;
    final now = DateTime.now();
    if (_lastInferAt != null &&
        now.difference(_lastInferAt!) < _minInferGap) {
      return;
    }
    _lastInferAt = now;
    _busy = true;

    // Snapshot plane bytes NOW — CameraImage buffers are recycled after return.
    final snap = _FrameSnapshot.from(frame);
    final sensorOrientation = _camera?.description.sensorOrientation ?? 0;
    final deviceOrientation = _camera?.value.deviceOrientation;
    final isFront =
        _camera?.description.lensDirection == CameraLensDirection.front;

    unawaited(
      _runInference(
        snap: snap,
        sensorOrientation: sensorOrientation,
        deviceOrientation: deviceOrientation,
        isFront: isFront,
      ),
    );
  }

  Future<void> _runInference({
    required _FrameSnapshot snap,
    required int sensorOrientation,
    required DeviceOrientation? deviceOrientation,
    required bool isFront,
  }) async {
    try {
      // Let a camera/UI frame paint before heavy work.
      await Future<void>.delayed(Duration.zero);
      if (!_running) return;

      final rgb = snap.toRgb(
        sensorOrientation: sensorOrientation,
        deviceOrientation: deviceOrientation,
        isFront: isFront,
      );
      if (rgb == null) return;

      final small = _downscale(rgb, _yolo.inputSize);
      final hits = _yolo.detect(small);

      final now = DateTime.now();
      if (_lastDebugLog == null ||
          now.difference(_lastDebugLog!) > const Duration(seconds: 3)) {
        _lastDebugLog = now;
        debugPrint(
          'YOLO peak=${_yolo.lastPeakScore.toStringAsFixed(3)} '
          '(${_yolo.lastPeakLabel}) hits=${hits.length} ${_yolo.lastDebug}',
        );
      }

      final drawable = _pickOverlayBoxes(
        hits.where(
          (h) =>
              h.hasBox &&
              h.confidence >= YoloM2Interpreter.thresholdFor(h.type),
        ),
      );
      if (drawable.isNotEmpty) {
        _liveBoxes = _smoothBoxes(drawable);
        _boxesSeenAt = now;
        _boxHoldTimer?.cancel();
        _boxHoldTimer = Timer(_boxHold + const Duration(milliseconds: 50), () {
          if (!_controller.isClosed) notifyListeners();
        });
        notifyListeners();
      }

      if (hits.isEmpty) {
        _streak.clear();
        return;
      }

      hits.sort((a, b) {
        final ap = _alertPriority(a);
        final bp = _alertPriority(b);
        if (ap != bp) return bp.compareTo(ap);
        return b.confidence.compareTo(a.confidence);
      });
      final best = hits.first;
      if (best.confidence < YoloM2Interpreter.thresholdFor(best.type)) {
        _streak.clear();
        return;
      }

      final key = best.type.name;
      _streak[key] = (_streak[key] ?? 0) + 1;
      for (final k in _streak.keys.where((k) => k != key).toList()) {
        _streak.remove(k);
      }
      final need = YoloM2Interpreter.isAnimal(best.type)
          ? _animalStreak
          : (best.type == HazardType.person ? _personStreak : _requiredStreak);
      if ((_streak[key] ?? 0) < need) return;

      final lastClass = _lastAlertAt[key];
      if (lastClass != null && now.difference(lastClass) < _classCooldown) {
        return;
      }
      if (_lastAnyAlertAt != null &&
          now.difference(_lastAnyAlertAt!) < _globalAlertGap) {
        return;
      }

      _lastAlertAt[key] = now;
      _lastAnyAlertAt = now;
      _streak[key] = 0;
      if (!_controller.isClosed) _controller.add(best);
    } catch (e, st) {
      debugPrint('YOLO frame error: $e\n$st');
    } finally {
      _busy = false;
    }
  }

  @override
  Future<void> stop() async {
    _running = false;
    _boxHoldTimer?.cancel();
    _liveBoxes = const [];
    _boxesSeenAt = null;
    try {
      if (_camera?.value.isStreamingImages == true) {
        await _camera!.stopImageStream();
      }
    } catch (_) {}
    await _fallback.stop();
    notifyListeners();
  }

  @override
  void dispose() {
    _boxHoldTimer?.cancel();
    unawaited(stop());
    _yolo.close();
    _fallback.dispose();
    _controller.close();
    super.dispose();
  }

  /// Prefer road damage, then person, then animals; nearer boxes win ties.
  List<HazardDetection> _pickOverlayBoxes(Iterable<HazardDetection> candidates) {
    final list = candidates.toList();
    if (list.isEmpty) return const [];
    list.sort((a, b) {
      final ap = _alertPriority(a);
      final bp = _alertPriority(b);
      if (ap != bp) return bp.compareTo(ap);
      final ad = a.distanceMeters ?? 999;
      final bd = b.distanceMeters ?? 999;
      if (ad != bd) return ad.compareTo(bd);
      return b.confidence.compareTo(a.confidence);
    });
    return list.take(_maxOverlayBoxes).toList();
  }

  /// Match by class + IoU, then EMA-smooth corners so boxes don't jitter.
  List<HazardDetection> _smoothBoxes(List<HazardDetection> next) {
    if (_liveBoxes.isEmpty) return next;
    final out = <HazardDetection>[];
    final usedPrev = <int>{};
    for (final n in next) {
      var bestIdx = -1;
      var bestIou = 0.0;
      for (var i = 0; i < _liveBoxes.length; i++) {
        if (usedPrev.contains(i)) continue;
        final p = _liveBoxes[i];
        if (p.type != n.type || !p.hasBox || !n.hasBox) continue;
        final iou = _normIou(p, n);
        if (iou > bestIou) {
          bestIou = iou;
          bestIdx = i;
        }
      }
      if (bestIdx >= 0 && bestIou >= 0.12) {
        usedPrev.add(bestIdx);
        final p = _liveBoxes[bestIdx];
        const a = _boxSmooth;
        out.add(
          HazardDetection(
            type: n.type,
            confidence: n.confidence,
            distanceMeters: n.distanceMeters,
            left: _lerp(p.left!, n.left!, a),
            top: _lerp(p.top!, n.top!, a),
            right: _lerp(p.right!, n.right!, a),
            bottom: _lerp(p.bottom!, n.bottom!, a),
          ),
        );
      } else {
        out.add(n);
      }
    }
    return out;
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  static double _normIou(HazardDetection a, HazardDetection b) {
    final x1 = a.left! > b.left! ? a.left! : b.left!;
    final y1 = a.top! > b.top! ? a.top! : b.top!;
    final x2 = a.right! < b.right! ? a.right! : b.right!;
    final y2 = a.bottom! < b.bottom! ? a.bottom! : b.bottom!;
    final iw = x2 > x1 ? x2 - x1 : 0.0;
    final ih = y2 > y1 ? y2 - y1 : 0.0;
    final inter = iw * ih;
    final areaA = (a.right! - a.left!) * (a.bottom! - a.top!);
    final areaB = (b.right! - b.left!) * (b.bottom! - b.top!);
    final union = areaA + areaB - inter;
    return union <= 0 ? 0 : inter / union;
  }
}

/// Higher = preferred for the spoken/banner alert.
double _alertPriority(HazardDetection h) {
  final road = h.type == HazardType.pothole ||
      h.type == HazardType.crack ||
      h.type == HazardType.speedBump;
  if (road) return h.confidence + 0.35;
  if (h.type == HazardType.person) return h.confidence + 0.10;
  // Animals: only competitive when clearly confident.
  if (YoloM2Interpreter.isAnimal(h.type)) {
    return h.confidence < YoloM2Interpreter.animalThreshold
        ? h.confidence - 1.0
        : h.confidence;
  }
  return h.confidence;
}

img.Image _downscale(img.Image src, int maxSide) {
  final longest = src.width > src.height ? src.width : src.height;
  if (longest <= maxSide) return src;
  final scale = maxSide / longest;
  return img.copyResize(
    src,
    width: (src.width * scale).round().clamp(1, maxSide),
    height: (src.height * scale).round().clamp(1, maxSide),
    interpolation: img.Interpolation.average,
  );
}

/// Copied camera planes so AI can run after the stream callback returns.
class _FrameSnapshot {
  _FrameSnapshot._({
    required this.width,
    required this.height,
    required this.isBgra,
    required this.plane0,
    required this.rowStride0,
    this.plane1,
    this.plane2,
    this.uvRowStride = 0,
    this.uvPixelStride = 1,
  });

  final int width;
  final int height;
  final bool isBgra;
  final Uint8List plane0;
  final int rowStride0;
  final Uint8List? plane1;
  final Uint8List? plane2;
  final int uvRowStride;
  final int uvPixelStride;

  factory _FrameSnapshot.from(CameraImage image) {
    final isBgra = image.format.group == ImageFormatGroup.bgra8888;
    Uint8List copyOf(Uint8List src) => Uint8List.fromList(src);
    if (isBgra) {
      return _FrameSnapshot._(
        width: image.width,
        height: image.height,
        isBgra: true,
        plane0: copyOf(image.planes[0].bytes),
        rowStride0: image.planes[0].bytesPerRow,
      );
    }
    return _FrameSnapshot._(
      width: image.width,
      height: image.height,
      isBgra: false,
      plane0: copyOf(image.planes[0].bytes),
      rowStride0: image.planes[0].bytesPerRow,
      plane1: copyOf(image.planes[1].bytes),
      plane2: copyOf(image.planes[2].bytes),
      uvRowStride: image.planes[1].bytesPerRow,
      uvPixelStride: image.planes[1].bytesPerPixel ?? 1,
    );
  }

  img.Image? toRgb({
    required int sensorOrientation,
    DeviceOrientation? deviceOrientation,
    bool isFront = false,
  }) {
    try {
      img.Image? rgb = isBgra ? _bgraToImageFast() : _yuv420ToImageFast();
      if (rgb == null) return null;

      final deviceDeg = switch (deviceOrientation) {
        DeviceOrientation.portraitUp => 0,
        DeviceOrientation.landscapeLeft => 90,
        DeviceOrientation.portraitDown => 180,
        DeviceOrientation.landscapeRight => 270,
        null => 0,
      };

      final rotation = isFront
          ? (sensorOrientation + deviceDeg) % 360
          : (sensorOrientation - deviceDeg + 360) % 360;

      if (rotation == 90) return img.copyRotate(rgb, angle: 90);
      if (rotation == 270) return img.copyRotate(rgb, angle: 270);
      if (rotation == 180) return img.copyRotate(rgb, angle: 180);
      return rgb;
    } catch (e) {
      debugPrint('camera->rgb failed: $e');
      return null;
    }
  }

  /// 3× subsample — much cheaper than full-res convert on phone.
  static const _step = 3;

  img.Image _bgraToImageFast() {
    final w = width ~/ _step;
    final h = height ~/ _step;
    final out = img.Image(width: w, height: h);
    for (var y = 0; y < h; y++) {
      final srcY = y * _step;
      final row = srcY * rowStride0;
      for (var x = 0; x < w; x++) {
        final i = row + (x * _step) * 4;
        if (i + 2 >= plane0.length) continue;
        out.setPixelRgb(
          x,
          y,
          plane0[i + 2] & 0xff,
          plane0[i + 1] & 0xff,
          plane0[i] & 0xff,
        );
      }
    }
    return out;
  }

  img.Image? _yuv420ToImageFast() {
    final u = plane1;
    final v = plane2;
    if (u == null || v == null) return null;
    final w = width ~/ _step;
    final h = height ~/ _step;
    final out = img.Image(width: w, height: h);
    for (var y = 0; y < h; y++) {
      final srcY = y * _step;
      final yRow = srcY * rowStride0;
      final uvRow = (srcY >> 1) * uvRowStride;
      for (var x = 0; x < w; x++) {
        final srcX = x * _step;
        final yp = plane0[yRow + srcX] & 0xff;
        final uvIndex = uvRow + (srcX >> 1) * uvPixelStride;
        final ui = uvIndex.clamp(0, u.length - 1);
        final vi = uvIndex.clamp(0, v.length - 1);
        final up = u[ui] & 0xff;
        final vp = v[vi] & 0xff;
        final r = (yp + 1.370705 * (vp - 128)).round().clamp(0, 255);
        final g =
            (yp - 0.337633 * (up - 128) - 0.698001 * (vp - 128)).round().clamp(
              0,
              255,
            );
        final b = (yp + 1.732446 * (up - 128)).round().clamp(0, 255);
        out.setPixelRgb(x, y, r, g, b);
      }
    }
    return out;
  }
}
