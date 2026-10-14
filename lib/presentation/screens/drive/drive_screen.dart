import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/hazard_type.dart';
import '../../../data/models/trip_record.dart';
import '../../../data/services/camera_yolo_detector.dart';
import '../../../data/services/wrong_way_service.dart';
import '../../providers/drive_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/trips_provider.dart';
import '../../widgets/confirm_dialog.dart';
import 'widgets/drive_alert_card.dart';
import 'widgets/drive_hud.dart';
import 'widgets/drive_sign_card.dart';
import 'widgets/drive_viewfinder.dart';
import 'widgets/trip_summary_sheet.dart';

/// Live drive: camera viewfinder, GPS HUD, spoken hazard / speed alerts.
class DriveScreen extends StatefulWidget {
  const DriveScreen({super.key});

  @override
  State<DriveScreen> createState() => _DriveScreenState();
}

class _DriveScreenState extends State<DriveScreen> {
  late final CameraYoloHazardDetector _detector = CameraYoloHazardDetector();

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DriveProvider(detector: _detector),
      child: _DriveView(detector: _detector),
    );
  }
}

class _DriveView extends StatefulWidget {
  const _DriveView({required this.detector});

  final CameraYoloHazardDetector detector;

  @override
  State<_DriveView> createState() => _DriveViewState();
}

