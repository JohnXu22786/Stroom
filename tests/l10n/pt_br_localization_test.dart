import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/providers/locale_provider.dart';

void main() {
  test('Brazilian Portuguese ARB preserves English keys and placeholders', () {
    final english = jsonDecode(
      File('lib/l10n/app_en.arb').readAsStringSync(),
    ) as Map<String, dynamic>;
    final portuguese = jsonDecode(
      File('lib/l10n/app_pt_BR.arb').readAsStringSync(),
    ) as Map<String, dynamic>;
    final englishKeys =
        english.keys.where((key) => !key.startsWith('@')).toSet();
    final portugueseKeys =
        portuguese.keys.where((key) => !key.startsWith('@')).toSet();

    expect(portugueseKeys, englishKeys);
    for (final key in englishKeys) {
      expect(
        _placeholders(portuguese[key] as String),
        _placeholders(english[key] as String),
        reason: 'Placeholder mismatch for $key',
      );
    }
  });

  test('Brazilian Portuguese system locales resolve to pt_BR', () {
    expect(resolveSystemLocale(const Locale('pt')).toString(), 'pt_BR');
    expect(resolveSystemLocale(const Locale('pt', 'BR')).toString(), 'pt_BR');
    expect(localeFromCode('pt_BR'), const Locale('pt', 'BR'));
  });

  test('Brazilian Portuguese renders localized and interpolated messages', () {
    final strings = appLocalizationsForLocale(const Locale('pt', 'BR'));

    expect(strings.localeName, 'pt_BR');
    expect(strings.languageSettingsTitle, 'Idioma');
    expect(strings.galleryPermissionCancel, 'Cancelar');
    expect(strings.taskFlowTemplateCount(1), '1 modelo');
    expect(strings.taskFlowTemplateCount(3), '3 modelos');
  });

  test('the Portuguese locale name is localized in existing languages', () {
    expect(
      appLocalizationsForLocale(const Locale('es', 'ES'))
          .languageNamePortuguese,
      'Portugués (Brasil)',
    );
    expect(
      appLocalizationsForLocale(const Locale('ja', 'JP'))
          .languageNamePortuguese,
      'ポルトガル語（ブラジル）',
    );
    expect(
      appLocalizationsForLocale(const Locale('zh', 'CN'))
          .languageNamePortuguese,
      '葡萄牙语（巴西）',
    );
  });
}

Set<String> _placeholders(String message) => RegExp(r'\{\s*([A-Za-z_]\w*)\s*\}')
    .allMatches(message)
    .map((match) => match.group(1)!)
    .toSet();
