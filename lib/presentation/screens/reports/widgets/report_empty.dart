import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_palette.dart';

/// Shared empty / celebration state for report tabs.
class ReportEmpty extends StatelessWidget {
  const ReportEmpty({
    super.key,
    required this.message,
    this.title = 'No saved drives',
    this.icon = Icons.query_stats_outlined,
    this.celebrate = false,
  });

  final String message;
  final String title;
  final IconData icon;
  final bool celebrate;

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
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: soft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, size: 30, color: accent),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.sora(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: p.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 13.5,
                color: p.textSecondary,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
