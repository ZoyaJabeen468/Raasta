import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/constants/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../data/services/permission_service.dart';
import '../../widgets/brand_buttons.dart';
import '../../widgets/screen_back_button.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final _service = PermissionService();
  final _status = <AppPermissionKind, PermissionStatus>{};
  bool _busy = false;
  late final AnimationController _enter;

  static const _items = [
    _PermItem(
      kind: AppPermissionKind.camera,
      icon: Icons.photo_camera_outlined,
      title: 'Camera',
      why: 'Spot hazards on the road ahead.',
      required: true,
      tint: Color(0xFF0F8A82),
    ),
    _PermItem(
      kind: AppPermissionKind.location,
      icon: Icons.place_outlined,
      title: 'Location',
      why: 'Track speed and trip distance.',
      required: true,
      tint: Color(0xFF3B82C4),
    ),
    _PermItem(
      kind: AppPermissionKind.microphone,
      icon: Icons.mic_none_outlined,
      title: 'Microphone',
      why: 'Voice alert checks.',
      required: false,
      tint: Color(0xFF7A5AF8),
    ),
    _PermItem(
      kind: AppPermissionKind.notifications,
      icon: Icons.notifications_none_outlined,
      title: 'Notifications',
      why: 'Alerts when the screen is locked.',
      required: false,
      tint: Color(0xFFE8A317),
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    )..forward();
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _enter.dispose();
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
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ScreenBackButton(),
              const SizedBox(height: 8),
              Text(
                'Permissions',
                style: GoogleFonts.sora(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: p.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'RAASTA only asks for what it needs to keep you safe.',
                style: GoogleFonts.dmSans(
                  fontSize: 14.5,
                  color: p.textSecondary,
                  height: 1.4,
                ),
              ),
              if (kIsWeb) ...[
                const SizedBox(height: 10),
                Text(
                  'Web preview grants these automatically. Real prompts appear on Android.',
                  style: GoogleFonts.dmSans(fontSize: 12.5, color: p.brand),
                ),
              ],
              const SizedBox(height: 22),
              Expanded(
                child: ListView.separated(
                  itemCount: _items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final item = _items[i];
                    final start = 0.08 + i * 0.12;
                    final fade = CurvedAnimation(
                      parent: _enter,
                      curve: Interval(
                        start.clamp(0.0, 0.85),
                        (start + 0.35).clamp(0.0, 1.0),
                        curve: Curves.easeOutCubic,
                      ),
                    );
                    return FadeTransition(
                      opacity: fade,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.08),
                          end: Offset.zero,
                        ).animate(fade),
                        child: _PermCard(
                          item: item,
                          status: _status[item.kind],
                          onAllow: () => _requestOne(item),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              GradientButton(
                label: 'Allow access',
                loading: _busy,
                onPressed: _allowAll,
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: _busy ? null : _skip,
                style: TextButton.styleFrom(foregroundColor: p.brand),
                child: Text(
                  'Skip for now',
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
                ),
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

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: granted
              ? AppColors.safe.withValues(alpha: 0.35)
              : p.border,
        ),
        boxShadow: [
          BoxShadow(
            color: p.shadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: granted
                  ? AppColors.safe.withValues(alpha: 0.12)
                  : item.tint.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              item.icon,
              size: 22,
              color: granted ? AppColors.safe : item.tint,
            ),
          ),
          const SizedBox(width: 12),
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
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _Badge(
                      label: item.required ? 'Required' : 'Optional',
                      filled: item.required,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  item.why,
                  style: GoogleFonts.dmSans(
                    color: p.textSecondary,
                    fontSize: 12.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          if (granted)
            const Icon(Icons.check_circle_rounded, color: AppColors.safe, size: 24)
          else
            TextButton(
              onPressed: onAllow,
              style: TextButton.styleFrom(
                foregroundColor: p.brand,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Allow',
                style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.filled});

  final String label;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? p.brandSoft : p.surfaceAlt,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: filled ? p.brand : p.textSecondary,
        ),
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
    required this.tint,
  });

  final AppPermissionKind kind;
  final IconData icon;
  final String title;
  final String why;
  final bool required;
  final Color tint;
}
