import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../data/services/sign_detector.dart';

/// Compact chip for the latest confirmed traffic sign (M3).
/// Fades in/out as [sign] changes; pass null to hide.
class DriveSignCard extends StatelessWidget {
  const DriveSignCard({super.key, required this.sign});

  final SignDetection? sign;

  @override
  Widget build(BuildContext context) {
    final s = sign;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1).animate(animation),
          child: child,
        ),
      ),
      child: s == null
          ? const SizedBox.shrink(key: ValueKey('no_sign'))
          // Keyed by sighting so an OCR update refreshes in place.
          : _SignChip(key: ValueKey((s.sign, s.at)), detection: s),
    );
  }
}

class _SignChip extends StatelessWidget {
  const _SignChip({super.key, required this.detection});

  final SignDetection detection;

  @override
  Widget build(BuildContext context) {
    final sign = detection.sign;
    final tint = sign.color;
    final limit = detection.ocrSpeedLimit;
    final title = limit != null ? 'Limit $limit' : sign.title;
    final ocr = detection.ocrText;
    final ocrLine = ocr == null || ocr.isEmpty || ocr == '$limit' ? null : ocr;

    return Semantics(
      liveRegion: true,
      label: 'Road sign: $title',
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
        decoration: BoxDecoration(
          color: const Color(0xE6101418),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: tint.withValues(alpha: 0.7), width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(sign.icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ROAD SIGN',
                    style: GoogleFonts.dmSans(
                      color: tint,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                  Text(
                    title,
                    style: GoogleFonts.sora(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (ocrLine != null)
                    Text(
                      ocrLine,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        color: Colors.white70,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
