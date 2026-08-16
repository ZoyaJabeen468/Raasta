import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_palette.dart';

/// Inline explanation or error banner used by the account forms.
class FormNotice extends StatelessWidget {
  const FormNotice({super.key, required this.icon, required this.message})
    : tint = null;

  const FormNotice.error(this.message, {super.key})
    : icon = Icons.error_outline_rounded,
      tint = AppColors.alert;

  final IconData icon;
  final String message;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = tint ?? p.brand;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                height: 1.45,
                color: tint == null ? p.textSecondary : color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
