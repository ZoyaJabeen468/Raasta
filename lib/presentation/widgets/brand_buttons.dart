import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';

/// Solid brand action used on auth screens. No gradient, no drop shadow.
class BrandButton extends StatelessWidget {
  const BrandButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.height = 52,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;

    return SizedBox(
      height: height,
      width: double.infinity,
      child: FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.tealDeep,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: AppColors.tealDeep.withValues(alpha: 0.45),
          disabledForegroundColor: AppColors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: GoogleFonts.dmSans(
            fontSize: 15.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.1,
                  color: AppColors.white,
                ),
              )
            : Text(label),
      ),
    );
  }
}

/// Primary call to action with the brand gradient and a soft lift.
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.height = 56,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;

    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: AppColors.driveGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppColors.teal.withValues(alpha: 0.35),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ]
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: AppColors.white,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, color: AppColors.white, size: 20),
                          const SizedBox(width: 10),
                        ],
                        Text(
                          label,
                          style: GoogleFonts.dmSans(
                            color: AppColors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Destructive counterpart to [GradientButton], for irreversible actions.
class DangerButton extends StatelessWidget {
  const DangerButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.height = 56,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;

    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: AppColors.alert,
          borderRadius: BorderRadius.circular(16),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppColors.alert.withValues(alpha: 0.32),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: AppColors.white,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, color: AppColors.white, size: 20),
                          const SizedBox(width: 10),
                        ],
                        Text(
                          label,
                          style: GoogleFonts.dmSans(
                            color: AppColors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Continue with …" button carrying the provider's own mark.
class SocialButton extends StatelessWidget {
  const SocialButton({
    super.key,
    required this.label,
    required this.glyph,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final Widget glyph;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return SizedBox(
      height: 54,
      child: Material(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: loading ? null : onPressed,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.border, width: 1.2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (loading)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: p.textSecondary,
                    ),
                  )
                else
                  SizedBox(width: 20, height: 20, child: glyph),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: p.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Official Google "G" mark (four brand colours + blue crossbar).
class GoogleGlyph extends StatelessWidget {
  const GoogleGlyph({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleGPainter()),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  static const _blue = Color(0xFF4285F4);
  static const _red = Color(0xFFEA4335);
  static const _yellow = Color(0xFFFBBC05);
  static const _green = Color(0xFF34A853);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 48, size.height / 48);

    void fill(Path path, Color color) {
      canvas.drawPath(path, Paint()..color = color);
    }

    fill(
      Path()
        ..moveTo(24, 9.5)
        ..cubicTo(27.54, 9.5, 30.71, 10.72, 33.21, 13.1)
        ..lineTo(40.06, 6.25)
        ..cubicTo(35.9, 2.38, 30.47, 0, 24, 0)
        ..cubicTo(14.62, 0, 6.51, 5.38, 2.56, 13.22)
        ..lineTo(10.54, 19.41)
        ..cubicTo(12.43, 13.72, 17.74, 9.5, 24, 9.5)
        ..close(),
      _red,
    );
    fill(
      Path()
        ..moveTo(46.98, 24.55)
        ..cubicTo(46.98, 22.98, 46.83, 21.46, 46.6, 20)
        ..lineTo(24, 20)
        ..lineTo(24, 29.02)
        ..lineTo(36.94, 29.02)
        ..cubicTo(36.36, 31.98, 34.68, 34.5, 32.16, 36.2)
        ..lineTo(39.89, 42.2)
        ..cubicTo(44.4, 38.02, 46.98, 31.84, 46.98, 24.55)
        ..close(),
      _blue,
    );
    fill(
      Path()
        ..moveTo(10.53, 28.59)
        ..cubicTo(10.05, 27.14, 9.77, 25.6, 9.77, 24)
        ..cubicTo(9.77, 22.4, 10.04, 20.86, 10.53, 19.41)
        ..lineTo(2.55, 13.22)
        ..cubicTo(0.92, 16.46, 0, 20.12, 0, 24)
        ..cubicTo(0, 27.88, 0.92, 31.54, 2.56, 34.78)
        ..lineTo(10.53, 28.59)
        ..close(),
      _yellow,
    );
    fill(
      Path()
        ..moveTo(24, 48)
        ..cubicTo(30.48, 48, 35.93, 45.87, 39.89, 42.19)
        ..lineTo(32.16, 36.19)
        ..cubicTo(30.01, 37.64, 27.24, 38.49, 24, 38.49)
        ..cubicTo(17.74, 38.49, 12.43, 34.27, 10.53, 28.58)
        ..lineTo(2.55, 34.77)
        ..cubicTo(6.51, 42.62, 14.62, 48, 24, 48)
        ..close(),
      _green,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Facebook's rounded "f" mark.
class FacebookGlyph extends StatelessWidget {
  const FacebookGlyph({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFF1877F2),
        shape: BoxShape.circle,
      ),
      child: Text(
        'f',
        style: GoogleFonts.dmSans(
          color: Colors.white,
          fontSize: size * 0.72,
          fontWeight: FontWeight.w800,
          height: 1.15,
        ),
      ),
    );
  }
}

/// Horizontal rule with a centred label, e.g. "or continue with email".
class LabelledDivider extends StatelessWidget {
  const LabelledDivider({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Row(
      children: [
        Expanded(child: Divider(color: p.border, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 12.5,
              color: p.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(child: Divider(color: p.border, thickness: 1)),
      ],
    );
  }
}
