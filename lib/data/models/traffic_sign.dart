import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// What the Drive screen does when a sign is confirmed.
enum SignAction {
  /// Card on screen + voice announcement.
  speak,

  /// Card on screen only, no voice.
  show,

  /// Detected by the model but never surfaced to the driver.
  ignore,
}

/// M3 traffic-sign classes (raasta_signs.tflite, 24 classes).
///
/// Declaration order MUST match the model's class ids (0–23).
enum TrafficSign {
  mph20(
    classLabel: '20_mph',
    // UK 20 mph is class 0. Empty scenes and Pakistani 60 km/h discs
    // both collapse here, so we never speak it or change the HUD.
    action: SignAction.ignore,
    title: 'Speed limit 20',
    english: 'Speed limit 20 ahead',
    urdu: 'آگے رفتار کی حد بیس ہے۔',
    icon: Icons.speed_rounded,
    color: AppColors.amber,
  ),
  giveWay(
    classLabel: 'Give_way_warn',
    action: SignAction.speak,
    title: 'Give way',
    english: 'Give way ahead',
    urdu: 'آگے راستہ دینے کا نشان ہے۔',
    icon: Icons.change_history_rounded,
    color: AppColors.amber,
  ),
  busStop(
    classLabel: 'bus_stop',
    action: SignAction.ignore,
    title: 'Bus stop',
    icon: Icons.directions_bus_rounded,
    color: AppColors.sky,
  ),
  cycleMark(
    classLabel: 'cycle_mark',
    action: SignAction.ignore,
    title: 'Cycle lane',
    icon: Icons.pedal_bike_rounded,
    color: AppColors.sky,
  ),
  doNotEnter(
    classLabel: 'do_not_enter',
    action: SignAction.speak,
    title: 'No entry',
    english: 'No entry ahead',
    urdu: 'آگے داخلہ ممنوع ہے۔',
    icon: Icons.do_not_disturb_on_rounded,
    color: AppColors.alert,
  ),
  doNotStop(
    classLabel: 'do_not_stop',
    action: SignAction.show,
    title: 'No stopping',
    english: 'No stopping',
    urdu: 'یہاں رکنا منع ہے۔',
    icon: Icons.block_rounded,
    color: AppColors.alert,
  ),
  noLeftTurn(
    classLabel: 'do_not_turn_l',
    action: SignAction.speak,
    title: 'No left turn',
    english: 'No left turn ahead',
    urdu: 'آگے بائیں مڑنا منع ہے۔',
    icon: Icons.turn_left_rounded,
    color: AppColors.alert,
  ),
  noRightTurn(
    classLabel: 'do_not_turn_r',
    action: SignAction.speak,
    title: 'No right turn',
    english: 'No right turn ahead',
    urdu: 'آگے دائیں مڑنا منع ہے۔',
    icon: Icons.turn_right_rounded,
    color: AppColors.alert,
  ),
  noUTurn(
    classLabel: 'do_not_u_turn',
    action: SignAction.speak,
    title: 'No U-turn',
    english: 'No U-turn ahead',
    urdu: 'آگے یو ٹرن منع ہے۔',
    icon: Icons.u_turn_left_rounded,
    color: AppColors.alert,
  ),
  enterLeftLane(
    classLabel: 'enter_left_lane',
    action: SignAction.show,
    title: 'Keep left',
    english: 'Keep to the left lane',
    urdu: 'بائیں لین میں رہیں۔',
    icon: Icons.turn_slight_left_rounded,
    color: AppColors.sky,
  ),
  greenLight(
    classLabel: 'green_light',
    action: SignAction.show,
    title: 'Green light',
    english: 'Green light',
    urdu: 'سبز بتی ہے۔',
    icon: Icons.traffic_rounded,
    color: AppColors.safe,
  ),
  leftRightLane(
    classLabel: 'left_right_lane',
    action: SignAction.show,
    title: 'Keep left or right',
    english: 'Keep left or right',
    urdu: 'دائیں یا بائیں جانب چلیں۔',
    icon: Icons.alt_route_rounded,
    color: AppColors.sky,
  ),
  noParking(
    classLabel: 'no_parking',
    action: SignAction.show,
    title: 'No parking',
    english: 'No parking',
    urdu: 'یہاں پارکنگ منع ہے۔',
    icon: Icons.local_parking_rounded,
    color: AppColors.alert,
  ),
  parking(
    classLabel: 'parking',
    action: SignAction.ignore,
    title: 'Parking',
    icon: Icons.local_parking_rounded,
    color: AppColors.sky,
  ),
  pedCrossing(
    classLabel: 'ped_crossing',
    action: SignAction.speak,
    title: 'Pedestrian crossing',
    english: 'Pedestrian crossing ahead',
    urdu: 'آگے پیدل گزرگاہ ہے۔',
    icon: Icons.directions_walk_rounded,
    color: AppColors.amber,
  ),
  zebraCrossing(
    classLabel: 'ped_zebra_cross',
    action: SignAction.speak,
    title: 'Zebra crossing',
    english: 'Zebra crossing ahead',
    urdu: 'آگے زیبرا کراسنگ ہے۔',
    icon: Icons.directions_walk_rounded,
    color: AppColors.amber,
  ),
  railwayCrossing(
    classLabel: 'railway_crossing',
    action: SignAction.speak,
    title: 'Railway crossing',
    english: 'Railway crossing ahead',
    urdu: 'آگے ریلوے پھاٹک ہے۔',
    icon: Icons.train_rounded,
    color: AppColors.amber,
  ),
  redLight(
    classLabel: 'red_light',
    action: SignAction.speak,
    title: 'Red light',
    english: 'Red light ahead. Stop.',
    urdu: 'آگے لال بتی ہے۔ رک جائیں۔',
    icon: Icons.traffic_rounded,
    color: AppColors.alert,
  ),
  stop(
    classLabel: 'stop',
    action: SignAction.speak,
    title: 'Stop',
    english: 'Stop sign ahead',
    urdu: 'آگے رکنے کا نشان ہے۔',
    icon: Icons.front_hand_rounded,
    color: AppColors.alert,
  ),
  tJunctionLeft(
    classLabel: 't_intersection_l',
    action: SignAction.speak,
    title: 'T-junction on left',
    english: 'T-junction ahead on the left',
    urdu: 'آگے بائیں جانب ٹی چوک ہے۔',
    icon: Icons.fork_left_rounded,
    color: AppColors.amber,
  ),
  trafficLight(
    classLabel: 'traffic_light',
    action: SignAction.ignore,
    title: 'Traffic light',
    icon: Icons.traffic_rounded,
    color: AppColors.sky,
  ),
  uTurn(
    classLabel: 'u_turn',
    action: SignAction.show,
    title: 'U-turn allowed',
    english: 'U-turn allowed',
    urdu: 'یو ٹرن کی اجازت ہے۔',
    icon: Icons.u_turn_left_rounded,
    color: AppColors.sky,
  ),
  warning(
    classLabel: 'warning',
    action: SignAction.speak,
    title: 'Warning',
    english: 'Warning sign ahead. Drive carefully.',
    urdu: 'آگے انتباہی نشان ہے۔ احتیاط سے چلائیں۔',
    icon: Icons.warning_amber_rounded,
    color: AppColors.amber,
  ),
  yellowLight(
    classLabel: 'yellow_light',
    action: SignAction.show,
    title: 'Yellow light',
    english: 'Yellow light',
    urdu: 'پیلی بتی ہے۔',
    icon: Icons.traffic_rounded,
    color: AppColors.amber,
  );

