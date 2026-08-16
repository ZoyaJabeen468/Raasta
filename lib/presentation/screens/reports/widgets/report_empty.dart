import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../widgets/brand_buttons.dart';

/// Shared empty / celebration state for report tabs.
class ReportEmpty extends StatelessWidget {
  const ReportEmpty({
    super.key,
    required this.message,
    this.title = 'Nothing to report yet',
    this.icon = Icons.query_stats_rounded,
    this.celebrate = false,
    this.showStartDrive = false,
  });

  final String message;
  final String title;
  final IconData icon;
  final bool celebrate;
  final bool showStartDrive;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final accent = celebrate ? AppColors.safe : p.brand;
    final soft = celebrate
        ? AppColors.safe.withValues(alpha: 0.12)
        : p.brandSoft;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: soft,
                borderRadius: BorderRadius.circular(26),
              ),
              child: Icon(icon, size: 34, color: accent),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.sora(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: p.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: p.textSecondary,
                height: 1.45,
              ),
            ),
            if (showStartDrive) ...[
              const SizedBox(height: 22),
              SizedBox(
                width: 220,
                child: GradientButton(
                  label: 'Start a drive',
                  height: 48,
                  icon: Icons.navigation_rounded,
                  onPressed: () =>
                      Navigator.of(context).pushNamed(AppRoutes.drive),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
