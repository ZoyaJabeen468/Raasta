import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/activity_item.dart';
import '../../../data/services/permission_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/trips_provider.dart';
import '../../widgets/activity_sheet.dart';
import '../../widgets/app_card.dart';
import '../../widgets/greeting_header.dart';
import '../../widgets/quick_action_strip.dart';
import '../../widgets/raasta_nav_bar.dart';

/// Drive tab — calm pre-drive surface: status, one start action, short tips.
class DriveTab extends StatefulWidget {
  const DriveTab({super.key});

  @override
  State<DriveTab> createState() => _DriveTabState();
}

class _DriveTabState extends State<DriveTab> with WidgetsBindingObserver {
  final _permissions = PermissionService();
  bool? _cameraReady;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkCamera();
  }

  Future<void> _checkCamera() async {
    final status = await _permissions.statusOf(AppPermissionKind.camera);
    if (mounted) setState(() => _cameraReady = status.isGranted);
  }

  Future<void> _openCameraHelp() async {
    if (_cameraReady == true) return;
    await openAppSettings();
    if (mounted) await _checkCamera();
  }

  Future<void> _startDrive() async {
    await Navigator.of(context).pushNamed(AppRoutes.drive);
    if (!mounted) return;
    await context.read<TripsProvider>().refresh();
    await _checkCamera();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final stats = context.watch<TripsProvider>().stats;
    final settings = context.watch<SettingsProvider>().settings;
    final first = user?.name.trim().split(' ').first ?? 'Driver';

    final activity = ActivityItem.from(stats);
    final hasRecent =
        activity.isNotEmpty &&
        DateTime.now().difference(activity.first.at) < const Duration(days: 1);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, RaastaNavBar.contentInset),
        children: [
          GreetingHeader(
            name: first,
            actions: [
              HeaderAction(
                icon: Icons.notifications_none_rounded,
                tooltip: 'Activity',
                showDot: hasRecent,
                onTap: () => ActivitySheet.show(context, activity),
              ),
              HeaderAction(
                icon: Icons.settings_outlined,
                tooltip: 'Settings',
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRoutes.settings),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _ReadyPill(
            cameraReady: _cameraReady,
            onTap: _cameraReady == false ? _openCameraHelp : null,
          ),
          const SizedBox(height: 16),
          _StartDriveCard(onStart: _startDrive),
          const SizedBox(height: 10),
          Text(
            'You can also use the Drive button in the bar below.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 12.5,
              color: context.palette.textSecondary,
            ),
          ),
          const SizedBox(height: 22),
          QuickActionStrip(
            actions: [
              QuickAction(
                icon: Icons.translate_rounded,
                label: settings.voiceAlerts
                    ? settings.language.label
                    : 'Muted',
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRoutes.settings),
              ),
              QuickAction(
                icon: Icons.insights_rounded,
                label: stats.trips.isEmpty
                    ? 'Reports'
                    : Format.tripStamp(
                        stats.trips.first.startedAt,
                      ).split(' · ').first,
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRoutes.reports),
              ),
              QuickAction(
                icon: Icons.help_outline_rounded,
                label: 'Help',
                onTap: () => Navigator.of(context).pushNamed(AppRoutes.faq),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const _BeforeYouGo(),
        ],
      ),
    );
  }
}

class _ReadyPill extends StatelessWidget {
  const _ReadyPill({required this.cameraReady, this.onTap});

  final bool? cameraReady;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    late final Widget pill;
    if (cameraReady == null) {
      pill = StatusPill(
        icon: Icons.hourglass_empty_rounded,
        label: 'Checking camera',
        color: p.textSecondary,
      );
    } else if (cameraReady!) {
      pill = const StatusPill(
        icon: Icons.verified_user_rounded,
        label: 'Camera ready',
        color: AppColors.safe,
      );
    } else {
      pill = const StatusPill(
        icon: Icons.videocam_off_rounded,
        label: 'Camera off — tap to enable',
        color: AppColors.amber,
      );
    }

    if (onTap == null) return Align(alignment: Alignment.centerLeft, child: pill);

    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(99),
          child: pill,
        ),
      ),
    );
  }
}

class _StartDriveCard extends StatelessWidget {
  const _StartDriveCard({required this.onStart});

  final Future<void> Function() onStart;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onStart,
        borderRadius: BorderRadius.circular(26),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
          decoration: BoxDecoration(
            gradient: AppColors.driveGradient,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: AppColors.teal.withValues(alpha: 0.28),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: AppColors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Start drive',
                      style: GoogleFonts.sora(
                        color: AppColors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Live alerts, GPS speed, trip summary.',
                      style: GoogleFonts.dmSans(
                        color: AppColors.white.withValues(alpha: 0.9),
                        fontSize: 13.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: AppColors.white.withValues(alpha: 0.85),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BeforeYouGo extends StatelessWidget {
  const _BeforeYouGo();

  static const _tips = [
    (Icons.phone_android_rounded, 'Mount your phone', 'Rear camera toward the road'),
    (Icons.volume_up_rounded, 'Allow microphone', 'Voice alerts; otherwise visual only'),
    (Icons.my_location_rounded, 'Keep location on', 'GPS speed and trip start'),
    (Icons.battery_charging_full_rounded, 'Keep it charged', 'Camera runs continuously'),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return AppCard(
      radius: 18,
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: p.brandSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.checklist_rounded, color: p.brand, size: 20),
          ),
          title: Text(
            'Before you go',
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w700,
              color: p.textPrimary,
              fontSize: 15.5,
            ),
          ),
          subtitle: Text(
            '4 quick checks',
            style: GoogleFonts.dmSans(
              color: p.textSecondary,
              fontSize: 12.5,
            ),
          ),
          children: [
            for (var i = 0; i < _tips.length; i++) ...[
              if (i > 0) Divider(height: 18, color: p.border),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(_tips[i].$1, size: 18, color: p.brand),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _tips[i].$2,
                          style: GoogleFonts.dmSans(
                            fontWeight: FontWeight.w700,
                            color: p.textPrimary,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _tips[i].$3,
                          style: GoogleFonts.dmSans(
                            color: p.textSecondary,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
