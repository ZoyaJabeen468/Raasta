import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../data/local/local_store.dart';
import '../../data/models/hazard_type.dart';
import '../../data/models/report_data.dart';
import '../../data/models/trip_record.dart';
import '../../data/models/trip_stats.dart';

/// Loads the signed-in driver's trip history and derived statistics.
class TripsProvider extends ChangeNotifier {
  TripsProvider({LocalStore? store}) : _store = store ?? LocalStore.instance;

  final LocalStore _store;

  String? _userId;
  TripStats _stats = TripStats.empty;
  ReportBundle _reports = ReportBundle.empty;
  bool _loading = false;
  bool _hasLoaded = false;

  TripStats get stats => _stats;
  ReportBundle get reports => _reports;
  bool get isLoading => _loading;
  List<TripRecord> get trips => _stats.trips;

  /// False until the first load finishes. Lets screens show a skeleton
  /// instead of flashing the "no trips yet" empty state on first paint.
  bool get isReady => _hasLoaded && !_loading;

  Future<void> load(String? userId) async {
    _userId = userId;
    if (userId == null) {
      _stats = TripStats.empty;
      _reports = ReportBundle.empty;
      _hasLoaded = true;
      notifyListeners();
      return;
    }

    _loading = true;
    notifyListeners();
    final records = _store.trips(userId);
    _stats = TripStats.from(records);
    _reports = ReportBundle.from(records);
    _loading = false;
    _hasLoaded = true;
    notifyListeners();
  }

  Future<void> refresh() => load(_userId);

  Future<void> add(TripRecord trip) async {
    final userId = _userId;
    if (userId == null) return;
    await _store.saveTrip(userId, trip);
    await refresh();
  }

  Future<void> remove(String tripId) async {
    final userId = _userId;
    if (userId == null) return;
    await _store.deleteTrip(userId, tripId);
    await refresh();
  }

  Future<void> clear() async {
    final userId = _userId;
    if (userId == null) return;
    await _store.clearTrips(userId);
    await refresh();
  }

  /// Seeds a plausible drive so the dashboard can be demoed before the
  /// camera detection module lands.
  Future<void> addSampleTrip() async {
    final random = Random();
    final minutesAgo = random.nextInt(60 * 24 * 5);
    final hazards = <HazardType, int>{};
    for (final type in HazardType.values) {
      final count = random.nextInt(4);
      if (count > 0) hazards[type] = count;
    }
    if (hazards.isEmpty) hazards[HazardType.pothole] = 1;

    final duration = 240 + random.nextInt(2400);
    final distance = 800 + random.nextDouble() * 18000;
    final avgSpeed = (distance / 1000) / (duration / 3600);

    await add(
      TripRecord(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        startedAt: DateTime.now().subtract(Duration(minutes: minutesAgo)),
        durationSeconds: duration,
        distanceMeters: distance,
        maxSpeedKph: avgSpeed * (1.3 + random.nextDouble() * 0.6),
        overspeedCount: random.nextInt(3),
        hazards: hazards,
      ),
    );
  }
}
