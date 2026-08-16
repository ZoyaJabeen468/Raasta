enum LanguagePreference {

  english,

  urdu,

  bilingual;



  String get label {

    switch (this) {

      case LanguagePreference.english:

        return 'English';

      case LanguagePreference.urdu:

        return 'Urdu';

      case LanguagePreference.bilingual:

        return 'Both';

    }

  }



  /// Meaningful demo lines — like a real road alert, not a placeholder.

  String get samplePhrase {

    switch (this) {

      case LanguagePreference.english:

        return 'Caution. Pothole eighty meters ahead. Slow down.';

      case LanguagePreference.urdu:

        return 'خبردار۔ آگے اسی میٹر پر گڑھا ہے۔ رفتار کم کریں۔';

      case LanguagePreference.bilingual:

        // Shown in UI only; TTS speaks EN then UR separately.

        return 'Caution. Pothole ahead. · خبردار۔ آگے گڑھا ہے۔';

    }

  }



  static LanguagePreference fromStorage(String? value) {

    return LanguagePreference.values.firstWhere(

      (e) => e.name == value,

      orElse: () => LanguagePreference.english,

    );

  }

}


