import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/constants/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/services/permission_service.dart';
import '../../widgets/brand_buttons.dart';
import '../../widgets/glass_tile.dart';
import '../../widgets/line_icon.dart';
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
      icon: LineIconKind.camera,
      title: 'Camera',
      why: 'Spot hazards on the road ahead.',
      required: true,
    ),
    _PermItem(
      kind: AppPermissionKind.location,
      icon: LineIconKind.location,
      title: 'Location',
      why: 'Track speed and trip distance.',
      required: true,
    ),
    _PermItem(
      kind: AppPermissionKind.microphone,
      icon: LineIconKind.mic,
      title: 'Microphone',
      why: 'Voice alert checks.',
      required: false,
    ),
    _PermItem(
      kind: AppPermissionKind.notifications,
      icon: LineIconKind.bell,
      title: 'Notifications',
      why: 'Alerts when the screen is locked.',
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
        builder: (ctx) => Theme(
          data: AppTheme.dark(),
          child: AlertDialog(
            backgroundColor: AppColors.nightSurface,
            title: Text(
              'Skip camera access?',
              style: GoogleFonts.sora(fontWeight: FontWeight.w700),
            ),
            content: Text(
              'Hazard detection needs the camera. You can still continue, '
              'but Drive will ask again before starting.',
              style: GoogleFonts.dmSans(height: 1.4),
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
    return Theme(
      data: AppTheme.dark(),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: AppColors.forest,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        child: Scaffold(
          backgroundColor: AppColors.forest,
          body: DecoratedBox(
            decoration: const BoxDecoration(gradient: AppColors.splashGradient),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
                child: Column(
                  children: [
                    const SizedBox(
                      height: 44,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: ScreenBackButton(bottomSpacing: 0),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Permissions',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.sora(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.white,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'RAASTA only asks for what it needs to keep you safe.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        color: AppColors.white.withValues(alpha: 0.72),
                        height: 1.4,
                      ),
                    ),
                    if (kIsWeb) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Web preview grants these automatically. Real prompts appear on Android.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(
                          fontSize: 12.5,
                          color: AppColors.mint,
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    Expanded(
                      child: ListView.separated(
                        itemCount: _items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
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
                    const SizedBox(height: 12),
                    GradientButton(
                      label: 'Allow access',
                      loading: _busy,
                      onPressed: _allowAll,
                    ),
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: _busy ? null : _skip,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.mint,
                      ),
                      child: Text(
                        'Skip for now',
                        style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
    final granted = status?.isGranted ?? false;

    return GlassTile(
      selected: granted,
      child: Row(
        children: [
          LineIconBox(kind: item.icon, accent: granted, size: 36),
          const SizedBox(width: 10),
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
                          color: AppColors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    QuietChip(
                      label: item.required ? 'Required' : 'Optional',
                      emphasized: item.required,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  item.why,
                  style: GoogleFonts.dmSans(
                    color: AppColors.white.withValues(alpha: 0.62),
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (granted)
            Icon(
              Icons.check_rounded,
              color: AppColors.mint,
              size: 20,
            )
          else
            TextButton(
              onPressed: onAllow,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.forest,
                backgroundColor: AppColors.mint,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: const StadiumBorder(),
              ),
              child: Text(
                'Allow',
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
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
  final LineIconKind icon;
  final String title;
  final String why;
  final bool required;
}
