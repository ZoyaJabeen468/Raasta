import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_palette.dart';
import 'app_card.dart';

/// Icon + value + label block used in the dashboard stat grids.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.accent,
    this.compact = false,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color? accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final tint = accent ?? p.brand;

    return AppCard(
      radius: compact ? 16 : 18,
      padding: EdgeInsets.all(compact ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: compact ? 30 : 36,
            height: compact ? 30 : 36,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: compact ? 16 : 19, color: tint),
          ),
          SizedBox(height: compact ? 10 : 14),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.sora(
              fontSize: compact ? 17 : 21,
              fontWeight: FontWeight.w700,
              color: p.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(
              fontSize: 12.5,
              color: p.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
