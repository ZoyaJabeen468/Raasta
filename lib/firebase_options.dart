// File generated for RAASTA — replace values via FlutterFire CLI.
// Run: dart pub global activate flutterfire_cli
//      flutterfire configure
//
// Until real values are set, auth screens show a setup message.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  /// True when real Firebase project keys have been pasted in.
  static bool get isConfigured =>
      !currentPlatform.apiKey.contains('YOUR_') &&
      currentPlatform.apiKey.isNotEmpty &&
      currentPlatform.projectId != 'YOUR_PROJECT_ID' &&
      currentPlatform.appId.isNotEmpty &&
      !currentPlatform.appId.contains('YOUR_');

  /// OAuth **Web** client ID from Google Cloud / Firebase
  /// (…apps.googleusercontent.com). Required for Google Sign-In on Android
  /// so Firebase receives an idToken. Leave empty until you paste it —
  /// see FIREBASE_SETUP.md § Google Sign-In.
  static const String googleWebClientId =
      '973226762120-5314k8lermj6fh8prqt634sn33jgn2hb.apps.googleusercontent.com';

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return web;
    }
  }

  // ---- Replace these with values from Firebase Console / flutterfire ----

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyB302RvEvJ2421xhgCQhiesESLeAzx2Bik',
    appId: '1:973226762120:web:a468d96fe8efd7e563a43d',
    messagingSenderId: '973226762120',
    projectId: 'raasta-a2689',
    authDomain: 'raasta-a2689.firebaseapp.com',
    storageBucket: 'raasta-a2689.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB302RvEvJ2421xhgCQhiesESLeAzx2Bik',
    appId: '1:973226762120:android:e4c62ae1f9670fcd63a43d',
    messagingSenderId: '973226762120',
    projectId: 'raasta-a2689',
    authDomain: 'raasta-a2689.firebaseapp.com',
    storageBucket: 'raasta-a2689.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyB302RvEvJ2421xhgCQhiesESLeAzx2Bik',
    appId: '1:973226762120:web:a468d96fe8efd7e563a43d',
    messagingSenderId: '973226762120',
    projectId: 'raasta-a2689',
    authDomain: 'raasta-a2689.firebaseapp.com',
    storageBucket: 'raasta-a2689.firebasestorage.app',
    iosBundleId: 'com.raasta.raasta',
  );
}
