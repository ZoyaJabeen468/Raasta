import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/trip_stats.dart';
import '../../providers/trips_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/charts/score_bar.dart';
import '../../widgets/charts/week_bars.dart';
import '../../widgets/greeting_header.dart';
import '../../widgets/insight_row.dart';
import '../../widgets/raasta_nav_bar.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/trip_card.dart';

/// Dashboard: this week and recent drives. Deeper totals live on Reports.
class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final trips = context.watch<TripsProvider>();
    final stats = trips.stats;

    if (!trips.isReady) {
      return const SafeArea(child: SkeletonList(cards: 3));
    }

    return SafeArea(
      child: RefreshIndicator(
        color: p.brand,
        onRefresh: trips.refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, RaastaNavBar.contentInset),
          children: [
            _Header(onRefresh: trips.refresh),
            const SizedBox(height: 12),
            Text(
              'Dashboard',
              style: GoogleFonts.sora(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: p.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'This week at a glance. Open Reports for full totals.',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: p.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            if (stats.isEmpty) ...[
              const EmptyState(
                icon: Icons.timeline_outlined,
                title: 'No saved drives',
                message:
                    'Start a drive from Home. This week and recent drives '
                    'appear here after you save.',
                compact: true,
              ),
            ] else ...[
              _WeeklyCard(stats: stats),
              const SizedBox(height: 16),
              Text(
                'Recent drives',
                style: GoogleFonts.sora(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: p.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              for (final trip in stats.trips.take(4)) ...[
                TripCard(trip: trip, compact: true),
                const SizedBox(height: 8),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return PillAppBar(
      actions: [
        PillBarAction(
          icon: Icons.refresh_rounded,
          tooltip: 'Refresh',
          onTap: onRefresh,
        ),
      ],
    );
  }
}

class _WeeklyCard extends StatelessWidget {
  const _WeeklyCard({required this.stats});

  final TripStats stats;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return AppCard(
      radius: 14,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'This week',
                style: GoogleFonts.sora(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: p.textPrimary,
                ),
              ),
              const Spacer(),
              const StatusPill(label: 'Last 7 days'),
            ],
          ),
          const SizedBox(height: 14),
          WeekBars(
            values: stats.dailyHazards,
            labels: Format.lastSevenDayLabels(),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  icon: Icons.route_outlined,
                  value: '${stats.weekTrips}',
                  label: 'Trips',
                ),
              ),
              Expanded(
                child: _MiniStat(
                  icon: Icons.straighten_outlined,
                  value: Format.distance(stats.weekDistanceMeters),
                  label: 'Distance',
                ),
              ),
              Expanded(
                child: _MiniStat(
                  icon: Icons.schedule_outlined,
                  value: Format.duration(stats.weekDurationSeconds),
                  label: 'Drive time',
                ),
              ),
              Expanded(
                child: _MiniStat(
                  icon: Icons.warning_amber_outlined,
                  value: '${stats.weekHazards}',
                  label: 'Hazards',
                  tint: AppColors.amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: p.border.withValues(alpha: 0.7), height: 1),
          const SizedBox(height: 14),
          ScoreBar(score: stats.safetyScore, hasTrips: !stats.isEmpty),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
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
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 6),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.sora(
            fontSize: 14.5,
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
