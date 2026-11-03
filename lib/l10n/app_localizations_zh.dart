// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get languageSettingsTitle => '语言';

  @override
  String get followSystemLanguage => '跟随系统';

  @override
  String get languageNameEnglish => '英语';

  @override
  String get languageNameChinese => '简体中文';
}

/// The translations for Chinese, as used in China (`zh_CN`).
class AppLocalizationsZhCn extends AppLocalizationsZh {
  AppLocalizationsZhCn() : super('zh_CN');

  @override
  String get languageSettingsTitle => '语言';

  @override
  String get followSystemLanguage => '跟随系统';

  @override
  String get languageNameEnglish => '英语';

  @override
  String get languageNameChinese => '简体中文';
}
