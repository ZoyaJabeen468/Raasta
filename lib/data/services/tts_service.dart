import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../models/hazard_type.dart';
import '../models/language_preference.dart';
import 'hazard_detector.dart';

class TtsService {
  TtsService() : _tts = FlutterTts();

  final FlutterTts _tts;
  bool _ready = false;
  bool _speaking = false;
  bool _signSpeaking = false;
  DateTime? _lastAnnounceAt;
  HazardType? _lastHazardType;
  HazardType? _pendingHazard;
  LanguagePreference? _pendingLanguage;
  HazardRange? _pendingRange;
  int? _pendingEta;

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
    HazardRange? range,
    int? etaSeconds,
  }) async {
    if (type == HazardType.crack && _speaking) return;
    if (_speaking) {
      final current = _lastHazardType;
      final otherSlot = current != null &&
          ((type.isLifeHazard && current.isRoadHazard) ||
              (type.isRoadHazard && current.isLifeHazard));
      if (otherSlot && type != HazardType.crack) {
        _pendingHazard = type;
        _pendingLanguage = language;
        _pendingRange = range;
        _pendingEta = etaSeconds;
      }
      return;
    }
    final now = DateTime.now();
    final last = _lastHazardType;
    final sameSlot = last != null &&
        ((type.isRoadHazard && last.isRoadHazard) ||
            (type.isLifeHazard && last.isLifeHazard));
    if (sameSlot &&
        _lastAnnounceAt != null &&
        now.difference(_lastAnnounceAt!) < _minGap) {
      return;
    }
    _speaking = true;
    _lastAnnounceAt = now;
    _lastHazardType = type;
    try {
      await _ensure();
      await _tts.stop();
      await _announceBoth(type, language, range, etaSeconds);
    } finally {
      _speaking = false;
      final pending = _pendingHazard;
      final pendingLang = _pendingLanguage;
      if (pending != null && pendingLang != null) {
        _pendingHazard = null;
        _pendingLanguage = null;
        final pendingRange = _pendingRange;
        final pendingEta = _pendingEta;
        _pendingRange = null;
        _pendingEta = null;
        await announceHazard(
          pending,
          pendingLang,
          range: pendingRange,
          etaSeconds: pendingEta,
        );
      }
    }
  }

  Future<void> _announceBoth(
    HazardType type,
    LanguagePreference language,
    HazardRange? range,
    int? etaSeconds,
  ) async {
    if (language == LanguagePreference.english) {
      await _setEnglish();
      await _speak(_english(type, range, etaSeconds));
      return;
    }

    if (language == LanguagePreference.urdu) {
      if (await _setUrdu()) {
        await _speak(_urdu(type, range, etaSeconds));
      } else {
        await _setEnglish();
        await _speak(_english(type, range, etaSeconds));
      }
      return;
    }

    // Bilingual: English first, then Urdu with its own voice.
    await _setEnglish();
    await _speak(_english(type, range, etaSeconds));
    if (await _setUrdu()) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await _speak(_urdu(type, range, etaSeconds));
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

  /// Speaks a road-sign notice. Lower priority than hazards: skipped while a
  /// hazard is speaking or was announced within the hazard gap, and abandoned
  /// mid-way if a hazard starts (hazards call `stop()` and take over).
  ///
  /// Returns `true` if the sign was (at least partly) spoken.
  Future<bool> announceSign(
    LanguagePreference language, {
    required String english,
    required String urdu,
  }) async {
    if (_speaking || _signSpeaking) return false;
    final last = _lastAnnounceAt;
    if (last != null && DateTime.now().difference(last) < _minGap) {
      return false;
    }
    _signSpeaking = true;
    try {
      await _ensure();
      if (_speaking) return false;

      if (language == LanguagePreference.english) {
        await _setEnglish();
        if (!_speaking) await _speak(english);
        return true;
      }

      if (language == LanguagePreference.urdu) {
        final hasUrdu = await _setUrdu();
        if (!hasUrdu) await _setEnglish();
        if (!_speaking) await _speak(hasUrdu ? urdu : english);
        return true;
      }

      await _setEnglish();
      if (_speaking) return false;
      await _speak(english);
      if (_speaking) return true;
      if (await _setUrdu()) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        if (!_speaking) await _speak(urdu);
      }
      return true;
    } finally {
      _signSpeaking = false;
    }
  }

  /// Speaks a speed limit read from a sign by OCR. Same priority rules as
  /// [announceSign]: never talks over a hazard.
  Future<bool> announceSpeedLimit(
    LanguagePreference language, {
    required int limitKph,
  }) => announceSign(
    language,
    english: 'Speed limit $limitKph',
    urdu: 'رفتار کی حد $limitKph ہے',
  );

  String _placeEn(HazardRange? range, int? etaSeconds) {
    final band = range?.english ?? 'ahead';
    if (etaSeconds == null) return band;
    return '$band, about $etaSeconds seconds';
  }

  String _placeUr(HazardRange? range, int? etaSeconds) {
    final band = range?.urdu ?? 'آگے';
    if (etaSeconds == null) return band;
    return '$band، تقریباً $etaSeconds سیکنڈ';
  }

  String _english(HazardType type, HazardRange? range, int? etaSeconds) {
    final dist = _placeEn(range, etaSeconds);
    switch (type) {
      case HazardType.person:
        return 'Slow down now. Pedestrian $dist.';
      case HazardType.cow:
        return 'Slow down now. Cow on the road $dist.';
      case HazardType.buffalo:
        return 'Slow down now. Buffalo on the road $dist.';
      case HazardType.dog:
        return 'Slow down now. Dog on the road $dist.';
      case HazardType.cat:
        return 'Slow down now. Animal on the road $dist.';
      case HazardType.horse:
        return 'Slow down now. Horse on the road $dist.';
      case HazardType.donkey:
        return 'Slow down now. Donkey on the road $dist.';
      case HazardType.goat:
        return 'Slow down now. Goat on the road $dist.';
      case HazardType.speedBump:
        return 'Slow down. Speed bump $dist.';
      case HazardType.pothole:
        return 'Pothole $dist.';
      case HazardType.crack:
        return 'Cracked road.';
      case HazardType.roadSign:
        return 'Road sign $dist.';
      case HazardType.wrongWay:
        return 'Warning. You appear to be driving the wrong way. Turn around safely.';
    }
  }

  String _urdu(HazardType type, HazardRange? range, int? etaSeconds) {
    final dist = _placeUr(range, etaSeconds);
    switch (type) {
      case HazardType.person:
        return 'ابھی رفتار کم کریں۔ $dist شخص ہے۔';
      case HazardType.cow:
        return 'ابھی رفتار کم کریں۔ $dist گائے ہے۔';
      case HazardType.buffalo:
        return 'ابھی رفتار کم کریں۔ $dist بھینس ہے۔';
      case HazardType.dog:
        return 'ابھی رفتار کم کریں۔ $dist کتا ہے۔';
      case HazardType.cat:
        return 'ابھی رفتار کم کریں۔ $dist جانور ہے۔';
      case HazardType.horse:
        return 'ابھی رفتار کم کریں۔ $dist گھوڑا ہے۔';
      case HazardType.donkey:
        return 'ابھی رفتار کم کریں۔ $dist گدھا ہے۔';
      case HazardType.goat:
        return 'ابھی رفتار کم کریں۔ $dist بکری ہے۔';
      case HazardType.speedBump:
        return 'رفتار کم کریں۔ $dist سپیڈ بریکر ہے۔';
      case HazardType.pothole:
        return '$dist گڑھا ہے۔';
      case HazardType.crack:
        return 'ٹوٹی سڑک ہے۔';
      case HazardType.roadSign:
        return '$dist سڑک کا نشان ہے۔';
      case HazardType.wrongWay:
        return 'خبردار۔ آپ غلط سمت میں جا رہے ہیں۔ محفوظ طریقے سے مڑیں۔';
    }
  }

  Future<void> stop() => _tts.stop();
}
