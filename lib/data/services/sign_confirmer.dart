import '../models/sign_detection.dart';
import '../models/traffic_sign.dart';

/// Turns per-frame sign hits into confirmed signs (no camera, no model).
///
/// A sign is confirmed when it is seen in [requiredStreak] consecutive
/// inferences and wasn't confirmed in the last [cooldown]. Only signs with
/// [TrafficSign.wantsOcr] count; other ignore classes never confirm.
class SignConfirmer {
  SignConfirmer({
    this.requiredStreak = 3,
    this.cooldown = const Duration(seconds: 20),
    this.confThreshold = 0.62,
  });

  final int requiredStreak;
  final Duration cooldown;
  final double confThreshold;

  final Map<TrafficSign, int> _streak = {};
  final Map<TrafficSign, DateTime> _lastConfirmedAt = {};

  /// Feeds one inference's hits. Returns at most one confirmed sign:
  /// spoken signs first, then shown signs, then the speed-limit candidate,
  /// then by confidence.
  SignDetection? add(List<SignDetection> hits, DateTime now) {
    // Best box per sign for this frame.
    final best = <TrafficSign, SignDetection>{};
    for (final h in hits) {
      if (h.confidence < confThreshold || !h.sign.wantsOcr) continue;
      final prev = best[h.sign];
      if (prev == null || h.confidence > prev.confidence) best[h.sign] = h;
    }

    // Streaks only survive across consecutive frames.
    _streak.removeWhere((sign, _) => !best.containsKey(sign));
    for (final sign in best.keys) {
      _streak[sign] = (_streak[sign] ?? 0) + 1;
    }

    final ready = best.values.where((d) {
      if ((_streak[d.sign] ?? 0) < requiredStreak) return false;
      final last = _lastConfirmedAt[d.sign];
      return last == null || now.difference(last) >= cooldown;
    }).toList();
    if (ready.isEmpty) return null;

    ready.sort((a, b) {
      final ap = _rank(a.sign);
      final bp = _rank(b.sign);
      if (ap != bp) return bp.compareTo(ap);
      return b.confidence.compareTo(a.confidence);
    });
    final pick = ready.first;
    _lastConfirmedAt[pick.sign] = now;
    _streak[pick.sign] = 0;
    return pick;
  }

  void reset() {
    _streak.clear();
    _lastConfirmedAt.clear();
  }

  static int _rank(TrafficSign sign) => switch (sign.action) {
    SignAction.speak => 2,
    SignAction.show => 1,
    SignAction.ignore => 0,
  };
}

/// Battery gate for OCR (work plan 6.1 step 6): one job at a time, and the
/// same sign at most once per [perSignGap].
class OcrGate {
  OcrGate({this.perSignGap = const Duration(seconds: 10)});

  final Duration perSignGap;
  bool _busy = false;
  final Map<TrafficSign, DateTime> _lastRunAt = {};

  bool get isBusy => _busy;

  /// Returns true and marks the gate busy if OCR may run for [sign] now.
  bool tryBegin(TrafficSign sign, DateTime now) {
    if (_busy || !sign.wantsOcr) return false;
    final last = _lastRunAt[sign];
    if (last != null && now.difference(last) < perSignGap) return false;
    _busy = true;
    _lastRunAt[sign] = now;
    return true;
  }

  void end() => _busy = false;

  void reset() {
    _busy = false;
    _lastRunAt.clear();
  }
}
