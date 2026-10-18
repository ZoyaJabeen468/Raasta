import '../services/hazard_detector.dart';
import 'hazard_type.dart';

/// A single hazard detection produced during a live drive.
class HazardEvent {
  const HazardEvent({
    required this.type,
    required this.at,
    required this.confidence,
    required this.speedKph,
    this.distanceMeters,
    this.range,
    this.etaSeconds,
  });

  final HazardType type;
  final DateTime at;

  /// Detector confidence, 0–1.
  final double confidence;

  /// Vehicle speed when the hazard was seen.
  final double speedKph;

  /// Ignored for live YOLO (do not treat as true range).
  final double? distanceMeters;

  final HazardRange? range;

  /// Rough time-to-hazard from GPS speed and [range]. Null when parked.
  final int? etaSeconds;

  /// Banner copy. Bands only, never fake metres.
  String get bannerLine {
    final ahead = range?.english ?? 'ahead';
    final place = etaSeconds == null
        ? ahead
        : '$ahead, about $etaSeconds seconds';
    switch (type) {
      case HazardType.pothole:
        return 'Pothole $place.';
      case HazardType.speedBump:
        return 'Slow down. Speed bump $place.';
      case HazardType.crack:
        return 'Cracked road.';
      case HazardType.person:
        return 'Slow down now. Pedestrian $place.';
      case HazardType.cow:
        return 'Slow down now. Cow on the road $place.';
      case HazardType.buffalo:
        return 'Slow down now. Buffalo on the road $place.';
      case HazardType.dog:
        return 'Slow down now. Dog on the road $place.';
      case HazardType.cat:
        return 'Slow down now. Animal on the road $place.';
      case HazardType.horse:
        return 'Slow down now. Horse on the road $place.';
      case HazardType.donkey:
        return 'Slow down now. Donkey on the road $place.';
      case HazardType.goat:
        return 'Slow down now. Goat on the road $place.';
      case HazardType.roadSign:
        return 'Road sign $place.';
      case HazardType.wrongWay:
        return 'Wrong-way driving detected. Turn around safely.';
    }
  }
}
