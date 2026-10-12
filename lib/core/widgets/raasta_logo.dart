import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import '../theme/app_palette.dart';

/// RAASTA brand mark — same artwork as the launcher icon.
///
/// [dashPhase] is kept for call-site compatibility; motion lives on the
/// splash scale/fade instead of redrawing the mark.
class RaastaLogo extends StatelessWidget {
  const RaastaLogo({
    super.key,
    this.size = 96,
    this.filled = true,
    this.circular = false,
    this.color,
    this.dashPhase = 0,
  });

  /// Unused visually (asset is always the teal badge); kept for API stability.
  final bool filled;
  final bool circular;
  final double size;
  final Color? color;
  final double dashPhase;

  static const assetPath = 'assets/branding/raasta_icon_1024.png';
  static const splashMarkPath = 'assets/branding/raasta_splash_mark.png';

  @override
  Widget build(BuildContext context) {
    final path = circular ? splashMarkPath : assetPath;
    final radius = circular ? size / 2 : size * 0.22;
    final image = Image.asset(
      path,
      width: size,
      height: size,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: circular ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circular ? null : BorderRadius.circular(radius),
        boxShadow: filled
            ? [
                BoxShadow(
                  color: AppColors.tealDeep.withValues(alpha: 0.18),
                  blurRadius: size * 0.14,
                  offset: Offset(0, size * 0.05),
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: image,
    );
  }
}

/// "RAASTA" wordmark with consistent brand tracking.
class RaastaWordmark extends StatelessWidget {
  const RaastaWordmark({super.key, this.fontSize = 28, this.color});

  final double fontSize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      'RAASTA',
      style: GoogleFonts.sora(
        color: color ?? context.palette.textPrimary,
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        letterSpacing: fontSize * 0.13,
        height: 1,
      ),
    );
  }
}
