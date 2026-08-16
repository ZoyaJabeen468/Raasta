import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/routes.dart';
import '../../core/widgets/ambient_background.dart';
import '../providers/auth_provider.dart';
import '../providers/driver_profile_provider.dart';
import '../providers/trips_provider.dart';
import '../widgets/raasta_nav_bar.dart';
import 'home/dashboard_tab.dart';
import 'home/drive_tab.dart';
import 'home/profile_tab.dart';
import 'reports/reports_screen.dart';

/// Signed-in shell: Home, Dashboard, Reports, Profile, with Start Drive as
/// the raised centre action.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadUserData());
  }

  Future<void> _loadUserData() async {
    if (!mounted) return;
    final userId = context.read<AuthProvider>().user?.id;
    await context.read<TripsProvider>().load(userId);
    if (!mounted) return;
    await context.read<DriverProfileProvider>().load(userId);
  }

  Future<void> _startDrive() async {
    await Navigator.of(context).pushNamed(AppRoutes.drive);
    if (!mounted) return;
    await context.read<TripsProvider>().refresh();
  }

  @override
  Widget build(BuildContext context) {
    return AmbientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        body: IndexedStack(
          index: _index,
          children: [
            const DriveTab(),
            DashboardTab(onStartDrive: _startDrive),
            const ReportsScreen(embedded: true),
            const ProfileTab(),
          ],
        ),
        bottomNavigationBar: RaastaNavBar(
          index: _index,
          onChanged: (i) => setState(() => _index = i),
          centerIcon: Icons.navigation_rounded,
          centerTooltip: 'Start drive',
          onCenterTap: _startDrive,
          items: const [
            NavBarItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home_rounded,
              label: 'Home',
            ),
            NavBarItem(
              icon: Icons.bar_chart_outlined,
              activeIcon: Icons.bar_chart_rounded,
              label: 'Dashboard',
            ),
            NavBarItem(
              icon: Icons.insights_outlined,
              activeIcon: Icons.insights_rounded,
              label: 'Reports',
            ),
            NavBarItem(
              icon: Icons.person_outline_rounded,
              activeIcon: Icons.person_rounded,
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
