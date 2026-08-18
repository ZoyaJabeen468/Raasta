import 'package:flutter/material.dart';

import '../../data/local/local_store.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/language_preference.dart';

/// Owns app preferences, including the active theme mode.
class SettingsProvider extends ChangeNotifier {
  SettingsProvider({LocalStore? store}) : _store = store ?? LocalStore.instance;

  final LocalStore _store;

  AppSettings _settings = AppSettings.defaults;
  bool _loaded = false;

  AppSettings get settings => _settings;
  bool get isLoaded => _loaded;
  ThemeMode get themeMode =>
      _settings.darkMode ? ThemeMode.dark : ThemeMode.light;

  Future<void> load() async {
    _settings = await _store.settings();
    _loaded = true;
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) =>
      _update(_settings.copyWith(darkMode: value));

  Future<void> setVoiceAlerts(bool value) =>
      _update(_settings.copyWith(voiceAlerts: value));

  Future<void> setHazardAlerts(bool value) =>
      _update(_settings.copyWith(hazardAlerts: value));

  Future<void> setWrongWayDemoMode(bool value) =>
      _update(_settings.copyWith(wrongWayDemoMode: value));

  Future<void> setLanguage(LanguagePreference value) =>
      _update(_settings.copyWith(language: value));

  Future<void> _update(AppSettings next) async {
    _settings = next;
    notifyListeners();
    await _store.saveSettings(next);
  }
}
