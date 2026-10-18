import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_palette.dart';
import '../../providers/trips_provider.dart';
import '../../widgets/greeting_header.dart';
import '../../widgets/skeleton.dart';
import 'tabs/hazards_report_tab.dart';
import 'tabs/monthly_report_tab.dart';
import 'tabs/speed_report_tab.dart';
import 'tabs/weekly_report_tab.dart';

/// Reports: weekly, monthly, hazard and speed breakdowns.
///
/// Set [embedded] when hosting it as a tab inside the home shell, so it
/// drops its own background and back button.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final trips = context.watch<TripsProvider>();
    final reports = trips.reports;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: embedded
            ? null
            : AppBar(
                backgroundColor: Colors.transparent,
                title: Text(
                  'Reports',
                  style: GoogleFonts.sora(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: p.textPrimary,
                  ),
                ),
              ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (embedded)
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PillAppBar(
                        actions: [
                          PillBarAction(
                            icon: Icons.refresh_rounded,
                            tooltip: 'Refresh',
                            onTap: trips.refresh,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Reports',
                        style: GoogleFonts.sora(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: p.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, embedded ? 12 : 8, 20, 8),
              child: _SegmentedTabs(palette: p),
            ),
            Expanded(
              child: !trips.isReady
                  ? const SkeletonList(cards: 3)
                  : RefreshIndicator(
                      color: p.brand,
                      onRefresh: trips.refresh,
                      child: TabBarView(
                        children: [
                          WeeklyReportTab(
                            report: reports.weekly,
                            hasTrips: reports.hasTrips,
                          ),
                          MonthlyReportTab(
                            report: reports.monthly,
                            hasTrips: reports.hasTrips,
                          ),
                          HazardsReportTab(
                            report: reports.hazards,
                            hasTrips: reports.hasTrips,
                          ),
                          SpeedReportTab(
                            report: reports.speed,
                            hasTrips: reports.hasTrips,
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FittedTab extends StatelessWidget {
  const _FittedTab(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: FittedBox(child: Text(label)),
      ),
    );
  }
}

class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({required this.palette});

  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: TabBar(
        isScrollable: false,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: EdgeInsets.zero,
        padding: EdgeInsets.zero,
        labelPadding: EdgeInsets.zero,
        indicator: BoxDecoration(
          color: palette.brand,
          borderRadius: BorderRadius.circular(9),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: palette.textSecondary,
        labelStyle: GoogleFonts.dmSans(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: GoogleFonts.dmSans(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
        tabs: const [
          _FittedTab('Weekly'),
          _FittedTab('Monthly'),
          _FittedTab('Hazards'),
          _FittedTab('Speed'),
        ],
      ),
    );
  }
}
