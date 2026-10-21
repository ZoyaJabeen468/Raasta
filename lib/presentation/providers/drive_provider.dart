import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/utils/speed_band.dart';
import '../../data/models/hazard_event.dart';
import '../../data/models/hazard_type.dart';
import '../../data/models/language_preference.dart';
import '../../data/models/traffic_sign.dart';
import '../../data/models/trip_record.dart';
import '../../data/services/camera_yolo_detector.dart';
import '../../data/services/gps_service.dart';
import '../../data/services/hazard_detector.dart';
import '../../data/services/sign_detector.dart';
import '../../data/services/tts_service.dart';
import '../../data/services/wrong_way_service.dart';
import '../screens/drive/models/drive_alert.dart';

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
    WrongWayService? wrongWay,
    SignDetector? signs,
    Random? random,
  }) : _detector = detector ?? SimulatedHazardDetector(),
       _tts = tts ?? TtsService(),
       _gps = gps ?? GpsService(),
       _wrongWay = wrongWay ?? WrongWayService(),
       _signs = signs ?? SignDetector(),
       _random = random ?? Random();

  final HazardDetector _detector;
  final SignDetector _signs;
  final TtsService _tts;
  final GpsService _gps;
  final WrongWayService _wrongWay;
  final Random _random;

  /// Fallback until a speed-limit sign is confirmed this trip.
  static const defaultSpeedLimitKph = 60;

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

  /// M3: how long the sign card stays on screen.
  static const signCardDuration = Duration(seconds: 5);

  /// M3: don't speak a sign right after an overspeed warning.
  static const signAfterOverspeedGap = Duration(seconds: 6);

  StreamSubscription<HazardDetection>? _detectionSub;
  StreamSubscription<SignDetection>? _signSub;
  StreamSubscription<SignDetection>? _signReadingSub;
  Timer? _signCardTimer;
  SignDetection? _lastSign;
  SignDetection? _visibleSign;
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
  int _speedLimitKph = defaultSpeedLimitKph;
  int _overspeedCount = 0;
  bool _wasOverspeed = false;
  bool _usingGps = false;
  bool _settingsVoicePreferred = true;
  bool _hazardAlerts = true;
  bool _wrongWayDemo = false;
  bool _pausedBySystem = false;
  DriveStatus? _resumeStatus;
  double? _lastHeadingDegrees;
  bool _lastHeadingAccurate = false;

  final List<HazardEvent> _events = [];
  final Map<HazardType, int> _counts = {};
  DriveAlert? _activeAlert;
  final List<DriveAlert> _alertQueue = [];
  int? _wrongWayConfirmSeconds;

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
  int get speedLimitKph => _speedLimitKph;
  bool get isOverspeed => _speedKph > speedLimitKph;
  bool get usingGps => _usingGps;
  bool get hazardAlertsEnabled => _hazardAlerts;
  DriveAlert? get activeAlert => _activeAlert;
  bool get wrongWayDemoMode => _wrongWayDemo;
  /// Seconds into M6 confirm window (demo or real), for HUD progress.
  int? get wrongWayConfirmSeconds => _wrongWayConfirmSeconds;
  bool get usingRealtimeModel {
    final d = _detector;
    return d is CameraYoloHazardDetector && d.usingRealtimeModel;
  }
  List<HazardEvent> get events => List.unmodifiable(_events);
  Map<HazardType, int> get counts => Map.unmodifiable(_counts);
  int get hazardCount => _events.length;

  /// Most recent confirmed sign this drive (kept for M4 speed limits).
  SignDetection? get lastSign => _lastSign;

  /// Sign shown on the Drive card; cleared after [signCardDuration].
  SignDetection? get visibleSign => _visibleSign;

  /// Spoken alerts follow the voice setting and the in-session mute.
  /// Text-to-speech does not need the microphone.
  bool get voiceEnabled => _settingsVoicePreferred;

  SpeedBand get speedBand => SpeedBand.from(
        speedKph: _speedKph,
        limitKph: speedLimitKph.toDouble(),
      );

  void didChangeAppLifecycleState(AppLifecycleState state) {
    final background = state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached;
    if (background) {
      if (_status == DriveStatus.running || _status == DriveStatus.arming) {
        _resumeStatus = _status;
        _pausedBySystem = true;
        _status = DriveStatus.paused;
        _stationarySince = null;
        _updateWakelock();
        notifyListeners();
        unawaited(_suspendSensors());
      } else if (_status == DriveStatus.paused) {
        unawaited(_suspendSensors());
      }
      return;
    }

    if (state == AppLifecycleState.resumed &&
        _pausedBySystem &&
        _status == DriveStatus.paused) {
      _pausedBySystem = false;
      _status = _resumeStatus ?? DriveStatus.running;
      _resumeStatus = null;
      _updateWakelock();
      notifyListeners();
      unawaited(_resumeSensors());
    }
  }

  void _updateWakelock() {
    final hold =
        _status == DriveStatus.running || _status == DriveStatus.arming;
    if (hold) {
      unawaited(WakelockPlus.enable());
    } else {
      unawaited(WakelockPlus.disable());
    }
  }

  Future<void> _suspendSensors() async {
    await _detector.pauseCapture();
    if (_usingGps) await _gps.stop();
  }

  Future<void> _resumeSensors() async {
    if (_status != DriveStatus.running && _status != DriveStatus.arming) {
      return;
    }
    await _detector.resumeCapture();
    if (!_usingGps || _gps.isActive) return;
    final ok = await _gps.start();
    if (!ok || _gpsSub != null) return;
    _gpsSub = _gps.samples.listen(_onGpsSample);
  }

  Future<void> configure({
    required LanguagePreference language,
    required bool voiceEnabled,
    bool hazardAlerts = true,
    bool wrongWayDemoMode = false,
  }) async {
    _language = language;
    _settingsVoicePreferred = voiceEnabled;
    _hazardAlerts = hazardAlerts;
    _wrongWayDemo = wrongWayDemoMode;
    _wrongWay.demoForceConflict = wrongWayDemoMode;
    notifyListeners();
  }

  /// Mutes or unmutes spoken alerts for the current session only.
  void toggleVoice() {
    _settingsVoicePreferred = !_settingsVoicePreferred;
    if (!voiceEnabled) _tts.stop();
    notifyListeners();
  }

  Future<void> start() async {
    if (_status == DriveStatus.running || _status == DriveStatus.arming) {
      return;
    }

    _resetState();

    _usingGps = await _gps.start();
    if (_usingGps) {
      _gpsSub = _gps.samples.listen(_onGpsSample);
    } else {
      // Simulation: start rolling so Chrome / denied-GPS demos still work.
      _speedKph = 18 + _random.nextDouble() * 12;
    }
    _syncDetectorSpeed();

    // Opening Drive is the start. Don't wait for a second tap or for
    // speed to climb past the old arming threshold.
    await _ensureDetectorListening();
    await _beginActiveTrip(alreadyDetecting: true);

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _pauseIfAlreadyBackgrounded();
  }

  /// Covers a background transition that arrived before [start] finished.
  void _pauseIfAlreadyBackgrounded() {
    final state = WidgetsBinding.instance.lifecycleState;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      didChangeAppLifecycleState(state!);
    }
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
    await _startSignDetection();
    notifyListeners();
  }

  /// M3: shares camera frames from the M2 detector with the sign model.
  Future<void> _startSignDetection() async {
    await _signSub?.cancel();
    _signSub = null;
    await _signReadingSub?.cancel();
    _signReadingSub = null;
    final d = _detector;
    if (d is! CameraYoloHazardDetector) return;
    if (!await _signs.start()) return;
    _signSub = _signs.detections.listen(_onSign);
    _signReadingSub = _signs.readings.listen(_onSignReading);
    d.onFrameTap = _signs.onCameraFrame;
  }

  Future<void> _beginActiveTrip({bool alreadyDetecting = false}) async {
    if (_status == DriveStatus.running) return;

    _status = DriveStatus.running;
    _startedAt = DateTime.now();
    _stationarySince = null;
    _updateWakelock();
    notifyListeners();

    if (!alreadyDetecting) {
      await _ensureDetectorListening();
    }
  }

  void togglePause() {
    if (_status == DriveStatus.running) {
      _pausedBySystem = false;
      _resumeStatus = null;
      _status = DriveStatus.paused;
      _stationarySince = null;
      _updateWakelock();
      notifyListeners();
      unawaited(_suspendSensors());
    } else if (_status == DriveStatus.paused) {
      _pausedBySystem = false;
      _status = _resumeStatus ?? DriveStatus.running;
      _resumeStatus = null;
      _updateWakelock();
      notifyListeners();
      unawaited(_resumeSensors());
    }
  }

  /// Ends the drive and returns the recorded trip, or null if nothing usable
  /// was captured (e.g. stopped while still arming).
  Future<TripRecord?> stop() async {
    if (_status == DriveStatus.idle) return null;

    final wasArming = _status == DriveStatus.arming;
    _status = DriveStatus.finished;
    _updateWakelock();
    await _tearDownSensors();
    await _tts.stop();
    notifyListeners();

    if (wasArming || (_elapsedSeconds < 2 && _events.isEmpty)) {
      return null;
    }

    // Fallback hazards are scripted. They must not show up as a real trip.
    if (!usingRealtimeModel) return null;

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
    final d = _detector;
    if (d is CameraYoloHazardDetector) d.onFrameTap = null;
    await _signSub?.cancel();
    _signSub = null;
    await _signReadingSub?.cancel();
    _signReadingSub = null;
    _signCardTimer?.cancel();
    _visibleSign = null;
    await _signs.stop();
    await _detector.stop();
    await _gps.stop();
  }

  void dismissActiveAlert() {
    _activeAlert = null;
    _promoteNextAlert();
    notifyListeners();
  }

  void _enqueueAlert(DriveAlert alert) {
    if (_activeAlert == null) {
      _activeAlert = alert;
      notifyListeners();
      return;
    }
    final current = _activeAlert!;
    if (alert.priority > current.priority) {
      _alertQueue.add(current);
      _activeAlert = alert;
    } else if (alert.priority == current.priority) {
      // Same kind of hazard: the newer one is the one on the road now.
      _activeAlert = alert;
    } else {
      _alertQueue.add(alert);
    }
    _alertQueue.sort((a, b) => b.priority.compareTo(a.priority));
    notifyListeners();
  }

  void _promoteNextAlert() {
    if (_alertQueue.isEmpty) {
      _activeAlert = null;
      return;
    }
    _activeAlert = _alertQueue.removeAt(0);
  }

  void clearAlert() => dismissActiveAlert();

  void clearOverspeedBanner() => dismissActiveAlert();

  void reset() {
    _resetState();
    _status = DriveStatus.idle;
    _pausedBySystem = false;
    _resumeStatus = null;
    _updateWakelock();
    notifyListeners();
  }

  void _syncDetectorSpeed() {
    final d = _detector;
    if (d is CameraYoloHazardDetector) d.speedKph = _speedKph;
  }

  void _resetState() {
    _elapsedSeconds = 0;
    _distanceMeters = 0;
    _speedKph = 0;
    _syncDetectorSpeed();
    _maxSpeedKph = 0;
    _overspeedCount = 0;
    _wasOverspeed = false;
    _events.clear();
    _counts.clear();
    _activeAlert = null;
    _alertQueue.clear();
    _wrongWayConfirmSeconds = null;
    _startedAt = null;
    _lastOverspeedVoiceAt = null;
    _stationarySince = null;
    _usingGps = false;
    _pausedBySystem = false;
    _resumeStatus = null;
    _lastHeadingDegrees = null;
    _lastHeadingAccurate = false;
    _signCardTimer?.cancel();
    _lastSign = null;
    _visibleSign = null;
    _speedLimitKph = defaultSpeedLimitKph;
    _wrongWay.reset();
    _wrongWay.demoForceConflict = _wrongWayDemo;
  }

  void _onGpsSample(GpsSample sample) {
    if (_status == DriveStatus.idle || _status == DriveStatus.finished) return;
    if (_status == DriveStatus.paused) return;

    _speedKph = sample.speedKph.clamp(0, 200);
    _syncDetectorSpeed();
    if (_speedKph > _maxSpeedKph) _maxSpeedKph = _speedKph;
    _lastHeadingDegrees = sample.headingDegrees;
    _lastHeadingAccurate = WrongWayService.isHeadingUsable(
      sample.headingDegrees,
      sample.headingAccuracyDeg,
    );

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
      // Indoor tests have no GPS. Keep speed under the 60 km/h limit so
      // overspeed banners do not fire while you point the camera at a screen.
      final drift = (_random.nextDouble() - 0.5) * 4;
      _speedKph = (_speedKph + drift).clamp(28, 48);
      _syncDetectorSpeed();
      if (_speedKph > _maxSpeedKph) _maxSpeedKph = _speedKph;
    }

    // Integrate distance for this 1-second slice.
    _distanceMeters += _speedKph * 1000 / 3600;

    // M6: one tick per second so confirm timers stay accurate.
    _handleWrongWayLogic(
      headingDegrees: _lastHeadingDegrees,
      headingAccurate: _lastHeadingAccurate,
    );

    _checkStationaryAutoEnd();
    notifyListeners();
  }

  void _handleWrongWayLogic({
    required double? headingDegrees,
    required bool headingAccurate,
  }) {
    if (_status != DriveStatus.running) {
      _wrongWayConfirmSeconds = null;
      return;
    }

    final now = DateTime.now();
    final shouldAlert = _wrongWay.tick(
      tripActive: true,
      speedKph: _speedKph,
      now: now,
      headingDegrees: headingDegrees,
      headingAccurate: headingAccurate,
    );
    _wrongWayConfirmSeconds = _wrongWay.conflictElapsedSeconds(now);

    if (!shouldAlert) return;

    final event = HazardEvent(
      type: HazardType.wrongWay,
      at: now,
      confidence: 1,
      speedKph: _speedKph,
    );
    _events.add(event);
    _counts[HazardType.wrongWay] = (_counts[HazardType.wrongWay] ?? 0) + 1;
    _wrongWayConfirmSeconds = null;

    if (!_hazardAlerts) return;

    _enqueueAlert(DriveAlert.hazard(event));
    if (voiceEnabled) {
      unawaited(_tts.announceHazard(HazardType.wrongWay, _language));
    }
  }

  void _handleOverspeedLogic() {
    if (!_usingGps) return;
    final over = _speedKph > speedLimitKph;
    if (over && !_wasOverspeed) {
      _overspeedCount++;
      _enqueueAlert(
        DriveAlert.overspeed(
          speedKph: _speedKph,
          limitKph: speedLimitKph,
        ),
      );
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
    // Never count or speak unless the live TFLite model is running.
    if (!usingRealtimeModel) return;

    // First detection while waiting for motion → start the trip (good for demos).
    if (_status == DriveStatus.arming) {
      _status = DriveStatus.running;
      _startedAt = DateTime.now();
      _stationarySince = null;
      _updateWakelock();
    }

    final eta = _etaSeconds(detection.range);
    final event = HazardEvent(
      type: detection.type,
      at: DateTime.now(),
      confidence: detection.confidence,
      speedKph: _speedKph,
      range: detection.range,
      etaSeconds: eta,
    );
    _events.add(event);
    _counts[detection.type] = (_counts[detection.type] ?? 0) + 1;

    if (!_hazardAlerts) {
      notifyListeners();
      return;
    }

    _enqueueAlert(DriveAlert.hazard(event));

    if (voiceEnabled) {
      // Extra guard against bilingual double-spam from rapid events.
      unawaited(
        _tts.announceHazard(
          detection.type,
          _language,
          range: detection.range,
          etaSeconds: eta,
        ),
      );
    }
  }

  /// Band plus GPS speed, not a measured range. Null when nearly stopped.
  int? _etaSeconds(HazardRange? range) {
    if (range == null || _speedKph < 5) return null;
    final assumeM = switch (range) {
      HazardRange.near => 10.0,
      HazardRange.mid => 25.0,
      HazardRange.far => 45.0,
    };
    final sec = assumeM / (_speedKph / 3.6);
    return sec.round().clamp(2, 15);
  }

  bool get _signsActive =>
      _status != DriveStatus.idle &&
      _status != DriveStatus.finished &&
      _status != DriveStatus.paused;

  void _onSign(SignDetection sign) {
    if (!_signsActive) return;

    _showSignCard(sign);
    notifyListeners();

    if (sign.sign.action != SignAction.speak || !_signMayTalk) return;
    unawaited(
      _tts.announceSign(
        _language,
        english: sign.sign.english,
        urdu: sign.sign.urdu,
      ),
    );
  }

  /// OCR results from [SignDetector.readings].
  void _onSignReading(SignDetection reading) {
    if (!_signsActive) return;

    final limit = reading.ocrSpeedLimit;
    if (reading.sign.isSpeedLimitCandidate) {
      // M4: only an OCR-read number changes the limit, never the label.
      if (limit == null) return;
      _speedLimitKph = limit;
      _showSignCard(reading);
      notifyListeners();
      if (_signMayTalk) {
        unawaited(_tts.announceSpeedLimit(_language, limitKph: limit));
      }
      return;
    }

    // Other signs: add the OCR text to the card already on screen. Raw OCR
    // text is never spoken (too noisy).
    final visible = _visibleSign;
    if (visible == null || !visible.sameSightingAs(reading)) return;
    _visibleSign = reading;
    _lastSign = reading;
    notifyListeners();
  }

  void _showSignCard(SignDetection sign) {
    _lastSign = sign;
    _visibleSign = sign;
    _signCardTimer?.cancel();
    _signCardTimer = Timer(signCardDuration, () {
      final visible = _visibleSign;
      if (visible == null || !visible.sameSightingAs(sign)) return;
      _visibleSign = null;
      notifyListeners();
    });
  }

  /// Signs don't talk right after an overspeed warning (hazards are
  /// handled inside [TtsService.announceSign]).
  bool get _signMayTalk {
    if (!voiceEnabled) return false;
    final lastOverspeed = _lastOverspeedVoiceAt;
    return lastOverspeed == null ||
        DateTime.now().difference(lastOverspeed) >= signAfterOverspeedGap;
  }

  @override
  void dispose() {
    _detectionSub?.cancel();
    _signSub?.cancel();
    _signReadingSub?.cancel();
    _signCardTimer?.cancel();
    final d = _detector;
    if (d is CameraYoloHazardDetector) d.onFrameTap = null;
    _signs.dispose();
    _gpsSub?.cancel();
    _ticker?.cancel();
    _detector.dispose();
    _gps.dispose();
    _tts.stop();
    unawaited(WakelockPlus.disable());
    super.dispose();
  }
}
