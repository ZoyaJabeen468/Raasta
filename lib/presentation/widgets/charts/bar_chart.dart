import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_palette.dart';

class BarDatum {
  const BarDatum({required this.label, required this.value, this.color});

  final String label;
  final double value;
  final Color? color;
}

/// Vertical bars with a value axis, dashed gridlines and animated growth.
class BarChart extends StatelessWidget {
  const BarChart({
    super.key,
    required this.data,
    this.height = 180,
    this.color,
    this.highlightLast = false,
    this.barWidth = 18,
  });

  final List<BarDatum> data;
  final double height;
  final Color? color;
  final bool highlightLast;
  final double barWidth;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final tint = color ?? p.brand;

    final maxValue = data.isEmpty
        ? 0.0
        : data.map((d) => d.value).reduce((a, b) => a > b ? a : b);
    final top = _niceCeiling(maxValue);
    final ticks = List.generate(5, (i) => top * i / 4);

    final labelStyle = GoogleFonts.dmSans(
      fontSize: 10.5,
      color: p.textSecondary,
    );

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 26,
            height: height - 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final tick in ticks.reversed)
                  Text(
                    tick == tick.roundToDouble()
                        ? tick.round().toString()
                        : tick.toStringAsFixed(1),
                    style: labelStyle,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _GridPainter(
                            lines: ticks.length,
                            color: p.border,
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (var i = 0; i < data.length; i++)
                              Expanded(
                                child: _Bar(
                                  datum: data[i],
                                  maxValue: top,
                                  width: barWidth,
                                  color:
                                      data[i].color ??
                                      (highlightLast && i == data.length - 1
                                          ? tint
                                          : tint.withValues(alpha: 0.85)),
                                  emptyColor: p.surfaceAlt,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    for (final datum in data)
                      Expanded(
                        child: Text(
                          datum.label,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: labelStyle,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static double _niceCeiling(double value) {
    if (value <= 0) return 4;
    final magnitude = math.pow(10, (math.log(value) / math.ln10).floor());
    final normalized = value / magnitude;
    final step = normalized <= 1
        ? 1.0
        : normalized <= 2
        ? 2.0
        : normalized <= 5
        ? 5.0
        : 10.0;
    return step * magnitude.toDouble();
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.datum,
    required this.maxValue,
    required this.width,
    required this.color,
    required this.emptyColor,
  });

  final BarDatum datum;
  final double maxValue;
  final double width;
  final Color color;
  final Color emptyColor;

  @override
  Widget build(BuildContext context) {
    final ratio = maxValue <= 0
        ? 0.0
        : (datum.value / maxValue).clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: ratio),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (context, t, _) {
            return Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: width,
                height: math.max(4, constraints.maxHeight * t),
                decoration: BoxDecoration(
                  gradient: datum.value <= 0
                      ? null
                      : LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [color, color.withValues(alpha: 0.6)],
                        ),
                  color: datum.value <= 0 ? emptyColor : null,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({required this.lines, required this.color});

  final int lines;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    for (var i = 0; i < lines; i++) {
      final y = size.height * i / (lines - 1);
      var x = 0.0;
      while (x < size.width) {
        canvas.drawLine(
          Offset(x, y),
          Offset(math.min(x + 4, size.width), y),
          paint,
        );
        x += 8;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) =>
      old.lines != lines || old.color != color;
}
