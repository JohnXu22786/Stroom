import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/l10n/app_localizations_en.dart';
import 'package:stroom/l10n/app_localizations_zh.dart';
import 'package:stroom/l10n/locale_name_catalog.dart';
import 'package:stroom/pages/settings_page.dart';
import 'package:stroom/pages/theme_display_settings_page.dart';
import 'package:stroom/providers/locale_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/providers/theme_provider.dart';
import 'package:stroom/providers/update_provider.dart';

void main() {
  test('system locale resolution uses supported locales and English fallback',
      () {
    expect(resolveSystemLocale(const Locale('zh', 'CN')),
        const Locale('zh', 'CN'));
    expect(resolveSystemLocale(const Locale('zh')), const Locale('zh', 'CN'));
    expect(resolveSystemLocale(const Locale('zh', 'TW')),
        const Locale('en', 'US'));
    expect(resolveSystemLocale(const Locale('fr', 'FR')),
        const Locale('en', 'US'));
  });

  test('localized display-name catalog covers generated supported locales', () {
    expect(
      localeNameCatalog.keys,
      containsAll(supportedAppLocales.map(localeCodeForCatalog)),
    );
    expect(
      localeDisplayName(AppLocalizationsEnUs(), const Locale('zh', 'CN')),
      'Chinese (Simplified)',
    );
    expect(
      localeDisplayName(AppLocalizationsZhCn(), const Locale('en', 'US')),
      '英语',
    );
  });

  group('locale preference persistence', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('missing and invalid saved locale follow system', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(localeProvider.notifier);
      await controller.load();
      expect(container.read(localeProvider), isNull);
      SharedPreferences.setMockInitialValues({localePreferenceKey: 'fr_FR'});
      final invalidContainer = ProviderContainer();
      addTearDown(invalidContainer.dispose);
      await invalidContainer.read(localeProvider.notifier).load();
      expect(invalidContainer.read(localeProvider), isNull);
      await controller.setLocaleCode('fr_FR');
      expect(container.read(localeProvider), isNull);
      expect(
        (await SharedPreferences.getInstance()).getString(localePreferenceKey),
        isNull,
      );
    });

    test('explicit override persists and follow-system clears it', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(localeProvider.notifier);
      await controller.load();
      await controller.setLocaleCode('zh_CN');
      expect(container.read(localeProvider), const Locale('zh', 'CN'));
      expect(
        (await SharedPreferences.getInstance()).getString(localePreferenceKey),
        'zh_CN',
      );
      final restoredContainer = ProviderContainer();
      addTearDown(restoredContainer.dispose);
      await restoredContainer.read(localeProvider.notifier).load();
      expect(restoredContainer.read(localeProvider), const Locale('zh', 'CN'));
      await controller.followSystem();
      expect(container.read(localeProvider), isNull);
      expect(
        (await SharedPreferences.getInstance()).getString(localePreferenceKey),
        isNull,
      );
    });
  });

  testWidgets('theme mode and language options update', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [themeProvider.overrideWith((ref) => ThemeNotifier())],
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            locale: ref.watch(localeProvider),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Column(
                children: [
                  const Expanded(child: ThemeDisplaySettingsPage()),
                  Consumer(
                    builder: (context, ref, _) => Text(
                      ref.watch(themeProvider).name,
                      key: const Key('selected-theme-mode'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('浅色模式'), findsOneWidget);
    expect(find.text('深色模式'), findsOneWidget);
    expect(find.text('Follow system'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Chinese (Simplified)'), findsOneWidget);
    expect(find.text('主题'), findsOneWidget);
    expect(find.text('主题与显示'), findsOneWidget);
    expect(find.byType(Card), findsNWidgets(2));
    expect(find.text('system'), findsOneWidget);

    await tester.tap(find.text('深色模式'));
    await tester.pumpAndSettle();

    expect(find.text('dark'), findsOneWidget);

    await tester.tap(find.text('Chinese (Simplified)'));
    await tester.pumpAndSettle();
    expect(
      (await SharedPreferences.getInstance()).getString(localePreferenceKey),
      'zh_CN',
    );
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).locale,
      const Locale('zh', 'CN'),
    );
  });

  testWidgets('settings entry opens the titled theme and display page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          themeProvider.overrideWith((ref) => ThemeNotifier()),
          providerEntriesProvider.overrideWith((ref) {
            final notifier = ProviderEntriesNotifier();
            notifier.load();
            return notifier;
          }),
          updateProvider.overrideWith((ref) => UpdateNotifier()),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final themeIcon = tester.widget<Icon>(find.byIcon(Icons.palette_outlined));
    final notificationIcon = tester.widget<Icon>(
      find.byIcon(Icons.notifications_active),
    );
    final optimizationIcon = tester.widget<Icon>(find.byIcon(Icons.speed));
    expect(themeIcon.color, Colors.deepPurple);
    expect(notificationIcon.color, Colors.blue);
    expect(optimizationIcon.color, Colors.teal);
    expect({
      themeIcon.color,
      notificationIcon.color,
      optimizationIcon.color,
    }, hasLength(3));

    expect(find.text('深色模式、显示语言'), findsOneWidget);
    await tester.tap(find.text('主题与显示'));
    await tester.pumpAndSettle();

    expect(find.text('主题与显示'), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.text('主题'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Chinese (Simplified)'), findsOneWidget);
  });
}
