import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/browser_page.dart';
import 'package:stroom/services/browser_cookie_service.dart';

// Note: Full BrowserPage widget tests require platform-native InAppWebView
// which cannot run in unit test mode. These tests verify the cookie lifecycle
// that BrowserPage drives through BrowserCookieService:
//   1. visited-domain tracking (feeds per-domain persistence on platforms
//      without CookieManager.getAllCookies),
//   2. the restore-on-create path,
//   3. the dispose path (persist when retention is enabled, clear when not).

class _RecordingCookiePlatform implements CookiePlatform {
  final events = <String>[];
  final nativeCookieNames = <String>{'stale-session'};
  bool deleteAllSucceeds = true;

  @override
  Future<List<Cookie>> getAllCookies() async => [];

  @override
  Future<List<Cookie>> getCookies({required WebUri url}) async => [];

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
    events.add('restore:$name');
    nativeCookieNames.add(name);
    return true;
  }

  @override
  Future<bool> deleteCookie({
    required WebUri url,
    required String name,
    String path = '/',
    String? domain,
  }) async =>
      true;

  @override
  Future<bool> deleteCookies({
    required WebUri url,
    String path = '/',
    String? domain,
  }) async =>
      true;

  @override
  Future<bool> deleteAllCookies() async {
    events.add('clear-native');
    if (deleteAllSucceeds) nativeCookieNames.clear();
    return deleteAllSucceeds;
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
  // Visited-domain tracking (called from BrowserPage.onLoadStop)
  // ====================================================================

  group('noteVisitedUrl (BrowserPage.onLoadStop)', () {
    test('records the host of an https URL', () async {
      BrowserCookieService.noteVisitedUrl('https://m.example.com/a/b?c=1');
      expect(BrowserCookieService.visitedDomainsForTest,
          contains('m.example.com'));
    });

    test('strips the port from the recorded host', () async {
      BrowserCookieService.noteVisitedUrl('https://example.com:8080/page');
      expect(
          BrowserCookieService.visitedDomainsForTest, contains('example.com'));
    });

    test('deduplicates repeated visits', () async {
      BrowserCookieService.noteVisitedUrl('https://example.com/1');
      BrowserCookieService.noteVisitedUrl('https://example.com/2');
      expect(BrowserCookieService.visitedDomainsForTest.length, 1);
    });

    test('ignores URLs without a host (about:, data:, invalid)', () async {
      BrowserCookieService.noteVisitedUrl('about:blank');
      BrowserCookieService.noteVisitedUrl('data:text/plain,hello');
      BrowserCookieService.noteVisitedUrl('not a url');
      expect(BrowserCookieService.visitedDomainsForTest, isEmpty);
    });

    test('caps the tracked host set to avoid unbounded growth', () async {
      for (var i = 0; i < BrowserCookieService.maxVisitedDomains + 10; i++) {
        BrowserCookieService.noteVisitedUrl('https://site$i.example.com/');
      }
      expect(
        BrowserCookieService.visitedDomainsForTest.length,
        BrowserCookieService.maxVisitedDomains,
      );
    });

    test('revisiting a tracked host refreshes its recency', () async {
      // Fill the set to capacity.
      for (var i = 0; i < BrowserCookieService.maxVisitedDomains; i++) {
        BrowserCookieService.noteVisitedUrl('https://site$i.example.com/');
      }
      // Revisit the OLDEST host — it must move to the most-recent position.
      BrowserCookieService.noteVisitedUrl('https://site0.example.com/');
      // Insert a brand-new host at capacity — the oldest host (site1) is
      // evicted, and the revisited site0 survives.
      BrowserCookieService.noteVisitedUrl('https://brand-new.example.com/');

      final tracked = BrowserCookieService.visitedDomainsForTest;
      expect(tracked.contains('site0.example.com'), isTrue,
          reason: 'a revisited host must not be evicted by the next insert');
      expect(tracked.contains('site1.example.com'), isFalse,
          reason: 'the oldest never-revisited host is the one evicted');
      expect(tracked.length, BrowserCookieService.maxVisitedDomains);
    });
  });

  // ====================================================================
  // Restore-on-create path (BrowserPage.onWebViewCreated)
  // ====================================================================

  group('restoreCookiesFromFile (on WebView create)', () {
    test('leaves the persisted store intact so it can be restored later',
        () async {
      await BrowserCookieService.setRetentionMode(true);
      await BrowserCookieService.persistCookiesRawForTest([
        {'domain': 'example.com', 'name': 'session', 'value': 'abc'},
      ]);

      await BrowserCookieService.restoreCookiesFromFile();
      expect(await BrowserCookieService.getCookiesFromFile(), isNotEmpty);
    });
  });

  // ====================================================================
  // Initial navigation cookie preparation (BrowserPage.onWebViewCreated)
  // ====================================================================

  group('first navigation cookie preparation', () {
    test('disabled retention clears native cookies before navigation',
        () async {
      await BrowserCookieService.setRetentionMode(false);
      await BrowserCookieService.persistCookiesRawForTest([
        {'domain': 'example.com', 'name': 'old-session', 'value': 'stale'},
      ]);
      final platform = _RecordingCookiePlatform();
      BrowserCookieService.cookiePlatform = platform;

      final navigated = await navigateBrowserPageAfterCookiePreparation(
        prepareCookies: BrowserCookieService.prepareForBrowserPageLoad,
        loadUrl: () async {
          platform.events.add('navigate');
          expect(platform.nativeCookieNames, isEmpty);
        },
      );

      expect(navigated, isTrue);
      expect(platform.events, ['clear-native', 'navigate']);
      expect(await BrowserCookieService.getCookiesFromFile(), isEmpty);
    });

    test('failed native cleanup prevents the first navigation', () async {
      await BrowserCookieService.setRetentionMode(false);
      final platform = _RecordingCookiePlatform()..deleteAllSucceeds = false;
      BrowserCookieService.cookiePlatform = platform;

      final navigated = await navigateBrowserPageAfterCookiePreparation(
        prepareCookies: BrowserCookieService.prepareForBrowserPageLoad,
        loadUrl: () async => platform.events.add('navigate'),
      );

      expect(navigated, isFalse);
      expect(platform.nativeCookieNames, contains('stale-session'));
      expect(platform.events, ['clear-native']);

      platform.deleteAllSucceeds = true;
      final retriedNavigation = await navigateBrowserPageAfterCookiePreparation(
        prepareCookies: BrowserCookieService.prepareForBrowserPageLoad,
        loadUrl: () async => platform.events.add('navigate'),
      );

      expect(retriedNavigation, isTrue);
      expect(platform.nativeCookieNames, isEmpty);
      expect(platform.events, ['clear-native', 'clear-native', 'navigate']);
    });

    test('enabled retention restores cookies before navigation', () async {
      await BrowserCookieService.setRetentionMode(true);
      await BrowserCookieService.persistCookiesRawForTest([
        {'domain': 'example.com', 'name': 'saved-session', 'value': 'kept'},
      ]);
      final platform = _RecordingCookiePlatform();
      BrowserCookieService.cookiePlatform = platform;

      final navigated = await navigateBrowserPageAfterCookiePreparation(
        prepareCookies: BrowserCookieService.prepareForBrowserPageLoad,
        loadUrl: () async {
          platform.events.add('navigate');
          expect(platform.nativeCookieNames,
              containsAll(['stale-session', 'saved-session']));
        },
      );

      expect(navigated, isTrue);
      expect(platform.events, ['restore:saved-session', 'navigate']);
    });
  });

  // ====================================================================
  // Dispose path (BrowserPage.dispose)
  // ====================================================================

  group('dispose-time cookie handling', () {
    test('retention disabled → clearAllCookies wipes the persisted store',
        () async {
      await BrowserCookieService.setRetentionMode(false);
      await BrowserCookieService.persistCookiesRawForTest([
        {'domain': 'example.com', 'name': 'session', 'value': 'abc'},
      ]);

      final ok = await BrowserCookieService.clearAllCookies();
      expect(ok, isTrue);
      expect(await BrowserCookieService.getCookiesFromFile(), isEmpty);
    });

    test('retention enabled → persisted cookies survive', () async {
      await BrowserCookieService.setRetentionMode(true);
      await BrowserCookieService.persistCookiesRawForTest([
        {'domain': 'example.com', 'name': 'session', 'value': 'abc'},
      ]);

      // The persist path (persistCookiesToFile) is a no-op in test mode
      // (no platform cookie store); the stored data must not be clobbered.
      await BrowserCookieService.persistCookiesToFile();
      expect(await BrowserCookieService.getCookiesFromFile(), isNotEmpty);
    });

    test('close cleanup uses a retention toggle that is still in flight',
        () async {
      await BrowserCookieService.setRetentionMode(false);
      await BrowserCookieService.persistCookiesRawForTest([
        {'domain': 'example.com', 'name': 'session', 'value': 'abc'},
      ]);

      final pendingToggle = BrowserCookieService.toggleRetentionMode();
      final closeCleanup = BrowserCookieService.handleBrowserClose();

      await Future.wait([pendingToggle, closeCleanup]);

      expect(await BrowserCookieService.getRetentionMode(), isTrue);
      expect(await BrowserCookieService.getCookiesFromFile(), isNotEmpty);
    });

    test('close cleanup waits for a direct retention update', () async {
      await BrowserCookieService.setRetentionMode(false);
      await BrowserCookieService.persistCookiesRawForTest([
        {'domain': 'example.com', 'name': 'session', 'value': 'abc'},
      ]);

      final pendingUpdate = BrowserCookieService.setRetentionMode(true);
      final closeCleanup = BrowserCookieService.handleBrowserClose();

      await Future.wait([pendingUpdate, closeCleanup]);

      expect(await BrowserCookieService.getRetentionMode(), isTrue);
      expect(await BrowserCookieService.getCookiesFromFile(), isNotEmpty);
    });

    test('toggle driven by the AppBar button persists across reads', () async {
      final newValue = await BrowserCookieService.toggleRetentionMode();
      expect(newValue, isTrue);
      expect(await BrowserCookieService.getRetentionMode(), isTrue);
    });
  });
}
