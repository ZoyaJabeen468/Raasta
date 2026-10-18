import 'package:flutter/material.dart';

/// Brand palette aligned to the RAASTA teal product look.
///
/// Brand colours are constant across themes; surface/text tokens live in
/// [AppPalette] so they can flip with the active brightness.
abstract final class AppColors {
  static const Color forest = Color(0xFF062E2B);
  static const Color tealDeep = Color(0xFF0B5E57);
  static const Color teal = Color(0xFF129188);
  static const Color tealBright = Color(0xFF1AA89E);
  static const Color mint = Color(0xFF9AF0E0);
  static const Color tealSoft = Color(0xFFE6F5F3);

  static const Color ink = Color(0xFF12171C);
  static const Color slate = Color(0xFF6B7580);
  static const Color mist = Color(0xFFF5F7F8);
  static const Color fog = Color(0xFFE8ECF0);
  static const Color white = Color(0xFFFFFFFF);

  static const Color alert = Color(0xFFD64545);
  static const Color safe = Color(0xFF2F9E6B);
  static const Color amber = Color(0xFFE8A317);
  static const Color violet = Color(0xFF7A5AF8);
  static const Color sky = Color(0xFF3B82C4);

  // Dark surface ramp.
  static const Color night = Color(0xFF0E1315);
  static const Color nightSurface = Color(0xFF161D20);
  static const Color nightAlt = Color(0xFF1E272B);
  static const Color nightBorder = Color(0xFF2A353A);
  static const Color chalk = Color(0xFFECF1F2);
  static const Color ash = Color(0xFF97A4AB);

  /// Splash / brand gradient (matches product splash).
  static const LinearGradient splashGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF062E2B), Color(0xFF0B5E57), Color(0xFF0F7A72)],
  );

  static const LinearGradient driveGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0B5E57), Color(0xFF129188), Color(0xFF1AA89E)],
  );

  /// Home welcome card: deep teal left, turquoise right. Quieter than
  /// [driveGradient] so the card does not dominate the screen.
  static const LinearGradient homeHeroGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF0B5E57), Color(0xFF1AA89E)],
  );
}
