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
import '../../widgets/greeting_header.dart';
import '../../widgets/raasta_nav_bar.dart';

/// Home: start a drive + readiness. Stats live on Dashboard / Reports.
class DriveTab extends StatefulWidget {
  const DriveTab({super.key});

  @override
  State<DriveTab> createState() => _DriveTabState();
}

class _DriveTabState extends State<DriveTab> with WidgetsBindingObserver {
  final _permissions = PermissionService();
  bool? _cameraOk;
  bool? _locationOk;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshReady();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshReady();
  }

  Future<void> _refreshReady() async {
    final cam = await _permissions.statusOf(AppPermissionKind.camera);
    final loc = await _permissions.statusOf(AppPermissionKind.location);
    if (!mounted) return;
    setState(() {
      _cameraOk = cam.isGranted;
      _locationOk = loc.isGranted;
    });
  }

  Future<void> _fixPermission(AppPermissionKind kind) async {
    final status = await _permissions.request(kind);
    if (!status.isGranted) await openAppSettings();
    if (mounted) await _refreshReady();
  }

  static String _readyLine({
    required bool cameraOk,
    required bool locationOk,
  }) {
    if (!cameraOk && !locationOk) {
      return 'Allow camera and location to start a drive.';
    }
    if (!cameraOk) {
      return 'Allow camera access to detect road hazards.';
    }
    if (!locationOk) {
      return 'Allow location to show speed and distance.';
    }
    return 'Camera and location are ready.';
  }

  Future<void> _startDrive() async {
    await Navigator.of(context).pushNamed(AppRoutes.drive);
    if (!mounted) return;
    await context.read<TripsProvider>().refresh();
    await _refreshReady();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final user = context.watch<AuthProvider>().user;
    final settings = context.watch<SettingsProvider>().settings;
    final stats = context.watch<TripsProvider>().stats;
    final first = user?.name.trim().split(' ').first ?? 'Driver';
    final now = DateTime.now();

    final activity = ActivityItem.from(stats);
    final hasRecent = activity.isNotEmpty &&
        DateTime.now().difference(activity.first.at) < const Duration(days: 1);

    final greeting = GreetingHeader.greetingFor(now);
    final cameraOk = _cameraOk == true;
    final locationOk = _locationOk == true;
    final voiceOk = settings.voiceAlerts;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, RaastaNavBar.contentInset),
        children: [
          PillAppBar(
            actions: [
              PillBarAction(
                icon: Icons.notifications_none_rounded,
                tooltip: 'Activity',
                showDot: hasRecent,
                onTap: () => ActivitySheet.show(context, activity),
              ),
              PillBarAction(
                icon: Icons.settings_outlined,
                tooltip: 'Settings',
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRoutes.settings),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _WelcomeHero(
            dateLabel: Format.longDate(now),
            title: '$greeting, $first',
            subtitle: _readyLine(cameraOk: cameraOk, locationOk: locationOk),
            onStart: _startDrive,
          ),
          const SizedBox(height: 16),
          Text(
            'Drive readiness',
            style: GoogleFonts.sora(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: p.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          _ReadyRow(
            items: [
              _ReadyItem(
                icon: Icons.photo_camera_outlined,
                label: 'Camera',
                ok: cameraOk,
                offLabel: 'Allow access',
                onTap: () => _fixPermission(AppPermissionKind.camera),
              ),
              _ReadyItem(
                icon: Icons.place_outlined,
                label: 'GPS',
                ok: locationOk,
                offLabel: 'Allow access',
                onTap: () => _fixPermission(AppPermissionKind.location),
              ),
              _ReadyItem(
                icon: Icons.volume_up_outlined,
                label: 'Voice',
                ok: voiceOk,
                offLabel: 'Off',
                alwaysTappable: true,
                onTap: () async {
                  await context.read<SettingsProvider>().setVoiceAlerts(
                    !settings.voiceAlerts,
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Quick tips',
            style: GoogleFonts.sora(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: p.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const _TipStrip(),
        ],
      ),
    );
  }
}

class _WelcomeHero extends StatelessWidget {
  const _WelcomeHero({
    required this.dateLabel,
    required this.title,
    required this.subtitle,
    required this.onStart,
  });

  final String dateLabel;
  final String title;
  final String subtitle;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: AppColors.homeHeroGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dateLabel,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              color: AppColors.white.withValues(alpha: 0.68),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: GoogleFonts.sora(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: GoogleFonts.dmSans(
              fontSize: 12.5,
              color: AppColors.white.withValues(alpha: 0.78),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Material(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(99),
            child: InkWell(
              onTap: onStart,
              borderRadius: BorderRadius.circular(99),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.play_arrow_rounded,
                      size: 18,
                      color: AppColors.tealDeep,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Start drive',
                      style: GoogleFonts.dmSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.tealDeep,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadyItem {
  const _ReadyItem({
    required this.icon,
    required this.label,
    required this.ok,
    required this.offLabel,
    required this.onTap,
    this.alwaysTappable = false,
  });

  final IconData icon;
  final String label;
  final bool ok;
  final String offLabel;
  final VoidCallback onTap;
  final bool alwaysTappable;
}

class _ReadyRow extends StatelessWidget {
  const _ReadyRow({required this.items});

  final List<_ReadyItem> items;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: _ReadyChip(item: items[i], palette: p)),
        ],
      ],
    );
  }
}

class _ReadyChip extends StatelessWidget {
  const _ReadyChip({required this.item, required this.palette});

  final _ReadyItem item;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final ok = item.ok;
    final tint = ok ? AppColors.safe : AppColors.amber;

    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: ok && !item.alwaysTappable ? null : item.onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: ok ? palette.border : AppColors.amber.withValues(alpha: 0.45),
            ),
          ),
          child: Column(
            children: [
              Icon(item.icon, size: 18, color: palette.brand),
              const SizedBox(height: 4),
              Text(
                item.label,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                ok ? 'On' : item.offLabel,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  height: 1.15,
                  color: tint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TipStrip extends StatelessWidget {
  const _TipStrip();

  static const _tips = [
    (
      Icons.phone_android_outlined,
      'Mount the phone',
      'Point the rear camera at the road.',
    ),
    (
      Icons.volume_up_outlined,
      'Keep voice on',
      'Alerts are spoken so you can watch the road.',
    ),
    (
      Icons.place_outlined,
      'Leave location on',
      'GPS is used for speed and distance.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < _tips.length; i++) ...[
            if (i > 0)
              Divider(height: 1, color: p.border.withValues(alpha: 0.9)),
            _TipRow(
              icon: _tips[i].$1,
              title: _tips[i].$2,
              body: _tips[i].$3,
            ),
          ],
        ],
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  const _TipRow({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: p.brand),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: p.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: p.textSecondary,
                    height: 1.3,
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
