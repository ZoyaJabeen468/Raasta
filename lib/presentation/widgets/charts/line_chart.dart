import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_palette.dart';

/// Smoothed line chart with gridlines, a soft area fill and point markers.
class LineChart extends StatelessWidget {
  const LineChart({
    super.key,
    required this.values,
    required this.labels,
    this.color,
    this.height = 180,
    this.unit = '',
    this.smooth = true,
    this.minTicks = 4,
  });

  final List<double> values;
  final List<String> labels;
  final Color? color;
  final double height;
  final String unit;
  final bool smooth;
  final int minTicks;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final tint = color ?? p.brand;

    final maxValue = values.isEmpty
        ? 0.0
        : values.reduce((a, b) => a > b ? a : b);
    final top = _niceCeiling(maxValue);
    final ticks = _ticks(top, minTicks);

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
            width: 34,
            height: height - 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final tick in ticks.reversed)
                  Text(_tickLabel(tick), style: labelStyle),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (context, t, _) => CustomPaint(
                      size: Size.infinite,
                      painter: _LinePainter(
                        values: values,
                        maxValue: top,
                        ticks: ticks.length,
                        color: tint,
                        grid: p.border,
                        progress: t,
                        smooth: smooth,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    for (final label in labels)
                      Expanded(
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.clip,
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

  String _tickLabel(double value) {
    final text = value >= 10 || value == value.roundToDouble()
        ? value.round().toString()
        : value.toStringAsFixed(1);
    return unit.isEmpty ? text : '$text$unit';
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

  static List<double> _ticks(double top, int count) {
    final n = math.max(count, 2);
    return List.generate(n + 1, (i) => top * i / n);
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.values,
    required this.maxValue,
    required this.ticks,
    required this.color,
    required this.grid,
    required this.progress,
    required this.smooth,
  });

  final List<double> values;
  final double maxValue;
  final int ticks;
  final Color color;
  final Color grid;
  final double progress;
  final bool smooth;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;

    for (var i = 0; i < ticks; i++) {
      final y = size.height * i / (ticks - 1);
      _dashedLine(canvas, Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (values.isEmpty || maxValue <= 0) return;

    final points = <Offset>[];
    final slot = values.length == 1 ? size.width : size.width / values.length;
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1
          ? size.width / 2
          : slot * i + slot / 2;
      final ratio = (values[i] / maxValue).clamp(0.0, 1.0);
      points.add(Offset(x, size.height - size.height * ratio * progress));
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    if (smooth && points.length > 2) {
      for (var i = 0; i < points.length - 1; i++) {
        final current = points[i];
        final next = points[i + 1];
        final midX = (current.dx + next.dx) / 2;
        path.cubicTo(midX, current.dy, midX, next.dy, next.dx, next.dy);
      }
    } else {
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
    }

    final fill = Path.from(path)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.22),
            color.withValues(alpha: 0.01),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    for (final point in points) {
      canvas.drawCircle(point, 3.4, Paint()..color = color);
    }
  }

  void _dashedLine(Canvas canvas, Offset from, Offset to, Paint paint) {
    const dash = 4.0;
    const gap = 4.0;
    var x = from.dx;
    while (x < to.dx) {
      canvas.drawLine(
        Offset(x, from.dy),
        Offset(math.min(x + dash, to.dx), to.dy),
        paint,
      );
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) =>
      old.progress != progress ||
      old.values != values ||
      old.maxValue != maxValue ||
      old.color != color;
}