  const TrafficSign({
    required this.classLabel,
    required this.action,
    required this.title,
    required this.icon,
    required this.color,
    this.english = '',
    this.urdu = '',
    this.speedLimit,
  });

  /// Raw class name from the training dataset.
  final String classLabel;
  final SignAction action;

  /// Short name for the on-screen card.
  final String title;

  /// Spoken / displayed phrases. Empty for [SignAction.ignore] signs.
  final String english;
  final String urdu;

  final IconData icon;
  final Color color;

  /// km/h printed on a speed-limit class. Null until a km/h class exists.
  final int? speedLimit;

  static const numClasses = 24;

  /// 24-class id (0–23) → sign.
  static TrafficSign? fromClassId(int id) {
    if (id < 0 || id >= values.length) return null;
    return values[id];
  }

  /// Maps a class id using the exported head width (22-class v2 or 24-class).
  static TrafficSign? fromModel(int id, int classCount) {
    if (classCount == 24) return fromClassId(id);
    if (classCount != 22) return null;
    return switch (id) {
      0 => mph20,
      1 => busStop,
      2 => doNotEnter,
      3 => doNotStop,
      4 => noLeftTurn,
      5 => noRightTurn,
      6 => noUTurn,
      7 => enterLeftLane,
      8 => greenLight,
      9 => leftRightLane,
      10 => noParking,
      11 => parking,
      12 => pedCrossing,
      13 => zebraCrossing,
      14 => railwayCrossing,
      15 => redLight,
      16 => stop,
      17 => tJunctionLeft,
      18 => trafficLight,
      19 => uTurn,
      20 => warning,
      21 => yellowLight,
      _ => null,
    };
  }
}
