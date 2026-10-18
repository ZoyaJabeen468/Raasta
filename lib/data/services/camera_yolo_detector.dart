import 'dart:async';
import 'dart:math' as math;
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
  /// [fallback] is kept for callers/tests. Live Drive never starts it:
  /// a missing TFLite model means no hazard events, not simulated ones.
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
  DateTime? _lastFrameDoneAt;
  double _frameMs = 0;
  DateTime? _lastRoadSlotAt;
  DateTime? _lastLifeSlotAt;
  final Map<String, DateTime> _lastAlertAt = {};
  final List<_HazardTrack> _tracks = [];
  final List<_AlertMemory> _memory = [];
  int _nextTrackId = 1;

  /// Live GPS / sim speed. Below [_stoppedKph] we keep silence longer.
  double speedKph = 0;

  /// Inference already serializes on [_busy]. Keep a tiny gap so we do not
  /// queue work while the previous isolate handoff is still finishing.
  static const _minInferGap = Duration(milliseconds: 80);

  static const _classCooldown = Duration(seconds: 6);
  static const _slotCooldown = Duration(seconds: 4);

  static const _requiredStreak = 1;
  static const _animalStreak = 2;
  static const _personStreak = 1;

  static const _minBoxHoldMs = 1600;
  static const _maxBoxHoldMs = 4000;

  /// Outlasts one inference gap, so a slow phone does not blink boxes off
  /// between frames.
  Duration get _boxHold {
    final ms = (_frameMs * 1.3).round().clamp(_minBoxHoldMs, _maxBoxHoldMs);
    return Duration(milliseconds: ms);
  }
  static const _boxSmooth = 0.42;
  static const _matchIou = 0.12;
  static const _matchCenter = 0.16;
  static const _maxMissed = 4;
  static const _maxMissedAnnounced = 20;
  static const _maxTracks = 8;
  static const _maxOverlayBoxes = 3;
  static const _stoppedKph = 4.0;
  static const _memoryHoldMoving = Duration(seconds: 12);
  static const _memoryHoldStopped = Duration(seconds: 90);

  Timer? _boxHoldTimer;

  /// Shares every streamed frame without opening the camera twice.
  CameraFrameTap? onFrameTap;

  bool get usingRealtimeModel => _usingModel;
  double debugPeakScore = 0;
  String debugPeakLabel = '-';
  String debugInfo = 'not run';

  List<HazardDetection> get liveBoxes {
    final now = DateTime.now();
    final held = [
      for (final t in _tracks)
        if (now.difference(t.lastSeen) <= _boxHold) t.toDetection(),
    ];
    if (held.isEmpty) return const [];
    held.sort((a, b) {
      final c = _alertPriority(b).compareTo(_alertPriority(a));
      return c != 0 ? c : b.confidence.compareTo(a.confidence);
    });
    return held.take(_maxOverlayBoxes).toList();
  }

  @override
  Stream<HazardDetection> get detections => _controller.stream;

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
      debugPrint(
        'CameraYolo: model unavailable, hazard AI off, no simulated hazards',
      );
      notifyListeners();
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
      final hits = postResult.hits;

      final now = DateTime.now();
      final prev = _lastFrameDoneAt;
      _lastFrameDoneAt = now;
      if (prev != null) {
        final ms = now.difference(prev).inMilliseconds.clamp(1, 10000);
        _frameMs = _frameMs == 0 ? ms.toDouble() : _frameMs * 0.7 + ms * 0.3;
      }
      final fps = _frameMs == 0 ? 0 : 1000 / _frameMs;
      debugInfo = 'top box: ${postResult.peakFate} · '
          'kept ${hits.length} · ${fps.toStringAsFixed(1)} fps';

      if (_lastDebugLog == null ||
          now.difference(_lastDebugLog!) > const Duration(seconds: 3)) {
        _lastDebugLog = now;
        debugPrint(
          'YOLO peak=${debugPeakScore.toStringAsFixed(3)} '
          '($debugPeakLabel) $debugInfo ${_worker.debug}',
        );
      }

      final gated = [
        for (final h in hits)
          if (h.hasBox &&
              h.confidence >=
                  YoloM2Interpreter.thresholdFor(
                    h.type,
                    areaFrac: (h.right! - h.left!) * (h.bottom! - h.top!),
                  ))
            h,
      ];
      _updateTracks(gated, now);
      _refreshMemory(gated, now);
      notifyListeners();
      _boxHoldTimer?.cancel();
      _boxHoldTimer = Timer(_boxHold + const Duration(milliseconds: 50), () {
        _pruneTracks(DateTime.now());
        if (!_controller.isClosed) notifyListeners();
      });
      _maybeAnnounce(now);
    } catch (e, st) {
      debugPrint('YOLO frame error: $e\n$st');
    } finally {
      _busy = false;
    }
  }

  @override
  Future<void> pauseCapture() async {
    _capturePaused = true;
    _boxHoldTimer?.cancel();
    _tracks.clear();
    _memory.clear();
    try {
      if (_camera?.value.isStreamingImages == true) {
        await _camera!.stopImageStream();
      }
    } catch (_) {}
    notifyListeners();
  }

  @override
  Future<void> resumeCapture() async {
    if (!_running) return;
    _capturePaused = false;
    if (!_usingModel) return;
    await _startStream();
  }

  @override
  Future<void> stop() async {
    _running = false;
    _capturePaused = false;
    _boxHoldTimer?.cancel();
    _tracks.clear();
    _memory.clear();
    try {
      if (_camera?.value.isStreamingImages == true) {
        await _camera!.stopImageStream();
      }
    } catch (_) {}
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

  void _updateTracks(List<HazardDetection> hits, DateTime now) {
    hits.sort((a, b) => b.confidence.compareTo(a.confidence));
    final used = <int>{};

    for (final h in hits) {
      var bestIdx = -1;
      var bestScore = 0.0;
      for (var i = 0; i < _tracks.length; i++) {
        if (used.contains(i)) continue;
        final t = _tracks[i];
        if (!_sameTrackFamily(t.type, h.type)) continue;
        final iou = _normIou(t.toDetection(), h);
        final dist = _centerDist(t.toDetection(), h);
        final matched = iou >= _matchIou || dist <= _matchCenter;
        if (!matched) continue;
        final score = iou >= _matchIou ? 1 + iou : 1 - dist;
        if (score > bestScore) {
          bestScore = score;
          bestIdx = i;
        }
      }
      if (bestIdx >= 0) {
        used.add(bestIdx);
        _tracks[bestIdx].observe(h, now);
        if (_bestMemory(h) != null) _tracks[bestIdx].announced = true;
      } else if (_tracks.length < _maxTracks) {
        used.add(_tracks.length);
        _tracks.add(
          _HazardTrack(
            id: _nextTrackId++,
            type: h.type,
            hit: h,
            at: now,
            announced: _bestMemory(h) != null,
          ),
        );
      }
    }

    for (var i = 0; i < _tracks.length; i++) {
      if (!used.contains(i)) _tracks[i].missed += 1;
    }
    _pruneTracks(now);
  }

  void _pruneTracks(DateTime now) {
    _tracks.removeWhere((t) {
      if (t.announced) {
        return t.missed > _maxMissedAnnounced ||
            now.difference(t.lastSeen) > _memoryHold;
      }
      return t.missed > _maxMissed || now.difference(t.lastSeen) > _boxHold;
    });
  }

  Duration get _memoryHold =>
      speedKph < _stoppedKph ? _memoryHoldStopped : _memoryHoldMoving;

  void _refreshMemory(List<HazardDetection> hits, DateTime now) {
    _memory.removeWhere((m) => now.difference(m.lastSeen) > _memoryHold);
    final claimed = <int>{};
    for (final h in hits) {
      var bestIdx = -1;
      var bestD = _matchCenter;
      for (var i = 0; i < _memory.length; i++) {
        if (claimed.contains(i)) continue;
        final m = _memory[i];
        if (!_sameTrackFamily(m.type, h.type)) continue;
        final d = m.distanceTo(h);
        if (d < bestD) {
          bestD = d;
          bestIdx = i;
        }
      }
      if (bestIdx < 0) continue;
      claimed.add(bestIdx);
      _memory[bestIdx].remember(h, now);
    }
  }

  _AlertMemory? _bestMemory(HazardDetection h) {
    _AlertMemory? best;
    var bestD = _matchCenter;
    for (final m in _memory) {
      if (!_sameTrackFamily(m.type, h.type)) continue;
      final d = m.distanceTo(h);
      if (d < bestD) {
        bestD = d;
        best = m;
      }
    }
    return best;
  }

  void _maybeAnnounce(DateTime now) {
    _HazardTrack? road;
    _HazardTrack? life;
    var roadScore = -1.0e9;
    var lifeScore = -1.0e9;
    for (final t in _tracks) {
      if (t.announced || _bestMemory(t.toDetection()) != null) continue;
      if (!_readyToAnnounce(t)) continue;
      final lastClass = _lastAlertAt[t.type.name];
      if (lastClass != null && now.difference(lastClass) < _classCooldown) {
        continue;
      }
      final score = _alertPriority(t.toDetection());
      if (t.type.isRoadHazard && score > roadScore) {
        roadScore = score;
        road = t;
      } else if (t.type.isLifeHazard && score > lifeScore) {
        lifeScore = score;
        life = t;
      }
    }

    if (life != null &&
        _lastLifeSlotAt != null &&
        now.difference(_lastLifeSlotAt!) < _slotCooldown) {
      life = null;
    }
    if (road != null &&
        _lastRoadSlotAt != null &&
        now.difference(_lastRoadSlotAt!) < _slotCooldown) {
      road = null;
    }

    // Life first so the person/animal card and voice lead.
    _emitTrack(life, now);
    _emitTrack(road, now);
  }

  void _emitTrack(_HazardTrack? track, DateTime now) {
    if (track == null || _controller.isClosed) return;
    track.announced = true;
    _lastAlertAt[track.type.name] = now;
    if (track.type.isRoadHazard) _lastRoadSlotAt = now;
    if (track.type.isLifeHazard) _lastLifeSlotAt = now;
    final det = track.toDetection();
    final existing = _bestMemory(det);
    if (existing != null) {
      existing.remember(det, now);
    } else {
      _memory.add(_AlertMemory.fromDetection(det, now));
    }
    _controller.add(det);
    debugPrint(
      'YOLO alert ${track.type.name} conf='
      '${track.confidence.toStringAsFixed(2)} hits=${track.hits}',
    );
  }

  static bool _readyToAnnounce(_HazardTrack t) {
    if (t.hits >= _confirmNeed(t.type)) return true;
    // One strong frame is enough when the overlay already locked on.
    if (t.hits >= 1 && t.confidence >= 0.48) return true;
    return false;
  }

  static int _confirmNeed(HazardType type) {
    if (YoloM2Interpreter.isAnimal(type)) return _animalStreak;
    if (type == HazardType.person) return _personStreak;
    return _requiredStreak;
  }

  static bool _sameTrackFamily(HazardType a, HazardType b) {
    if (a == b) return true;
    return YoloM2Interpreter.isAnimal(a) && YoloM2Interpreter.isAnimal(b);
  }

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

  static double _centerDist(HazardDetection a, HazardDetection b) {
    final dx = ((a.left! + a.right!) / 2) - ((b.left! + b.right!) / 2);
    final dy = ((a.top! + a.bottom!) / 2) - ((b.top! + b.bottom!) / 2);
    return math.sqrt(dx * dx + dy * dy);
  }
}

