import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/report_data.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/raasta_nav_bar.dart';
import '../../../widgets/charts/bar_chart.dart';
import '../../../widgets/charts/score_ring.dart';
import '../../../widgets/insight_row.dart';
import '../../../widgets/stat_tile.dart';
import '../widgets/report_empty.dart';

class WeeklyReportTab extends StatelessWidget {
  const WeeklyReportTab({
    super.key,
    required this.report,
    required this.hasTrips,
  });

  final WeeklyReport report;
  final bool hasTrips;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    if (!hasTrips) {
      return const ReportEmpty(
        message: 'Finish a drive and your weekly report will build itself.',
        showStartDrive: true,
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, RaastaNavBar.contentInset),
      children: [
        const SectionLabel('This week'),
        Row(
          children: [
            Expanded(
              child: StatTile(
                icon: Icons.route_rounded,
                value: '${report.trips}',
                label: 'Trips',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatTile(
                icon: Icons.straighten_rounded,
                value: Format.distance(report.distanceMeters),
                label: 'Distance',
                accent: AppColors.safe,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: StatTile(
                icon: Icons.schedule_rounded,
                value: Format.duration(report.durationSeconds),
                label: 'Drive time',
                accent: AppColors.sky,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatTile(
                icon: Icons.warning_amber_rounded,
                value: '${report.hazards}',
                label: 'Hazards found',
                accent: AppColors.amber,
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        const SectionLabel('Trips by day'),
        AppCard(
          padding: const EdgeInsets.fromLTRB(14, 18, 16, 14),
          child: BarChart(
            highlightLast: true,
            data: [
              for (var i = 0; i < report.tripsPerDay.length; i++)
                BarDatum(
                  label: report.dayLabels[i],
                  value: report.tripsPerDay[i].toDouble(),
                ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const SectionLabel('Hazards by day'),
        AppCard(
          padding: const EdgeInsets.fromLTRB(14, 18, 16, 14),
          child: BarChart(
            color: AppColors.amber,
            data: [
              for (var i = 0; i < report.hazardsPerDay.length; i++)
                BarDatum(
                  label: report.dayLabels[i],
                  value: report.hazardsPerDay[i].toDouble(),
                ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const SectionLabel('Safety score'),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: ScoreRing(
              score: report.safetyScore,
              hasData: report.trips > 0,
              caption: report.trips > 0
                  ? 'Averaged across ${report.trips} '
                        '${report.trips == 1 ? 'trip' : 'trips'} this week'
                  : 'No trips logged in the last 7 days',
            ),
          ),
        ),
        const SizedBox(height: 22),
        const SectionLabel("This week's insights"),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            children: [
              InsightRow(
                icon: Icons.speed_rounded,
                label: 'Average speed',
                value: '${report.avgSpeedKph.round()} km/h',
              ),
              InsightRow(
                icon: Icons.straighten_rounded,
                label: 'Distance covered',
                value: Format.distance(report.distanceMeters),
                tint: AppColors.safe,
              ),
              InsightRow(
                icon: Icons.wb_twilight_rounded,
                label: 'Safest time to drive',
                value: report.safestPart?.label ?? '—',
                tint: AppColors.sky,
              ),
              InsightRow(
                icon: Icons.calendar_today_rounded,
                label: 'Most active day',
                value: report.mostActiveDay ?? '—',
                tint: AppColors.violet,
              ),
              _TrendRow(delta: report.tripDelta, palette: p),
            ],
          ),
        ),
      ],
    );
  }
}

class _TrendRow extends StatelessWidget {
  const _TrendRow({required this.delta, required this.palette});

  final int delta;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final up = delta > 0;
    final flat = delta == 0;
    final tint = flat
        ? palette.textSecondary
        : up
        ? AppColors.safe
        : AppColors.amber;

    return InsightRow(
      icon: flat
          ? Icons.trending_flat_rounded
          : up
          ? Icons.trending_up_rounded
          : Icons.trending_down_rounded,
      label: 'Compared to last week',
      value: flat ? 'Same' : '${up ? '+' : ''}$delta trips',
      tint: tint,
    );
  }
}
