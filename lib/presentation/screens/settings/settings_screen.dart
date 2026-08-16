import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/ambient_scaffold.dart';
import '../../../data/models/language_preference.dart';
import '../../../data/services/permission_service.dart';
import '../../../data/services/tts_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/trips_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/settings_tiles.dart';

const _appVersion = 'v0.4.0 · M2+M5 TFLite';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _permissions = PermissionService();
  final _tts = TtsService();
  final _status = <AppPermissionKind, PermissionStatus>{};
  bool _testingVoice = false;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _loadPermissions() async {
    for (final kind in AppPermissionKind.values) {
      final status = await _permissions.statusOf(kind);
      if (!mounted) return;
      setState(() => _status[kind] = status);
    }
  }

  Future<void> _requestPermission(AppPermissionKind kind) async {
    final current = _status[kind];
    if (current != null && current.isPermanentlyDenied) {
      await openAppSettings();
      return;
    }
    final result = await _permissions.request(kind);
    if (!mounted) return;
    setState(() => _status[kind] = result);
  }

  Future<void> _pickLanguage() async {
    final settings = context.read<SettingsProvider>();
    final p = context.palette;

    final choice = await showModalBottomSheet<LanguagePreference>(
      context: context,
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 14),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: p.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Alert language',
              style: GoogleFonts.sora(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: p.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            for (final option in LanguagePreference.values)
              ListTile(
                title: Text(
                  option.label,
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w600,
                    color: p.textPrimary,
                  ),
                ),
                subtitle: Text(
                  option.samplePhrase,
                  style: GoogleFonts.dmSans(color: p.textSecondary),
                ),
                trailing: settings.settings.language == option
                    ? Icon(Icons.check_circle_rounded, color: p.brand)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(option),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );

    if (choice != null) {
      await settings.setLanguage(choice);
      if (mounted) context.read<AuthProvider>().setLanguage(choice);
    }
  }

  Future<void> _testVoice() async {
    final settings = context.read<SettingsProvider>();
    setState(() => _testingVoice = true);
    try {
      final ok = await _tts.speakSample(settings.settings.language);
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not play a sample. Check Text-to-speech voices '
              'on this phone.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _testingVoice = false);
    }
  }

  Future<void> _confirmSignOut() async {
    final auth = context.read<AuthProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('Your trips stay saved on this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.alert),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await auth.signOut();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.welcome, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final settings = context.watch<SettingsProvider>();
    final trips = context.watch<TripsProvider>();
    final auth = context.watch<AuthProvider>();
    final config = settings.settings;
    final passwordAccount = auth.hasPasswordProvider;

    return AmbientScaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            const SectionLabel('Appearance'),
            SettingsGroup(
              children: [
                SettingsSwitch(
                  icon: config.darkMode
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                  title: 'Dark mode',
                  subtitle: config.darkMode
                      ? 'Easier on the eyes at night'
                      : 'Bright theme for daytime driving',
                  value: config.darkMode,
                  onChanged: settings.setDarkMode,
                ),
              ],
            ),
            const SizedBox(height: 22),
            const SectionLabel('Voice & language'),
            SettingsGroup(
              children: [
                SettingsRow(
                  icon: Icons.translate_rounded,
                  title: 'Alert language',
                  subtitle: config.language.label,
                  onTap: _pickLanguage,
                ),
                SettingsRow(
                  icon: Icons.play_circle_outline_rounded,
                  title: 'Test voice alert',
                  subtitle: _testingVoice
                      ? 'Playing sample…'
                      : 'Hear a sample in ${config.language.label}',
                  showChevron: false,
                  onTap: _testingVoice ? null : _testVoice,
                ),
                SettingsSwitch(
                  icon: Icons.record_voice_over_rounded,
                  title: 'Voice alerts',
                  subtitle: config.voiceAlerts
                      ? 'Spoken warnings (needs microphone permission)'
                      : 'Visual warnings only',
                  value: config.voiceAlerts,
                  onChanged: settings.setVoiceAlerts,
                ),
              ],
            ),
            const SizedBox(height: 22),
            const SectionLabel('Notifications'),
            SettingsGroup(
              children: [
                SettingsSwitch(
                  icon: Icons.notifications_active_rounded,
                  title: 'Hazard alerts',
                  subtitle: 'Notify me when a hazard is detected',
                  value: config.hazardAlerts,
                  onChanged: settings.setHazardAlerts,
                ),
              ],
            ),
            const SizedBox(height: 22),
            const SectionLabel('Permissions'),
            SettingsGroup(
              children: [
                for (final kind in AppPermissionKind.values)
                  _PermissionRow(
                    kind: kind,
                    status: _status[kind],
                    onTap: () => _requestPermission(kind),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            const SectionLabel('Account'),
            SettingsGroup(
              children: [
                if (passwordAccount) ...[
                  SettingsRow(
                    icon: Icons.alternate_email_rounded,
                    title: 'Change email',
                    subtitle: auth.user?.email,
                    onTap: () =>
                        Navigator.of(context).pushNamed(AppRoutes.changeEmail),
                  ),
                  SettingsRow(
                    icon: Icons.password_rounded,
                    title: 'Change password',
                    onTap: () => Navigator.of(
                      context,
                    ).pushNamed(AppRoutes.changePassword),
                  ),
                ] else
                  SettingsRow(
                    icon: Icons.lock_outline_rounded,
                    title: 'Signed in with Google / Facebook',
                    subtitle:
                        'Email and password are managed by that provider',
                    showChevron: false,
                    onTap: null,
                  ),
                SettingsRow(
                  icon: Icons.logout_rounded,
                  title: 'Sign out',
                  tint: AppColors.alert,
                  showChevron: false,
                  onTap: _confirmSignOut,
                ),
                SettingsRow(
                  icon: Icons.delete_outline_rounded,
                  title: 'Delete account',
                  tint: AppColors.alert,
                  onTap: () =>
                      Navigator.of(context).pushNamed(AppRoutes.deleteAccount),
                ),
              ],
            ),
            const SizedBox(height: 22),
            const SectionLabel('About'),
            SettingsGroup(
              children: [
                SettingsRow(
                  icon: Icons.info_outline_rounded,
                  title: 'About RAASTA',
                  onTap: () => Navigator.of(context).pushNamed(AppRoutes.about),
                ),
                SettingsRow(
                  icon: Icons.help_outline_rounded,
                  title: 'FAQ',
                  onTap: () => Navigator.of(context).pushNamed(AppRoutes.faq),
                ),
                SettingsRow(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy policy',
                  onTap: () =>
                      Navigator.of(context).pushNamed(AppRoutes.privacy),
                ),
              ],
            ),
            const SizedBox(height: 22),
            const SectionLabel('Data'),
            SettingsGroup(
              children: [
                SettingsRow(
                  icon: Icons.delete_sweep_outlined,
                  title: 'Clear trip history',
                  subtitle: '${trips.trips.length} stored on this device',
                  tint: AppColors.amber,
                  showChevron: false,
                  onTap: trips.trips.isEmpty
                      ? null
                      : () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final ok = await confirmAction(
                            context,
                            title: 'Clear trip history?',
                            message:
                                'All ${trips.trips.length} saved trips will be '
                                'deleted from this device. This cannot be '
                                'undone.',
                            confirmLabel: 'Clear all',
                          );
                          if (!ok) return;
                          await trips.clear();
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Trip history cleared'),
                            ),
                          );
                        },
                ),
              ],
            ),
            if (kDebugMode) ...[
              const SizedBox(height: 22),
              const SectionLabel('Developer tools'),
              SettingsGroup(
                children: [
                  SettingsRow(
                    icon: Icons.science_outlined,
                    title: 'Seed a sample trip',
                    subtitle: 'Populate the dashboard with test data',
                    showChevron: false,
                    onTap: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      await trips.addSampleTrip();
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Sample trip added')),
                      );
                    },
                  ),
                ],
              ),
            ],
            const SizedBox(height: 26),
            Center(
              child: Text(
                'RAASTA · $_appVersion',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: p.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.kind,
    required this.status,
    required this.onTap,
  });

  final AppPermissionKind kind;
  final PermissionStatus? status;
  final VoidCallback onTap;

  static const _meta = {
    AppPermissionKind.camera: (Icons.photo_camera_outlined, 'Camera'),
    AppPermissionKind.location: (Icons.place_outlined, 'Location'),
    AppPermissionKind.microphone: (Icons.mic_none_rounded, 'Microphone'),
    AppPermissionKind.notifications: (
      Icons.notifications_none_rounded,
      'Notifications',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final meta = _meta[kind]!;

    final granted = status?.isGranted ?? false;
    final label = status == null
        ? 'Checking…'
        : granted
        ? 'Granted'
        : status!.isPermanentlyDenied
        ? 'Blocked'
        : 'Not granted';
    final tint = granted
        ? AppColors.safe
        : status == null
        ? p.textSecondary
        : AppColors.amber;

    return SettingsRow(
      icon: meta.$1,
      title: meta.$2,
      subtitle: label,
      showChevron: !granted,
      onTap: granted ? null : onTap,
      trailing: granted
          ? const Icon(
              Icons.check_circle_rounded,
              size: 18,
              color: AppColors.safe,
            )
          : Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
            ),
    );
  }
}
