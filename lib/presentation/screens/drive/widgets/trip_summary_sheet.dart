import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/trip_record.dart';
import '../../../widgets/brand_buttons.dart';
import '../../../widgets/charts/score_ring.dart';

/// Post-drive summary shown in a bottom sheet before the trip is saved.
class TripSummarySheet extends StatelessWidget {
  const TripSummarySheet({super.key, required this.trip, required this.onSave});

  final TripRecord trip;
  final VoidCallback onSave;

  Future<void> _share(BuildContext context) async {
    final hazards = trip.hazards.entries
        .where((e) => e.value > 0)
        .map((e) => '${e.key.label}: ${e.value}')
        .join(', ');

    final text = StringBuffer()
      ..writeln('RAASTA trip summary')
      ..writeln(Format.tripStamp(trip.startedAt))
      ..writeln('Safety score: ${trip.safetyScore}')
      ..writeln('Duration: ${Format.duration(trip.durationSeconds)}')
      ..writeln('Distance: ${Format.distance(trip.distanceMeters)}')
      ..writeln('Hazards: ${trip.hazardCount}')
      ..writeln('Top speed: ${trip.maxSpeedKph.round()} km/h');
    if (hazards.isNotEmpty) {
      text.writeln('Details: $hazards');
    }
    text.writeln('\nKnow the road before you reach it.');

    await SharePlus.instance.share(ShareParams(text: text.toString()));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: p.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Drive complete',
              style: GoogleFonts.sora(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: p.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              Format.tripStamp(trip.startedAt),
              style: GoogleFonts.dmSans(
                fontSize: 13.5,
                color: p.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            ScoreRing(score: trip.safetyScore, size: 128),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _Stat(
                    icon: Icons.schedule_rounded,
                    value: Format.duration(trip.durationSeconds),
                    label: 'Duration',
                  ),
                ),
                Expanded(
                  child: _Stat(
                    icon: Icons.straighten_rounded,
                    value: Format.distance(trip.distanceMeters),
                    label: 'Distance',
                    tint: AppColors.safe,
                  ),
                ),
                Expanded(
                  child: _Stat(
                    icon: Icons.warning_amber_rounded,
                    value: '${trip.hazardCount}',
                    label: 'Hazards',
                    tint: AppColors.amber,
                  ),
                ),
                Expanded(
                  child: _Stat(
                    icon: Icons.speed_rounded,
                    value: '${trip.maxSpeedKph.round()}',
                    label: 'Top km/h',
                    tint: AppColors.sky,
                  ),
                ),
              ],
            ),
            if (trip.hazards.isNotEmpty) ...[
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Hazards spotted',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: p.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in trip.hazards.entries)
                    if (entry.value > 0)
                      _HazardChip(
                        icon: entry.key.icon,
                        color: entry.key.color,
                        label: '${entry.key.label} · ${entry.value}',
                      ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => _share(context),
              icon: const Icon(Icons.ios_share_rounded, size: 18),
              label: const Text('Share summary'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                foregroundColor: p.brand,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Discard'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: GradientButton(
                    label: 'Save trip',
                    height: 52,
                    onPressed: onSave,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.value,
    required this.label,
    this.tint,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = tint ?? p.brand;

    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 6),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.sora(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: p.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.dmSans(fontSize: 11.5, color: p.textSecondary),
        ),
      ],
    );
  }
}

class _HazardChip extends StatelessWidget {
  const _HazardChip({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 7),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
