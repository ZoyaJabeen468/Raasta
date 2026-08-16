import 'language_preference.dart';

/// User-controlled app preferences shown on the settings screen.
class AppSettings {
  const AppSettings({
    this.darkMode = false,
    this.voiceAlerts = true,
    this.hazardAlerts = true,
    this.language = LanguagePreference.english,
  });

  final bool darkMode;
  final bool voiceAlerts;
  final bool hazardAlerts;
  final LanguagePreference language;

  static const defaults = AppSettings();

  AppSettings copyWith({
    bool? darkMode,
    bool? voiceAlerts,
    bool? hazardAlerts,
    LanguagePreference? language,
  }) {
    return AppSettings(
      darkMode: darkMode ?? this.darkMode,
      voiceAlerts: voiceAlerts ?? this.voiceAlerts,
      hazardAlerts: hazardAlerts ?? this.hazardAlerts,
      language: language ?? this.language,
    );
  }
}
