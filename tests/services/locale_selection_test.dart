import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/providers/locale_provider.dart';

void main() {
  group('locale resolution', () {
    test(
      'uses supported system locale and falls back for unsupported locale',
      () {
        expect(
          resolveSystemLocale(const Locale('zh', 'CN')),
          const Locale('zh', 'CN'),
        );
        expect(
          resolveSystemLocale(const Locale('fr', 'FR')),
          const Locale('en', 'US'),
        );
      },
    );

    test(
      'matches language-only system locale and unsupported Chinese region',
      () {
        expect(
          resolveSystemLocale(const Locale('zh')),
          const Locale('zh', 'CN'),
        );
        expect(
          resolveSystemLocale(const Locale('zh', 'TW')),
          const Locale('en', 'US'),
        );
      },
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
      final invalidController = invalidContainer.read(localeProvider.notifier);
      await invalidController.load();
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
}
