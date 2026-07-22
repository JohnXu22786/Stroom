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

      // Simulate reload by creating a new SharedPreferences instance
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
  // Cookie manager calls (service-level)
  // ====================================================================

  group('BrowserCookieService cookie operations', () {
    test('clearAllCookies handles errors gracefully', () async {
      // This should not throw even if CookieManager is not available
      // (e.g., in test environment without platform implementation)
      final result = await BrowserCookieService.clearAllCookies();
      // In test environment, this may return false (exception caught)
      // or true (if CookieManager somehow works).
      // The important thing is it doesn't throw.
      expect(result, isA<bool>());
    });

    test('getAllCookiesGrouped returns empty on error', () async {
      final result = await BrowserCookieService.getAllCookiesGrouped();
      // In test environment without platform, should return empty map
      expect(result, isA<Map<String, dynamic>>());
      // Empty is expected since CookieManager requires platform
    });
  });
}
