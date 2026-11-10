import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

typedef LocaleName = String Function(AppLocalizations strings);

class LocaleNameInfo {
  const LocaleNameInfo({
    required this.displayName,
    required this.nativeName,
    required this.id,
  });

  final LocaleName displayName;
  final String nativeName;
  final String id;
}

const localeNameCatalog = <String, LocaleNameInfo>{
  'en_US': LocaleNameInfo(
    displayName: _englishName,
    nativeName: 'English',
    id: 'en-us',
  ),
  'zh_CN': LocaleNameInfo(
    displayName: _chineseName,
    nativeName: '简体中文',
    id: 'zh-cn',
  ),
  'es_ES': LocaleNameInfo(
    displayName: _spanishName,
    nativeName: 'Español',
    id: 'es-es',
  ),
  'ja_JP': LocaleNameInfo(
    displayName: _japaneseName,
    nativeName: '日本語',
    id: 'ja-jp',
  ),
};

String _englishName(AppLocalizations strings) => strings.languageNameEnglish;
String _chineseName(AppLocalizations strings) => strings.languageNameChinese;
String _spanishName(AppLocalizations strings) => strings.languageNameSpanish;
String _japaneseName(AppLocalizations strings) => strings.languageNameJapanese;

String localeDisplayName(AppLocalizations strings, Locale locale) =>
    localeNameCatalog[localeCodeForCatalog(locale)]?.displayName(strings) ??
    locale.toLanguageTag();

String localeNativeName(Locale locale) =>
    localeNameCatalog[localeCodeForCatalog(locale)]?.nativeName ??
    locale.toLanguageTag();

String localeIdTag(Locale locale) =>
    localeNameCatalog[localeCodeForCatalog(locale)]?.id ??
    locale.toLanguageTag().toLowerCase();

String localeCodeForCatalog(Locale locale) =>
    '${locale.languageCode}_${locale.countryCode}';
