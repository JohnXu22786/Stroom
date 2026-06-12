import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:stroom/pages/home_page.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/text_manifest.dart';

/// A GlobalKey for the outer [Navigator] so tests can trigger [Navigator.maybePop]
/// to simulate the Android system back button, which is intercepted by [PopScope]
/// in [HomePage].
final _navigatorKey = GlobalKey<NavigatorState>();

/// Build a test app that wraps [HomePage] inside a [Navigator] route, so that
/// the system back button (simulated via [_navigatorKey]) triggers [PopScope].
Widget _buildTestApp({Size? screenSize}) {
  final app = ProviderScope(
    child: MaterialApp(
      home: Navigator(
        key: _navigatorKey,
        onGenerateRoute: (settings) {
          return MaterialPageRoute(
            builder: (_) => const HomePage(),
            settings: settings,
          );
        },
      ),
      localizationsDelegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
    ),
  );
  if (screenSize != null) {
    return MediaQuery(
      data: MediaQueryData(size: screenSize),
      child: app,
    );
  }
  return app;
}

/// Helper: simulate the system back button by calling [Navigator.maybePop].
Future<void> _simulateBackButton(WidgetTester tester) async {
  await _navigatorKey.currentState?.maybePop();
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    TextManifest.invalidateCache();
  });

  group('Main page navigation (4 buttons, state preservation)', () {
    testWidgets('renders four nav destinations on mobile, no plus button', (tester) async {
      // Use mobile width so bottom nav bar is shown
      await tester.pumpWidget(_buildTestApp(screenSize: const Size(390, 844)));
      await tester.pumpAndSettle();

      // Bottom nav bar should contain exactly the 4 main destinations
      expect(find.text('主页'), findsOneWidget);
      expect(find.text('对话'), findsOneWidget);
      expect(find.text('文件'), findsOneWidget);
      expect(find.text('设置'), findsOneWidget);

      // No plus button should exist
      expect(find.byIcon(Icons.add), findsNothing);

      // Home page content should be visible by default
      expect(find.text('欢迎使用 Stroom'), findsOneWidget);
    });

    testWidgets('tapping nav bar items switches pages', (tester) async {
      await tester.pumpWidget(_buildTestApp(screenSize: const Size(390, 844)));
      await tester.pumpAndSettle();

      // Default: home page
      expect(find.text('欢迎使用 Stroom'), findsOneWidget);

      // Tap "文件" in nav bar to go to Files page
      await tester.tap(find.text('文件'));
      await tester.pumpAndSettle();

      // Should see Files page content
      expect(find.text('文件'), findsWidgets);

      // Tap "设置" in nav bar to go to Settings page
      await tester.tap(find.text('设置'));
      await tester.pumpAndSettle();

      // Should see Settings page content
      expect(find.text('设置'), findsWidgets);

      // Tap "主页" in nav bar to go back to Home
      await tester.tap(find.text('主页'));
      await tester.pumpAndSettle();

      expect(find.text('欢迎使用 Stroom'), findsOneWidget);
    });

    testWidgets('horizontal swipe does NOT change main page',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(screenSize: const Size(390, 844)));
      await tester.pumpAndSettle();

      // Verify we start on home page
      expect(find.text('欢迎使用 Stroom'), findsOneWidget);

      // Attempt to swipe left (which would normally go to Chat page with PageView)
      await tester.drag(
        find.byType(HomePage),
        const Offset(-300, 0),
      );
      await tester.pumpAndSettle();

      // Should still be on home page — swipe had no effect
      expect(find.text('欢迎使用 Stroom'), findsOneWidget);

      // Try a fast fling left
      await tester.fling(
        find.byType(HomePage),
        const Offset(-500, 0),
        1000,
      );
      await tester.pumpAndSettle();

      // Should still be on home page
      expect(find.text('欢迎使用 Stroom'), findsOneWidget);

      // Try swiping right too
      await tester.fling(
        find.byType(HomePage),
        const Offset(500, 0),
        1000,
      );
      await tester.pumpAndSettle();

      // Should still be on home page
      expect(find.text('欢迎使用 Stroom'), findsOneWidget);
    });

    testWidgets('back from Files page returns to Home',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(screenSize: const Size(390, 844)));
      await tester.pumpAndSettle();

      // Navigate to Files via nav bar
      await tester.tap(find.text('文件'));
      await tester.pumpAndSettle();

      // Verify on Files page
      expect(find.text('文件'), findsWidgets);

      // Simulate system back
      await _simulateBackButton(tester);

      // Should return to Home
      expect(find.text('欢迎使用 Stroom'), findsOneWidget);
    });

    testWidgets('back from Settings page returns to Home',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(screenSize: const Size(390, 844)));
      await tester.pumpAndSettle();

      // Navigate to Settings via nav bar
      await tester.tap(find.text('设置'));
      await tester.pumpAndSettle();

      // Simulate system back
      await _simulateBackButton(tester);

      // Should return to Home
      expect(find.text('欢迎使用 Stroom'), findsOneWidget);
    });

    testWidgets('back from Home page does not pop the app (stays on Home)',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(screenSize: const Size(390, 844)));
      await tester.pumpAndSettle();

      // We're on home page with empty history
      expect(find.text('欢迎使用 Stroom'), findsOneWidget);

      // Simulate system back — should NOT pop the route
      await _simulateBackButton(tester);

      // Should still be on home page (not popped)
      expect(find.text('欢迎使用 Stroom'), findsOneWidget);

      // HomePage should still be displayed (the outer navigator did not pop it)
      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets('hierarchical back: Home→Chat→Files→Back→Home, not Chat',
        (tester) async {
      // The back button should navigate to the parent page (Home),
      // not the previously visited tab (Chat).
      await tester.pumpWidget(_buildTestApp(screenSize: const Size(390, 844)));
      await tester.pumpAndSettle();

      // Start on Home
      expect(find.text('欢迎使用 Stroom'), findsOneWidget);

      // Go to Chat
      await tester.tap(find.text('对话'));
      await tester.pumpAndSettle();
      expect(find.text('选择助手'), findsOneWidget);

      // Go to Files
      await tester.tap(find.text('文件'));
      await tester.pumpAndSettle();
      expect(find.text('文件'), findsWidgets);

      // Press back — should go to Home (parent), NOT Chat (previous step)
      await _simulateBackButton(tester);
      expect(find.text('欢迎使用 Stroom'), findsOneWidget);
    });

    testWidgets('hierarchical back: Home→Chat→Files→Settings→Back→Home',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(screenSize: const Size(390, 844)));
      await tester.pumpAndSettle();

      // Go through multiple tabs
      await tester.tap(find.text('对话'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('文件'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('设置'));
      await tester.pumpAndSettle();
      expect(find.text('设置'), findsWidgets);

      // Press back — should go to Home (parent), not Files (previous step)
      await _simulateBackButton(tester);
      expect(find.text('欢迎使用 Stroom'), findsOneWidget);
    });

    testWidgets('double-tap Chat tab stays on assistant selection (already at home)',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(screenSize: const Size(390, 844)));
      await tester.pumpAndSettle();

      // First tap: go to Chat
      await tester.tap(find.text('对话'));
      await tester.pumpAndSettle();
      expect(find.text('选择助手'), findsOneWidget);

      // Second tap on same Chat tab: stay at assistant selection (already at home)
      await tester.tap(find.text('对话'));
      await tester.pumpAndSettle();
      expect(find.text('选择助手'), findsOneWidget);
    });

    testWidgets('chat state preserved when switching away and back',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(screenSize: const Size(390, 844)));
      await tester.pumpAndSettle();

      // Enter chat page
      await tester.tap(find.text('对话'));
      await tester.pumpAndSettle();
      expect(find.text('选择助手'), findsOneWidget);

      // Switch to files
      await tester.tap(find.text('文件'));
      await tester.pumpAndSettle();
      expect(find.text('文件'), findsWidgets);

      // Switch back to chat - should still show assistant selection (state preserved)
      // Since we never navigated deeper into chat, it should still show assistant selection
      await tester.tap(find.text('对话'));
      await tester.pumpAndSettle();
      expect(find.text('选择助手'), findsOneWidget);
    });

    testWidgets('home page module cards still work after navigation changes',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(screenSize: const Size(390, 844)));
      await tester.pumpAndSettle();

      // Verify OCR module card is tappable
      expect(find.text('OCR'), findsOneWidget);
      await tester.tap(find.text('OCR'));
      await tester.pumpAndSettle();

      // Should navigate to OCR page
      expect(find.text('文字识别'), findsOneWidget);
    });
  });
}
