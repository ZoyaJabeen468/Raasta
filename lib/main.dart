import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/config/firebase_bootstrap.dart';
import 'data/local/local_store.dart';
import 'presentation/providers/settings_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await LocalStore.instance.init();
  await FirebaseBootstrap.init();

  // Preloaded so the app opens straight into the saved theme.
  final settings = SettingsProvider();
  await settings.load();

  runApp(RaastaApp(settings: settings));
}
