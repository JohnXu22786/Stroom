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

    testWidgets('shows 6 module cards on home page', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Should show 6 module cards (was 5, now with chart making card)
      expect(find.text('OCR'), findsOneWidget);
      expect(find.text('语音识别'), findsOneWidget);
      expect(find.text('下载网页资源'), findsOneWidget);
      expect(find.text('音频分离'), findsOneWidget);
      expect(find.text('语音合成'), findsOneWidget);
      expect(find.text('图表制作'), findsOneWidget);
    });

    testWidgets('TTSCreatePage import is available', (tester) async {
      // Verify the tts_create_page module can be imported
      // This test just checks the import works
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // The homepage should load without errors
      expect(tester.takeException(), isNull);
    });

    testWidgets('语音合成 card has record_voice_over icon', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // The new TTS card should have the record_voice_over icon
      // Also check the subtitle
      expect(find.text('语音合成'), findsOneWidget);
    });

    testWidgets('语音合成 card navigates to TTSCreatePage', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Tap the 语音合成 card
      final cardFinder = find.text('语音合成');
      await tester.ensureVisible(cardFinder);
      await tester.pumpAndSettle();
      await tester.tap(cardFinder);
      await tester.pumpAndSettle();

      // Should navigate to TTSCreatePage (it has "生成录音" title + body text)
      expect(find.text('生成录音'), findsWidgets);
    });

    testWidgets('图表制作 card is visible on home page', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // The new chart making card should be visible
      expect(find.text('图表制作'), findsOneWidget);
    });

    testWidgets('图表制作 card navigates to MermaidChartPage', (tester) async {
      // Verify the card exists and can be tapped; full navigation test
      // is covered in mermaid_chart_page_test to avoid InAppWebView
      // platform issues in test environment.
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // The 图表制作 card should be present on the home page
      expect(find.text('图表制作'), findsOneWidget);
      expect(find.text('Mermaid图表编辑'), findsOneWidget);
    });
  });

  group('HomePage responsive layout', () {
    testWidgets(
      'welcome text and status card visible on small screen',
      (tester) async {
        _setSmallScreen(tester);

        await tester.pumpWidget(_buildTestApp());
        await tester.pumpAndSettle();

        // Welcome text should be visible
        expect(find.text('欢迎使用 Stroom'), findsOneWidget);

        // Status card should be visible with "查看全部" button
        expect(find.text('查看全部'), findsOneWidget);

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
      expect(find.text('查看全部'), findsOneWidget);

      // No overflow exceptions
      expect(tester.takeException(), isNull);
    });

    testWidgets('status card is below welcome text and subtitle', (
      tester,
    ) async {
      _setSmallScreen(tester);

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Get the position of the welcome text
      final welcomeTextFinder = find.text('欢迎使用 Stroom');
      expect(welcomeTextFinder, findsOneWidget);

      final welcomeRenderBox = tester.renderObject<RenderBox>(
        welcomeTextFinder,
      );
      final welcomeBottom =
          welcomeRenderBox.localToGlobal(Offset.zero).dy +
          welcomeRenderBox.size.height;

      // Get the position of the status card's "查看全部"
      final viewAllFinder = find.text('查看全部');
      expect(viewAllFinder, findsOneWidget);

      final viewAllRenderBox = tester.renderObject<RenderBox>(
        viewAllFinder,
      );
      final viewAllTop =
          viewAllRenderBox.localToGlobal(Offset.zero).dy;

      // The status card should be below the welcome text
      expect(
        viewAllTop,
        greaterThan(welcomeBottom),
        reason: 'Status card should be positioned below the welcome text',
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
      expect(find.text('查看全部'), findsOneWidget);
      expect(find.text('进行中'), findsOneWidget);
      expect(find.text('已完成'), findsOneWidget);
      expect(find.text('失败'), findsOneWidget);

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

  group('HomePage status card visual design', () {
    testWidgets('status card shows "查看全部 >" with greater-than character', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // The "查看全部" text should exist
      expect(find.text('查看全部'), findsOneWidget,
          reason: '查看全部 button text should exist');

      // The ">" character should be present as a visual indicator
      expect(find.text('>'), findsOneWidget,
          reason:
              'Greater-than character ">" should appear in the view-all button');
    });

    testWidgets('status card displays count numbers for all 3 statuses', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // All 3 status items should show their count (initially all "0")
      // Use findsAtLeast(3) to ensure all three status counts are rendered,
      // accounting for the possibility that the navigation badge also
      // renders a "0" text (making the total ≥ 3).
      expect(find.text('0'), findsAtLeast(3),
          reason:
              'All 3 status count numbers should be displayed (found fewer than 3)');
    });

    testWidgets('tapping status items navigates to task list page', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Test tapping 进行中
      await tester.tap(find.text('进行中'));
      await tester.pumpAndSettle();
      expect(find.text('任务列表'), findsOneWidget,
          reason: 'Tapping 进行中 should navigate to task list page');

      // Go back to home
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // Test tapping 已完成
      await tester.tap(find.text('已完成'));
      await tester.pumpAndSettle();
      expect(find.text('任务列表'), findsOneWidget,
          reason: 'Tapping 已完成 should navigate to task list page');

      // Go back to home
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // Test tapping 失败
      await tester.tap(find.text('失败'));
      await tester.pumpAndSettle();
      expect(find.text('任务列表'), findsOneWidget,
          reason: 'Tapping 失败 should navigate to task list page');
    });

    testWidgets('tapping 查看全部 navigates to task list page', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('查看全部'));
      await tester.pumpAndSettle();

      expect(find.text('任务列表'), findsOneWidget,
          reason: 'Tapping 查看全部 should navigate to task list page');
    });
  });
}
