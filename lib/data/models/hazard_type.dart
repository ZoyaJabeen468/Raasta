import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Road hazards RAASTA can report from a drive.
///
/// YOLO M2+M5 classes (0–10): pothole, crack, speed_bump, person, cow,
/// buffalo, dog, cat, horse, donkey, goat.
/// [roadSign] is reserved for Amna’s M3 pipeline (not in the YOLO model).
enum HazardType {
  pothole,
  crack,
  speedBump,
  person,
  cow,
  buffalo,
  dog,
  cat,
  horse,
  donkey,
  goat,
  roadSign;

  String get label {
    switch (this) {
      case HazardType.pothole:
        return 'Pothole';
      case HazardType.crack:
        return 'Crack';
      case HazardType.speedBump:
        return 'Speed bump';
      case HazardType.person:
        return 'Person';
      case HazardType.cow:
        return 'Cow';
      case HazardType.buffalo:
        return 'Buffalo';
      case HazardType.dog:
        return 'Dog';
      case HazardType.cat:
        return 'Cat';
      case HazardType.horse:
        return 'Horse';
      case HazardType.donkey:
        return 'Donkey';
      case HazardType.goat:
        return 'Goat';
      case HazardType.roadSign:
        return 'Road sign';
    }
  }

  IconData get icon {
    switch (this) {
      case HazardType.pothole:
        return Icons.dangerous_outlined;
      case HazardType.crack:
        return Icons.timeline_rounded;
      case HazardType.speedBump:
        return Icons.speed_rounded;
      case HazardType.person:
        return Icons.directions_walk_rounded;
      case HazardType.cow:
      case HazardType.buffalo:
      case HazardType.horse:
      case HazardType.donkey:
      case HazardType.goat:
        return Icons.pets_rounded;
      case HazardType.dog:
      case HazardType.cat:
        return Icons.cruelty_free_outlined;
      case HazardType.roadSign:
        return Icons.signpost_outlined;
    }
  }

  Color get color {
    switch (this) {
      case HazardType.pothole:
        return AppColors.alert;
      case HazardType.crack:
        return AppColors.violet;
      case HazardType.speedBump:
        return AppColors.amber;
      case HazardType.person:
        return AppColors.sky;
      case HazardType.cow:
      case HazardType.buffalo:
        return const Color(0xFF8D6E63);
      case HazardType.dog:
      case HazardType.cat:
        return AppColors.safe;
      case HazardType.horse:
      case HazardType.donkey:
      case HazardType.goat:
        return const Color(0xFF5D8A66);
      case HazardType.roadSign:
        return AppColors.sky;
    }
  }

  /// Map YOLO class id (0–10) → hazard. Unknown ids fall back to pothole.
  static HazardType fromClassId(int id) {
    return switch (id) {
      0 => HazardType.pothole,
      1 => HazardType.crack,
      2 => HazardType.speedBump,
      3 => HazardType.person,
      4 => HazardType.cow,
      5 => HazardType.buffalo,
      6 => HazardType.dog,
      7 => HazardType.cat,
      8 => HazardType.horse,
      9 => HazardType.donkey,
      10 => HazardType.goat,
      _ => HazardType.pothole,
    };
  }

  static const classLabels = [
    'pothole',
    'crack',
    'speed_bump',
    'person',
    'cow',
    'buffalo',
    'dog',
    'cat',
    'horse',
    'donkey',
    'goat',
  ];

  static HazardType fromName(String? value) {
    if (value == null || value.isEmpty) return HazardType.pothole;
    // Legacy alias from older trips.
    if (value == 'obstacle') return HazardType.person;
    return HazardType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => HazardType.pothole,
    );
  }
}
