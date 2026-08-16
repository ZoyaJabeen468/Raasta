import 'hazard_type.dart';
import 'trip_record.dart';

/// Coarse parts of the day used for "safest time" style insights.
enum DayPart {
  earlyMorning,
  morning,
  afternoon,
  evening,
  night;

  String get label {
    switch (this) {
      case DayPart.earlyMorning:
        return 'Early morning';
      case DayPart.morning:
        return 'Morning';
      case DayPart.afternoon:
        return 'Afternoon';
      case DayPart.evening:
        return 'Evening';
      case DayPart.night:
        return 'Night';
    }
  }

  static DayPart of(DateTime time) {
    final hour = time.hour;
    if (hour >= 5 && hour < 9) return DayPart.earlyMorning;
    if (hour >= 9 && hour < 12) return DayPart.morning;
    if (hour >= 12 && hour < 17) return DayPart.afternoon;
    if (hour >= 17 && hour < 21) return DayPart.evening;
    return DayPart.night;
  }
}

class WeeklyReport {
  const WeeklyReport({
    required this.trips,
    required this.hazards,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.tripsPerDay,
    required this.hazardsPerDay,
    required this.dayLabels,
    required this.avgSpeedKph,
    required this.safetyScore,
    required this.mostActiveDay,
    required this.safestPart,
    required this.previousTrips,
  });

  final int trips;
  final int hazards;
  final double distanceMeters;
  final int durationSeconds;
  final List<int> tripsPerDay;
  final List<int> hazardsPerDay;
  final List<String> dayLabels;
  final double avgSpeedKph;
  final int safetyScore;
  final String? mostActiveDay;
  final DayPart? safestPart;
  final int previousTrips;

  bool get isEmpty => trips == 0;
  int get tripDelta => trips - previousTrips;
}

class MonthlyReport {
  const MonthlyReport({
    required this.trips,
    required this.hazards,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.tripsPerWeek,
    required this.weekLabels,
    required this.safetyScore,
    required this.previousSafetyScore,
    required this.previousTrips,
    required this.previousDistanceMeters,
  });

  final int trips;
  final int hazards;
  final double distanceMeters;
  final int durationSeconds;
  final List<int> tripsPerWeek;
  final List<String> weekLabels;
  final int safetyScore;
  final int previousSafetyScore;
  final int previousTrips;
  final double previousDistanceMeters;

  bool get isEmpty => trips == 0;
  int get scoreDelta => safetyScore - previousSafetyScore;
  int get tripDelta => trips - previousTrips;
  double get distanceDelta => distanceMeters - previousDistanceMeters;
}

class HazardReport {
  const HazardReport({
    required this.breakdown,
    required this.total,
    required this.thisMonth,
    required this.avgPerTrip,
    required this.worstDayPart,
  });

  final List<MapEntry<HazardType, int>> breakdown;
  final int total;
  final int thisMonth;
  final double avgPerTrip;
  final DayPart? worstDayPart;

  bool get isEmpty => total == 0;
  HazardType? get mostCommon =>
      breakdown.isEmpty ? null : breakdown.first.key;
}

class SpeedReport {
  const SpeedReport({
    required this.avgSpeedKph,
    required this.maxSpeedKph,
    required this.overspeedCount,
    required this.dailyAvgSpeed,
    required this.dayLabels,
    required this.fastestDay,
    required this.calmestPart,
  });

  final double avgSpeedKph;
  final double maxSpeedKph;
  final int overspeedCount;
  final List<double> dailyAvgSpeed;
  final List<String> dayLabels;
  final String? fastestDay;
  final DayPart? calmestPart;

  bool get isEmpty => avgSpeedKph <= 0 && maxSpeedKph <= 0;
}

/// Everything the Reports & Insights screen needs, derived from trip history.
class ReportBundle {
  const ReportBundle({
    required this.weekly,
    required this.monthly,
    required this.hazards,
    required this.speed,
    required this.hasTrips,
  });

  final WeeklyReport weekly;
  final MonthlyReport monthly;
  final HazardReport hazards;
  final SpeedReport speed;
  final bool hasTrips;

