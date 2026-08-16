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
        message: 'Speed patterns appear once RAASTA has logged a drive.',
        showStartDrive: true,
      );
    }

    if (report.isEmpty) {
      return const ReportEmpty(
        message: 'Speed patterns appear once RAASTA has logged a drive.',
        showStartDrive: true,
      );
    }

    final overspeedTint = report.overspeedCount == 0
        ? AppColors.safe
        : AppColors.alert;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, RaastaNavBar.contentInset),
      children: [
        const SectionLabel('Speed statistics'),
        Row(
          children: [
            Expanded(
              child: StatTile(
                icon: Icons.speed_rounded,
                value: '${report.avgSpeedKph.round()} km/h',
                label: 'Average speed',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatTile(
                icon: Icons.rocket_launch_rounded,
                value: '${report.maxSpeedKph.round()} km/h',
                label: 'Top speed',
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
                icon: Icons.report_gmailerrorred_rounded,
                value: '${report.overspeedCount}',
                label: 'Overspeed events',
                accent: overspeedTint,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatTile(
                icon: Icons.trending_up_rounded,
                value: report.fastestDay ?? '—',
                label: 'Fastest day',
                accent: AppColors.violet,
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        const SectionLabel('Average speed by day'),
        AppCard(
          padding: const EdgeInsets.fromLTRB(14, 18, 16, 14),
          child: LineChart(
            values: report.dailyAvgSpeed,
            labels: report.dayLabels,
            color: AppColors.sky,
          ),
        ),
        const SizedBox(height: 22),
        const SectionLabel('Speed insights'),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            children: [
              InsightRow(
                icon: Icons.wb_twilight_rounded,
                label: 'Calmest driving window',
                value: report.calmestPart?.label ?? '—',
                tint: AppColors.sky,
              ),
              InsightRow(
                icon: Icons.calendar_today_rounded,
                label: 'Highest average day',
                value: report.fastestDay ?? '—',
                tint: AppColors.violet,
              ),
              InsightRow(
                icon: Icons.shield_rounded,
                label: report.overspeedCount == 0
                    ? 'No speed violations logged'
                    : 'Speed violations recorded',
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
