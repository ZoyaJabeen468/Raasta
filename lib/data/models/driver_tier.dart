import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'trip_stats.dart';

/// Driver standing shown on the profile header.
///
/// Earned from logged trips and gated on safety score, so a driver can't
/// climb tiers purely by racking up distance.
enum DriverTier {
  newDriver('New driver', Icons.explore_outlined, AppColors.slate),
  bronze('Bronze', Icons.workspace_premium_outlined, Color(0xFFB0713C)),
  silver('Silver', Icons.workspace_premium_rounded, Color(0xFF8E9AA3)),
  gold('Gold', Icons.military_tech_rounded, AppColors.amber),
  platinum('Platinum', Icons.shield_moon_rounded, AppColors.tealBright);

  const DriverTier(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;

  static DriverTier of(TripStats stats) {
    final trips = stats.totalTrips;
    final score = stats.safetyScore;

    if (trips == 0) return DriverTier.newDriver;
    if (trips >= 50 && score >= 85) return DriverTier.platinum;
    if (trips >= 25 && score >= 70) return DriverTier.gold;
    if (trips >= 10) return DriverTier.silver;
    return DriverTier.bronze;
  }

  /// Short line explaining what unlocks the next tier.
  String nextGoal(TripStats stats) {
    switch (this) {
      case DriverTier.newDriver:
        return 'Log your first drive to reach Bronze';
      case DriverTier.bronze:
        return '${10 - stats.totalTrips} more trips to reach Silver';
      case DriverTier.silver:
        return 'Reach 25 trips with a 70+ score for Gold';
      case DriverTier.gold:
        return 'Reach 50 trips with an 85+ score for Platinum';
      case DriverTier.platinum:
        return 'Top tier — keep that score up';
    }
  }
}
