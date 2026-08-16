import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import 'achievement.dart';
import 'trip_record.dart';
import 'trip_stats.dart';

enum ActivityKind {
  trip('Trips', Icons.directions_car_filled_rounded),
  hazard('Hazards', Icons.warning_amber_rounded),
  milestone('Milestones', Icons.emoji_events_rounded);

  const ActivityKind(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// One entry in the activity feed.
///
/// Every item is derived from stored trips — nothing here is synthetic, so an
/// empty trip history means an empty feed.
@immutable
class ActivityItem {
  const ActivityItem({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.at,
    required this.icon,
    required this.tint,
  });

  final ActivityKind kind;
  final String title;
  final String subtitle;
  final DateTime at;
  final IconData icon;
  final Color tint;

  /// Builds the feed newest-first from trip history.
  ///
  /// Milestones are dated by replaying trips in order and noting the drive
  /// that pushed each achievement over the line, so they slot into the
  /// timeline at the moment they were actually earned.
  static List<ActivityItem> from(TripStats stats) {
    if (stats.trips.isEmpty) return const [];

    final items = <ActivityItem>[];

    for (final trip in stats.trips) {
      items.add(_tripItem(trip));

      if (trip.hazardCount > 0) {
        final top = trip.hazards.entries.where((e) => e.value > 0).toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        items.add(
          ActivityItem(
            kind: ActivityKind.hazard,
            title:
                '${trip.hazardCount} '
                '${trip.hazardCount == 1 ? 'hazard' : 'hazards'} detected',
            subtitle: top
                .take(3)
                .map((e) => '${e.key.label} · ${e.value}')
                .join('   '),
            at: trip.startedAt.add(const Duration(seconds: 1)),
            icon: top.first.key.icon,
            tint: top.first.key.color,
          ),
        );
      }

      if (trip.overspeedCount > 0) {
        items.add(
          ActivityItem(
            kind: ActivityKind.hazard,
            title: 'Speed limit crossed ${trip.overspeedCount}x',
            subtitle: 'Peak ${trip.maxSpeedKph.round()} km/h on this drive',
            at: trip.startedAt.add(const Duration(seconds: 2)),
            icon: Icons.speed_rounded,
            tint: AppColors.alert,
          ),
        );
      }
    }

    items.addAll(_milestones(stats.trips));
    items.sort((a, b) => b.at.compareTo(a.at));
    return items;
  }

  static ActivityItem _tripItem(TripRecord trip) {
    return ActivityItem(
      kind: ActivityKind.trip,
      title: 'Drive completed',
      subtitle:
          '${Format.distance(trip.distanceMeters)}   '
          '${Format.duration(trip.durationSeconds)}   '
          'Score ${trip.safetyScore}',
      at: trip.startedAt,
      icon: Icons.directions_car_filled_rounded,
      tint: AppColors.tealBright,
    );
  }

  static List<ActivityItem> _milestones(List<TripRecord> newestFirst) {
    final chronological = newestFirst.reversed.toList();
    final unlocked = <String>{};
    final items = <ActivityItem>[];
    final soFar = <TripRecord>[];

    for (final trip in chronological) {
      soFar.add(trip);
      for (final badge in Achievement.evaluate(TripStats.from(soFar))) {
        if (!badge.unlocked || !unlocked.add(badge.label)) continue;
        items.add(
          ActivityItem(
            kind: ActivityKind.milestone,
            title: '${badge.label} unlocked',
            subtitle: badge.requirement,
            at: trip.startedAt.add(const Duration(seconds: 3)),
            icon: badge.icon,
            tint: AppColors.amber,
          ),
        );
      }
    }

    return items;
  }
}
