import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/services/browser_cookie_service.dart';

// Note: Full BrowserPage widget tests require platform-native InAppWebView
// which cannot run in unit test mode. These tests verify the cookie lifecycle
// that BrowserPage drives through BrowserCookieService:
//   1. visited-domain tracking (feeds per-domain persistence on platforms
//      without CookieManager.getAllCookies),
//   2. the restore-on-create path,
//   3. the dispose path (persist when retention is enabled, clear when not).

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

    test('toggle driven by the AppBar button persists across reads', () async {
      final newValue = await BrowserCookieService.toggleRetentionMode();
      expect(newValue, isTrue);
      expect(await BrowserCookieService.getRetentionMode(), isTrue);
    });
  });
}
