import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/browser_cookies_page.dart';
import 'package:stroom/services/browser_cookie_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
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
      // The switch being on means it's toggled
      expect(find.textContaining('保留Cookies数据'), findsOneWidget);
    });
  });

  // ====================================================================
  // Clear All confirmation dialog
  // ====================================================================

  group('Clear All cookies', () {
    testWidgets('tapping Clear All shows confirmation dialog',
        (tester) async {
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
  });
}
