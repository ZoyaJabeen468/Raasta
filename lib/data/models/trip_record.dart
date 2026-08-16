import 'hazard_type.dart';

/// One completed drive, stored locally after the trip ends.
class TripRecord {
  const TripRecord({
    required this.id,
    required this.startedAt,
    required this.durationSeconds,
    required this.distanceMeters,
    required this.hazards,
    this.maxSpeedKph = 0,
    this.overspeedCount = 0,
  });

  final String id;
  final DateTime startedAt;
  final int durationSeconds;
  final double distanceMeters;

  /// Hazard counts keyed by type; absent types mean zero detections.
  final Map<HazardType, int> hazards;

  final double maxSpeedKph;

  /// Times the driver crossed the speed limit during the trip.
  final int overspeedCount;

  int get hazardCount => hazards.values.fold(0, (sum, n) => sum + n);

  double get distanceKm => distanceMeters / 1000;

  double get avgSpeedKph {
    if (durationSeconds <= 0) return 0;
    return distanceKm / (durationSeconds / 3600);
  }

  /// 0–100. Starts at 100 and drops with hazards encountered per kilometre
  /// plus a penalty for speeding. Very short trips are scored on raw hazard
  /// count so one pothole in the first 50 metres doesn't zero the score.
  int get safetyScore {
    final perKm = distanceKm < 0.5
        ? hazardCount * 2
        : hazardCount / distanceKm;
    final score = 100 - (perKm * 8).round() - (overspeedCount * 4);
    return score.clamp(0, 100);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'startedAt': startedAt.toIso8601String(),
      'durationSeconds': durationSeconds,
      'distanceMeters': distanceMeters,
      'maxSpeedKph': maxSpeedKph,
      'overspeedCount': overspeedCount,
      'hazards': hazards.map((k, v) => MapEntry(k.name, v)),
    };
  }

  static TripRecord fromMap(Map<dynamic, dynamic> map) {
    final raw = Map<dynamic, dynamic>.from(
      (map['hazards'] as Map?) ?? const {},
    );
    return TripRecord(
      id: map['id'] as String? ?? '',
      startedAt:
          DateTime.tryParse(map['startedAt'] as String? ?? '') ??
          DateTime.now(),
      durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 0,
      distanceMeters: (map['distanceMeters'] as num?)?.toDouble() ?? 0,
      maxSpeedKph: (map['maxSpeedKph'] as num?)?.toDouble() ?? 0,
      overspeedCount: (map['overspeedCount'] as num?)?.toInt() ?? 0,
      hazards: {
        for (final entry in raw.entries)
          HazardType.fromName(entry.key as String?):
              (entry.value as num?)?.toInt() ?? 0,
      },
    );
  }
}
