import 'language_preference.dart';

/// User-controlled app preferences shown on the settings screen.
class AppSettings {
  const AppSettings({
    this.darkMode = false,
    this.voiceAlerts = true,
    this.hazardAlerts = true,
    this.language = LanguagePreference.english,
    this.wrongWayDemoMode = false,
  });

  final bool darkMode;
  final bool voiceAlerts;
  final bool hazardAlerts;
  final LanguagePreference language;

  /// M6 FYP demo: treat the trip as wrong-way so the delayed alert can fire
  /// indoors without reversing on a real road.
  final bool wrongWayDemoMode;

  static const defaults = AppSettings();

  AppSettings copyWith({
    bool? darkMode,
    bool? voiceAlerts,
    bool? hazardAlerts,
    LanguagePreference? language,
    bool? wrongWayDemoMode,
  }) {
    return AppSettings(
      darkMode: darkMode ?? this.darkMode,
      voiceAlerts: voiceAlerts ?? this.voiceAlerts,
      hazardAlerts: hazardAlerts ?? this.hazardAlerts,
      language: language ?? this.language,
      wrongWayDemoMode: wrongWayDemoMode ?? this.wrongWayDemoMode,
    );
  }
}
