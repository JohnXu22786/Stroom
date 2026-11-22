import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/l10n/app_localizations_fr.dart';

void main() {
  test('French base and regional locales resolve generated translations', () {
    final base = lookupAppLocalizations(const Locale('fr'));
    final regional = lookupAppLocalizations(const Locale('fr', 'FR'));

    expect(base, isA<AppLocalizationsFr>());
    expect(regional, isA<AppLocalizationsFrFr>());
    expect(base.localeName, 'fr');
    expect(regional.localeName, 'fr_FR');
    expect(base.themeDisplaySettingsTitle, 'Thème et affichage');
    expect(base.languageNamePortuguese, 'Portugais (Brésil)');
    expect(regional.languageNameKorean, 'Coréen');
    expect(regional.languageNamePortuguese, 'Portugais (Brésil)');
    expect(regional.languageNameFrench, 'Français');
    expect(
      lookupAppLocalizations(const Locale('ko', 'KR')).languageNameFrench,
      '프랑스어',
    );
  });
}