class _DriveViewState extends State<_DriveView> with WidgetsBindingObserver {
  Timer? _alertTimer;
  bool _finishing = false;
  DriveProvider? _drive;
  static const _alertAutoDismiss = Duration(seconds: 8);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.detector.addListener(_onDetectorTick);
    // Vertical mount (most car holders). Full-bleed camera still covers the road.
    unawaited(
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
      ]),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _begin());
  }

  void _onDetectorTick() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _drive?.didChangeAppLifecycleState(state);
  }

  Future<void> _begin() async {
    final settings = context.read<SettingsProvider>().settings;
    final drive = context.read<DriveProvider>();
    await drive.configure(
      language: settings.language,
      voiceEnabled: settings.voiceAlerts,
      hazardAlerts: settings.hazardAlerts,
      wrongWayDemoMode: settings.wrongWayDemoMode,
    );
    _drive = drive..addListener(_onDriveChanged);
    await drive.start();
  }

  /// Auto-dismisses banners. Lives on a provider listener rather than in
  /// build() so scheduling a timer isn't a build side effect.
  void _onDriveChanged() {
    final drive = _drive;
    if (drive == null) return;

    if (drive.didAutoEnd && !_finishing) {
      final trip = drive.takeCompletedTrip();
      unawaited(_finishWithTrip(trip));
      return;
    }

    if (drive.activeAlert != null) {
      final id = drive.activeAlert!.id;
      _alertTimer?.cancel();
      _alertTimer = Timer(_alertAutoDismiss, () {
        if (_drive?.activeAlert?.id == id) {
          _drive?.dismissActiveAlert();
        }
      });
    } else {
      _alertTimer?.cancel();
    }
  }

  Future<void> _finishWithTrip(TripRecord? trip) async {
    if (_finishing) return;
    _finishing = true;
    final navigator = Navigator.of(context);
    if (!mounted) return;
    if (trip == null) {
      navigator.pop();
      return;
    }
    await _showSummary(trip);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.detector.removeListener(_onDetectorTick);
    _alertTimer?.cancel();
    _drive?.removeListener(_onDriveChanged);
    // Rest of app stays portrait.
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
  }

  Future<void> _endDrive({bool confirm = true}) async {
    if (_finishing) return;

    final drive = context.read<DriveProvider>();

    if (confirm && drive.isRunning && drive.elapsedSeconds > 5) {
      final ok = await confirmAction(
        context,
        title: 'End this drive?',
        message:
            'Detection will stop and you can review or discard the trip '
            'summary.',
        confirmLabel: 'End drive',
        icon: Icons.stop_circle_outlined,
      );
      if (!ok || !mounted) return;
    }

    if (_finishing) return;
    _finishing = true;

    final navigator = Navigator.of(context);
    final trip = await drive.stop();

    if (!mounted) return;
    if (trip == null) {
      navigator.pop();
      return;
    }
    await _showSummary(trip);
  }

  Future<void> _showSummary(TripRecord trip) async {
    final rootNavigator = Navigator.of(context);
    final trips = context.read<TripsProvider>();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => TripSummarySheet(
        trip: trip,
        onSave: () async {
          await trips.add(trip);
          if (sheetContext.mounted) Navigator.of(sheetContext).pop();
        },
      ),
    );

    if (mounted) rootNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final drive = context.watch<DriveProvider>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _endDrive();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            DriveViewfinder(
              active: drive.isRunning || drive.isArming,
              onCameraReady: (cam) => widget.detector.attachCamera(cam),
              boxes: widget.detector.liveBoxes,
            ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
                    child: Row(
                      children: [
                        _GlassIconButton(
                          icon: Icons.close_rounded,
                          label: 'End drive',
                          onTap: _endDrive,
                        ),
                        const Spacer(),
                        _LiveBadge(
                          paused: drive.isPaused,
                          arming: drive.isArming,
                          usingGps: drive.usingGps,
                          usingAi: drive.usingRealtimeModel,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: DriveHud(
                      speedKph: drive.speedKph,
                      speedLimitKph: drive.speedLimitKph,
                      band: drive.speedBand,
                      elapsedSeconds: drive.elapsedSeconds,
                      distanceMeters: drive.distanceMeters,
                      hazardCount: drive.hazardCount,
                      usingGps: drive.usingGps,
                      arming: drive.isArming,
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: _DriveCenterChips(
                            drive: drive,
                            detector: widget.detector,
                          ),
                        ),
                        Align(
                          alignment: Alignment.topCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: DriveSignCard(sign: drive.visibleSign),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                    child: DriveAlertToast(
                      alert: drive.activeAlert,
                      onDismiss: drive.dismissActiveAlert,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                    child: _Controls(
                      paused: drive.isPaused,
                      muted: !drive.voiceEnabled,
                      onPause: drive.isArming ? null : drive.togglePause,
                      onToggleVoice: drive.toggleVoice,
                      onStop: _endDrive,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DriveCenterChips extends StatelessWidget {
  const _DriveCenterChips({required this.drive, required this.detector});

  final DriveProvider drive;
  final CameraYoloHazardDetector detector;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (drive.wrongWayConfirmSeconds != null &&
                drive.activeAlert?.event?.type != HazardType.wrongWay) ...[
              _WrongWayProgressChip(
                seconds: drive.wrongWayConfirmSeconds!,
                demo: drive.wrongWayDemoMode,
              ),
            ],
            if (kDebugMode &&
                drive.usingRealtimeModel &&
                detector.debugPeakScore >= 0.45) ...[
              const SizedBox(height: 10),
              _AiDebugChip(
                label: detector.debugPeakLabel,
                score: detector.debugPeakScore,
                info: detector.debugInfo,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WrongWayProgressChip extends StatelessWidget {
  const _WrongWayProgressChip({
    required this.seconds,
    required this.demo,
  });

  final int seconds;
  final bool demo;

  @override
  Widget build(BuildContext context) {
    final need = demo
        ? WrongWayService.demoConfirmFor.inSeconds
        : WrongWayService.confirmFor.inSeconds;
    final left = (need - seconds).clamp(0, need);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xCC12171C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Icon(Icons.u_turn_left_rounded,
              color: AppColors.amber.withValues(alpha: 0.95), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              demo
                  ? 'Wrong-way demo · alert in ${left}s'
                  : 'Checking direction · ${left}s',
              style: GoogleFonts.dmSans(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiDebugChip extends StatelessWidget {
  const _AiDebugChip({
    required this.label,
    required this.score,
    required this.info,
  });

  final String label;
  final double score;
  final String info;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        'AI peak: ${score.toStringAsFixed(2)} · $label\n$info',
        textAlign: TextAlign.center,
        style: GoogleFonts.dmSans(
          color: Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          height: 1.25,
        ),
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({
    required this.paused,
    required this.arming,
    required this.usingGps,
    required this.usingAi,
  });

  final bool paused;
  final bool arming;
  final bool usingGps;
  final bool usingAi;

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;
    if (paused) {
      color = AppColors.amber;
      label = 'PAUSED';
    } else if (arming) {
      color = AppColors.sky;
      label = 'WAITING';
    } else if (usingAi) {
      color = AppColors.safe;
      label = 'AI LIVE';
    } else {
      color = AppColors.alert;
      label = usingGps ? 'GPS LIVE' : 'DETECTING';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xCC12171C),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: GoogleFonts.dmSans(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.paused,
    required this.muted,
    required this.onPause,
    required this.onToggleVoice,
    required this.onStop,
  });

  final bool paused;
  final bool muted;
  final VoidCallback? onPause;
  final VoidCallback onToggleVoice;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final pauseEnabled = onPause != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xE012171C),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _GlassIconButton(
            icon: paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            label: !pauseEnabled
                ? 'Pause unavailable while waiting for trip to start'
                : paused
                    ? 'Resume drive'
                    : 'Pause drive',
            onTap: onPause,
            size: 48,
            tint: pauseEnabled ? Colors.white : Colors.white38,
            enabled: pauseEnabled,
          ),
          Semantics(
            button: true,
            label: 'Stop drive',
            child: Material(
              color: AppColors.alert,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onStop,
                child: const SizedBox(
                  width: 58,
                  height: 58,
                  child: Icon(Icons.stop_rounded, color: Colors.white, size: 28),
                ),
              ),
            ),
          ),
          _GlassIconButton(
            icon: muted ? Icons.volume_off_outlined : Icons.volume_up_outlined,
            label: muted ? 'Unmute voice alerts' : 'Mute voice alerts',
            onTap: onToggleVoice,
            size: 48,
            tint: muted ? AppColors.amber : Colors.white,
          ),
        ],
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.size = 40,
    this.tint = Colors.white,
    this.enabled = true,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String label;
  final double size;
  final Color tint;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Material(
          color: Colors.white.withValues(alpha: enabled ? 0.08 : 0.04),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onTap : null,
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(icon, color: tint, size: size * 0.48),
            ),
          ),
        ),
      ),
    );
  }
}
