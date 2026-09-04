import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/hazard_event.dart';
import '../../../../data/models/hazard_type.dart';

/// One in-drive notification (hazard, overspeed, or wrong-way via hazard event).
class DriveAlert {
  const DriveAlert({
    required this.id,
    required this.kind,
    required this.at,
    this.event,
    this.speedKph,
    this.speedLimitKph,
  });

  final String id;
  final DriveAlertKind kind;
  final DateTime at;
  final HazardEvent? event;
  final double? speedKph;
  final int? speedLimitKph;

  factory DriveAlert.hazard(HazardEvent event) {
    return DriveAlert(
      id: '${event.type.name}_${event.at.microsecondsSinceEpoch}',
      kind: DriveAlertKind.hazard,
      at: event.at,
      event: event,
    );
  }

  factory DriveAlert.overspeed({
    required double speedKph,
    required int limitKph,
  }) {
    final now = DateTime.now();
    return DriveAlert(
      id: 'overspeed_${now.microsecondsSinceEpoch}',
      kind: DriveAlertKind.overspeed,
      at: now,
      speedKph: speedKph,
      speedLimitKph: limitKph,
    );
  }

  /// Higher = shown first / can interrupt a lower-priority active alert.
  int get priority {
    if (kind == DriveAlertKind.overspeed) return 20;
    final type = event?.type;
    if (type == null) return 0;
    return switch (type) {
      HazardType.wrongWay => 100,
      HazardType.pothole || HazardType.crack || HazardType.speedBump => 80,
      HazardType.person => 60,
      HazardType.roadSign => 55,
      _ => 40,
    };
  }

  String get severityLabel {
    if (kind == DriveAlertKind.overspeed) return 'WARNING';
    final type = event?.type;
    if (type == HazardType.wrongWay) return 'DANGER';
    if (type == HazardType.person) return 'CAUTION';
    return 'CAUTION';
  }

  IconData get icon {
    if (kind == DriveAlertKind.overspeed) {
      return Icons.speed_rounded;
    }
    return event!.type.icon;
  }

  Color get tint {
    if (kind == DriveAlertKind.overspeed) return AppColors.alert;
    final type = event!.type;
    if (type == HazardType.wrongWay) return AppColors.alert;
    return type.color;
  }

  String get title {
    if (kind == DriveAlertKind.overspeed) {
      return 'Overspeed';
    }
    return event!.type.label;
  }

  String get subtitle {
    if (kind == DriveAlertKind.overspeed) {
      final spd = speedKph?.round() ?? 0;
      final lim = speedLimitKph ?? 60;
      return 'You are at $spd km/h · limit $lim. Slow down.';
    }
    return event!.bannerLine;
  }

  String? get metaLine {
    if (kind != DriveAlertKind.hazard || event == null) return null;
    final pct = (event!.confidence * 100).clamp(0, 99).round();
    final dist = event!.distanceMeters?.round();
    if (dist != null) return '$pct% confidence · ~${dist}m ahead';
    return '$pct% confidence';
  }
}

enum DriveAlertKind { hazard, overspeed }
