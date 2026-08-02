import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/services/browser_cookie_service.dart';

/// Fake platform facade recording every platform call so the platform
/// branches (merge, per-domain fallback, restore validation, delete
/// forwarding) can be exercised without a device.
class _FakeCookiePlatform implements CookiePlatform {
  bool throwOnGetAll = false;
  bool throwOtherErrorOnGetAll = false;
  List<Cookie> allCookies = [];
  final Map<String, List<Cookie>> perUrlCookies = {};
  int getCookiesCalls = 0;
  final List<Map<String, dynamic>> setCookieCalls = [];
  final List<Map<String, dynamic>> deleteCookieCalls = [];
  final List<Map<String, dynamic>> deleteCookiesCalls = [];
  int deleteAllCookiesCalls = 0;

  @override
  Future<List<Cookie>> getAllCookies() async {
    if (throwOnGetAll) {
      throw UnimplementedError('getAllCookies is not implemented');
    }
    if (throwOtherErrorOnGetAll) {
      throw StateError('platform exploded');
    }
    return allCookies;
  }

  @override
  Future<List<Cookie>> getCookies({required WebUri url}) async {
    getCookiesCalls++;
    return perUrlCookies[url.toString()] ?? [];
  }

  @override
  Future<bool> setCookie({
    required WebUri url,
    required String name,
    required String value,
    String path = '/',
    String? domain,
    int? expiresDate,
    bool? isSecure,
    bool? isHttpOnly,
    HTTPCookieSameSitePolicy? sameSite,
  }) async {
    setCookieCalls.add({
      'url': url.toString(),
      'name': name,
      'value': value,
      'path': path,
      'domain': domain,
      'expiresDate': expiresDate,
      'isSecure': isSecure,
      'isHttpOnly': isHttpOnly,
      'sameSite': sameSite,
    });
    return true;
  }

  @override
  Future<bool> deleteCookie({
    required WebUri url,
    required String name,
    String path = '/',
    String? domain,
  }) async {
    deleteCookieCalls.add({
      'url': url.toString(),
      'name': name,
      'path': path,
      'domain': domain,
    });
    return true;
  }

  @override
  Future<bool> deleteCookies(
      {required WebUri url, String path = '/', String? domain}) async {
    deleteCookiesCalls.add({'url': url.toString(), 'path': path, 'domain': domain});
    return true;
  }

