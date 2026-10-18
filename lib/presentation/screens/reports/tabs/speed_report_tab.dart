import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/report_data.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/raasta_nav_bar.dart';
import '../../../widgets/charts/line_chart.dart';
import '../../../widgets/insight_row.dart';
import '../../../widgets/stat_tile.dart';
import '../widgets/report_empty.dart';

class SpeedReportTab extends StatelessWidget {
  const SpeedReportTab({
    super.key,
    required this.report,
    required this.hasTrips,
  });

  final SpeedReport report;
  final bool hasTrips;

  @override
  Widget build(BuildContext context) {
    if (!hasTrips) {
      return const ReportEmpty(
        title: 'No saved drives',
        message: 'Save a drive from Home to see speed totals.',
      );
    }

    if (report.isEmpty) {
      return const ReportEmpty(
        title: 'No speed data',
        message: 'Average speed appears after a saved drive with GPS.',
      );
    }

    final overspeedTint = report.overspeedCount == 0
        ? AppColors.safe
        : AppColors.alert;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, RaastaNavBar.contentInset),
      children: [
        const SectionLabel('Speed statistics'),
        Row(
          children: [
            Expanded(
              child: StatTile(
                icon: Icons.speed_outlined,
                value: '${report.avgSpeedKph.round()} km/h',
                label: 'Average speed',
                compact: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatTile(
                icon: Icons.speed_outlined,
                value: '${report.maxSpeedKph.round()} km/h',
                label: 'Top speed',
                accent: AppColors.teal,
                compact: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: StatTile(
                icon: Icons.warning_amber_outlined,
                value: '${report.overspeedCount}',
                label: 'Overspeed alerts',
                accent: overspeedTint,
                compact: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatTile(
                icon: Icons.trending_up_outlined,
                value: report.fastestDay ?? '—',
                label: 'Fastest day',
                compact: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const SectionLabel('Average speed by day'),
        AppCard(
          radius: 14,
          padding: const EdgeInsets.fromLTRB(14, 16, 16, 14),
          child: LineChart(
            values: report.dailyAvgSpeed,
            labels: report.dayLabels,
            color: AppColors.teal,
          ),
        ),
        const SizedBox(height: 16),
        const SectionLabel('Speed insights'),
        AppCard(
          radius: 14,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            children: [
              InsightRow(
                icon: Icons.wb_twilight_outlined,
                label: 'Calmest driving window',
                value: report.calmestPart?.label ?? '—',
                tint: AppColors.teal,
              ),
              InsightRow(
                icon: Icons.shield_outlined,
                label: report.overspeedCount == 0
                    ? 'No overspeed alerts'
                    : 'Overspeed alerts recorded',
                value: '${report.overspeedCount}',
                tint: overspeedTint,
              ),
              InsightRow(
                icon: Icons.info_outline_rounded,
                label: 'Speeds are estimated from trip distance and time',
                value: '',
                tint: AppColors.amber,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
