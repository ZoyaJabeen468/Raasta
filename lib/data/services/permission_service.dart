import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

enum AppPermissionKind { camera, location, microphone, notifications }

class PermissionService {
  Future<PermissionStatus> statusOf(AppPermissionKind kind) {
    return _map(kind).status;
  }

  /// FE-6: voice alerts require microphone; deny → visual-only.
  Future<bool> isMicrophoneGranted() async {
    if (kIsWeb) return true;
    final status = await statusOf(AppPermissionKind.microphone);
    return status.isGranted;
  }

  Future<PermissionStatus> request(AppPermissionKind kind) async {
    if (kIsWeb) {
      // Browser cannot grant native camera/location the same way.
      // Mark as granted for UI flow; real grants happen on Android.
      return PermissionStatus.granted;
    }
    return _map(kind).request();
  }

  Future<Map<AppPermissionKind, PermissionStatus>> requestCore() async {
    final results = <AppPermissionKind, PermissionStatus>{};
    for (final kind in AppPermissionKind.values) {
      results[kind] = await request(kind);
    }
    return results;
  }

  Permission _map(AppPermissionKind kind) {
    switch (kind) {
      case AppPermissionKind.camera:
        return Permission.camera;
      case AppPermissionKind.location:
        return Permission.locationWhenInUse;
      case AppPermissionKind.microphone:
        return Permission.microphone;
      case AppPermissionKind.notifications:
        return Permission.notification;
    }
  }
}