  @override
  Future<bool> deleteAllCookies() async {
    deleteAllCookiesCalls++;
    return true;
  }
}

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

  group('persistCookiesRawForTest / getCookiesFromFile', () {
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

    test('empty cookie list yields empty grouped cookies', () async {
      await BrowserCookieService.persistCookiesRawForTest([]);
      final retrieved = await BrowserCookieService.getCookiesFromFile();
      expect(retrieved, isEmpty);
    });

    test('persisted cookies are readable via getCookiesFromFile', () async {
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
    test('getCookiesGrouped returns empty map when no cookies exist', () async {
      final result = await BrowserCookieService.getCookiesGrouped();
      // In test mode the Android-like platform fake throws UnimplementedError
      // and the in-memory store (empty) is returned via the fallback merge.
      expect(result, isA<Map<String, List<Map<String, dynamic>>>>());
      expect(result, isEmpty);
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

    test('groups by domain with leading-dot domains kept separate', () async {
      await BrowserCookieService.persistCookiesRawForTest([
        {'domain': '.example.com', 'name': 'a', 'value': '1', 'path': '/'},
        {'domain': 'example.com', 'name': 'b', 'value': '2', 'path': '/'},
      ]);

      final result = await BrowserCookieService.getCookiesGrouped();
      expect(result.containsKey('.example.com'), isTrue);
      expect(result.containsKey('example.com'), isTrue);
    });
  });

  // ====================================================================
  // deleteCookie — persisted store side (test mode)
  // ====================================================================

  group('deleteCookie', () {
    test('removes the cookie with the matching path', () async {
      await BrowserCookieService.persistCookiesRawForTest([
        {
          'domain': 'example.com',
          'name': 'session',
          'value': 'abc',
          'path': '/',
        },
        {
          'domain': 'example.com',
          'name': 'session',
          'value': 'abc',
          'path': '/api',
        },
      ]);

      final ok = await BrowserCookieService.deleteCookie(
          'example.com', 'session',
          path: '/api');
      expect(ok, isTrue);

      final cookies = await BrowserCookieService.getCookiesFromFile();
      final paths = cookies['example.com']!
          .map((c) => c['path'])
          .toList();
      expect(paths, ['/']);
    });

    test('without path removes every path for the domain+name', () async {
      await BrowserCookieService.persistCookiesRawForTest([
        {
          'domain': 'example.com',
          'name': 'session',
          'value': 'abc',
          'path': '/',
        },
        {
          'domain': 'example.com',
          'name': 'session',
          'value': 'abc',
          'path': '/api',
        },
        {
          'domain': 'example.com',
          'name': 'other',
          'value': 'x',
          'path': '/',
        },
      ]);

      await BrowserCookieService.deleteCookie('example.com', 'session');

      final cookies = await BrowserCookieService.getCookiesFromFile();
      final names =
          cookies['example.com']!.map((c) => c['name']).toList();
      expect(names, ['other']);
    });

    test('handles leading-dot domain entries', () async {
      await BrowserCookieService.persistCookiesRawForTest([
        {
          'domain': '.example.com',
          'name': 'session',
          'value': 'abc',
          'path': '/',
        },
      ]);

      final ok =
          await BrowserCookieService.deleteCookie('.example.com', 'session');
      expect(ok, isTrue);
      expect(await BrowserCookieService.getCookiesFromFile(), isEmpty);
    });

    test('empty name returns false and keeps the store', () async {
      await BrowserCookieService.persistCookiesRawForTest([
        {'domain': 'example.com', 'name': 'session', 'value': 'abc'},
      ]);

      final ok = await BrowserCookieService.deleteCookie('example.com', '');
      expect(ok, isFalse);
      expect(await BrowserCookieService.getCookiesFromFile(), isNotEmpty);
    });
  });

  // ====================================================================
  // clearCookiesForDomain — persisted store side (test mode)
  // ====================================================================

  group('clearCookiesForDomain', () {
    test('removes all persisted cookies for the domain', () async {
      await BrowserCookieService.persistCookiesRawForTest([
        {
          'domain': 'example.com',
          'name': 'session',
          'value': 'abc',
          'path': '/',
        },
        {
          'domain': 'example.com',
          'name': 'pref',
          'value': 'dark',
          'path': '/',
        },
        {
          'domain': 'other.org',
          'name': 'keep',
          'value': 'me',
          'path': '/',
        },
      ]);

      final ok = await BrowserCookieService.clearCookiesForDomain(
          '.example.com');
      expect(ok, isTrue);

      final cookies = await BrowserCookieService.getCookiesFromFile();
      expect(cookies.containsKey('example.com'), isFalse);
      expect(cookies.containsKey('other.org'), isTrue);
    });
  });

  // ====================================================================
  // clearAllCookies
  // ====================================================================

  group('clearAllCookies', () {
    test('clears the persisted store and calls the platform delete-all',
        () async {
      final fake = _FakeCookiePlatform();
      BrowserCookieService.cookiePlatform = fake;
      await BrowserCookieService.persistCookiesRawForTest([
        {'domain': 'example.com', 'name': 'session', 'value': 'abc'},
      ]);
      expect(await BrowserCookieService.getCookiesFromFile(), isNotEmpty);

      final ok = await BrowserCookieService.clearAllCookies();
      expect(ok, isTrue);
      expect(fake.deleteAllCookiesCalls, 1);
      expect(await BrowserCookieService.getCookiesFromFile(), isEmpty);
    });
  });

  // ====================================================================
  // restoreCookiesFromFile — test mode must not touch the store
  // ====================================================================

  group('restoreCookiesFromFile', () {
    test('does not modify the persisted store in test mode', () async {
      await BrowserCookieService.setRetentionMode(true);
      await BrowserCookieService.persistCookiesRawForTest([
        {'domain': 'example.com', 'name': 'session', 'value': 'abc'},
      ]);

      await BrowserCookieService.restoreCookiesFromFile();
      expect(await BrowserCookieService.getCookiesFromFile(), isNotEmpty);
    });

    test('does nothing when retention is disabled', () async {
      await BrowserCookieService.setRetentionMode(false);
      await BrowserCookieService.persistCookiesRawForTest([
        {'domain': 'example.com', 'name': 'session', 'value': 'abc'},
      ]);

      // No platform cookie store exists in test mode; the call must simply
      // no-op without throwing.
      await BrowserCookieService.restoreCookiesFromFile();
    });
  });

  // ====================================================================
  // getCookiesGrouped — platform merge (via fake CookiePlatform)
  // ====================================================================

  group('getCookiesGrouped platform merge', () {
    test(
        'partial (fallback) snapshots merge: platform wins per key, '
        'file-only entries kept', () async {
      // On platforms without getAllCookies the per-domain snapshot is
      // partial — the file is merged in so unvisited domains stay visible.
      final fake = _FakeCookiePlatform()..throwOnGetAll = true;
      BrowserCookieService.cookiePlatform = fake;
      BrowserCookieService.noteVisitedUrl('https://example.com/');
      fake.perUrlCookies['https://example.com'] = [
        Cookie(name: 'session', value: 'new', domain: 'example.com', path: '/'),
      ];
      await BrowserCookieService.persistCookiesRawForTest([
        {
          'domain': 'example.com',
          'name': 'session',
          'value': 'old',
          'path': '/',
        },
        {
          'domain': 'old-site.org',
          'name': 'keep',
          'value': 'me',
          'path': '/',
        },
      ]);

      final result = await BrowserCookieService.getCookiesGrouped();

      // Platform (fresh) value wins for the same domain/name/path.
      expect(result['example.com']!.first['value'], 'new');
      // File entries for domains not visited this session are kept.
      expect(result['old-site.org']!.first['name'], 'keep');
    });

    test(
        'falls back to per-domain enumeration when getAllCookies is unsupported '
        'and stamps null domains with the visited host', () async {
      final fake = _FakeCookiePlatform()..throwOnGetAll = true;
      BrowserCookieService.cookiePlatform = fake;
      BrowserCookieService.noteVisitedUrl('https://cdn.example.com/v.mp4');
      fake.perUrlCookies['https://cdn.example.com'] = [
        // Host-only cookie: platform reports no domain → must be stamped.
        Cookie(name: 'session', value: 'abc'),
        Cookie(name: 'theme', value: 'dark', domain: '.example.com', path: '/'),
      ];

      final result = await BrowserCookieService.getCookiesGrouped();

      expect(result.containsKey('cdn.example.com'), isTrue,
          reason: 'host-only cookies must be grouped under the visited host');
      expect(result['cdn.example.com']!.first['name'], 'session');
      expect(result['cdn.example.com']!.first['domain'], 'cdn.example.com');
      // Genuine domain cookies keep their own leading-dot domain.
      expect(result.containsKey('.example.com'), isTrue);
    });

    test(
        'falls back to the file store when getAllCookies throws an '
        'unexpected error', () async {
      final fake = _FakeCookiePlatform()..throwOtherErrorOnGetAll = true;
      BrowserCookieService.cookiePlatform = fake;
      await BrowserCookieService.persistCookiesRawForTest([
        {'domain': 'example.com', 'name': 'session', 'value': 'abc'},
      ]);

      final result = await BrowserCookieService.getCookiesGrouped();

      // A non-UnimplementedError is a platform failure, not an authoritative
      // empty snapshot — the persisted store must be shown unchanged.
      expect(result['example.com']!.first['name'], 'session');
    });
  });

  // ====================================================================
  // restoreCookiesFromFile — validation via fake CookiePlatform
  // ====================================================================

  group('restoreCookiesFromFile validation', () {
    test('restores valid cookies with exact domain/path; skips invalid ones',
        () async {
      final fake = _FakeCookiePlatform();
      BrowserCookieService.cookiePlatform = fake;
      await BrowserCookieService.setRetentionMode(true);
      await BrowserCookieService.persistCookiesRawForTest([
        {
          'domain': '.example.com',
          'name': 'domain_cookie',
          'value': 'v1',
          'path': '/api',
        },
        {
          'domain': 'example.com',
          'name': 'host_cookie',
          'value': 'v2',
          'path': '/',
        },
        // Invalid entries must be skipped without aborting the rest.
        {
          'domain': 'example.com',
          'name': 'no_value',
          'value': null,
          'path': '/',
        },
        {
          'domain': 'example.com',
          'name': 'bad_value',
          'value': 'a;b',
          'path': '/',
        },
        {'domain': 'example.com', 'name': '', 'value': 'x', 'path': '/'},
        // Empty values are legitimate ("name=" presence cookies).
        {
          'domain': 'example.com',
          'name': 'empty_value',
          'value': '',
          'path': '/',
        },
      ]);

      await BrowserCookieService.restoreCookiesFromFile();

      final names =
          fake.setCookieCalls.map((c) => c['name']).toList();
      expect(
          names, containsAll(['domain_cookie', 'host_cookie', 'empty_value']));
      expect(names, isNot(contains('no_value')));
      expect(names, isNot(contains('bad_value')));

      // Leading-dot domain keeps the Domain attribute; host-only cookies are
      // restored without one.
      final domainCall = fake.setCookieCalls
          .firstWhere((c) => c['name'] == 'domain_cookie');
      expect(domainCall['domain'], '.example.com');
      expect(domainCall['path'], '/api');
      expect(domainCall['url'], 'https://example.com');
      final hostCall =
          fake.setCookieCalls.firstWhere((c) => c['name'] == 'host_cookie');
      expect(hostCall['domain'], isNull);
    });
  });

  // ====================================================================
  // persistCookiesToFile — fallback path merge (via fake CookiePlatform)
  // ====================================================================

  group('persistCookiesToFile fallback merge', () {
    test('merges with the existing file so unvisited domains survive',
        () async {
      final fake = _FakeCookiePlatform()..throwOnGetAll = true;
      BrowserCookieService.cookiePlatform = fake;
      await BrowserCookieService.setRetentionMode(true);

      // Cookies persisted in an earlier session for a domain not visited
      // in this one.
      await BrowserCookieService.persistCookiesRawForTest([
        {'domain': 'old-site.org', 'name': 'keep', 'value': 'me', 'path': '/'},
      ]);

      BrowserCookieService.noteVisitedUrl('https://new-site.com/');
      fake.perUrlCookies['https://new-site.com'] = [
        Cookie(name: 'session', value: 'abc', domain: 'new-site.com', path: '/'),
      ];

      await BrowserCookieService.persistCookiesToFile();

      final stored = await BrowserCookieService.getCookiesFromFile();
      expect(stored.containsKey('new-site.com'), isTrue,
          reason: 'freshly collected cookies must be persisted');
      expect(stored.containsKey('old-site.org'), isTrue,
          reason: 'domains not visited this session must not be dropped');
    });

    test('authoritative snapshot replaces the file (deleted cookies stay deleted)',
        () async {
      // getAllCookies succeeded → the snapshot is complete; file entries
      // for cookies the site deleted or that expired must NOT resurface.
      final fake = _FakeCookiePlatform();
      BrowserCookieService.cookiePlatform = fake;
      await BrowserCookieService.setRetentionMode(true);
      await BrowserCookieService.persistCookiesRawForTest([
        {'domain': 'gone.com', 'name': 'old', 'value': 'x', 'path': '/'},
      ]);
      fake.allCookies = [
        Cookie(name: 'session', value: 'new', domain: 'example.com', path: '/'),
      ];

      await BrowserCookieService.persistCookiesToFile();

      final stored = await BrowserCookieService.getCookiesFromFile();
      expect(stored.containsKey('gone.com'), isFalse,
          reason: 'cookies missing from the authoritative snapshot must not '
              'resurrect from the file');
      expect(stored.containsKey('example.com'), isTrue);
    });

    test('authoritative snapshot is shown as-is by getCookiesGrouped',
        () async {
      final fake = _FakeCookiePlatform();
      BrowserCookieService.cookiePlatform = fake;
      fake.allCookies = [
        Cookie(name: 'session', value: 'new', domain: 'example.com', path: '/'),
      ];
      await BrowserCookieService.persistCookiesRawForTest([
        {'domain': 'stale.com', 'name': 'old', 'value': 'x', 'path': '/'},
      ]);

      final result = await BrowserCookieService.getCookiesGrouped();

      expect(result.containsKey('stale.com'), isFalse,
          reason: 'file-only entries must not appear when the platform '
              'snapshot is authoritative');
      expect(result['example.com']!.first['value'], 'new');
    });

    test(
        'authoritative EMPTY snapshot shows nothing (deleted cookies do not '
        'resurface from the file)', () async {
      // The user cleared all cookies on the platform (site JS / expiry);
      // the successful-but-empty snapshot is still authoritative and the
      // stale file must not be merged in.
      final fake = _FakeCookiePlatform();
      BrowserCookieService.cookiePlatform = fake;
      fake.allCookies = [];
      await BrowserCookieService.persistCookiesRawForTest([
        {'domain': 'gone.com', 'name': 'old', 'value': 'x', 'path': '/'},
      ]);

      final result = await BrowserCookieService.getCookiesGrouped();
      expect(result, isEmpty);

      // The next persist with the authoritative empty snapshot wipes the
      // file, so the deletion sticks.
      await BrowserCookieService.setRetentionMode(true);
      await BrowserCookieService.persistCookiesToFile();
      expect(await BrowserCookieService.getCookiesFromFile(), isEmpty);
    });

    test('does not enumerate nor clobber the file when nothing is known',
        () async {
      final fake = _FakeCookiePlatform()..throwOnGetAll = true;
      // Reset visited-domain tracking so no host from earlier tests leaks in.
      BrowserCookieService.enableTestMode();
      BrowserCookieService.cookiePlatform = fake;
      await BrowserCookieService.setRetentionMode(true);
      await BrowserCookieService.persistCookiesRawForTest([
        {'domain': 'example.com', 'name': 'session', 'value': 'abc'},
      ]);

      await BrowserCookieService.persistCookiesToFile();

      // With no visited domains the per-domain fallback must not make any
      // platform calls.
      expect(fake.getCookiesCalls, 0);
      // And the existing file must be left untouched.
      expect(await BrowserCookieService.getCookiesFromFile(), isNotEmpty);
    });
  });

  // ====================================================================
  // Platform delete forwarding (via fake CookiePlatform)
  // ====================================================================

  group('platform delete forwarding', () {
    test('deleteCookie forwards path and leading-dot domain', () async {
      final fake = _FakeCookiePlatform();
      BrowserCookieService.cookiePlatform = fake;

      final ok = await BrowserCookieService.deleteCookie(
          '.example.com', 'session',
          path: '/api');
      expect(ok, isTrue);

      expect(fake.deleteCookieCalls.length, 2);
      expect(fake.deleteCookieCalls[0]['url'], 'https://example.com');
      expect(fake.deleteCookieCalls[0]['domain'], '.example.com');
      expect(fake.deleteCookieCalls[0]['path'], '/api');
      expect(fake.deleteCookieCalls[1]['url'], 'http://example.com');
    });

    test('host-only cookie deletion passes no domain attribute', () async {
      final fake = _FakeCookiePlatform();
      BrowserCookieService.cookiePlatform = fake;

      await BrowserCookieService.deleteCookie('example.com', 'session');
      expect(fake.deleteCookieCalls.first['domain'], isNull);
    });

    test(
        'clearCookiesForDomain expires host-only and domain cookies over '
        'both schemes', () async {
      final fake = _FakeCookiePlatform();
      BrowserCookieService.cookiePlatform = fake;

      await BrowserCookieService.clearCookiesForDomain('example.com');

      expect(fake.deleteCookiesCalls.length, 4);
      final combos = fake.deleteCookiesCalls
          .map((c) => '${c['url']}|${c['domain']}')
          .toList();
      expect(combos, containsAll([
        'https://example.com|null',
        'https://example.com|.example.com',
        'http://example.com|null',
        'http://example.com|.example.com',
      ]));
    });
  });
}
