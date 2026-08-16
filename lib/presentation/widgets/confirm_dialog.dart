import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';

/// Shared confirmation dialog for destructive or irreversible actions.
///
/// Returns true only when the user explicitly confirms.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = true,
  IconData icon = Icons.warning_amber_rounded,
}) async {
  final p = context.palette;
  final tint = destructive ? AppColors.alert : p.brand;

  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: p.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      icon: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: tint, size: 26),
      ),
      title: Text(
        title,
        textAlign: TextAlign.center,
        style: GoogleFonts.sora(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: p.textPrimary,
        ),
      ),
      content: Text(
        message,
        textAlign: TextAlign.center,
        style: GoogleFonts.dmSans(
          fontSize: 14,
          height: 1.5,
          color: p.textSecondary,
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(foregroundColor: p.textSecondary),
          child: Text(cancelLabel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(foregroundColor: tint),
          child: Text(
            confirmLabel,
            style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );

  return result ?? false;
}
