import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import '../models/driver_details.dart';
import '../models/language_preference.dart';
import '../models/trip_record.dart';
import '../models/user_profile.dart';

/// Local preferences, user cache, driver details and trip history.
class LocalStore {
  LocalStore._();
  static final LocalStore instance = LocalStore._();

  static const _usersBox = 'users';
  static const _tripsBox = 'trips';
  static const _driversBox = 'drivers';

  static const _introSeenKey = 'intro_seen';
  static const _onboardingDoneKey = 'onboarding_done';
  static const _languageKey = 'language_preference';
  static const _darkModeKey = 'dark_mode';
  static const _voiceAlertsKey = 'voice_alerts';
  static const _hazardAlertsKey = 'hazard_alerts';

  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    await Hive.initFlutter();
    await Hive.openBox(_usersBox);
    await Hive.openBox(_tripsBox);
    await Hive.openBox(_driversBox);
    _ready = true;
  }

  void _ensure() {
    if (!_ready) {
      throw StateError('LocalStore.init() must be called before use');
    }
  }

  Box<dynamic> _box(String name) {
    _ensure();
    return Hive.box(name);
  }

  // ---------------------------------------------------------------- users

  Future<void> saveUser(UserProfile user) async {
    await _box(_usersBox).put(user.id, user.toMap());
  }

  UserProfile? findById(String id) {
    final value = _box(_usersBox).get(id);
    if (value == null) return null;
    return UserProfile.fromMap(Map<dynamic, dynamic>.from(value as Map));
  }

  // ---------------------------------------------------------------- trips

  String _tripKey(String userId, String tripId) => '$userId|$tripId';

  Future<void> saveTrip(String userId, TripRecord trip) async {
    await _box(_tripsBox).put(_tripKey(userId, trip.id), trip.toMap());
  }

  List<TripRecord> trips(String userId) {
    final box = _box(_tripsBox);
    final prefix = '$userId|';
    final result = <TripRecord>[];
    for (final key in box.keys) {
      if (key is! String || !key.startsWith(prefix)) continue;
      final value = box.get(key);
      if (value is Map) {
        result.add(TripRecord.fromMap(Map<dynamic, dynamic>.from(value)));
      }
    }
    result.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return result;
  }

  Future<void> deleteTrip(String userId, String tripId) async {
    await _box(_tripsBox).delete(_tripKey(userId, tripId));
  }

  Future<void> clearTrips(String userId) async {
    final box = _box(_tripsBox);
    final prefix = '$userId|';
    final keys = box.keys
        .whereType<String>()
        .where((k) => k.startsWith(prefix))
        .toList();
    await box.deleteAll(keys);
  }

  // -------------------------------------------------------- driver details

  DriverDetails driverDetails(String userId) {
    final value = _box(_driversBox).get(userId);
    if (value is! Map) return DriverDetails.empty;
    return DriverDetails.fromMap(Map<dynamic, dynamic>.from(value));
  }

  Future<void> saveDriverDetails(String userId, DriverDetails details) async {
    await _box(_driversBox).put(userId, details.toMap());
  }

  Future<void> clearDriverDetails(String userId) async {
    await _box(_driversBox).delete(userId);
  }

  // ------------------------------------------------------------- app flags

  Future<bool> hasSeenIntro() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_introSeenKey) ?? false;
  }

  Future<void> markIntroSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_introSeenKey, true);
  }

  Future<bool> isOnboardingDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingDoneKey) ?? false;
  }

  Future<void> markOnboardingDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingDoneKey, true);
  }

  Future<LanguagePreference> language() async {
    final prefs = await SharedPreferences.getInstance();
    return LanguagePreference.fromStorage(prefs.getString(_languageKey));
  }

  Future<void> setLanguage(LanguagePreference language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, language.name);
  }

  // -------------------------------------------------------------- settings

  Future<AppSettings> settings() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(
      darkMode: prefs.getBool(_darkModeKey) ?? false,
      voiceAlerts: prefs.getBool(_voiceAlertsKey) ?? true,
      hazardAlerts: prefs.getBool(_hazardAlertsKey) ?? true,
      language: LanguagePreference.fromStorage(prefs.getString(_languageKey)),
    );
  }

  Future<void> saveSettings(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, settings.darkMode);
    await prefs.setBool(_voiceAlertsKey, settings.voiceAlerts);
    await prefs.setBool(_hazardAlertsKey, settings.hazardAlerts);
    await prefs.setString(_languageKey, settings.language.name);
  }
}
