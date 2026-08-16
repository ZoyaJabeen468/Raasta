import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

class FirebaseBootstrap {
  FirebaseBootstrap._();

  static bool ready = false;
  static String? initError;

  static Future<void> init() async {
    if (!DefaultFirebaseOptions.isConfigured) {
      ready = false;
      initError =
          'Firebase is not configured yet. Open FIREBASE_SETUP.md and run flutterfire configure.';
      debugPrint('RAASTA: $initError');
      return;
    }

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      ready = true;
      initError = null;
      debugPrint('RAASTA: Firebase ready');
    } catch (e) {
      ready = false;
      initError = e.toString();
      debugPrint('RAASTA: Firebase init failed: $e');
    }
  }
}
