// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get languageSettingsTitle => 'Language';

  @override
  String get followSystemLanguage => 'Follow system';

  @override
  String get languageNameEnglish => 'English';

  @override
  String get languageNameChinese => 'Chinese (Simplified)';
}

/// The translations for English, as used in the United States (`en_US`).
class AppLocalizationsEnUs extends AppLocalizationsEn {
  AppLocalizationsEnUs() : super('en_US');

  @override
  String get languageSettingsTitle => 'Language';

  @override
  String get followSystemLanguage => 'Follow system';

  @override
  String get languageNameEnglish => 'English';

  @override
  String get languageNameChinese => 'Chinese (Simplified)';
}
