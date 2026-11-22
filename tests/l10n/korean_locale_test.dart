import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/l10n/app_localizations_ko.dart';
import 'package:stroom/l10n/locale_name_catalog.dart';
import 'package:stroom/providers/locale_provider.dart';

void main() {
  test(
    'Korean ARB catalogs preserve the English message and metadata keys',
    () {
      final english = jsonDecode(
        File('lib/l10n/app_en.arb').readAsStringSync(),
      ) as Map<String, dynamic>;
      for (final path in ['lib/l10n/app_ko.arb', 'lib/l10n/app_ko_KR.arb']) {
        final korean =
            jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
        expect(korean.keys.toSet(), english.keys.toSet(), reason: path);
        expect(
          korean['@@locale'],
          path.endsWith('app_ko.arb') ? 'ko' : 'ko_KR',
        );
      }
    },
  );

  test('Korean is selectable and resolves to Korean messages', () {
    const korean = Locale('ko', 'KR');
    expect(supportedAppLocales, contains(korean));
    expect(resolveSystemLocale(const Locale('ko')), korean);
    expect(resolveSystemLocale(korean), korean);
    expect(localeNameCatalog.keys, contains('ko_KR'));
    expect(localeNativeName(korean), '한국어');
    expect(localeIdTag(korean), 'ko-kr');
    expect(
      localeDisplayName(
        lookupAppLocalizations(const Locale('en', 'US')),
        korean,
      ),
      'Korean',
    );
    final strings = lookupAppLocalizations(korean);
    expect(strings, isA<AppLocalizationsKo>());
    expect(strings.localeName, 'ko_KR');
    expect(strings.languageNameKorean, '한국어');
    expect(strings.galleryPermissionTitle, '사진 라이브러리 접근 권한 필요');
  });

  testWidgets('Korean app localization renders through the Flutter delegate', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ko', 'KR'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) =>
              Text(AppLocalizations.of(context)!.galleryPermissionTitle),
        ),
      ),
    );

    expect(find.text('사진 라이브러리 접근 권한 필요'), findsOneWidget);
  });
}
