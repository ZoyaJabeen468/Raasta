import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_palette.dart';
import '../../providers/trips_provider.dart';
import '../../widgets/skeleton.dart';
import 'tabs/hazards_report_tab.dart';
import 'tabs/monthly_report_tab.dart';
import 'tabs/speed_report_tab.dart';
import 'tabs/weekly_report_tab.dart';

/// Reports & Insights — weekly, monthly, hazard and speed breakdowns.
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
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          automaticallyImplyLeading: !embedded,
          title: const Text('Reports & insights'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(58),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _SegmentedTabs(palette: p),
            ),
          ),
        ),
        body: !trips.isReady
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
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
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
          borderRadius: BorderRadius.circular(11),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: palette.textSecondary,
        labelStyle: GoogleFonts.dmSans(
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: GoogleFonts.dmSans(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        // FittedBox keeps the longest label ("Hazards") readable when four
        // equal tabs are squeezed onto a narrow phone.
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
