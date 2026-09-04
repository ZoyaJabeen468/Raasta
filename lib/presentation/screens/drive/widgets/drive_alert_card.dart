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
        decoration: BoxDecoration(
          color: const Color(0xF0101418),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: tint.withValues(alpha: 0.75), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: tint.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: tint.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(alert.icon, color: Colors.white, size: 26),
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
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          alert.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.sora(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            height: 1.15,
                          ),
                        ),
                        if (meta != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            meta,
                            style: GoogleFonts.dmSans(
                              color: Colors.white60,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          alert.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
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
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      iconSize: 22,
                      padding: const EdgeInsets.all(10),
                      constraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(18),
              ),
              child: Container(
                height: 3,
                color: tint.withValues(alpha: 0.85),
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
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final slide = Tween<Offset>(
          begin: const Offset(0, 0.35),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
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
