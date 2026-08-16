import 'hazard_type.dart';
import 'trip_record.dart';

/// Aggregated view of a driver's trips, computed on demand.
class TripStats {
  const TripStats({
    required this.trips,
    required this.totalTrips,
    required this.totalHazards,
    required this.totalDistanceMeters,
    required this.totalDurationSeconds,
    required this.hazardBreakdown,
    required this.weekTrips,
    required this.weekHazards,
    required this.weekDistanceMeters,
    required this.weekDurationSeconds,
    required this.dailyHazards,
    required this.safetyScore,
    required this.streakDays,
  });

  final List<TripRecord> trips;
  final int totalTrips;
  final int totalHazards;
  final double totalDistanceMeters;
  final int totalDurationSeconds;

  /// Hazard counts across all trips, highest first.
  final List<MapEntry<HazardType, int>> hazardBreakdown;

  final int weekTrips;
  final int weekHazards;
  final double weekDistanceMeters;
  final int weekDurationSeconds;

  /// Hazards per day for the last 7 days, oldest first.
  final List<int> dailyHazards;

  /// Average safety score across all trips (100 when there are none).
  final int safetyScore;

  /// Consecutive days, ending today, with at least one trip.
  final int streakDays;

  bool get isEmpty => totalTrips == 0;

  static const empty = TripStats(
    trips: [],
    totalTrips: 0,
    totalHazards: 0,
    totalDistanceMeters: 0,
    totalDurationSeconds: 0,
    hazardBreakdown: [],
    weekTrips: 0,
    weekHazards: 0,
    weekDistanceMeters: 0,
    weekDurationSeconds: 0,
    dailyHazards: [0, 0, 0, 0, 0, 0, 0],
    safetyScore: 100,
    streakDays: 0,
  );

  factory TripStats.from(List<TripRecord> trips) {
    if (trips.isEmpty) return empty;

    final sorted = [...trips]
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(const Duration(days: 6));

    var totalHazards = 0;
    var totalDistance = 0.0;
    var totalDuration = 0;
    var weekTrips = 0;
    var weekHazards = 0;
    var weekDistance = 0.0;
    var weekDuration = 0;
    var scoreSum = 0;

    final breakdown = <HazardType, int>{};
    final daily = List<int>.filled(7, 0);
    final tripDays = <DateTime>{};

    for (final trip in sorted) {
      totalHazards += trip.hazardCount;
      totalDistance += trip.distanceMeters;
      totalDuration += trip.durationSeconds;
      scoreSum += trip.safetyScore;

      for (final entry in trip.hazards.entries) {
        if (entry.value <= 0) continue;
        breakdown[entry.key] = (breakdown[entry.key] ?? 0) + entry.value;
      }

      final day = DateTime(
        trip.startedAt.year,
        trip.startedAt.month,
        trip.startedAt.day,
      );
      tripDays.add(day);

      if (!day.isBefore(weekStart)) {
        weekTrips++;
        weekHazards += trip.hazardCount;
        weekDistance += trip.distanceMeters;
        weekDuration += trip.durationSeconds;

        final slot = day.difference(weekStart).inDays;
        if (slot >= 0 && slot < 7) daily[slot] += trip.hazardCount;
      }
    }

    var streak = 0;
    var cursor = today;
    while (tripDays.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    final ranked = breakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return TripStats(
      trips: sorted,
      totalTrips: sorted.length,
      totalHazards: totalHazards,
      totalDistanceMeters: totalDistance,
      totalDurationSeconds: totalDuration,
      hazardBreakdown: ranked,
      weekTrips: weekTrips,
      weekHazards: weekHazards,
      weekDistanceMeters: weekDistance,
      weekDurationSeconds: weekDuration,
      dailyHazards: daily,
      safetyScore: (scoreSum / sorted.length).round(),
      streakDays: streak,
    );
  }
}
