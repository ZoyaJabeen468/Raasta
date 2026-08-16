import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Visual speed band for the drive HUD (Module 4 FE-6).
enum SpeedBand {
  /// Comfortably under the limit.
  safe,

  /// Within ~10% of the limit — yellow caution.
  caution,

  /// Over the posted / default limit — red.
  over;

  static SpeedBand from({
    required double speedKph,
    required double limitKph,
  }) {
    if (speedKph > limitKph) return SpeedBand.over;
    if (speedKph >= limitKph * 0.9) return SpeedBand.caution;
    return SpeedBand.safe;
  }

  Color get color {
    switch (this) {
      case SpeedBand.safe:
        return AppColors.safe;
      case SpeedBand.caution:
        return AppColors.amber;
      case SpeedBand.over:
        return AppColors.alert;
    }
  }
}
