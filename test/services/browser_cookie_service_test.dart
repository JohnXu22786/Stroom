import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/services/browser_cookie_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
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
}
