import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../models/hazard_type.dart';
import '../models/language_preference.dart';

class TtsService {
  TtsService() : _tts = FlutterTts();

  final FlutterTts _tts;
  bool _ready = false;
  bool _speaking = false;
  DateTime? _lastAnnounceAt;

  /// Cached result of probing the device for an Urdu-capable locale.
  String? _urduLocale;
  bool _urduProbed = false;

  static const _minGap = Duration(seconds: 5);

  Future<void> _ensure() async {
    if (_ready) return;
    await _tts.setVolume(1);
    await _tts.setSpeechRate(0.47);
    await _tts.setPitch(1);
    await _tts.awaitSpeakCompletion(true);
    // Android: prefer installed engines; iOS uses AVSpeech.
    try {
      await _tts.setSharedInstance(true);
    } catch (_) {}
    _ready = true;
  }

  /// Prefer a real Urdu voice. Many phones only have English installed —
  /// without this, Urdu text is skipped or garbled.
  Future<String?> _resolveUrduLocale() async {
    if (_urduProbed) return _urduLocale;
    _urduProbed = true;

    final preferred = <String>[
      'ur-PK',
      'ur_PK',
      'ur-IN',
      'ur_IN',
      'ur',
    ];

    try {
      final raw = await _tts.getLanguages;
      final available = <String>[];
      if (raw is List) {
        for (final item in raw) {
          available.add(item.toString());
        }
      }

      String norm(String s) =>
          s.toLowerCase().replaceAll('_', '-').trim();

      final normalized = {for (final a in available) norm(a): a};

      for (final want in preferred) {
        final key = norm(want);
        if (normalized.containsKey(key)) {
          _urduLocale = normalized[key];
          return _urduLocale;
        }
        // Match prefix e.g. "ur-*"
        for (final entry in normalized.entries) {
          if (entry.key == 'ur' || entry.key.startsWith('ur-')) {
            _urduLocale = entry.value;
            return _urduLocale;
          }
        }
      }
    } catch (e) {
      debugPrint('TTS language probe failed: $e');
    }

    // Last attempt: ask the engine directly (returns 1 on success on Android).
    for (final code in preferred) {
      try {
        final result = await _tts.isLanguageAvailable(code);
        if (result == true || result == 1) {
          _urduLocale = code;
          return _urduLocale;
        }
      } catch (_) {}
    }

    _urduLocale = null;
    return null;
  }

  Future<bool> _setEnglish() async {
    final r = await _tts.setLanguage('en-US');
    return r == 1 || r == true || r == null;
  }

  Future<bool> _setUrdu() async {
    final locale = await _resolveUrduLocale();
    if (locale == null) return false;
    final r = await _tts.setLanguage(locale);
    return r == 1 || r == true || r == null;
  }

  Future<void> _speak(String text) async {
    if (text.trim().isEmpty) return;
    await _tts.speak(text);
  }

  /// Test alert for onboarding / settings.
  /// Returns `false` if Urdu was requested but no Urdu voice is installed.
  Future<bool> speakSample(LanguagePreference language) async {
    await _ensure();
    await _tts.stop();

    switch (language) {
      case LanguagePreference.english:
        await _setEnglish();
        await _speak(LanguagePreference.english.samplePhrase);
        return true;

      case LanguagePreference.urdu:
        final ok = await _setUrdu();
        if (!ok) {
          // Fallback so the user still hears something, then report failure.
          await _setEnglish();
          await _speak(
            'Urdu voice is not installed on this phone. '
            'Please install Urdu in Text-to-speech settings.',
          );
          return false;
        }
        await _speak(LanguagePreference.urdu.samplePhrase);
        return true;

      case LanguagePreference.bilingual:
        await _setEnglish();
        await _speak(LanguagePreference.english.samplePhrase);
        final ok = await _setUrdu();
        if (!ok) return false;
        // Short pause between languages so both are clear.
        await Future<void>.delayed(const Duration(milliseconds: 280));
        await _speak(LanguagePreference.urdu.samplePhrase);
        return true;
    }
  }

  /// Speaks a short warning for [type] in the driver's language.
  Future<void> announceHazard(
    HazardType type,
    LanguagePreference language, {
    double? distanceMeters,
  }) async {
    final now = DateTime.now();
    if (_speaking) return;
    if (_lastAnnounceAt != null && now.difference(_lastAnnounceAt!) < _minGap) {
      return;
    }
    _speaking = true;
    _lastAnnounceAt = now;
    final meters = _roundDistance(distanceMeters);
    try {
      await _ensure();
      await _tts.stop();
      await _announceBoth(type, language, meters);
    } finally {
      _speaking = false;
    }
  }

