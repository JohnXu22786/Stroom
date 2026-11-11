import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart' show Locale, WidgetsBinding;
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/providers/locale_provider.dart';

void main() {
  test('service localization lookup works without WidgetsBinding', () {
    expect(() => WidgetsBinding.instance, throwsFlutterError);

    final strings = appLocalizationsForLocale(null);

    expect(
      strings.localeName,
      localeCode(resolveSystemLocale(PlatformDispatcher.instance.locale)),
    );
  });

  test('service localization lookup honors an explicit locale override', () {
    final strings = appLocalizationsForLocale(const Locale('zh', 'CN'));

    expect(strings.localeName, 'zh_CN');
  });

  test('French is selectable and resolves French system preferences', () {
    const french = Locale('fr', 'FR');

    expect(supportedAppLocales, contains(french));
    expect(localeFromCode('fr_FR'), french);
    expect(resolveSystemLocale(const Locale('fr')), french);
    expect(appLocalizationsForLocale(french).localeName, 'fr_FR');
  });
}
