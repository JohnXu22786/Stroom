import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/services/browser_cookie_service.dart';

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
  // getRetentionMode — default value
  // ====================================================================

  group('getRetentionMode', () {
    test('returns false when no value has been set', () async {
      final enabled = await BrowserCookieService.getRetentionMode();
      expect(enabled, isFalse);
    });

    test('returns true after setRetentionMode(true)', () async {
      await BrowserCookieService.setRetentionMode(true);
      final enabled = await BrowserCookieService.getRetentionMode();
      expect(enabled, isTrue);
    });

    test('returns false after setRetentionMode(false)', () async {
      await BrowserCookieService.setRetentionMode(true);
      await BrowserCookieService.setRetentionMode(false);
      final enabled = await BrowserCookieService.getRetentionMode();
      expect(enabled, isFalse);
    });
  });

  // ====================================================================
  // setRetentionMode — persistence
  // ====================================================================

  group('setRetentionMode', () {
    test('persists true across multiple reads', () async {
      await BrowserCookieService.setRetentionMode(true);
      expect(await BrowserCookieService.getRetentionMode(), isTrue);
      expect(await BrowserCookieService.getRetentionMode(), isTrue);
    });

    test('persists false across multiple reads', () async {
      await BrowserCookieService.setRetentionMode(false);
      expect(await BrowserCookieService.getRetentionMode(), isFalse);
      expect(await BrowserCookieService.getRetentionMode(), isFalse);
    });
  });

  // ====================================================================
  // toggleRetentionMode — flips state
  // ====================================================================

  group('toggleRetentionMode', () {
    test('flips false to true', () async {
      // Ensure default is false
      expect(await BrowserCookieService.getRetentionMode(), isFalse);
      final newValue = await BrowserCookieService.toggleRetentionMode();
      expect(newValue, isTrue);
      expect(await BrowserCookieService.getRetentionMode(), isTrue);
    });

    test('flips true to false', () async {
      await BrowserCookieService.setRetentionMode(true);
      final newValue = await BrowserCookieService.toggleRetentionMode();
      expect(newValue, isFalse);
      expect(await BrowserCookieService.getRetentionMode(), isFalse);
    });
  });

  // ====================================================================
  // Cookie persistence (file-based, test mode uses in-memory)
  // ====================================================================

  group('persistCookiesToFile / getCookiesFromFile', () {
    test('getCookiesFromFile returns empty map when no file exists', () async {
      final cookies = await BrowserCookieService.getCookiesFromFile();
      expect(cookies, isA<Map<String, List<Map<String, dynamic>>>>());
      expect(cookies, isEmpty);
    });

    test('persist and retrieve cookies round-trips correctly', () async {
      final testCookies = [
        {
          'domain': 'example.com',
          'name': 'session_id',
          'value': 'abc123',
          'path': '/',
          'isSecure': false,
          'isHttpOnly': false,
        },
        {
          'domain': 'example.com',
          'name': 'theme',
          'value': 'dark',
          'path': '/',
          'isSecure': false,
          'isHttpOnly': false,
        },
        {
          'domain': 'google.com',
          'name': 'pref',
          'value': 'lang=en',
          'path': '/',
          'isSecure': true,
          'isHttpOnly': false,
        },
      ];

      await BrowserCookieService.persistCookiesRawForTest(testCookies);
      final retrieved = await BrowserCookieService.getCookiesFromFile();

      expect(retrieved.length, equals(2));
      expect(retrieved.containsKey('example.com'), isTrue);
      expect(retrieved.containsKey('google.com'), isTrue);
      expect(retrieved['example.com']!.length, equals(2));
      expect(retrieved['google.com']!.length, equals(1));
      expect(retrieved['example.com']![0]['name'], equals('session_id'));
      expect(retrieved['example.com']![0]['value'], equals('abc123'));
    });

    test('persistCookiesToFile handles empty cookie list gracefully', () async {
      await BrowserCookieService.persistCookiesRawForTest([]);
      final retrieved = await BrowserCookieService.getCookiesFromFile();
      expect(retrieved, isEmpty);
    });

    test('persistCookiesToFile with retention enabled stores cookies',
        () async {
      await BrowserCookieService.setRetentionMode(true);

      final testCookies = [
        {
          'domain': 'test.org',
          'name': 'test_cookie',
          'value': 'test_value',
          'path': '/',
        },
      ];

      await BrowserCookieService.persistCookiesRawForTest(testCookies);
      final retrieved = await BrowserCookieService.getCookiesFromFile();
      expect(retrieved.containsKey('test.org'), isTrue);
      expect(retrieved['test.org']!.first['name'], equals('test_cookie'));
    });
  });

  // ====================================================================
  // clearPersistedCookies
  // ====================================================================

  group('clearPersistedCookies', () {
    test('clears all persisted cookies', () async {
      final testCookies = [
        {
          'domain': 'example.com',
          'name': 'session_id',
          'value': 'abc123',
          'path': '/',
        },
      ];

      await BrowserCookieService.persistCookiesRawForTest(testCookies);
      expect(await BrowserCookieService.getCookiesFromFile(), isNotEmpty);

      await BrowserCookieService.clearPersistedCookies();
      final retrieved = await BrowserCookieService.getCookiesFromFile();
      expect(retrieved, isEmpty);
    });

    test('clearPersistedCookies on empty store does not throw', () async {
      await BrowserCookieService.clearPersistedCookies();
      final retrieved = await BrowserCookieService.getCookiesFromFile();
      expect(retrieved, isEmpty);
    });
  });

  // ====================================================================
  // getCookiesGrouped (combined source)
  // ====================================================================

  group('getCookiesGrouped', () {
    test('getCookiesGrouped returns empty map when no cookies exist',
        () async {
      final result = await BrowserCookieService.getCookiesGrouped();
      // In test mode without platform CookieManager, should return file-based
      // data (which is empty)
      expect(result, isA<Map<String, List<Map<String, dynamic>>>>());
    });

    test('getCookiesGrouped returns persisted cookies', () async {
      final testCookies = [
        {
          'domain': 'my-site.com',
          'name': 'auth',
          'value': 'token123',
          'path': '/',
        },
      ];

      await BrowserCookieService.persistCookiesRawForTest(testCookies);
      final result = await BrowserCookieService.getCookiesGrouped();

      expect(result.containsKey('my-site.com'), isTrue);
      expect(result['my-site.com']!.first['name'], equals('auth'));
    });
  });
}
