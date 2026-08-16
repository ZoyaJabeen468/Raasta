import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../data/models/report_data.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/raasta_nav_bar.dart';
import '../../../widgets/charts/bar_chart.dart';
import '../../../widgets/insight_row.dart';
import '../widgets/report_empty.dart';

class HazardsReportTab extends StatelessWidget {
  const HazardsReportTab({
    super.key,
    required this.report,
    required this.hasTrips,
  });

  final HazardReport report;
  final bool hasTrips;

  @override
  Widget build(BuildContext context) {
    if (!hasTrips) {
      return const ReportEmpty(
        message: 'Hazard detections from your drives will be broken down here.',
        showStartDrive: true,
      );
    }

    if (report.isEmpty) {
      return const ReportEmpty(
        title: 'Clean roads so far',
        message:
            'No hazards logged on your trips yet. Keep driving safely — '
            'this is the best kind of empty report.',
        icon: Icons.verified_rounded,
        celebrate: true,
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, RaastaNavBar.contentInset),
      children: [
        const SectionLabel('Detections'),
        _TypeGrid(report: report),
        const SizedBox(height: 22),
        const SectionLabel('Hazard breakdown'),
        AppCard(
          padding: const EdgeInsets.fromLTRB(14, 18, 16, 14),
          child: BarChart(
            barWidth: 22,
            data: [
              for (final entry in report.breakdown)
                BarDatum(
                  label: entry.key.label,
                  value: entry.value.toDouble(),
                  color: entry.key.color,
                ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const SectionLabel('Share of detections'),
        _ShareCard(report: report),
        const SizedBox(height: 22),
        const SectionLabel('Analysis'),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            children: [
              InsightRow(
                icon: Icons.priority_high_rounded,
                label: 'Most common hazard',
                value: report.mostCommon?.label ?? '—',
                tint: report.mostCommon?.color,
              ),
              InsightRow(
                icon: Icons.calendar_month_rounded,
                label: 'Detected this month',
                value: '${report.thisMonth}',
                tint: AppColors.sky,
              ),
              InsightRow(
                icon: Icons.functions_rounded,
                label: 'Average per trip',
                value: report.avgPerTrip.toStringAsFixed(1),
                tint: AppColors.violet,
              ),
              InsightRow(
                icon: Icons.nightlight_round,
                label: 'Riskiest time of day',
                value: report.worstDayPart?.label ?? '—',
                tint: AppColors.amber,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TypeGrid extends StatelessWidget {
  const _TypeGrid({required this.report});

  final HazardReport report;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final items = report.breakdown.take(4).toList();

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final entry in items)
          SizedBox(
            width: (MediaQuery.sizeOf(context).width - 32 - 12) / 2,
            child: AppCard(
              radius: 18,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: entry.key.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      entry.key.icon,
                      size: 19,
                      color: entry.key.color,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '${entry.value}',
                    style: GoogleFonts.sora(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      color: p.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.key.label,
                    style: GoogleFonts.dmSans(
                      fontSize: 12.5,
                      color: p.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ShareCard extends StatelessWidget {
  const _ShareCard({required this.report});

  final HazardReport report;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        children: [
          for (final entry in report.breakdown)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(entry.key.icon, size: 15, color: entry.key.color),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          entry.key.label,
                          style: GoogleFonts.dmSans(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: p.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        '${((entry.value / report.total) * 100).round()}%',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: p.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: entry.value / report.total),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      builder: (context, t, _) => LinearProgressIndicator(
                        value: t,
                        minHeight: 7,
                        backgroundColor: p.surfaceAlt,
                        valueColor: AlwaysStoppedAnimation(entry.key.color),
                      ),
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
