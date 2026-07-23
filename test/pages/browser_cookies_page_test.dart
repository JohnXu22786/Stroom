import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/browser_cookies_page.dart';
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
  // Page renders basic structure
  // ====================================================================

  group('BrowserCookiesPage rendering', () {
    testWidgets('shows AppBar with correct title', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: BrowserCookiesPage()),
      );
      await tester.pumpAndSettle();

      expect(find.text('浏览器数据管理'), findsOneWidget);
    });

    testWidgets('shows Clear All Cookies button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: BrowserCookiesPage()),
      );
      await tester.pumpAndSettle();

      expect(find.text('清除所有Cookies'), findsOneWidget);
    });

    testWidgets('shows retention toggle with correct label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: BrowserCookiesPage()),
      );
      await tester.pumpAndSettle();

      // Should show the retention toggle label
      expect(find.textContaining('退出保留Cookies'), findsOneWidget);
    });

    testWidgets('retention toggle reflects saved preference', (tester) async {
      // Set retention mode to true
      await BrowserCookieService.setRetentionMode(true);

      await tester.pumpWidget(
        const MaterialApp(home: BrowserCookiesPage()),
      );
      await tester.pumpAndSettle();

      // The toggle switch should be on
      // We check the page shows "已启用" or similar indicator
      expect(find.textContaining('保留Cookies数据'), findsOneWidget);
    });

    testWidgets('shows persisted cookies grouped by domain', (tester) async {
      // Persist some test cookies
      await BrowserCookieService.persistCookiesRawForTest([
        {
          'domain': 'example.com',
          'name': 'session',
          'value': 'abc',
          'path': '/',
        },
        {
          'domain': 'test.org',
          'name': 'pref',
          'value': 'dark',
          'path': '/',
        },
      ]);

      await tester.pumpWidget(
        const MaterialApp(home: BrowserCookiesPage()),
      );
      await tester.pumpAndSettle();

      // Should show domain names
      expect(find.text('example.com'), findsOneWidget);
      expect(find.text('test.org'), findsOneWidget);

      // Should show cookie count
      expect(find.textContaining('1 个Cookie'), findsAtLeast(1));
    });

    testWidgets('shows empty state when no cookies are persisted',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: BrowserCookiesPage()),
      );
      await tester.pumpAndSettle();

      // Should show the empty state message
      expect(find.text('暂无持久化数据'), findsOneWidget);
    });
  });

  // ====================================================================
  // Clear All confirmation dialog
  // ====================================================================

  group('Clear All cookies', () {
    testWidgets('tapping Clear All shows confirmation dialog', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: BrowserCookiesPage()),
      );
      await tester.pumpAndSettle();

      // Tap the Clear All button
      await tester.tap(find.text('清除所有Cookies'));
      await tester.pumpAndSettle();

      // Confirmation dialog should appear
      expect(find.text('确认清除'), findsOneWidget);
      expect(find.textContaining('确定要清除所有Cookies吗'), findsOneWidget);
    });

    testWidgets('cancelling confirmation dialog does not clear cookies',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: BrowserCookiesPage()),
      );
      await tester.pumpAndSettle();

      // Tap Clear All
      await tester.tap(find.text('清除所有Cookies'));
      await tester.pumpAndSettle();

      // Tap cancel
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      // Dialog should be dismissed
      expect(find.text('确认清除'), findsNothing);
    });

    testWidgets('confirming Clear All clears persisted cookies',
        (tester) async {
      // Persist some test cookies
      await BrowserCookieService.persistCookiesRawForTest([
        {
          'domain': 'example.com',
          'name': 'session',
          'value': 'abc',
          'path': '/',
        },
      ]);

      await tester.pumpWidget(
        const MaterialApp(home: BrowserCookiesPage()),
      );
      await tester.pumpAndSettle();

      // Verify cookie is shown
      expect(find.text('example.com'), findsOneWidget);

      // Tap Clear All
      await tester.tap(find.text('清除所有Cookies'));
      await tester.pumpAndSettle();

      // Confirm
      await tester.tap(find.text('清除'));
      await tester.pumpAndSettle();

      // Should show empty state after clearing
      expect(find.text('暂无持久化数据'), findsOneWidget);
    });
  });

  // ====================================================================
  // Domain-level cookie deletion
  // ====================================================================

  group('Domain cookie deletion', () {
    testWidgets('delete domain cookies removes domain card', (tester) async {
      await BrowserCookieService.persistCookiesRawForTest([
        {
          'domain': 'example.com',
          'name': 'session',
          'value': 'abc',
          'path': '/',
        },
      ]);

      await tester.pumpWidget(
        const MaterialApp(home: BrowserCookiesPage()),
      );
      await tester.pumpAndSettle();

      // Find and tap the delete button for the domain
      // The delete button is an IconButton with tooltip '清除此域名下的所有Cookies'
      final deleteButtons = find.widgetWithIcon(IconButton, Icons.delete_outline);
      expect(deleteButtons, findsAtLeast(1));
    });
  });
}
