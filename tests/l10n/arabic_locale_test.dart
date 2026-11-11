import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/l10n/locale_name_catalog.dart';
import 'package:stroom/providers/locale_provider.dart';

void main() {
  test('Arabic catalogs preserve English keys and placeholders', () {
    final english = jsonDecode(
      File('lib/l10n/app_en.arb').readAsStringSync(),
    ) as Map<String, dynamic>;
    final baseArabic = jsonDecode(
      File('lib/l10n/app_ar.arb').readAsStringSync(),
    ) as Map<String, dynamic>;
    final regionalArabic = jsonDecode(
      File('lib/l10n/app_ar_SA.arb').readAsStringSync(),
    ) as Map<String, dynamic>;
    expect(
      Map<String, dynamic>.of(regionalArabic)..remove('@@locale'),
      Map<String, dynamic>.of(baseArabic)..remove('@@locale'),
    );
    final placeholders = RegExp(r'\{\s*([A-Za-z_]\w*)\s*(?:,|\})');

    for (final entry in [
      ('lib/l10n/app_ar.arb', 'ar'),
      ('lib/l10n/app_ar_SA.arb', 'ar_SA'),
    ]) {
      final arabic =
          jsonDecode(File(entry.$1).readAsStringSync()) as Map<String, dynamic>;
      expect(arabic.keys.toSet(), english.keys.toSet(), reason: entry.$1);
      expect(arabic['@@locale'], entry.$2);
      for (final key in english.keys.where((key) => !key.startsWith('@'))) {
        expect(
          placeholders
              .allMatches(arabic[key] as String)
              .map((match) => match.group(1))
              .toSet(),
          placeholders
              .allMatches(english[key] as String)
              .map((match) => match.group(1))
              .toSet(),
          reason: '${entry.$1}: $key',
        );
      }
    }
  });

  test('Arabic is selectable and system Arabic resolves to the locale', () {
    const arabic = Locale('ar', 'SA');
    expect(textDirectionForLocale(arabic), TextDirection.rtl);
    expect(supportedAppLocales, contains(arabic));
    expect(resolveSystemLocale(const Locale('ar')), arabic);
    expect(resolveSystemLocale(const Locale('ar', 'EG')), arabic);
    expect(localeFromCode('ar_SA'), arabic);
    expect(localeNameCatalog.keys, contains('ar_SA'));
    expect(localeNativeName(arabic), 'العربية');

    final strings = lookupAppLocalizations(arabic);
    expect(strings.localeName, 'ar_SA');
    expect(strings.languageSettingsTitle, isNotEmpty);
    expect(strings.languageNameEnglish, 'الإنجليزية');
  });

  testWidgets('Flutter localization delegate gives Arabic RTL direction', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar', 'SA'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) => Text(
            '${Directionality.of(context)}|'
            '${AppLocalizations.of(context)!.languageSettingsTitle}',
          ),
        ),
      ),
    );

    expect(find.textContaining('TextDirection.rtl|'), findsOneWidget);
  });

  testWidgets('RTL mirrors trailing navigation chevrons', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar', 'SA'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const Scaffold(
          body: ListTile(
            title: Text('إعدادات'),
            trailing: Icon(Icons.chevron_right),
          ),
        ),
      ),
    );

    final chevron = find.byIcon(Icons.chevron_right);
    expect(chevron, findsOneWidget);
    final mirror = find.descendant(
      of: chevron,
      matching: find.byType(Transform),
    );
    expect(mirror, findsOneWidget);
    expect(tester.widget<Transform>(mirror).transform.entry(0, 0), -1);
  });
}
