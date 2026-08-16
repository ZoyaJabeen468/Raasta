import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/safety_score.dart';

/// Safety score readout: label, value and an animated 0–100 track.
class ScoreBar extends StatelessWidget {
  const ScoreBar({super.key, required this.score, this.hasTrips = true});

  final int score;
  final bool hasTrips;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final tint = SafetyScale.tint(
      score,
      hasData: hasTrips,
      muted: p.textSecondary,
    );
    final verdict = SafetyScale.verdict(score, hasData: hasTrips);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.shield_rounded, size: 16, color: tint),
            const SizedBox(width: 8),
            Text(
              'Safety score',
              style: GoogleFonts.dmSans(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: p.textPrimary,
              ),
            ),
            const Spacer(),
            Text(
              hasTrips ? '$score' : '—',
              style: GoogleFonts.sora(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: tint,
              ),
            ),
            Text(
              hasTrips ? ' / 100' : '',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: p.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: hasTrips ? score / 100 : 0),
            duration: const Duration(milliseconds: 750),
            curve: Curves.easeOutCubic,
            builder: (context, t, _) => LinearProgressIndicator(
              value: t,
              minHeight: 8,
              backgroundColor: p.surfaceAlt,
              valueColor: AlwaysStoppedAnimation(tint),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          verdict,
          style: GoogleFonts.dmSans(fontSize: 12, color: p.textSecondary),
        ),
      ],
    );
  }
}