  static const _weekdayNames = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  factory ReportBundle.from(List<TripRecord> trips) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(const Duration(days: 6));
    final prevWeekStart = weekStart.subtract(const Duration(days: 7));
    final monthStart = DateTime(now.year, now.month);
    final prevMonthStart = DateTime(now.year, now.month - 1);

    final dayLabels = List.generate(7, (i) {
      final day = weekStart.add(Duration(days: i));
      return _weekdayNames[day.weekday - 1];
    });

    final tripsPerDay = List<int>.filled(7, 0);
    final hazardsPerDay = List<int>.filled(7, 0);
    final speedSumPerDay = List<double>.filled(7, 0);
    final speedCountPerDay = List<int>.filled(7, 0);

    var weekTrips = 0;
    var weekHazards = 0;
    var weekDistance = 0.0;
    var weekDuration = 0;
    var weekScoreSum = 0;
    var prevWeekTrips = 0;

    var monthTrips = 0;
    var monthHazards = 0;
    var monthDistance = 0.0;
    var monthDuration = 0;
    var monthScoreSum = 0;
    var prevMonthTrips = 0;
    var prevMonthDistance = 0.0;
    var prevMonthScoreSum = 0;

    final tripsPerWeekOfMonth = List<int>.filled(5, 0);

    final hazardTotals = <HazardType, int>{};
    var hazardsThisMonth = 0;

    final tripsByWeekday = <int, int>{};
    final hazardsByPart = <DayPart, int>{};
    final tripsByPart = <DayPart, int>{};
    final speedByPart = <DayPart, double>{};

    var totalSpeedSum = 0.0;
    var totalSpeedCount = 0;
    var maxSpeed = 0.0;
    var overspeed = 0;

    for (final trip in trips) {
      final day = DateTime(
        trip.startedAt.year,
        trip.startedAt.month,
        trip.startedAt.day,
      );
      final part = DayPart.of(trip.startedAt);

      for (final entry in trip.hazards.entries) {
        if (entry.value <= 0) continue;
        hazardTotals[entry.key] = (hazardTotals[entry.key] ?? 0) + entry.value;
      }

      tripsByWeekday[trip.startedAt.weekday] =
          (tripsByWeekday[trip.startedAt.weekday] ?? 0) + 1;
      tripsByPart[part] = (tripsByPart[part] ?? 0) + 1;
      hazardsByPart[part] = (hazardsByPart[part] ?? 0) + trip.hazardCount;
      speedByPart[part] = (speedByPart[part] ?? 0) + trip.avgSpeedKph;

      if (trip.avgSpeedKph > 0) {
        totalSpeedSum += trip.avgSpeedKph;
        totalSpeedCount++;
      }
      if (trip.maxSpeedKph > maxSpeed) maxSpeed = trip.maxSpeedKph;
      overspeed += trip.overspeedCount;

      if (!day.isBefore(weekStart)) {
        weekTrips++;
        weekHazards += trip.hazardCount;
        weekDistance += trip.distanceMeters;
        weekDuration += trip.durationSeconds;
        weekScoreSum += trip.safetyScore;

        final slot = day.difference(weekStart).inDays;
        if (slot >= 0 && slot < 7) {
          tripsPerDay[slot]++;
          hazardsPerDay[slot] += trip.hazardCount;
          if (trip.avgSpeedKph > 0) {
            speedSumPerDay[slot] += trip.avgSpeedKph;
            speedCountPerDay[slot]++;
          }
        }
      } else if (!day.isBefore(prevWeekStart)) {
        prevWeekTrips++;
      }

      if (!day.isBefore(monthStart)) {
        monthTrips++;
        monthHazards += trip.hazardCount;
        monthDistance += trip.distanceMeters;
        monthDuration += trip.durationSeconds;
        monthScoreSum += trip.safetyScore;
        hazardsThisMonth += trip.hazardCount;

        final weekIndex = ((day.day - 1) ~/ 7).clamp(0, 4);
        tripsPerWeekOfMonth[weekIndex]++;
      } else if (!day.isBefore(prevMonthStart)) {
        prevMonthTrips++;
        prevMonthDistance += trip.distanceMeters;
        prevMonthScoreSum += trip.safetyScore;
      }
    }