  Future<void> _announceBoth(
    HazardType type,
    LanguagePreference language,
    int? meters,
  ) async {
    if (language == LanguagePreference.english) {
      await _setEnglish();
      await _speak(_english(type, meters));
      return;
    }

    if (language == LanguagePreference.urdu) {
      if (await _setUrdu()) {
        await _speak(_urdu(type, meters));
      } else {
        await _setEnglish();
        await _speak(_english(type, meters));
      }
      return;
    }

    // Bilingual: English first, then Urdu with its own voice.
    await _setEnglish();
    await _speak(_english(type, meters));
    if (await _setUrdu()) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await _speak(_urdu(type, meters));
    }
  }

  /// Speaks an overspeed warning in the driver's preferred language.
  Future<void> announceOverspeed(
    LanguagePreference language, {
    required int limitKph,
  }) async {
    await _ensure();
    await _tts.stop();

    final en = 'Slow down. Speed limit is $limitKph kilometres per hour.';
    final ur = 'رفتار کم کریں۔ رفتار کی حد $limitKph کلومیٹر فی گھنٹہ ہے۔';

    if (language == LanguagePreference.english) {
      await _setEnglish();
      await _speak(en);
      return;
    }

    if (language == LanguagePreference.urdu) {
      if (await _setUrdu()) {
        await _speak(ur);
      } else {
        await _setEnglish();
        await _speak(en);
      }
      return;
    }

    await _setEnglish();
    await _speak(en);
    if (await _setUrdu()) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await _speak(ur);
    }
  }

  int? _roundDistance(double? meters) {
    if (meters == null || meters <= 0) return null;
    return ((meters / 10).round() * 10).clamp(10, 150);
  }

  String _english(HazardType type, int? meters) {
    final dist = meters == null ? 'ahead' : 'ahead $meters meters';
    switch (type) {
      case HazardType.pothole:
        return 'Caution. Pothole $dist. Slow down.';
      case HazardType.speedBump:
        return 'Caution. Speed bump $dist. Slow down.';
      case HazardType.crack:
        return 'Caution. Cracked road $dist. Slow down.';
      case HazardType.person:
        return 'Caution. Pedestrian $dist. Slow down.';
      case HazardType.cow:
        return 'Caution. Cow on the road $dist. Slow down.';
      case HazardType.buffalo:
        return 'Caution. Buffalo on the road $dist. Slow down.';
      case HazardType.dog:
        return 'Caution. Dog on the road $dist.';
      case HazardType.cat:
        return 'Caution. Animal on the road $dist.';
      case HazardType.horse:
        return 'Caution. Horse on the road $dist. Slow down.';
      case HazardType.donkey:
        return 'Caution. Donkey on the road $dist. Slow down.';
      case HazardType.goat:
        return 'Caution. Goat on the road $dist.';
      case HazardType.roadSign:
        return 'Road sign $dist.';
    }
  }

  String _urdu(HazardType type, int? meters) {
    final dist = meters == null ? 'آگے' : '$meters میٹر آگے';
    switch (type) {
      case HazardType.pothole:
        return 'خبردار۔ $dist گڑھا ہے۔ رفتار کم کریں۔';
      case HazardType.speedBump:
        return 'خبردار۔ $dist سپیڈ بریکر ہے۔ رفتار کم کریں۔';
      case HazardType.crack:
        return 'خبردار۔ $dist ٹوٹی سڑک ہے۔';
      case HazardType.person:
        return 'خبردار۔ $dist شخص ہے۔ احتیاط کریں۔';
      case HazardType.cow:
        return 'خبردار۔ $dist گائے ہے۔ رفتار کم کریں۔';
      case HazardType.buffalo:
        return 'خبردار۔ $dist بھینس ہے۔ رفتار کم کریں۔';
      case HazardType.dog:
        return 'خبردار۔ $dist کتا ہے۔ احتیاط کریں۔';
      case HazardType.cat:
        return 'خبردار۔ $dist جانور ہے۔ احتیاط کریں۔';
      case HazardType.horse:
        return 'خبردار۔ $dist گھوڑا ہے۔ رفتار کم کریں۔';
      case HazardType.donkey:
        return 'خبردار۔ $dist گدھا ہے۔ رفتار کم کریں۔';
      case HazardType.goat:
        return 'خبردار۔ $dist بکری ہے۔ احتیاط کریں۔';
      case HazardType.roadSign:
        return 'خبردار۔ $dist سڑک کا نشان ہے۔';
    }
  }

  Future<void> stop() => _tts.stop();
}
