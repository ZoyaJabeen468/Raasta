import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

enum LineIconKind { camera, location, mic, bell, speaker, check }

/// Lucide-style stroke icon in a uniform 48px well.
class LineIconBox extends StatelessWidget {
  const LineIconBox({
    super.key,
    required this.kind,
    this.accent = false,
    this.size = 48,
  });

  final LineIconKind kind;
  final bool accent;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = accent ? AppColors.mint : AppColors.white.withValues(alpha: 0.88);

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.10)),
      ),
      child: CustomPaint(
        size: const Size(22, 22),
        painter: _LineIconPainter(kind: kind, color: color),
      ),
    );
  }
}

class _LineIconPainter extends CustomPainter {
  _LineIconPainter({required this.kind, required this.color});

  final LineIconKind kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (kind) {
      case LineIconKind.camera:
        final body = RRect.fromRectAndRadius(
          Rect.fromLTWH(size.width * 0.05, size.height * 0.28, size.width * 0.9, size.height * 0.62),
          const Radius.circular(3.5),
        );
        canvas.drawRRect(body, stroke);
        canvas.drawCircle(
          Offset(size.width * 0.5, size.height * 0.59),
          size.width * 0.16,
          stroke,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(size.width * 0.58, size.height * 0.08, size.width * 0.22, size.height * 0.2),
            const Radius.circular(2),
          ),
          stroke,
        );
      case LineIconKind.location:
        final pin = Path()
          ..moveTo(size.width * 0.5, size.height * 0.96)
          ..cubicTo(
            size.width * 0.18,
            size.height * 0.62,
            size.width * 0.12,
            size.height * 0.38,
            size.width * 0.5,
            size.height * 0.08,
          )
          ..cubicTo(
            size.width * 0.88,
            size.height * 0.38,
            size.width * 0.82,
            size.height * 0.62,
            size.width * 0.5,
            size.height * 0.96,
          );
        canvas.drawPath(pin, stroke);
        canvas.drawCircle(
          Offset(size.width * 0.5, size.height * 0.40),
          size.width * 0.14,
          stroke,
        );
      case LineIconKind.mic:
        canvas.drawCircle(
          Offset(size.width * 0.5, size.height * 0.38),
          size.width * 0.18,
          stroke,
        );
        canvas.drawArc(
          Rect.fromLTWH(
            size.width * 0.18,
            size.height * 0.28,
            size.width * 0.64,
            size.height * 0.48,
          ),
          0.15,
          2.85,
          false,
          stroke,
        );
        canvas.drawLine(
          Offset(size.width * 0.5, size.height * 0.76),
          Offset(size.width * 0.5, size.height * 0.92),
          stroke,
        );
        canvas.drawLine(
          Offset(size.width * 0.32, size.height * 0.92),
          Offset(size.width * 0.68, size.height * 0.92),
          stroke,
        );
      case LineIconKind.bell:
        final bell = Path()
          ..moveTo(size.width * 0.18, size.height * 0.58)
          ..cubicTo(
            size.width * 0.18,
            size.height * 0.28,
            size.width * 0.32,
            size.height * 0.1,
            size.width * 0.5,
            size.height * 0.1,
          )
          ..cubicTo(
            size.width * 0.68,
            size.height * 0.1,
            size.width * 0.82,
            size.height * 0.28,
            size.width * 0.82,
            size.height * 0.58,
          )
          ..lineTo(size.width * 0.88, size.height * 0.7)
          ..lineTo(size.width * 0.12, size.height * 0.7)
          ..close();
        canvas.drawPath(bell, stroke);
        canvas.drawArc(
          Rect.fromCircle(
            center: Offset(size.width * 0.5, size.height * 0.7),
            radius: size.width * 0.14,
          ),
          0,
          3.14,
          false,
          stroke,
        );
      case LineIconKind.speaker:
        final cone = Path()
          ..moveTo(size.width * 0.08, size.height * 0.38)
          ..lineTo(size.width * 0.28, size.height * 0.38)
          ..lineTo(size.width * 0.52, size.height * 0.18)
          ..lineTo(size.width * 0.52, size.height * 0.82)
          ..lineTo(size.width * 0.28, size.height * 0.62)
          ..lineTo(size.width * 0.08, size.height * 0.62)
          ..close();
        canvas.drawPath(cone, stroke);
        canvas.drawArc(
          Rect.fromCircle(
            center: Offset(size.width * 0.52, size.height * 0.5),
            radius: size.width * 0.22,
          ),
          -0.8,
          1.6,
          false,
          stroke,
        );
        canvas.drawArc(
          Rect.fromCircle(
            center: Offset(size.width * 0.52, size.height * 0.5),
            radius: size.width * 0.36,
          ),
          -0.8,
          1.6,
          false,
          stroke,
        );
      case LineIconKind.check:
        final check = Path()
          ..moveTo(size.width * 0.16, size.height * 0.52)
          ..lineTo(size.width * 0.4, size.height * 0.76)
          ..lineTo(size.width * 0.84, size.height * 0.24);
        canvas.drawPath(check, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _LineIconPainter oldDelegate) {
    return oldDelegate.kind != kind || oldDelegate.color != color;
  }
}
