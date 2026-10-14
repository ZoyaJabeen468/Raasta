import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

enum AppPermissionKind { camera, location, microphone, notifications }

class PermissionService {
  Future<PermissionStatus> statusOf(AppPermissionKind kind) {
    return _map(kind).status;
  }

  Future<PermissionStatus> request(AppPermissionKind kind) async {
    if (kIsWeb) {
      // Browser cannot grant native camera/location the same way.
      return PermissionStatus.granted;
    }
    return _map(kind).request();
  }

  /// Camera and location for Drive. Notifications are optional.
  /// Microphone is not requested: spoken alerts use TTS, not the mic.
  Future<Map<AppPermissionKind, PermissionStatus>> requestCore() async {
    final results = <AppPermissionKind, PermissionStatus>{};
    results[AppPermissionKind.camera] = await request(AppPermissionKind.camera);
    results[AppPermissionKind.location] =
        await request(AppPermissionKind.location);
    results[AppPermissionKind.notifications] =
        await request(AppPermissionKind.notifications);
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
