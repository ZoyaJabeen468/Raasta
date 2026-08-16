import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/constants/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../data/services/permission_service.dart';
import '../../widgets/app_card.dart';
import '../../widgets/brand_buttons.dart';
import '../../widgets/screen_back_button.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen>
    with WidgetsBindingObserver {
  final _service = PermissionService();
  final _status = <AppPermissionKind, PermissionStatus>{};
  bool _busy = false;

  static const _items = [
    _PermItem(
      kind: AppPermissionKind.camera,
      icon: Icons.videocam_rounded,
      title: 'Camera',
      why: 'Spot hazards on the road ahead',
      required: true,
    ),
    _PermItem(
      kind: AppPermissionKind.location,
      icon: Icons.my_location_rounded,
      title: 'Location',
      why: 'Track speed and trip distance',
      required: true,
    ),
    _PermItem(
      kind: AppPermissionKind.microphone,
      icon: Icons.mic_rounded,
      title: 'Microphone',
      why: 'Voice alert checks',
      required: false,
    ),
    _PermItem(
      kind: AppPermissionKind.notifications,
      icon: Icons.notifications_active_rounded,
      title: 'Notifications',
      why: 'Alerts when the screen is locked',
      required: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    for (final item in _items) {
      final status = await _service.statusOf(item.kind);
      if (!mounted) return;
      setState(() => _status[item.kind] = status);
    }
  }

  Future<void> _requestOne(_PermItem item) async {
    final current = _status[item.kind];
    if (current != null && current.isPermanentlyDenied) {
      await openAppSettings();
      return;
    }
    final result = await _service.request(item.kind);
    if (!mounted) return;
    setState(() => _status[item.kind] = result);
  }

  Future<void> _allowAll() async {
    setState(() => _busy = true);
    await _service.requestCore();
    await _refresh();
    if (!mounted) return;
    setState(() => _busy = false);
    Navigator.of(context).pushNamed(AppRoutes.language);
  }

  Future<void> _skip() async {
    final cameraOk = _status[AppPermissionKind.camera]?.isGranted ?? false;
    if (!cameraOk) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Skip camera access?'),
          content: const Text(
            'Hazard detection needs the camera. You can still continue, '
            'but Drive will ask again before starting.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Allow camera'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Skip anyway'),
            ),
          ],
        ),
      );
      if (proceed != true) {
        await _requestOne(_items.first);
        return;
      }
    }
    if (!mounted) return;
    Navigator.of(context).pushNamed(AppRoutes.language);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ScreenBackButton(),
              Text(
                'Permissions',
                style: GoogleFonts.sora(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: p.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'RAASTA only asks for what it needs to keep you safe.',
                style: GoogleFonts.dmSans(
                  fontSize: 15,
                  color: p.textSecondary,
                  height: 1.4,
                ),
              ),
              if (kIsWeb) ...[
                const SizedBox(height: 12),
                Text(
                  'Web preview grants these automatically. Real prompts '
                  'appear on Android.',
                  style: GoogleFonts.dmSans(fontSize: 13, color: p.brand),
                ),
              ],
              const SizedBox(height: 24),
              Expanded(
                child: ListView.separated(
                  itemCount: _items.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final item = _items[i];
                    return _PermCard(
                      item: item,
                      status: _status[item.kind],
                      onAllow: () => _requestOne(item),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              GradientButton(
                label: 'Allow access',
                loading: _busy,
                onPressed: _allowAll,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy ? null : _skip,
                child: const Text('Skip for now'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermCard extends StatelessWidget {
  const _PermCard({
    required this.item,
    required this.status,
    required this.onAllow,
  });

  final _PermItem item;
  final PermissionStatus? status;
  final VoidCallback onAllow;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final granted = status?.isGranted ?? false;

    return AppCard(
      radius: 16,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: granted
                  ? AppColors.safe.withValues(alpha: 0.12)
                  : p.brandSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              item.icon,
              color: granted ? AppColors.safe : p.brand,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.title,
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w700,
                          color: p.textPrimary,
                          fontSize: 15.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusPill(
                      label: item.required ? 'Required' : 'Optional',
                      color: item.required ? p.brand : p.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.why,
                  style: GoogleFonts.dmSans(
                    color: p.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (granted)
            const Icon(Icons.check_circle_rounded, color: AppColors.safe)
          else
            TextButton(
              onPressed: onAllow,
              style: TextButton.styleFrom(
                foregroundColor: p.brand,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('Allow'),
            ),
        ],
      ),
    );
  }
}

class _PermItem {
  const _PermItem({
    required this.kind,
    required this.icon,
    required this.title,
    required this.why,
    required this.required,
  });

  final AppPermissionKind kind;
  final IconData icon;
  final String title;
  final String why;
  final bool required;
}
