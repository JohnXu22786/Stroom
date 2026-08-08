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

  group('HomePage responsive layout', () {
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
      final welcomeBottom = welcomeRenderBox.localToGlobal(Offset.zero).dy +
          welcomeRenderBox.size.height;

      // Get the position of the status card's "查看全部"
      final viewAllFinder = find.text('查看全部');
      expect(viewAllFinder, findsOneWidget);

      final viewAllRenderBox = tester.renderObject<RenderBox>(
        viewAllFinder,
      );
      final viewAllTop = viewAllRenderBox.localToGlobal(Offset.zero).dy;

      // The status card should be below the welcome text
      expect(
        viewAllTop,
        greaterThan(welcomeBottom),
        reason: 'Status card should be positioned below the welcome text',
      );
    });
  });

  group('HomePage tablet adaptation', () {
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

    testWidgets('no overflow on tablet screen', (tester) async {
      _setTabletScreen(tester);

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Verify no overflow exceptions
      expect(tester.takeException(), isNull);
    });
  });
}
