import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

import '../models/hazard_type.dart';
import 'hazard_detector.dart';
import 'yolo_frame_worker.dart';
import 'yolo_m2_interpreter.dart';

/// Extra consumer of raw camera frames (e.g. M3 signs). Runs inside the
/// image-stream callback, so it must copy what it needs and return fast.
typedef CameraFrameTap = void Function(
  CameraImage frame,
  CameraController camera,
);

class CameraYoloHazardDetector extends ChangeNotifier
    implements HazardDetector {
  CameraYoloHazardDetector({HazardDetector? fallback})
    : _fallback = fallback ?? SimulatedHazardDetector();

  final HazardDetector _fallback;
  final YoloFrameWorker _worker = YoloFrameWorker();
  final _controller = StreamController<HazardDetection>.broadcast();

  CameraController? _camera;
  bool _running = false;
  bool _capturePaused = false;
  bool _usingModel = false;
  bool _busy = false;
  DateTime? _lastInferAt;
  DateTime? _lastDebugLog;
  DateTime? _lastAnyAlertAt;
  final Map<String, DateTime> _lastAlertAt = {};
  final Map<String, int> _streak = {};

  static const _minInferGap = Duration(milliseconds: 350);

  static const _classCooldown = Duration(seconds: 6);
  static const _globalAlertGap = Duration(seconds: 4);

  static const _requiredStreak = 3;
  static const _animalStreak = 3;
  static const _personStreak = 2;

  static const _boxHold = Duration(milliseconds: 1600);
  static const _boxSmooth = 0.42;
  static const _maxOverlayBoxes = 2;

  List<HazardDetection> _liveBoxes = const [];
  DateTime? _boxesSeenAt;
  Timer? _boxHoldTimer;

  /// Shares every streamed frame without opening the camera twice.
  CameraFrameTap? onFrameTap;

  bool get usingRealtimeModel => _usingModel;
  double debugPeakScore = 0;
  String debugPeakLabel = '-';
  String debugInfo = 'not run';

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
    if (_running && _usingModel && !_capturePaused) {
      await _startStream();
    }
  }

  @override
  Future<void> start() async {
    if (_running) return;
    _running = true;

    final loaded = !kIsWeb && await _worker.start();
    debugInfo = _worker.debug;
    _usingModel = loaded;

    if (!_usingModel) {
      debugPrint('CameraYolo: model unavailable, using simulated detector');
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
      debugInfo = 'camera stream failed';
      notifyListeners();
    }
  }

  void _onFrame(CameraImage frame) {
    final cam = _camera;
    if (cam != null) onFrameTap?.call(frame, cam);
    if (!_running || _capturePaused || !_usingModel || _busy) return;
    final now = DateTime.now();
    if (_lastInferAt != null &&
        now.difference(_lastInferAt!) < _minInferGap) {
      return;
    }
    _lastInferAt = now;
    _busy = true;

    final sensorOrientation = _camera?.description.sensorOrientation ?? 0;
    final isFront =
        _camera?.description.lensDirection == CameraLensDirection.front;
    final captured = YoloCameraFrame(
      width: frame.width,
      height: frame.height,
      isBgra: frame.format.group == ImageFormatGroup.bgra8888,
      plane0: Uint8List.fromList(frame.planes[0].bytes),
      rowStride0: frame.planes[0].bytesPerRow,
      plane1: frame.planes.length > 1
          ? Uint8List.fromList(frame.planes[1].bytes)
          : null,
      plane2: frame.planes.length > 2
          ? Uint8List.fromList(frame.planes[2].bytes)
          : null,
      uvRowStride: frame.planes.length > 1 ? frame.planes[1].bytesPerRow : 0,
      uvPixelStride: frame.planes.length > 1
          ? (frame.planes[1].bytesPerPixel ?? 1)
          : 1,
      sensorOrientation: sensorOrientation,
      isFront: isFront,
    );

    unawaited(_runInference(captured));
  }

  Future<void> _runInference(YoloCameraFrame frame) async {
    try {
      if (!_running || _capturePaused) return;
      final postResult = await _worker.detect(frame);
      if (postResult == null || !_running || _capturePaused) return;

      debugPeakScore = postResult.peakScore;
      debugPeakLabel = postResult.peakLabel;
      debugInfo = _worker.debug;
      final hits = postResult.hits;

      final now = DateTime.now();
      if (_lastDebugLog == null ||
          now.difference(_lastDebugLog!) > const Duration(seconds: 3)) {
        _lastDebugLog = now;
        debugPrint(
          'YOLO peak=${debugPeakScore.toStringAsFixed(3)} '
          '($debugPeakLabel) hits=${hits.length} $debugInfo',
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
  Future<void> pauseCapture() async {
    _capturePaused = true;
    try {
      if (_camera?.value.isStreamingImages == true) {
        await _camera!.stopImageStream();
      }
    } catch (_) {}
    await _fallback.stop();
  }

  @override
  Future<void> resumeCapture() async {
    if (!_running) return;
    _capturePaused = false;
    if (!_usingModel) {
      await _fallback.start();
      return;
    }
    await _startStream();
  }

  @override
  Future<void> stop() async {
    _running = false;
    _capturePaused = false;
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
    _worker.close();
    _fallback.dispose();
    _controller.close();
    super.dispose();
  }

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

double _alertPriority(HazardDetection h) {
  final road = h.type == HazardType.pothole ||
      h.type == HazardType.crack ||
      h.type == HazardType.speedBump;
  if (road) return h.confidence + 0.35;
  if (h.type == HazardType.person) return h.confidence + 0.10;
  if (YoloM2Interpreter.isAnimal(h.type)) {
    return h.confidence < YoloM2Interpreter.animalThreshold
        ? h.confidence - 1.0
        : h.confidence;
  }
  return h.confidence;
}

