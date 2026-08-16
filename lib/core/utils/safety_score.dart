import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The single safety-score scale used by every score widget.
///
/// [ScoreRing] and [ScoreBar] previously carried their own thresholds, which
/// disagreed and let the same trip read "Good" in one place and "Fair" in
/// another.
abstract final class SafetyScale {
  static const excellent = 85;
  static const good = 70;
  static const fair = 50;

  /// [muted] is supplied by the caller so the no-data state follows the
  /// active light/dark palette.
  static Color tint(int score, {required bool hasData, required Color muted}) {
    if (!hasData) return muted;
    if (score >= excellent) return AppColors.safe;
    if (score >= good) return AppColors.tealBright;
    if (score >= fair) return AppColors.amber;
    return AppColors.alert;
  }

  static String verdict(int score, {required bool hasData}) {
    if (!hasData) return 'No trips yet';
    if (score >= excellent) return 'Excellent';
    if (score >= good) return 'Good';
    if (score >= fair) return 'Needs care';
    return 'Needs improvement';
  }
}
