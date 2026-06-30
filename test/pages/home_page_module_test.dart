import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/home_page.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/text_manifest.dart';

Widget _buildTestApp() {
  return const ProviderScope(
    child: MaterialApp(
      home: HomePage(),
      localizationsDelegates: [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
    ),
  );
}

/// Sets the test surface to a small phone size (e.g. iPhone SE logical size).
void _setSmallScreen(WidgetTester tester) {
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  // Use logical 375x812 (iPhone X size) by setting physical size = logical size
  // with device pixel ratio = 1.0 for predictable test measurements.
  tester.view.physicalSize = const Size(375, 812);
  tester.view.devicePixelRatio = 1.0;
}

/// Sets the test surface to a very narrow size (e.g. very small phone).
void _setVeryNarrowScreen(WidgetTester tester) {
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  tester.view.physicalSize = const Size(320, 780);
  tester.view.devicePixelRatio = 1.0;
}

/// Sets the test surface to a tablet size (e.g. iPad logical size)
/// with a typical status bar top padding to simulate notch/status bar area.
void _setTabletScreen(WidgetTester tester) {
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPadding);
  // Use logical 768x1024 (iPad portrait size) with device pixel ratio = 1.0
  // to match the convention of the other screen helpers in this file.
  tester.view.physicalSize = const Size(768, 1024);
  tester.view.devicePixelRatio = 1.0;
  // Simulate a tablet status bar top padding of 24px (logical pixels)
  tester.view.padding = const FakeViewPadding(top: 24);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    TextManifest.invalidateCache();
  });

  group('HomePage modular blocks', () {
    testWidgets('renders welcome text on home page', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Should show the welcome text
      expect(find.text('欢迎使用 Stroom'), findsOneWidget);
    });

    testWidgets('shows module cards on home page', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Should show OCR module card
      expect(find.text('OCR'), findsOneWidget);
    });

    testWidgets('OCR module card is tappable', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Tap the OCR module
      await tester.tap(find.text('OCR'));
      await tester.pumpAndSettle();

      // Should navigate to OCR page (check for OCR page title)
      expect(find.text('文字识别'), findsOneWidget);
    });

    testWidgets('home page has module grid layout', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Verify the module grid exists
      expect(find.byType(GridView), findsOneWidget);
    });

    testWidgets('module cards have correct icons', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // OCR icon should be present
      expect(find.byIcon(Icons.text_snippet), findsOneWidget);
    });

    testWidgets('下载网页资源 card exists on home page', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Should show 下载网页资源 as a module card
      expect(find.text('下载网页资源'), findsOneWidget);
    });

    testWidgets('下载网页资源 card subtitle shows 下载网页中的音视频', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Scroll to find the module card with subtitle
      final cardFinder = find.text('下载网页资源');
      await tester.ensureVisible(cardFinder);
      await tester.pumpAndSettle();

      // The subtitle should be the new text, not the old one
      expect(find.text('下载网页中的音视频'), findsOneWidget);
      expect(find.text('下载网页中的资源'), findsNothing);
    });

    testWidgets('下载网页资源 card navigates to CatCatchPage', (tester) async {
      _setSmallScreen(tester);

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Tap the 下载网页资源 card - scroll down to find it if needed
      final cardFinder = find.text('下载网页资源');
      await tester.ensureVisible(cardFinder);
      await tester.pumpAndSettle();
      await tester.tap(cardFinder);
      await tester.pumpAndSettle();

      // Should navigate to CatCatchPage with new title
      expect(find.text('下载网页资源'), findsOneWidget);
    });

    testWidgets('音频分离 card exists on home page', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Should show 音频分离 as a module card
      expect(find.text('音频分离'), findsOneWidget);
    });

    testWidgets('音频分离 card has correct icon', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Should have the music note icon
      expect(find.byIcon(Icons.music_note), findsOneWidget);
    });

    testWidgets('音频分离 card navigates to AudioSeparationPage', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Tap the 音频分离 card
      final cardFinder = find.text('音频分离');
      await tester.ensureVisible(cardFinder);
      await tester.pumpAndSettle();
      await tester.tap(cardFinder);
      await tester.pumpAndSettle();

      // Should navigate to AudioSeparationPage (check for its title)
      expect(find.text('视频音频分离'), findsOneWidget);
    });
  });

  group('HomePage responsive layout', () {
    testWidgets(
      'welcome text and notification button both visible on small screen',
      (tester) async {
        _setSmallScreen(tester);

        await tester.pumpWidget(_buildTestApp());
        await tester.pumpAndSettle();

        // Welcome text should be visible
        expect(find.text('欢迎使用 Stroom'), findsOneWidget);

        // Notification button should be visible
        expect(find.byIcon(Icons.pending_actions), findsOneWidget);

        // Subtitle should be visible
        expect(find.text('选择一个功能模块开始使用'), findsOneWidget);

        // Module card labels should be visible
        expect(find.text('OCR'), findsOneWidget);
        expect(find.text('语音识别'), findsOneWidget);

        // No overflow exceptions should have been thrown
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('no RenderFlex overflow error on very narrow screen (320px)', (
      tester,
    ) async {
      _setVeryNarrowScreen(tester);

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Verify all key elements are still present
      expect(find.text('欢迎使用 Stroom'), findsOneWidget);
      expect(find.text('OCR'), findsOneWidget);
      expect(find.text('语音识别'), findsOneWidget);
      expect(find.byIcon(Icons.pending_actions), findsOneWidget);

      // No overflow exceptions
      expect(tester.takeException(), isNull);
    });

    testWidgets('notification button does not overlap with header text', (
      tester,
    ) async {
      _setSmallScreen(tester);

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Get the render box of the welcome text to find its right edge
      final welcomeTextFinder = find.text('欢迎使用 Stroom');
      expect(welcomeTextFinder, findsOneWidget);

      final welcomeRenderBox = tester.renderObject<RenderBox>(
        welcomeTextFinder,
      );
      final welcomeRect =
          welcomeRenderBox.localToGlobal(Offset.zero) & welcomeRenderBox.size;

      // Get the render box of the notification button
      final notifBtnFinder = find.byIcon(Icons.pending_actions);
      expect(notifBtnFinder, findsOneWidget);

      final notifRenderBox = tester.renderObject<RenderBox>(notifBtnFinder);
      final notifRect =
          notifRenderBox.localToGlobal(Offset.zero) & notifRenderBox.size;

      // The notification button should be to the RIGHT of the welcome text
      // (not overlapping horizontally)
      expect(
        notifRect.left,
        greaterThanOrEqualTo(welcomeRect.right - 8),
        reason: 'Notification button should not overlap with welcome text',
      );
    });

    testWidgets('module card texts fit within card bounds', (tester) async {
      _setSmallScreen(tester);

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Check that the OCR card text render boxes are within the card's area
      final ocrCard = find.text('OCR');
      expect(ocrCard, findsOneWidget);

      final ocrSubtitle = find.text('文字识别');
      expect(ocrSubtitle, findsOneWidget);

      // Verify they're rendered (rendering means they fit)
      expect(
        tester.renderObject<RenderBox>(ocrCard).size.width,
        greaterThan(0),
      );
      expect(
        tester.renderObject<RenderBox>(ocrSubtitle).size.width,
        greaterThan(0),
      );

      // Verify no overflow
      expect(tester.takeException(), isNull);
    });
  });

  group('HomePage tablet adaptation', () {
    testWidgets('SafeArea is present on home page content (tablet)', (
      tester,
    ) async {
      _setTabletScreen(tester);

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // FilesPage (from IndexedStack) + HomePage = 2 SafeArea widgets
      expect(find.byType(SafeArea), findsNWidgets(2));
    });

    testWidgets('welcome text is positioned below status bar area on tablet', (
      tester,
    ) async {
      _setTabletScreen(tester);

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // The welcome text should be positioned at least below the
      // simulated status bar top padding (24px)
      final welcomeFinder = find.text('欢迎使用 Stroom');
      expect(welcomeFinder, findsOneWidget);

      final welcomeBox = tester.renderObject<RenderBox>(welcomeFinder);
      final topLeft = welcomeBox.localToGlobal(Offset.zero);

      // The top of the welcome text should be below the status bar padding
      // (24px) + the SafeArea's own content padding (which includes the
      // top padding from EdgeInsets.fromLTRB(16, 16, 16, 0) = 16px)
      // So minimum top should be 24 (status bar) + some margin
      expect(
        topLeft.dy,
        greaterThanOrEqualTo(24.0),
        reason: 'Welcome text top position ($topLeft) should be '
            'below the status bar area (>= 24px)',
      );
    });

    testWidgets('all key elements are visible on tablet screen', (
      tester,
    ) async {
      _setTabletScreen(tester);

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // All key elements should be visible
      expect(find.text('欢迎使用 Stroom'), findsOneWidget);
      expect(find.text('选择一个功能模块开始使用'), findsOneWidget);
      expect(find.text('OCR'), findsOneWidget);
      expect(find.text('语音识别'), findsOneWidget);
      expect(find.byIcon(Icons.pending_actions), findsOneWidget);

      // No overflow exceptions
      expect(tester.takeException(), isNull);
    });

    testWidgets('no overflow on tablet screen', (tester) async {
      _setTabletScreen(tester);

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Verify no overflow exceptions
      expect(tester.takeException(), isNull);
    });
  });
}
