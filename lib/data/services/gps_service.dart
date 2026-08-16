import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Live GPS speed / position for drive mode.
///
/// Returns `null` from [start] when location is unavailable so callers can
/// fall back to a simulated speed source (web / denied permission).
class GpsService {
  StreamSubscription<Position>? _sub;
  final _controller = StreamController<GpsSample>.broadcast();

  Stream<GpsSample> get samples => _controller.stream;

  bool get isActive => _sub != null;

  /// Requests permission and starts the position stream.
  /// Returns `false` when GPS cannot be used.
  Future<bool> start() async {
    await stop();

    if (kIsWeb) {
      // Browser geolocation is unreliable for continuous drive demos.
      return false;
    }

    final serviceOn = await Geolocator.isLocationServiceEnabled();
    if (!serviceOn) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }

    const settings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    );

    _sub = Geolocator.getPositionStream(locationSettings: settings).listen(
      (pos) {
        // Geolocator speed is m/s; negative means unavailable.
        final speedMps = pos.speed.isNaN || pos.speed < 0 ? 0.0 : pos.speed;
        _controller.add(
          GpsSample(
            speedKph: speedMps * 3.6,
            latitude: pos.latitude,
            longitude: pos.longitude,
            at: pos.timestamp,
          ),
        );
      },
      onError: (_) {
        // Keep listening; transient GPS glitches are common in tunnels.
      },
    );
    return true;
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  void dispose() {
    _sub?.cancel();
    _controller.close();
  }
}

class GpsSample {
  const GpsSample({
    required this.speedKph,
    required this.latitude,
    required this.longitude,
    required this.at,
  });

  final double speedKph;
  final double latitude;
  final double longitude;
  final DateTime? at;
}
