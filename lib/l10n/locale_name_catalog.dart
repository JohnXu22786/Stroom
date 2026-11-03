import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

typedef LocaleName = String Function(AppLocalizations strings);

const localeNameCatalog = <String, LocaleName>{
  'en_US': _englishName,
  'zh_CN': _chineseName,
};

String _englishName(AppLocalizations strings) => strings.languageNameEnglish;
String _chineseName(AppLocalizations strings) => strings.languageNameChinese;

String localeDisplayName(AppLocalizations strings, Locale locale) =>
    localeNameCatalog[localeCodeForCatalog(locale)]?.call(strings) ??
    locale.toLanguageTag();

String localeCodeForCatalog(Locale locale) =>
    '${locale.languageCode}_${locale.countryCode}';
