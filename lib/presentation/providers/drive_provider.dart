import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/utils/speed_band.dart';
import '../../data/models/hazard_event.dart';
import '../../data/models/hazard_type.dart';
import '../../data/models/language_preference.dart';
import '../../data/models/trip_record.dart';
import '../../data/services/camera_yolo_detector.dart';
import '../../data/services/gps_service.dart';
import '../../data/services/hazard_detector.dart';
import '../../data/services/permission_service.dart';
import '../../data/services/tts_service.dart';

enum DriveStatus {
  /// Not in a drive session.
  idle,

  /// GPS live; waiting for speed > [tripStartKph] before logging starts.
  arming,

  running,
  paused,
  finished,
}

/// Runs a live drive: GPS speed, distance, hazard detections, spoken alerts,
/// and a [TripRecord] when it ends.
///
/// Speed prefers real GPS. When GPS is unavailable (web / denied), a smooth
/// random-walk simulation keeps demos working.
class DriveProvider extends ChangeNotifier {
  DriveProvider({
    HazardDetector? detector,
    TtsService? tts,
    GpsService? gps,
    PermissionService? permissions,
    Random? random,
  }) : _detector = detector ?? SimulatedHazardDetector(),
       _tts = tts ?? TtsService(),
       _gps = gps ?? GpsService(),
       _permissions = permissions ?? PermissionService(),
       _random = random ?? Random();

  final HazardDetector _detector;
  final TtsService _tts;
  final GpsService _gps;
  final PermissionService _permissions;
  final Random _random;

  /// Default limit until Module 3 supplies sign-based limits.
  static const speedLimitKph = 60;

  /// Voice when speed exceeds limit by this margin (km/h).
  static const overspeedMarginKph = 3;

  /// Minimum gap between overspeed voice alerts.
  static const overspeedCooldown = Duration(seconds: 45);

  /// M7 FE-1: trip arms once speed exceeds this.
  static const tripStartKph = 5.0;

  /// Treat below this as stationary for auto-end.
  static const stationaryKph = 2.0;

  /// M7 FE-1: end after this long while nearly stopped.
  static const stationaryEndAfter = Duration(minutes: 5);

  StreamSubscription<HazardDetection>? _detectionSub;
  StreamSubscription<GpsSample>? _gpsSub;
  Timer? _ticker;
  DateTime? _startedAt;
  DateTime? _lastOverspeedVoiceAt;
  DateTime? _stationarySince;

  DriveStatus _status = DriveStatus.idle;
  int _elapsedSeconds = 0;
  double _distanceMeters = 0;
  double _speedKph = 0;
  double _maxSpeedKph = 0;
  int _overspeedCount = 0;
  bool _wasOverspeed = false;
  bool _usingGps = false;
  bool _micGranted = true;
  bool _settingsVoicePreferred = true;

  final List<HazardEvent> _events = [];
  final Map<HazardType, int> _counts = {};
  HazardEvent? _lastAlert;
  bool _showOverspeedBanner = false;

  LanguagePreference _language = LanguagePreference.english;

  DriveStatus get status => _status;
  bool get isRunning => _status == DriveStatus.running;
  bool get isPaused => _status == DriveStatus.paused;
  bool get isArming => _status == DriveStatus.arming;
  int get elapsedSeconds => _elapsedSeconds;
  double get distanceMeters => _distanceMeters;
  double get speedKph => _speedKph;
  double get maxSpeedKph => _maxSpeedKph;
  int get overspeedCount => _overspeedCount;
  bool get isOverspeed => _speedKph > speedLimitKph;
  bool get usingGps => _usingGps;
  bool get micGranted => _micGranted;
  bool get showOverspeedBanner => _showOverspeedBanner;
  bool get usingRealtimeModel {
    final d = _detector;
    return d is CameraYoloHazardDetector && d.usingRealtimeModel;
  }
  List<HazardEvent> get events => List.unmodifiable(_events);
  Map<HazardType, int> get counts => Map.unmodifiable(_counts);
  int get hazardCount => _events.length;
  HazardEvent? get lastAlert => _lastAlert;

  /// Effective voice: settings + mic permission (FE-6) + in-session mute.
  bool get voiceEnabled => _settingsVoicePreferred && _micGranted;

  SpeedBand get speedBand => SpeedBand.from(
        speedKph: _speedKph,
        limitKph: speedLimitKph.toDouble(),
      );

