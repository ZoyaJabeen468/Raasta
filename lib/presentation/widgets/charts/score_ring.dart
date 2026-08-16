import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/safety_score.dart';

/// Circular safety-score gauge with a colour scale and plain-English verdict.
class ScoreRing extends StatelessWidget {
  const ScoreRing({
    super.key,
    required this.score,
    this.hasData = true,
    this.size = 140,
    this.caption,
  });

  final int score;
  final bool hasData;
  final double size;
  final String? caption;

  static Color tintFor(
    BuildContext context,
    int score, {
    bool hasData = true,
  }) {
    return SafetyScale.tint(
      score,
      hasData: hasData,
      muted: context.palette.textSecondary,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final tint = tintFor(context, score, hasData: hasData);
    final verdict = SafetyScale.verdict(score, hasData: hasData);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: hasData ? score / 100 : 0),
            duration: const Duration(milliseconds: 850),
            curve: Curves.easeOutCubic,
            builder: (context, t, _) => CustomPaint(
              painter: _RingPainter(
                progress: t,
                color: tint,
                track: p.surfaceAlt,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      hasData ? '${(t * 100).round()}' : '—',
                      style: GoogleFonts.sora(
                        fontSize: size * 0.27,
                        fontWeight: FontWeight.w700,
                        color: p.textPrimary,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'of 100',
                      style: GoogleFonts.dmSans(
                        fontSize: size * 0.08,
                        color: p.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            verdict,
            style: GoogleFonts.dmSans(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: tint,
            ),
          ),
        ),
        if (caption != null) ...[
          const SizedBox(height: 8),
          Text(
            caption!,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 12.5,
              color: p.textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.track,
  });

  final double progress;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.1;
    final rect = Rect.fromLTWH(
      0,
      0,
      size.width,
      size.height,
    ).deflate(stroke / 2 + 1);

    // Gauge runs from bottom-left round to bottom-right (270° sweep).
    const start = math.pi * 0.75;
    const total = math.pi * 1.5;

    canvas.drawArc(
      rect,
      start,
      total,
      false,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );

    if (progress <= 0) return;

    canvas.drawArc(
      rect,
      start,
      total * progress,
      false,
      Paint()
        ..shader = SweepGradient(
          startAngle: start,
          endAngle: start + total,
          colors: [color.withValues(alpha: 0.65), color],
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.color != color || old.track != track;
}
