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
        padding: const EdgeInsets.fromLTRB(20, 12, 20, RaastaNavBar.contentInset),
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
          const SizedBox(height: 16),
          _WelcomeHero(
            dateLabel: Format.longDate(now),
            title: '$greeting, $first',
            subtitle: cameraOk
                ? 'RAASTA is ready when you are.'
                : 'Turn on camera before you start.',
            onStart: _startDrive,
          ),
          const SizedBox(height: 22),
          Text(
            'Before you drive',
            style: GoogleFonts.sora(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: p.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          _ReadyRow(
            items: [
              _ReadyItem(
                icon: Icons.photo_camera_outlined,
                label: 'Camera',
                ok: cameraOk,
                onTap: () => _fixPermission(AppPermissionKind.camera),
              ),
              _ReadyItem(
                icon: Icons.place_outlined,
                label: 'GPS',
                ok: locationOk,
                onTap: () => _fixPermission(AppPermissionKind.location),
              ),
              _ReadyItem(
                icon: Icons.volume_up_outlined,
                label: 'Voice',
                ok: voiceOk,
                onTap: () async {
                  await context.read<SettingsProvider>().setVoiceAlerts(
                    !settings.voiceAlerts,
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            'Quick tips',
            style: GoogleFonts.sora(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: p.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
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
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        gradient: AppColors.driveGradient,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dateLabel,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: AppColors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.sora(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: AppColors.white.withValues(alpha: 0.88),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Material(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(99),
            child: InkWell(
              onTap: onStart,
              borderRadius: BorderRadius.circular(99),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                        fontSize: 14,
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
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool ok;
  final VoidCallback onTap;
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
        onTap: ok ? null : item.onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            children: [
              Icon(item.icon, size: 20, color: palette.brand),
              const SizedBox(height: 6),
              Text(
                item.label,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                ok ? 'On' : 'Off',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
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
    (Icons.phone_android_outlined, 'Mount phone', 'Rear camera to road'),
    (Icons.volume_up_outlined, 'Voice ready', 'Or use visual alerts'),
    (Icons.place_outlined, 'Location on', 'Needed for speed'),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _tips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final tip = _tips[i];
          return Container(
            width: 132,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: p.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(tip.$1, size: 18, color: p.brand),
                const Spacer(),
                Text(
                  tip.$2,
                  style: GoogleFonts.dmSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: p.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tip.$3,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: p.textSecondary,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