class _AlertMemory {
  _AlertMemory({
    required this.type,
    required this.cx,
    required this.cy,
    required this.lastSeen,
  });

  factory _AlertMemory.fromDetection(HazardDetection hit, DateTime at) {
    return _AlertMemory(
      type: hit.type,
      cx: (hit.left! + hit.right!) / 2,
      cy: (hit.top! + hit.bottom!) / 2,
      lastSeen: at,
    );
  }

  HazardType type;
  double cx;
  double cy;
  DateTime lastSeen;

  double distanceTo(HazardDetection hit) {
    final hx = (hit.left! + hit.right!) / 2;
    final hy = (hit.top! + hit.bottom!) / 2;
    final dx = cx - hx;
    final dy = cy - hy;
    return math.sqrt(dx * dx + dy * dy);
  }

  void remember(HazardDetection hit, DateTime at) {
    type = hit.type;
    cx = (hit.left! + hit.right!) / 2;
    cy = (hit.top! + hit.bottom!) / 2;
    lastSeen = at;
  }
}

class _HazardTrack {
  _HazardTrack({
    required this.id,
    required this.type,
    required HazardDetection hit,
    required DateTime at,
    this.announced = false,
  }) : left = hit.left!,
       top = hit.top!,
       right = hit.right!,
       bottom = hit.bottom!,
       confidence = hit.confidence,
       distanceMeters = hit.distanceMeters,
       range = hit.range,
       lastSeen = at;

  final int id;
  HazardType type;
  double left;
  double top;
  double right;
  double bottom;
  double confidence;
  double? distanceMeters;
  HazardRange? range;
  int hits = 1;
  int missed = 0;
  DateTime lastSeen;
  bool announced = false;

  HazardDetection toDetection() {
    return HazardDetection(
      type: type,
      confidence: confidence,
      distanceMeters: distanceMeters,
      range: range,
      left: left,
      top: top,
      right: right,
      bottom: bottom,
    );
  }

  void observe(HazardDetection hit, DateTime at) {
    const a = CameraYoloHazardDetector._boxSmooth;
    left = left + (hit.left! - left) * a;
    top = top + (hit.top! - top) * a;
    right = right + (hit.right! - right) * a;
    bottom = bottom + (hit.bottom! - bottom) * a;
    type = hit.type;
    confidence = hit.confidence;
    distanceMeters = hit.distanceMeters;
    range = hit.range;
    hits += 1;
    missed = 0;
    lastSeen = at;
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

