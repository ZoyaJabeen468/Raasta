/// M6 wrong-way detection without a custom neural net.
///
/// **Real drive:** locks a forward [baselineHeading] while the trip is moving,
/// then treats a sustained ~opposite GPS heading as conflict. After
/// [confirmFor], fires one alert and applies [cooldown].
///
/// **Demo mode:** [demoForceConflict] simulates conflict so a viva can show the
/// delayed alert indoors (uses [demoConfirmFor], shorter than real confirm).
class WrongWayService {
  static const confirmFor = Duration(seconds: 60);
  static const demoConfirmFor = Duration(seconds: 20);
  static const cooldown = Duration(seconds: 90);

  /// Ignore near-stationary heading noise.
  static const minSpeedKph = 8.0;

  /// Degrees from baseline that count as “opposite enough”.
  static const oppositeThresholdDeg = 135.0;

  /// Consecutive good samples before locking the road direction.
  static const baselineLockSamples = 5;

  /// Max headingAccuracy (degrees) accepted from Geolocator.
  static const maxHeadingAccuracyDeg = 45.0;

  bool demoForceConflict = false;

  double? _baselineHeading;
  int _baselineHits = 0;
  DateTime? _conflictSince;
  DateTime? _lastAlertAt;

  double? get baselineHeading => _baselineHeading;

  /// Seconds into the current conflict window, or null if none.
  int? conflictElapsedSeconds(DateTime now) {
    final since = _conflictSince;
    if (since == null) return null;
    return now.difference(since).inSeconds;
  }

  Duration get _confirmDuration =>
      demoForceConflict ? demoConfirmFor : confirmFor;

  void reset() {
    _baselineHeading = null;
    _baselineHits = 0;
    _conflictSince = null;
    _lastAlertAt = null;
  }

  /// Call each GPS sample or 1 Hz tick while the trip is active.
  /// Returns `true` when a wrong-way alert should fire once.
  bool tick({
    required bool tripActive,
    required double speedKph,
    required DateTime now,
    double? headingDegrees,
    bool headingAccurate = false,
  }) {
    if (!tripActive) {
      _conflictSince = null;
      return false;
    }

    final moving = speedKph >= minSpeedKph;
    // Demo: conflict while trip is active (works indoors / parked).
    // Real: only when moving with a usable opposite heading vs baseline.
    final conflict = demoForceConflict
        ? true
        : _gpsConflict(
            moving: moving,
            headingDegrees: headingDegrees,
            headingAccurate: headingAccurate,
          );

    if (!conflict) {
      _conflictSince = null;
      return false;
    }

    _conflictSince ??= now;
    if (now.difference(_conflictSince!) < _confirmDuration) return false;

    final last = _lastAlertAt;
    if (last != null && now.difference(last) < cooldown) return false;

    _lastAlertAt = now;
    // Keep conflict window; cooldown blocks re-fire. Clear timer so a new
    // 60s confirm is required after cooldown if still wrong-way.
    _conflictSince = null;
    return true;
  }

  bool _gpsConflict({
    required bool moving,
    required double? headingDegrees,
    required bool headingAccurate,
  }) {
    if (!moving || headingDegrees == null || !headingAccurate) return false;

    if (_baselineHeading == null) {
      _baselineHits++;
      if (_baselineHits >= baselineLockSamples) {
        _baselineHeading = headingDegrees;
      }
      return false;
    }

    return headingDelta(_baselineHeading!, headingDegrees) >=
        oppositeThresholdDeg;
  }

  /// Smallest angle between two compass headings (0–180).
  static double headingDelta(double a, double b) {
    var d = (a - b).abs() % 360;
    if (d > 180) d = 360 - d;
    return d;
  }

  /// Geolocator: heading &lt; 0 or NaN means unavailable.
  static bool isHeadingUsable(double? heading, double? accuracyDeg) {
    if (heading == null || heading.isNaN || heading < 0) return false;
    if (accuracyDeg != null &&
        !accuracyDeg.isNaN &&
        accuracyDeg >= 0 &&
        accuracyDeg > maxHeadingAccuracyDeg) {
      return false;
    }
    return true;
  }
}
