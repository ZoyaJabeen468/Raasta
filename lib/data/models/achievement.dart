import 'package:flutter/material.dart';

import 'trip_stats.dart';

/// Milestones unlocked from trip history.
class Achievement {
  const Achievement({
    required this.label,
    required this.icon,
    required this.requirement,
    required this.unlocked,
    required this.progress,
  });

  final String label;
  final IconData icon;
  final String requirement;
  final bool unlocked;

  /// 0–1 toward unlocking.
  final double progress;

  static List<Achievement> evaluate(TripStats stats) {
    return [
      Achievement(
        label: 'First trip',
        icon: Icons.emoji_flags_rounded,
        requirement: 'Finish one drive',
        unlocked: stats.totalTrips >= 1,
        progress: (stats.totalTrips / 1).clamp(0, 1).toDouble(),
      ),
      Achievement(
        label: '7-day streak',
        icon: Icons.local_fire_department_rounded,
        requirement: 'Drive 7 days in a row',
        unlocked: stats.streakDays >= 7,
        progress: (stats.streakDays / 7).clamp(0, 1).toDouble(),
      ),
      Achievement(
        label: 'Safe driver',
        icon: Icons.verified_user_rounded,
        requirement: 'Hold a safety score of 90+',
        unlocked: stats.totalTrips >= 3 && stats.safetyScore >= 90,
        progress: stats.totalTrips == 0
            ? 0
            : (stats.safetyScore / 90).clamp(0, 1).toDouble(),
      ),
      Achievement(
        label: 'Explorer',
        icon: Icons.explore_rounded,
        requirement: 'Cover 50 km with RAASTA',
        unlocked: stats.totalDistanceMeters >= 50000,
        progress: (stats.totalDistanceMeters / 50000).clamp(0, 1).toDouble(),
      ),
    ];
  }
}
