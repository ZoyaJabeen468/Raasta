import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/drive_alert.dart';

/// Bottom toast alert with dismiss — shared by hazard, overspeed, wrong-way.
class DriveAlertCard extends StatelessWidget {
  const DriveAlertCard({
    super.key,
    required this.alert,
    required this.onDismiss,
  });

  final DriveAlert alert;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final tint = alert.tint;
    final meta = alert.metaLine;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        decoration: BoxDecoration(
          color: const Color(0xF012171C),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: tint.withValues(alpha: 0.55)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: tint.withValues(alpha: 0.35)),
              ),
              child: Icon(alert.icon, color: tint, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alert.severityLabel,
                    style: GoogleFonts.dmSans(
                      color: tint,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.9,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    alert.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.sora(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
                  if (meta != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      meta,
                      style: GoogleFonts.dmSans(
                        color: Colors.white54,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    alert.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Semantics(
              button: true,
              label: 'Dismiss alert',
              child: IconButton(
                onPressed: onDismiss,
                icon: const Icon(Icons.close_rounded, color: Colors.white60),
                iconSize: 20,
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Slide-up wrapper for the active drive alert.
class DriveAlertToast extends StatelessWidget {
  const DriveAlertToast({
    super.key,
    required this.alert,
    required this.onDismiss,
  });

  final DriveAlert? alert;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final slide = Tween<Offset>(
          begin: const Offset(0, 0.28),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        );
        return SlideTransition(
          position: slide,
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: alert == null
          ? const SizedBox.shrink(key: ValueKey('no_alert'))
          : DriveAlertCard(
              key: ValueKey(alert!.id),
              alert: alert!,
              onDismiss: onDismiss,
            ),
    );
  }
}