    String? mostActiveDay;
    if (tripsByWeekday.isNotEmpty) {
      final best = tripsByWeekday.entries.reduce(
        (a, b) => b.value > a.value ? b : a,
      );
      mostActiveDay = _weekdayNames[best.key - 1];
    }

    // Safest part of day = fewest hazards per trip among parts actually driven.
    DayPart? safestPart;
    var bestRate = double.infinity;
    for (final entry in tripsByPart.entries) {
      final rate = (hazardsByPart[entry.key] ?? 0) / entry.value;
      if (rate < bestRate) {
        bestRate = rate;
        safestPart = entry.key;
      }
    }

    DayPart? worstPart;
    var worstRate = -1.0;
    for (final entry in tripsByPart.entries) {
      final rate = (hazardsByPart[entry.key] ?? 0) / entry.value;
      if (rate > worstRate) {
        worstRate = rate;
        worstPart = entry.key;
      }
    }

    DayPart? calmestPart;
    var calmest = double.infinity;
    for (final entry in tripsByPart.entries) {
      final avg = (speedByPart[entry.key] ?? 0) / entry.value;
      if (avg > 0 && avg < calmest) {
        calmest = avg;
        calmestPart = entry.key;
      }
    }

    final dailyAvgSpeed = List<double>.generate(
      7,
      (i) => speedCountPerDay[i] == 0
          ? 0
          : speedSumPerDay[i] / speedCountPerDay[i],
    );

    String? fastestDay;
    var fastest = 0.0;
    for (var i = 0; i < 7; i++) {
      if (dailyAvgSpeed[i] > fastest) {
        fastest = dailyAvgSpeed[i];
        fastestDay = dayLabels[i];
      }
    }

    final ranked = hazardTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final hazardTotal = ranked.fold<int>(0, (sum, e) => sum + e.value);

    return ReportBundle(
      hasTrips: trips.isNotEmpty,
      weekly: WeeklyReport(
        trips: weekTrips,
        hazards: weekHazards,
        distanceMeters: weekDistance,
        durationSeconds: weekDuration,
        tripsPerDay: tripsPerDay,
        hazardsPerDay: hazardsPerDay,
        dayLabels: dayLabels,
        avgSpeedKph: weekDuration <= 0
            ? 0
            : (weekDistance / 1000) / (weekDuration / 3600),
        safetyScore: weekTrips == 0 ? 100 : (weekScoreSum / weekTrips).round(),
        mostActiveDay: mostActiveDay,
        safestPart: safestPart,
        previousTrips: prevWeekTrips,
      ),
      monthly: MonthlyReport(
        trips: monthTrips,
        hazards: monthHazards,
        distanceMeters: monthDistance,
        durationSeconds: monthDuration,
        tripsPerWeek: tripsPerWeekOfMonth,
        weekLabels: const ['W1', 'W2', 'W3', 'W4', 'W5'],
        safetyScore: monthTrips == 0
            ? 100
            : (monthScoreSum / monthTrips).round(),
        previousSafetyScore: prevMonthTrips == 0
            ? 100
            : (prevMonthScoreSum / prevMonthTrips).round(),
        previousTrips: prevMonthTrips,
        previousDistanceMeters: prevMonthDistance,
      ),
      hazards: HazardReport(
        breakdown: ranked,
        total: hazardTotal,
        thisMonth: hazardsThisMonth,
        avgPerTrip: trips.isEmpty ? 0 : hazardTotal / trips.length,
        worstDayPart: worstPart,
      ),
      speed: SpeedReport(
        avgSpeedKph: totalSpeedCount == 0 ? 0 : totalSpeedSum / totalSpeedCount,
        maxSpeedKph: maxSpeed,
        overspeedCount: overspeed,
        dailyAvgSpeed: dailyAvgSpeed,
        dayLabels: dayLabels,
        fastestDay: fastestDay,
        calmestPart: calmestPart,
      ),
    );
  }

  static final empty = ReportBundle.from(const []);
}
