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
    testWidgets('retention toggle is off when the preference is false',
        (tester) async {
      await BrowserCookieService.setRetentionMode(false);

      await tester.pumpWidget(
        const MaterialApp(home: BrowserCookiesPage()),
      );
      await tester.pumpAndSettle();

      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, isFalse);
    });

    testWidgets('retention toggle is on when the preference is true',
        (tester) async {
      await BrowserCookieService.setRetentionMode(true);

      await tester.pumpWidget(
        const MaterialApp(home: BrowserCookiesPage()),
      );
      await tester.pumpAndSettle();

      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, isTrue);
    });

    testWidgets('toggling the switch updates the stored preference',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: BrowserCookiesPage()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(await BrowserCookieService.getRetentionMode(), isTrue);
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
    testWidgets('delete domain cookies removes the domain card',
        (tester) async {
      await BrowserCookieService.persistCookiesRawForTest([
        {
          'domain': 'example.com',
          'name': 'session',
          'value': 'abc',
          'path': '/',
        },
        {
          'domain': 'keep.org',
          'name': 'pref',
          'value': 'dark',
          'path': '/',
        },
      ]);

      await tester.pumpWidget(
        const MaterialApp(home: BrowserCookiesPage()),
      );
      await tester.pumpAndSettle();

      // Delete the example.com group. The delete button is identified by its
      // tooltip scoped to the example.com card (the tooltip alone matches
      // every domain card).
      await tester.tap(
        find.descendant(
          of: find.ancestor(
            of: find.text('example.com'),
            matching: find.byType(Card),
          ),
          matching: find.byTooltip('清除此域名下的所有Cookies'),
        ),
      );
      await tester.pumpAndSettle();

      // Confirmation dialog
      expect(find.textContaining('确定要清除 example.com'), findsOneWidget);
      await tester.tap(find.text('清除'));
      await tester.pumpAndSettle();

      // example.com card is gone; keep.org is still there; store updated.
      expect(find.text('example.com'), findsNothing);
      expect(find.text('keep.org'), findsOneWidget);
      final cookies = await BrowserCookieService.getCookiesFromFile();
      expect(cookies.containsKey('example.com'), isFalse);
      expect(cookies.containsKey('keep.org'), isTrue);
    });

    testWidgets('cancelling domain delete keeps the cookies', (tester) async {
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

      await tester.tap(find.byTooltip('清除此域名下的所有Cookies').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      expect(find.text('example.com'), findsOneWidget);
      expect(await BrowserCookieService.getCookiesFromFile(), isNotEmpty);
    });
  });

  // ====================================================================
  // Single-cookie deletion
  // ====================================================================

  group('Single cookie deletion', () {
    testWidgets('deleting one cookie removes it and keeps the rest',
        (tester) async {
      await BrowserCookieService.persistCookiesRawForTest([
        {
          'domain': 'example.com',
          'name': 'session',
          'value': 'abc',
          'path': '/',
        },
        {
          'domain': 'example.com',
          'name': 'theme',
          'value': 'dark',
          'path': '/',
        },
      ]);

      await tester.pumpWidget(
        const MaterialApp(home: BrowserCookiesPage()),
      );
      await tester.pumpAndSettle();

      // Both cookie rows render a per-cookie delete button.
      expect(find.byTooltip('删除此Cookie'), findsNWidgets(2));

      // Delete the first one (session). The tooltip finder returns them in
      // tree order; delete the first row's button.
      await tester.tap(find.byTooltip('删除此Cookie').first);
      await tester.pumpAndSettle();

      final cookies = await BrowserCookieService.getCookiesFromFile();
      final names = cookies['example.com']!.map((c) => c['name']).toList();
      expect(names, ['theme']);
      expect(find.byTooltip('删除此Cookie'), findsOneWidget);
    });

    testWidgets('cookie without a name shows no delete button', (tester) async {
      // Some platform cookies can lack a name; they cannot be deleted via
      // the platform API, so the row must not offer a dead delete button.
      await BrowserCookieService.persistCookiesRawForTest([
        {'domain': 'example.com', 'value': 'orphan'},
      ]);

      await tester.pumpWidget(
        const MaterialApp(home: BrowserCookiesPage()),
      );
      await tester.pumpAndSettle();

      expect(find.text('example.com'), findsOneWidget);
      expect(find.byTooltip('删除此Cookie'), findsNothing);
    });
  });
}
