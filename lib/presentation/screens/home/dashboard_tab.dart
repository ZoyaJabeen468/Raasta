import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/trip_stats.dart';
import '../../providers/trips_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/charts/donut_chart.dart';
import '../../widgets/charts/score_bar.dart';
import '../../widgets/charts/week_bars.dart';
import '../../widgets/greeting_header.dart';
import '../../widgets/insight_row.dart';
import '../../widgets/raasta_nav_bar.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/trip_card.dart';

/// Dashboard: weekly/lifetime stats and recent trips. Driving starts on Home.
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
          padding: const EdgeInsets.fromLTRB(20, 12, 20, RaastaNavBar.contentInset),
          children: [
            _Header(onRefresh: trips.refresh),
            const SizedBox(height: 14),
            Text(
              'Your driving stats',
              style: GoogleFonts.sora(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: p.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Weekly and lifetime trends. Start drives from Home.',
              style: GoogleFonts.dmSans(
                fontSize: 13.5,
                color: p.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            _SummaryBanner(stats: stats),
            const SizedBox(height: 22),
            if (stats.isEmpty) ...[
              EmptyState(
                icon: Icons.timeline_rounded,
                title: 'No drives recorded yet',
                message:
                    'Go to Home, start a drive, and RAASTA will log distance, '
                    'hazards, and your safety score here.',
              ),
            ] else ...[
              _WeeklyCard(stats: stats),
              const SizedBox(height: 22),
              const SectionHeading('Lifetime stats'),
              _LifetimeGrid(stats: stats),
              const SizedBox(height: 22),
              const SectionHeading('Hazards spotted'),
              _HazardsCard(stats: stats),
              const SizedBox(height: 22),
              const SectionHeading('Recent trips'),
              for (final trip in stats.trips.take(4)) ...[
                TripCard(trip: trip),
                const SizedBox(height: 12),
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

class _SummaryBanner extends StatelessWidget {
  const _SummaryBanner({required this.stats});

  final TripStats stats;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final headline = stats.isEmpty
        ? 'Waiting for your first trip'
        : '${stats.totalTrips} ${stats.totalTrips == 1 ? 'trip' : 'trips'} logged';
    final sub = stats.isEmpty
        ? 'Charts and totals will show up after you save a drive.'
        : '${stats.totalHazards} hazards · '
              '${Format.distance(stats.totalDistanceMeters)} total';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: p.brand.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.insights_outlined,
              color: p.brand,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  style: GoogleFonts.sora(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: p.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: GoogleFonts.dmSans(
                    fontSize: 12.5,
                    height: 1.35,
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

class _WeeklyCard extends StatelessWidget {
  const _WeeklyCard({required this.stats});

  final TripStats stats;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Weekly overview',
                style: GoogleFonts.sora(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: p.textPrimary,
                ),
              ),
              const Spacer(),
              const StatusPill(label: 'Last 7 days'),
            ],
          ),
          const SizedBox(height: 16),
          WeekBars(
            values: stats.dailyHazards,
            labels: Format.lastSevenDayLabels(),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  icon: Icons.route_rounded,
                  value: '${stats.weekTrips}',
                  label: 'Trips',
                ),
              ),
              Expanded(
                child: _MiniStat(
                  icon: Icons.straighten_rounded,
                  value: Format.distance(stats.weekDistanceMeters),
                  label: 'Distance',
                ),
              ),
              Expanded(
                child: _MiniStat(
                  icon: Icons.schedule_rounded,
                  value: Format.duration(stats.weekDurationSeconds),
                  label: 'Drive time',
                ),
              ),
              Expanded(
                child: _MiniStat(
                  icon: Icons.warning_amber_rounded,
                  value: '${stats.weekHazards}',
                  label: 'Hazards',
                  tint: AppColors.amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Divider(color: p.border, height: 1),
          const SizedBox(height: 16),
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
        Icon(icon, size: 17, color: color),
        const SizedBox(height: 8),
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

class _LifetimeGrid extends StatelessWidget {
  const _LifetimeGrid({required this.stats});

  final TripStats stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StatTile(
                icon: Icons.route_rounded,
                value: '${stats.totalTrips}',
                label: 'Total trips',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatTile(
                icon: Icons.schedule_rounded,
                value: Format.duration(stats.totalDurationSeconds),
                label: 'Drive time',
                accent: AppColors.sky,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: StatTile(
                icon: Icons.warning_amber_rounded,
                value: '${stats.totalHazards}',
                label: 'Hazards',
                accent: AppColors.amber,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatTile(
                icon: Icons.straighten_rounded,
                value: Format.distance(stats.totalDistanceMeters),
                label: 'Distance',
                accent: AppColors.safe,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HazardsCard extends StatelessWidget {
  const _HazardsCard({required this.stats});

  final TripStats stats;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final breakdown = stats.hazardBreakdown;

    if (breakdown.isEmpty) {
      return const EmptyState(
        icon: Icons.verified_rounded,
        title: 'No hazards detected',
        message: 'Clean roads so far. RAASTA will log anything it spots.',
      );
    }

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            children: [
              DonutChart(
                size: 132,
                slices: [
                  for (final entry in breakdown)
                    DonutSlice(
                      label: entry.key.label,
                      value: entry.value,
                      color: entry.key.color,
                    ),
                ],
                centerValue: '${stats.totalHazards}',
                centerLabel: 'total',
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final entry in breakdown.take(4))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                color: entry.key.color,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                entry.key.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.dmSans(
                                  fontSize: 13,
                                  color: p.textSecondary,
                                ),
                              ),
                            ),
                            Text(
                              '${entry.value}',
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: p.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

