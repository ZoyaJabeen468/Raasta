import 'dart:async';
import 'dart:math';

import '../models/hazard_type.dart';

/// Monocular band only. Not survey metres.
enum HazardRange {
  near,
  mid,
  far;

  String get english {
    switch (this) {
      case HazardRange.near:
        return 'close ahead';
      case HazardRange.mid:
        return 'ahead';
      case HazardRange.far:
        return 'far ahead';
    }
  }

  String get urdu {
    switch (this) {
      case HazardRange.near:
        return 'بالکل قریب آگے';
      case HazardRange.mid:
        return 'آگے';
      case HazardRange.far:
        return 'دور آگے';
    }
  }

  String get shortLabel {
    switch (this) {
      case HazardRange.near:
        return 'near';
      case HazardRange.mid:
        return 'mid';
      case HazardRange.far:
        return 'far';
    }
  }
}

/// A raw detection emitted by a [HazardDetector] before the drive session
/// attaches trip context (speed, safety impact) to it.
class HazardDetection {
  const HazardDetection({
    required this.type,
    required this.confidence,
    this.distanceMeters,
    this.range,
    this.left,
    this.top,
    this.right,
    this.bottom,
  });

  final HazardType type;
  final double confidence;

  /// Unused for live YOLO. Kept so older callers compile.
  final double? distanceMeters;

  /// near / mid / far from box size and position.
  final HazardRange? range;

  /// Normalized box in the detection frame (0–1). Null when unknown (sim).
  final double? left;
  final double? top;
  final double? right;
  final double? bottom;

  bool get hasBox =>
      left != null && top != null && right != null && bottom != null;
}

/// Source of hazard detections during a drive.
///
/// The live camera + ML model will implement this interface later. For now
/// [SimulatedHazardDetector] emits believable events so the full drive flow,
/// voice alerts and trip logging can be built and demonstrated end to end.
abstract class HazardDetector {
  Stream<HazardDetection> get detections;

  Future<void> start();

  Future<void> stop();

  /// Stops capture without ending the session. Default is a full [stop].
  Future<void> pauseCapture() => stop();

  /// Continues after [pauseCapture]. Default is a full [start].
  Future<void> resumeCapture() => start();

  void dispose();
}

/// Emits random, weighted hazard detections at irregular intervals.
class SimulatedHazardDetector implements HazardDetector {
  SimulatedHazardDetector({Random? random}) : _random = random ?? Random();

  final Random _random;
  final _controller = StreamController<HazardDetection>.broadcast();
  Timer? _timer;
  bool _running = false;

  // Local-road mix: damage first, then people/animals.
  static const _weights = <HazardType, int>{
    HazardType.pothole: 28,
    HazardType.speedBump: 18,
    HazardType.crack: 14,
    HazardType.person: 16,
    HazardType.cow: 8,
    HazardType.dog: 6,
    HazardType.goat: 4,
    HazardType.buffalo: 3,
    HazardType.horse: 2,
    HazardType.donkey: 1,
  };

  @override
  Stream<HazardDetection> get detections => _controller.stream;

  @override
  Future<void> start() async {
    if (_running) return;
    _running = true;
    _scheduleNext();
  }

  @override
  Future<void> stop() async {
    _running = false;
    _timer?.cancel();
    _timer = null;
  }

  @override
  Future<void> pauseCapture() => stop();

  @override
  Future<void> resumeCapture() => start();

  @override
  void dispose() {
    _timer?.cancel();
    _controller.close();
  }

  void _scheduleNext() {
    if (!_running) return;
    // Next hazard somewhere between 4 and 13 seconds out.
    final seconds = 4 + _random.nextInt(10);
    _timer = Timer(Duration(seconds: seconds), () {
      if (!_running) return;
      _controller.add(
        HazardDetection(
          type: _pickType(),
          confidence: 0.62 + _random.nextDouble() * 0.36,
          distanceMeters: (30 + _random.nextInt(8) * 10).toDouble(),
        ),
      );
      _scheduleNext();
    });
  }

  HazardType _pickType() {
    final total = _weights.values.reduce((a, b) => a + b);
    var roll = _random.nextInt(total);
    for (final entry in _weights.entries) {
      if (roll < entry.value) return entry.key;
      roll -= entry.value;
    }
    return HazardType.pothole;
  }
}
