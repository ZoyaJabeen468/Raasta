import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/report_data.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/raasta_nav_bar.dart';
import '../../../widgets/charts/line_chart.dart';
import '../../../widgets/charts/score_ring.dart';
import '../../../widgets/stat_tile.dart';
import '../widgets/report_empty.dart';

class MonthlyReportTab extends StatelessWidget {
  const MonthlyReportTab({
    super.key,
    required this.report,
    required this.hasTrips,
  });

  final MonthlyReport report;
  final bool hasTrips;

  @override
  Widget build(BuildContext context) {
    if (!hasTrips) {
      return const ReportEmpty(
        message: 'Drive through the month and trends will show up here.',
        showStartDrive: true,
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, RaastaNavBar.contentInset),
      children: [
        SectionLabel(Format.monthYear(DateTime.now())),
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
        const SectionLabel('Versus last month'),
        _ComparisonCard(report: report),
        const SizedBox(height: 22),
        const SectionLabel('Trip trend'),
        AppCard(
          padding: const EdgeInsets.fromLTRB(14, 18, 16, 14),
          child: LineChart(
            values: report.tripsPerWeek.map((v) => v.toDouble()).toList(),
            labels: report.weekLabels,
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
              caption: 'Monthly average across ${report.trips} '
                  '${report.trips == 1 ? 'trip' : 'trips'}',
            ),
          ),
        ),
      ],
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard({required this.report});

  final MonthlyReport report;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        children: [
          _DeltaRow(
            label: 'Safety score',
            current: '${report.safetyScore}',
            delta: report.scoreDelta,
            deltaLabel: report.scoreDelta == 0
                ? 'No change'
                : '${report.scoreDelta > 0 ? '+' : ''}${report.scoreDelta} pts',
            positiveIsGood: true,
            palette: p,
          ),
          Divider(color: p.border, height: 20),
          _DeltaRow(
            label: 'Trips',
            current: '${report.trips}',
            delta: report.tripDelta,
            deltaLabel: report.tripDelta == 0
                ? 'No change'
                : '${report.tripDelta > 0 ? '+' : ''}${report.tripDelta}',
            positiveIsGood: true,
            palette: p,
          ),
          Divider(color: p.border, height: 20),
          _DeltaRow(
            label: 'Distance',
            current: Format.distance(report.distanceMeters),
            delta: report.distanceDelta.round(),
            deltaLabel: report.distanceDelta.abs() < 1
                ? 'No change'
                : '${report.distanceDelta > 0 ? '+' : '-'}'
                      '${Format.distance(report.distanceDelta.abs())}',
            positiveIsGood: true,
            palette: p,
          ),
        ],
      ),
    );
  }
}

class _DeltaRow extends StatelessWidget {
  const _DeltaRow({
    required this.label,
    required this.current,
    required this.delta,
    required this.deltaLabel,
    required this.positiveIsGood,
    required this.palette,
  });

  final String label;
  final String current;
  final int delta;
  final String deltaLabel;
  final bool positiveIsGood;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final flat = delta == 0;
    final good = positiveIsGood ? delta > 0 : delta < 0;
    final tint = flat
        ? palette.textSecondary
        : good
        ? AppColors.safe
        : AppColors.alert;

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 13.5,
              color: palette.textSecondary,
            ),
          ),
        ),
        Text(
          current,
          style: GoogleFonts.sora(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                flat
                    ? Icons.remove_rounded
                    : good
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                size: 12,
                color: tint,
              ),
              const SizedBox(width: 3),
              Text(
                deltaLabel,
                style: GoogleFonts.dmSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: tint,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
