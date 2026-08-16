import 'package:flutter/foundation.dart';

import '../../data/local/local_store.dart';
import '../../data/models/driver_details.dart';

/// Optional driver details (age, experience, vehicle) kept on the device.
class DriverProfileProvider extends ChangeNotifier {
  DriverProfileProvider({LocalStore? store})
    : _store = store ?? LocalStore.instance;

  final LocalStore _store;

  String? _userId;
  DriverDetails _details = DriverDetails.empty;

  DriverDetails get details => _details;
  bool get hasDetails => !_details.isEmpty;

  Future<void> load(String? userId) async {
    _userId = userId;
    _details = userId == null
        ? DriverDetails.empty
        : _store.driverDetails(userId);
    notifyListeners();
  }

  Future<void> save(DriverDetails details) async {
    _details = details;
    notifyListeners();
    final userId = _userId;
    if (userId != null) {
      await _store.saveDriverDetails(userId, details);
    }
  }

  Future<void> clear() async {
    final userId = _userId;
    _details = DriverDetails.empty;
    notifyListeners();
    if (userId != null) {
      await _store.clearDriverDetails(userId);
    }
  }
}
