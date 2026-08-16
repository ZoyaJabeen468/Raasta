import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import '../theme/app_palette.dart';

/// RAASTA brand mark: a bold "R" sitting on a perspective road.
///
/// [dashPhase] animates the road dashes toward the viewer (0 → 1 loops).
class RaastaLogo extends StatelessWidget {
  const RaastaLogo({
    super.key,
    this.size = 96,
    this.filled = true,
    this.color,
    this.dashPhase = 0,
  });

  /// Solid gradient badge (for dark/brand backgrounds) vs. outlined tile.
  final bool filled;
  final double size;
  final Color? color;
  final double dashPhase;

  @override
  Widget build(BuildContext context) {
    final content = color ?? (filled ? AppColors.white : AppColors.tealDeep);
    final radius = size * 0.26;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: filled ? AppColors.driveGradient : null,
        color: filled ? null : AppColors.white,
        borderRadius: BorderRadius.circular(radius),
        border: filled
            ? null
            : Border.all(color: AppColors.fog, width: size * 0.02),
        boxShadow: filled
            ? [
                BoxShadow(
                  color: AppColors.teal.withValues(alpha: 0.30),
                  blurRadius: size * 0.28,
                  offset: Offset(0, size * 0.12),
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _RoadPainter(color: content, dashPhase: dashPhase),
            ),
          ),
          Align(
            alignment: const Alignment(0, -0.42),
            child: Text(
              'R',
              style: GoogleFonts.sora(
                color: content,
                fontSize: size * 0.44,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoadPainter extends CustomPainter {
  _RoadPainter({required this.color, required this.dashPhase});

  final Color color;
  final double dashPhase;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Horizon where the road narrows, then widens toward the bottom edge.
    final horizonY = h * 0.52;
    final bottomY = h * 1.02;

    final road = Path()
      ..moveTo(w * 0.435, horizonY)
      ..lineTo(w * 0.565, horizonY)
      ..lineTo(w * 1.02, bottomY)
      ..lineTo(w * -0.02, bottomY)
      ..close();

    canvas.drawPath(
      road,
      Paint()..color = color.withValues(alpha: 0.22),
    );

    // Road edges.
    final edge = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.035
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(w * 0.435, horizonY),
      Offset(w * 0.02, bottomY),
      edge,
    );
    canvas.drawLine(
      Offset(w * 0.565, horizonY),
      Offset(w * 0.98, bottomY),
      edge,
    );

    // Center dashes with perspective: shorter and thinner near the horizon.
    final dash = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const dashCount = 3;
    for (var i = 0; i < dashCount; i++) {
      // t: 0 at horizon, 1 at bottom. Phase makes dashes travel outward.
      final t = ((i + dashPhase) / dashCount).clamp(0.0, 1.0);
      final eased = t * t; // perspective compression

      final startY = horizonY + (bottomY - horizonY) * eased;
      final length = h * 0.05 + h * 0.13 * eased;
      final endY = (startY + length).clamp(horizonY, bottomY);

      dash
        ..strokeWidth = w * (0.022 + 0.045 * eased)
        ..color = color.withValues(alpha: 0.55 + 0.45 * eased);

      canvas.drawLine(
        Offset(w * 0.5, startY),
        Offset(w * 0.5, endY),
        dash,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RoadPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.dashPhase != dashPhase;
  }
}

/// "RAASTA" wordmark with consistent brand tracking.
class RaastaWordmark extends StatelessWidget {
  const RaastaWordmark({super.key, this.fontSize = 28, this.color});

  final double fontSize;

  /// Defaults to the active palette's primary text colour so the wordmark
  /// stays legible in dark mode.
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
