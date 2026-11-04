import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../l10n/locale_name_catalog.dart';

const localePreferenceKey = 'app_locale_override';

final supportedAppLocales = AppLocalizations.supportedLocales
    .where(
      (locale) => localeNameCatalog.containsKey(localeCodeForCatalog(locale)),
    )
    .toList(growable: false);

String localeCode(Locale locale) =>
    '${locale.languageCode}_${locale.countryCode}';

Locale? localeFromCode(String? code) {
  for (final locale in supportedAppLocales) {
    if (localeCode(locale) == code) return locale;
  }
  return null;
}

Locale resolveSystemLocale(Locale systemLocale) {
  for (final locale in supportedAppLocales) {
    if (locale.languageCode == systemLocale.languageCode &&
        (systemLocale.countryCode == null ||
            locale.countryCode == systemLocale.countryCode)) {
      return locale;
    }
  }
  return const Locale('en', 'US');
}

/// Resolves localization resources with the same override/follow-system
/// behavior used by MaterialApp, for app services without a BuildContext.
AppLocalizations appLocalizationsForLocale(Locale? override) {
  final locale = override ??
      resolveSystemLocale(WidgetsBinding.instance.platformDispatcher.locale);
  return lookupAppLocalizations(locale);
}

final localeProvider = NotifierProvider<LocaleSelectionController, Locale?>(
  LocaleSelectionController.new,
);

class LocaleSelectionController extends Notifier<Locale?> {
  var _selectionVersion = 0;

  @override
  Locale? build() => null;

  Future<void> load() async {
    final version = _selectionVersion;
    final prefs = await SharedPreferences.getInstance();
    if (version != _selectionVersion) return;
    state = localeFromCode(prefs.getString(localePreferenceKey));
  }

  Future<void> setLocaleCode(String code) async {
    _selectionVersion++;
    final locale = localeFromCode(code);
    if (locale == null) {
      state = null;
      await (await SharedPreferences.getInstance()).remove(localePreferenceKey);
      return;
    }
    state = locale;
    await (await SharedPreferences.getInstance()).setString(
      localePreferenceKey,
      code,
    );
  }

  Future<void> followSystem() async {
    _selectionVersion++;
    state = null;
    await (await SharedPreferences.getInstance()).remove(localePreferenceKey);
  }
}
