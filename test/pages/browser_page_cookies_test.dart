import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/services/browser_cookie_service.dart';

// Note: Full BrowserPage widget tests require platform-native InAppWebView
// which cannot run in unit test mode. These tests verify the cookie retention
// behavior at the service layer instead.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    BrowserCookieService.enableTestMode();
  });

  tearDown(() {
    BrowserCookieService.disableTestMode();
  });

  // ====================================================================
  // Cookie retention service behavior
  // ====================================================================

  group('BrowserPage cookie retention service', () {
    test('retention mode defaults to false', () async {
      expect(await BrowserCookieService.getRetentionMode(), isFalse);
    });

    test('toggling retention mode on then off works', () async {
      await BrowserCookieService.toggleRetentionMode();
      expect(await BrowserCookieService.getRetentionMode(), isTrue);

      await BrowserCookieService.toggleRetentionMode();
      expect(await BrowserCookieService.getRetentionMode(), isFalse);
    });

    test('persists retention state across set/get cycles', () async {
      await BrowserCookieService.setRetentionMode(true);
      expect(await BrowserCookieService.getRetentionMode(), isTrue);
    });

    test('toggling twice returns to original state', () async {
      final initialState = await BrowserCookieService.getRetentionMode();

      await BrowserCookieService.toggleRetentionMode();
      await BrowserCookieService.toggleRetentionMode();

      expect(
          await BrowserCookieService.getRetentionMode(), equals(initialState));
    });
  });

  // ====================================================================
  // Cookie persistence integration
  // ====================================================================

  group('Cookie persistence integration', () {
    test('persistCookiesToFile with retention enabled stores cookies',
        () async {
      await BrowserCookieService.setRetentionMode(true);

      final testCookies = [
        {
          'domain': 'example.com',
          'name': 'session',
          'value': 'abc',
          'path': '/',
        },
      ];

      await BrowserCookieService.persistCookiesRawForTest(testCookies);
      final cookies = await BrowserCookieService.getCookiesFromFile();
      expect(cookies, isNotEmpty);
      expect(cookies['example.com']?.first['name'], equals('session'));
    });

    test('clearPersistedCookies called when retention disabled', () async {
      // When retention is disabled and browser closes, cookies should be cleared
      await BrowserCookieService.setRetentionMode(false);

      final testCookies = [
        {
          'domain': 'example.com',
          'name': 'session',
          'value': 'abc',
          'path': '/',
        },
      ];

      await BrowserCookieService.persistCookiesRawForTest(testCookies);
      await BrowserCookieService.clearPersistedCookies();

      final cookies = await BrowserCookieService.getCookiesFromFile();
      expect(cookies, isEmpty);
    });

    test('getCookiesGrouped returns combined data from file', () async {
      final testCookies = [
        {
          'domain': 'store.example.com',
          'name': 'token',
          'value': 'xyz',
          'path': '/',
        },
      ];

      await BrowserCookieService.persistCookiesRawForTest(testCookies);
      final grouped = await BrowserCookieService.getCookiesGrouped();

      expect(grouped.containsKey('store.example.com'), isTrue);
      expect(grouped['store.example.com']!.first['name'], equals('token'));
    });

    test('persistCookiesToFile with empty cookies is safe', () async {
      await BrowserCookieService.setRetentionMode(true);
      // Should not throw when there are no cookies
      await BrowserCookieService.persistCookiesRawForTest([]);
      final cookies = await BrowserCookieService.getCookiesFromFile();
      expect(cookies, isEmpty);
    });
  });
}
