import 'package:flutter/material.dart';

/// How long the driver has been on the road.
enum DrivingExperience {
  learner,
  underTwo,
  twoToFive,
  overFive;

  String get label {
    switch (this) {
      case DrivingExperience.learner:
        return 'Learner';
      case DrivingExperience.underTwo:
        return 'Less than 2 years';
      case DrivingExperience.twoToFive:
        return '2 – 5 years';
      case DrivingExperience.overFive:
        return 'More than 5 years';
    }
  }
}

/// Primary vehicle the driver uses with RAASTA.
enum VehicleKind {
  car,
  motorbike,
  rickshaw,
  truck,
  bus,
  other;

  String get label {
    switch (this) {
      case VehicleKind.car:
        return 'Car';
      case VehicleKind.motorbike:
        return 'Motorbike';
      case VehicleKind.rickshaw:
        return 'Rickshaw';
      case VehicleKind.truck:
        return 'Truck';
      case VehicleKind.bus:
        return 'Bus';
      case VehicleKind.other:
        return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case VehicleKind.car:
        return Icons.directions_car_filled_rounded;
      case VehicleKind.motorbike:
        return Icons.two_wheeler_rounded;
      case VehicleKind.rickshaw:
        return Icons.electric_rickshaw_rounded;
      case VehicleKind.truck:
        return Icons.local_shipping_rounded;
      case VehicleKind.bus:
        return Icons.directions_bus_rounded;
      case VehicleKind.other:
        return Icons.commute_rounded;
    }
  }
}

/// Optional driver details captured on the edit profile screen.
class DriverDetails {
  const DriverDetails({
    this.age,
    this.experience,
    this.vehicle,
    this.plate = '',
    this.vehicleModel = '',
    this.photoPath = '',
  });

  final int? age;
  final DrivingExperience? experience;
  final VehicleKind? vehicle;
  final String plate;
  final String vehicleModel;
  final String photoPath;

  static const empty = DriverDetails();

  bool get isEmpty =>
      age == null &&
      experience == null &&
      vehicle == null &&
      plate.isEmpty &&
      vehicleModel.isEmpty;

  DriverDetails copyWith({
    int? age,
    DrivingExperience? experience,
    VehicleKind? vehicle,
    String? plate,
    String? vehicleModel,
    String? photoPath,
    bool clearAge = false,
  }) {
    return DriverDetails(
      age: clearAge ? null : (age ?? this.age),
      experience: experience ?? this.experience,
      vehicle: vehicle ?? this.vehicle,
      plate: plate ?? this.plate,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      photoPath: photoPath ?? this.photoPath,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'age': age,
      'experience': experience?.name,
      'vehicle': vehicle?.name,
      'plate': plate,
      'vehicleModel': vehicleModel,
      'photoPath': photoPath,
    };
  }

  static DriverDetails fromMap(Map<dynamic, dynamic> map) {
    return DriverDetails(
      age: (map['age'] as num?)?.toInt(),
      experience: _enumOrNull(DrivingExperience.values, map['experience']),
      vehicle: _enumOrNull(VehicleKind.values, map['vehicle']),
      plate: map['plate'] as String? ?? '',
      vehicleModel: map['vehicleModel'] as String? ?? '',
      photoPath: map['photoPath'] as String? ?? '',
    );
  }

  static T? _enumOrNull<T extends Enum>(List<T> values, Object? name) {
    if (name is! String) return null;
    for (final value in values) {
      if (value.name == name) return value;
    }
    return null;
  }
}