  Future<void> configure({
    required LanguagePreference language,
    required bool voiceEnabled,
  }) async {
    _language = language;
    _settingsVoicePreferred = voiceEnabled;
    _micGranted = await _permissions.isMicrophoneGranted();
    notifyListeners();
  }

  /// Re-check mic (e.g. after returning from system settings).
  Future<void> refreshMicrophonePermission() async {
    final granted = await _permissions.isMicrophoneGranted();
    if (granted == _micGranted) return;
    _micGranted = granted;
    if (!_micGranted) await _tts.stop();
    notifyListeners();
  }

  /// Mutes or unmutes spoken alerts for the current session only.
  /// No-op when microphone is denied (FE-6 forces visual-only).
  void toggleVoice() {
    if (!_micGranted) return;
    _settingsVoicePreferred = !_settingsVoicePreferred;
    if (!voiceEnabled) _tts.stop();
    notifyListeners();
  }

  Future<void> start() async {
    if (_status == DriveStatus.running || _status == DriveStatus.arming) {
      return;
    }

    _resetState();
    _micGranted = await _permissions.isMicrophoneGranted();

    _usingGps = await _gps.start();
    if (_usingGps) {
      _gpsSub = _gps.samples.listen(_onGpsSample);
      _status = DriveStatus.arming;
      notifyListeners();
      // Start AI immediately so hazards work while standing still (demos / traffic lights).
      await _ensureDetectorListening();
    } else {
      // Simulation: start rolling so Chrome / denied-GPS demos still work.
      _speedKph = 18 + _random.nextDouble() * 12;
      await _beginActiveTrip();
    }

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  /// Manual override when GPS stays at 0 (indoor demo / parked test).
  Future<void> forceStartTrip() async {
    if (_status != DriveStatus.arming) return;
    await _beginActiveTrip(alreadyDetecting: true);
  }

  Future<void> _ensureDetectorListening() async {
    await _detector.start();
    await _detectionSub?.cancel();
    _detectionSub = _detector.detections.listen(_onDetection);
    notifyListeners();
  }

  Future<void> _beginActiveTrip({bool alreadyDetecting = false}) async {
    if (_status == DriveStatus.running) return;

    _status = DriveStatus.running;
    _startedAt = DateTime.now();
    _stationarySince = null;
    notifyListeners();

    if (!alreadyDetecting) {
      await _ensureDetectorListening();
    }
  }

  void togglePause() {
    if (_status == DriveStatus.running) {
      _status = DriveStatus.paused;
      _stationarySince = null;
    } else if (_status == DriveStatus.paused) {
      _status = DriveStatus.running;
    }
    notifyListeners();
  }

  /// Ends the drive and returns the recorded trip, or null if nothing usable
  /// was captured (e.g. stopped while still arming).
  Future<TripRecord?> stop() async {
    if (_status == DriveStatus.idle) return null;

    final wasArming = _status == DriveStatus.arming;
    _status = DriveStatus.finished;
    await _tearDownSensors();
    await _tts.stop();
    notifyListeners();

    if (wasArming || (_elapsedSeconds < 2 && _events.isEmpty)) {
      return null;
    }

    return TripRecord(
      id: (_startedAt ?? DateTime.now()).microsecondsSinceEpoch.toString(),
      startedAt: _startedAt ?? DateTime.now(),
      durationSeconds: _elapsedSeconds,
      distanceMeters: _distanceMeters,
      maxSpeedKph: _maxSpeedKph,
      overspeedCount: _overspeedCount,
      hazards: Map<HazardType, int>.from(_counts),
    );
  }

  Future<void> _tearDownSensors() async {
    await _detectionSub?.cancel();
    _detectionSub = null;
    await _gpsSub?.cancel();
    _gpsSub = null;
    _ticker?.cancel();
    _ticker = null;
    await _detector.stop();
    await _gps.stop();
  }

  void clearAlert() {
    _lastAlert = null;
    notifyListeners();
  }

  void clearOverspeedBanner() {
    if (!_showOverspeedBanner) return;
    _showOverspeedBanner = false;
    notifyListeners();
  }

  void reset() {
    _resetState();
    _status = DriveStatus.idle;
    notifyListeners();
  }

  void _resetState() {
    _elapsedSeconds = 0;
    _distanceMeters = 0;
    _speedKph = 0;
    _maxSpeedKph = 0;
    _overspeedCount = 0;
    _wasOverspeed = false;
    _events.clear();
    _counts.clear();
    _lastAlert = null;
    _showOverspeedBanner = false;
    _startedAt = null;
    _lastOverspeedVoiceAt = null;
    _stationarySince = null;
    _usingGps = false;
  }

  void _onGpsSample(GpsSample sample) {
    if (_status == DriveStatus.idle || _status == DriveStatus.finished) return;
    if (_status == DriveStatus.paused) return;

    _speedKph = sample.speedKph.clamp(0, 200);
    if (_speedKph > _maxSpeedKph) _maxSpeedKph = _speedKph;

    if (_status == DriveStatus.arming && _speedKph >= tripStartKph) {
      unawaited(_beginActiveTrip(alreadyDetecting: true));
      return;
    }

    _handleOverspeedLogic();
    notifyListeners();
  }

  void _tick() {
    if (_status == DriveStatus.arming) {
      // Still show live GPS speed while waiting to roll.
      notifyListeners();
      return;
    }
    if (_status != DriveStatus.running) return;

    _elapsedSeconds++;

    if (!_usingGps) {
      // Smooth random walk around city speeds for non-GPS demos.
      final drift = (_random.nextDouble() - 0.45) * 12;
      _speedKph = (_speedKph + drift).clamp(0, 85);
      if (_speedKph > _maxSpeedKph) _maxSpeedKph = _speedKph;
      _handleOverspeedLogic();
    }

    // Integrate distance for this 1-second slice.
    _distanceMeters += _speedKph * 1000 / 3600;

    _checkStationaryAutoEnd();
    notifyListeners();
  }

  void _handleOverspeedLogic() {
    final over = _speedKph > speedLimitKph;
    if (over && !_wasOverspeed) {
      _overspeedCount++;
      _showOverspeedBanner = true;
    }
    _wasOverspeed = over;

    // Voice only when over by a margin, with cooldown (M4 FE-4 / FE-5).
    final shouldWarn =
        _speedKph > speedLimitKph + overspeedMarginKph && voiceEnabled;
    if (!shouldWarn) return;

    final now = DateTime.now();
    final last = _lastOverspeedVoiceAt;
    if (last != null && now.difference(last) < overspeedCooldown) return;

    _lastOverspeedVoiceAt = now;
    _showOverspeedBanner = true;
    unawaited(
      _tts.announceOverspeed(_language, limitKph: speedLimitKph),
    );
  }

  void _checkStationaryAutoEnd() {
    if (_speedKph >= stationaryKph) {
      _stationarySince = null;
      return;
    }

    _stationarySince ??= DateTime.now();
    if (DateTime.now().difference(_stationarySince!) >= stationaryEndAfter) {
      unawaited(_autoEnd());
    }
  }

  Future<void> _autoEnd() async {
    if (_status != DriveStatus.running) return;
    _autoEnded = true;
    final trip = await stop();
    _completedTrip = trip;
    notifyListeners();
  }

  bool _autoEnded = false;
  TripRecord? _completedTrip;

  /// Consumed by DriveScreen after an automatic stop.
  bool get didAutoEnd => _autoEnded;

  TripRecord? takeCompletedTrip() {
    final trip = _completedTrip;
    _completedTrip = null;
    _autoEnded = false;
    return trip;
  }

  void _onDetection(HazardDetection detection) {
    if (_status == DriveStatus.idle ||
        _status == DriveStatus.finished ||
        _status == DriveStatus.paused) {
      return;
    }

    // First detection while waiting for motion → start the trip (good for demos).
    if (_status == DriveStatus.arming) {
      _status = DriveStatus.running;
      _startedAt = DateTime.now();
      _stationarySince = null;
    }

    final event = HazardEvent(
      type: detection.type,
      at: DateTime.now(),
      confidence: detection.confidence,
      speedKph: _speedKph,
      distanceMeters: detection.distanceMeters,
    );
    _events.add(event);
    _counts[detection.type] = (_counts[detection.type] ?? 0) + 1;
    _lastAlert = event;
    notifyListeners();

    if (voiceEnabled) {
      // Extra guard against bilingual double-spam from rapid events.
      unawaited(
        _tts.announceHazard(
          detection.type,
          _language,
          distanceMeters: detection.distanceMeters,
        ),
      );
    }
  }

  @override
  void dispose() {
    _detectionSub?.cancel();
    _gpsSub?.cancel();
    _ticker?.cancel();
    _detector.dispose();
    _gps.dispose();
    _tts.stop();
    super.dispose();
  }
}
