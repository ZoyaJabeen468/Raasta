import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';

/// Compact glass row used on Permissions and Voice alerts.
class GlassTile extends StatelessWidget {
  const GlassTile({
    super.key,
    required this.child,
    this.selected = false,
    this.padding = const EdgeInsets.fromLTRB(12, 12, 12, 12),
    this.onTap,
  });

  final Widget child;
  final bool selected;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(
        color: selected
            ? AppColors.mint.withValues(alpha: 0.45)
            : AppColors.white.withValues(alpha: 0.10),
      ),
    );

    final body = Padding(padding: padding, child: child);

    return Material(
      color: selected
          ? AppColors.mint.withValues(alpha: 0.08)
          : AppColors.white.withValues(alpha: 0.05),
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? body
          : InkWell(onTap: onTap, customBorder: shape, child: body),
    );
  }
}

class QuietChip extends StatelessWidget {
  const QuietChip({
    super.key,
    required this.label,
    this.emphasized = false,
  });

  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: emphasized
            ? AppColors.mint.withValues(alpha: 0.14)
            : AppColors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadii.full),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: emphasized
              ? AppColors.mint
              : AppColors.white.withValues(alpha: 0.58),
        ),
      ),
    );
  }
}
