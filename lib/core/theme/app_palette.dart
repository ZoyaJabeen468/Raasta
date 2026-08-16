import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Surface and text tokens that flip between light and dark themes.
///
/// Read it with `context.palette` instead of reaching for [AppColors]
/// directly, so every screen follows the dark-mode setting.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.brand,
    required this.brandSoft,
    required this.shadow,
    required this.washTop,
    required this.washBottom,
    required this.blob,
  });

  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color brand;
  final Color brandSoft;
  final Color shadow;

  /// Ambient page wash. Screens sit on this tinted gradient rather than a
  /// flat [background], with [blob] used for the soft out-of-focus circles.
  final Color washTop;
  final Color washBottom;
  final Color blob;

  static const light = AppPalette(
    background: AppColors.mist,
    surface: AppColors.white,
    surfaceAlt: Color(0xFFF0F3F5),
    border: AppColors.fog,
    textPrimary: AppColors.ink,
    textSecondary: AppColors.slate,
    brand: AppColors.teal,
    brandSoft: AppColors.tealSoft,
    shadow: Color(0x14000000),
    washTop: Color(0xFFDCEFEC),
    washBottom: Color(0xFFF7FAFA),
    blob: Color(0x22129188),
  );

  static const dark = AppPalette(
    background: AppColors.night,
    surface: AppColors.nightSurface,
    surfaceAlt: AppColors.nightAlt,
    border: AppColors.nightBorder,
    textPrimary: AppColors.chalk,
    textSecondary: AppColors.ash,
    brand: AppColors.tealBright,
    brandSoft: Color(0xFF15302E),
    shadow: Color(0x33000000),
    washTop: Color(0xFF102624),
    washBottom: AppColors.night,
    blob: Color(0x1A1AA89E),
  );

  @override
  AppPalette copyWith({
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? brand,
    Color? brandSoft,
    Color? shadow,
    Color? washTop,
    Color? washBottom,
    Color? blob,
  }) {
    return AppPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      brand: brand ?? this.brand,
      brandSoft: brandSoft ?? this.brandSoft,
      shadow: shadow ?? this.shadow,
      washTop: washTop ?? this.washTop,
      washBottom: washBottom ?? this.washBottom,
      blob: blob ?? this.blob,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      brand: Color.lerp(brand, other.brand, t)!,
      brandSoft: Color.lerp(brandSoft, other.brandSoft, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      washTop: Color.lerp(washTop, other.washTop, t)!,
      washBottom: Color.lerp(washBottom, other.washBottom, t)!,
      blob: Color.lerp(blob, other.blob, t)!,
    );
  }
}

extension AppPaletteX on BuildContext {
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
}
