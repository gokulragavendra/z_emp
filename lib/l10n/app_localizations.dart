// lib/l10n/app_localizations.dart

import 'package:flutter/material.dart';
import 'dart:async';

import 'app_localizations_en.dart';
import 'app_localizations_ta.dart';

class AppLocalizations {
  final Locale locale;

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  late Map<String, String> _localizedStrings;

  AppLocalizations(this.locale);

  /// Loads the appropriate localization map based on [locale].
  /// Falls back to English if any error occurs or if the locale is not supported.
  Future<bool> load() async {
    try {
      // Only 'en' and 'ta' are supported. Default to 'en' if not recognized.
      if (!['en', 'ta'].contains(locale.languageCode)) {
        debugPrint(
            'Unsupported locale "${locale.languageCode}". Falling back to English.');
        _localizedStrings = localizedStringsEn;
        return true;
      }

      switch (locale.languageCode) {
        case 'ta':
          _localizedStrings = localizedStringsTa;
          break;
        case 'en':
        default:
          _localizedStrings = localizedStringsEn;
      }
      return true;
    } catch (e) {
      debugPrint(
          'Error loading localization for "${locale.languageCode}": $e\nFalling back to English.');
      _localizedStrings = localizedStringsEn;
      return false;
    }
  }

  /// Returns the localized string for [key].
  /// If the key is missing, logs a warning and returns [key].
  String translate(String key) {
    if (!_localizedStrings.containsKey(key)) {
      debugPrint(
          'Warning: Missing localization key "$key" in "${locale.languageCode}"');
    }
    return _localizedStrings[key] ?? key;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'ta'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    final localization = AppLocalizations(locale);
    await localization.load();
    return localization;
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
