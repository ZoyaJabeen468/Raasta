import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_palette.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/safety_score.dart';
import '../../data/models/trip_record.dart';
import 'app_card.dart';

/// Rich summary of one drive: timestamp, score chip, key figures and the
/// hazard types picked up along the way.
class TripCard extends StatelessWidget {
  const TripCard({super.key, required this.trip, this.onTap});

  final TripRecord trip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final score = trip.safetyScore;
    final tint = SafetyScale.tint(score, hasData: true, muted: p.textSecondary);

    final hazards = trip.hazards.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return AppCard(
      radius: 20,
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.directions_car_filled_rounded,
                  size: 20,
                  color: tint,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Format.tripStamp(trip.startedAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: p.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      SafetyScale.verdict(score, hasData: true),
                      style: GoogleFonts.dmSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: tint,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: tint.withValues(alpha: 0.35)),
                ),
                child: Text(
                  '$score',
                  style: GoogleFonts.sora(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: tint,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: p.border, height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              _TripFigure(
                icon: Icons.route_rounded,
                value: Format.distance(trip.distanceMeters),
                label: 'Distance',
              ),
              _TripFigure(
                icon: Icons.schedule_rounded,
                value: Format.duration(trip.durationSeconds),
                label: 'Duration',
              ),
              _TripFigure(
                icon: Icons.warning_amber_rounded,
                value: '${trip.hazardCount}',
                label: trip.hazardCount == 1 ? 'Hazard' : 'Hazards',
              ),
            ],
          ),
          if (hazards.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final entry in hazards.take(3))
                  _HazardChip(
                    icon: entry.key.icon,
                    label: entry.key.label,
                    count: entry.value,
                    tint: entry.key.color,
                  ),
                if (hazards.length > 3)
                  _HazardChip(
                    icon: Icons.more_horiz_rounded,
                    label: '${hazards.length - 3} more',
                    count: 0,
                    tint: p.textSecondary,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TripFigure extends StatelessWidget {
  const _TripFigure({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 16, color: p.textSecondary),
          const SizedBox(width: 7),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: p.textPrimary,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: p.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HazardChip extends StatelessWidget {
  const _HazardChip({
    required this.icon,
    required this.label,
    required this.count,
    required this.tint,
  });

  final IconData icon;
  final String label;
  final int count;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: tint),
          const SizedBox(width: 5),
          Text(
            count > 0 ? '$label · $count' : label,
            style: GoogleFonts.dmSans(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: tint,
            ),
          ),
        ],
      ),
    );
  }
}
