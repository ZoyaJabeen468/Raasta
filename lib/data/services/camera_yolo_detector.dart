import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
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

  /// Slower inference = less heat / hang on mid-range phones.
  /// Preview freezes if we infer every frame; ~1.5s keeps UI responsive.
  static const _minInferGap = Duration(milliseconds: 1500);

  /// Don't spam the same class.
  static const _classCooldown = Duration(seconds: 6);

  /// Gap between any spoken/visual alerts.
  static const _globalAlertGap = Duration(seconds: 4);

  /// Two hits in a row — enough to cut flicker, not so high demos never fire.
  static const _requiredStreak = 2;

  /// Keep drawing boxes briefly after a miss so they don't blink.
  static const _boxHold = Duration(milliseconds: 1200);

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
      await cam.startImageStream(_onFrame);
    } catch (e) {
      debugPrint('startImageStream failed: $e');
      _usingModel = false;
      await _fallback.start();
      notifyListeners();
    }
  }

  Future<void> _onFrame(CameraImage frame) async {
    if (!_running || !_usingModel || _busy) return;
    final now = DateTime.now();
    if (_lastInferAt != null &&
        now.difference(_lastInferAt!) < _minInferGap) {
      return;
    }
    _lastInferAt = now;
    _busy = true;
    try {
      final rgb = _cameraImageToRgb(
        frame,
        _camera?.description.sensorOrientation ?? 0,
      );
      if (rgb == null) return;

      // Keep native letterbox quality — do not shrink below model input.
      final small = _downscale(rgb, _yolo.inputSize);
      final hits = _yolo.detect(small);

      var didDebugTick = false;
      if (_lastDebugLog == null ||
          now.difference(_lastDebugLog!) > const Duration(seconds: 2)) {
        _lastDebugLog = now;
        didDebugTick = true;
        debugPrint(
          'YOLO peak=${_yolo.lastPeakScore.toStringAsFixed(3)} '
          '(${_yolo.lastPeakLabel}) hits=${hits.length} ${_yolo.lastDebug}',
        );
      }

      // Overlay: show confident boxes (road damage can be a bit lower).
      final drawable = hits
          .where(
            (h) =>
                h.hasBox &&
                h.confidence >= YoloM2Interpreter.thresholdFor(h.type) * 0.95,
          )
          .take(6)
          .toList();
      var boxesChanged = false;
      if (drawable.isNotEmpty) {
        boxesChanged = true;
        _liveBoxes = drawable;
        _boxesSeenAt = now;
        _boxHoldTimer?.cancel();
        _boxHoldTimer = Timer(_boxHold + const Duration(milliseconds: 50), () {
          if (!_controller.isClosed) notifyListeners();
        });
      }
      // Throttle UI rebuilds — notifying every inference stalled the preview.
      if (boxesChanged || didDebugTick) {
        notifyListeners();
      }

      if (hits.isEmpty) {
        _streak.clear();
        return;
      }

      // Prefer road damage over weak animal false-positives (common on photos).
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
      if ((_streak[key] ?? 0) < _requiredStreak) return;

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

img.Image? _cameraImageToRgb(CameraImage image, int sensorOrientation) {
  try {
    // Convert at reduced resolution for speed (every 2nd pixel).
    img.Image? rgb;
    if (image.format.group == ImageFormatGroup.bgra8888) {
      final bytes = image.planes.first.bytes;
      rgb = img.Image.fromBytes(
        width: image.width,
        height: image.height,
        bytes: bytes.buffer,
        order: img.ChannelOrder.bgra,
      );
    } else if (image.format.group == ImageFormatGroup.yuv420) {
      rgb = _yuv420ToImageFast(image);
    }
    if (rgb == null) return null;

    if (sensorOrientation == 90) {
      return img.copyRotate(rgb, angle: 90);
    }
    if (sensorOrientation == 270) {
      return img.copyRotate(rgb, angle: 270);
    }
    if (sensorOrientation == 180) {
      return img.copyRotate(rgb, angle: 180);
    }
    return rgb;
  } catch (e) {
    debugPrint('camera->rgb failed: $e');
    return null;
  }
}

/// Subsamples 2x while converting — much cheaper on mid-range phones.
img.Image _yuv420ToImageFast(CameraImage image) {
  final srcW = image.width;
  final srcH = image.height;
  final w = srcW ~/ 2;
  final h = srcH ~/ 2;
  final yPlane = image.planes[0];
  final uPlane = image.planes[1];
  final vPlane = image.planes[2];
  final uvRowStride = uPlane.bytesPerRow;
  final uvPixelStride = uPlane.bytesPerPixel ?? 1;

  final out = img.Image(width: w, height: h);
  for (var y = 0; y < h; y++) {
    final srcY = y * 2;
    final yRow = srcY * yPlane.bytesPerRow;
    final uvRow = (srcY >> 1) * uvRowStride;
    for (var x = 0; x < w; x++) {
      final srcX = x * 2;
      final yp = yPlane.bytes[yRow + srcX] & 0xff;
      final uvIndex = uvRow + (srcX >> 1) * uvPixelStride;
      final ui = uvIndex.clamp(0, uPlane.bytes.length - 1);
      final vi = uvIndex.clamp(0, vPlane.bytes.length - 1);
      final up = uPlane.bytes[ui] & 0xff;
      final vp = vPlane.bytes[vi] & 0xff;

      var r = (yp + 1.370705 * (vp - 128)).round();
      var g = (yp - 0.337633 * (up - 128) - 0.698001 * (vp - 128)).round();
      var b = (yp + 1.732446 * (up - 128)).round();
      out.setPixelRgb(x, y, r.clamp(0, 255), g.clamp(0, 255), b.clamp(0, 255));
    }
  }
  return out;
}
