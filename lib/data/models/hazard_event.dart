import 'hazard_type.dart';

/// A single hazard detection produced during a live drive.
class HazardEvent {
  const HazardEvent({
    required this.type,
    required this.at,
    required this.confidence,
    required this.speedKph,
    this.distanceMeters,
  });

  final HazardType type;
  final DateTime at;

  /// Detector confidence, 0–1.
  final double confidence;

  /// Vehicle speed when the hazard was seen.
  final double speedKph;

  /// Estimated meters ahead (rounded for display / voice).
  final double? distanceMeters;

  /// Banner copy, e.g. "Pothole ahead 80 meters. Slow down."
  String get bannerLine {
    final meters = distanceMeters?.round();
    final ahead = meters == null ? 'ahead' : 'ahead $meters meters';
    switch (type) {
      case HazardType.pothole:
        return 'Pothole $ahead. Slow down.';
      case HazardType.speedBump:
        return 'Speed bump $ahead. Slow down.';
      case HazardType.crack:
        return 'Cracked road $ahead. Slow down.';
      case HazardType.person:
        return 'Pedestrian $ahead. Slow down.';
      case HazardType.cow:
        return 'Cow on the road $ahead. Slow down.';
      case HazardType.buffalo:
        return 'Buffalo on the road $ahead. Slow down.';
      case HazardType.dog:
        return 'Dog on the road $ahead. Caution.';
      case HazardType.cat:
        return 'Animal on the road $ahead. Caution.';
      case HazardType.horse:
        return 'Horse on the road $ahead. Slow down.';
      case HazardType.donkey:
        return 'Donkey on the road $ahead. Slow down.';
      case HazardType.goat:
        return 'Goat on the road $ahead. Caution.';
      case HazardType.roadSign:
        return 'Road sign $ahead.';
      case HazardType.wrongWay:
        return 'Wrong-way driving detected. Turn around safely.';
    }
  }
}
