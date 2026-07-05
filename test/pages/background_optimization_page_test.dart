import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/background_optimization_page.dart';
import 'package:stroom/pages/platform_tutorial_page.dart';

/// Builds the test app wrapping BackgroundOptimizationPage.
Widget _buildTestApp() {
  return const ProviderScope(
    child: MaterialApp(
      home: BackgroundOptimizationPage(),
    ),
  );
}

void main() {
  group('BackgroundOptimizationPage - rendering', () {
    testWidgets('renders page title', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      // Title bar
      expect(find.text('后台运行优化'), findsOneWidget);
    });

    testWidgets('shows system environment detection section', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      // Section header 系统环境检测 should be visible
      expect(find.text('系统环境检测'), findsOneWidget);
      // Platform name should be displayed (Android in test env)
      expect(find.text('Android'), findsAtLeast(1));
    });

    testWidgets('shows background optimization status section', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      // Section header 后台优化检测 should be visible
      expect(find.text('后台优化检测'), findsOneWidget);
    });

    testWidgets('shows platform tutorial categories', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      // Section header 平台教程 should be visible
      expect(find.text('平台教程'), findsOneWidget);

      // Should show all platform tutorial cards (some text may appear multiple times
      // due to platform detection displaying the same name)
      expect(find.text('Android'), findsAtLeast(1));
      expect(find.text('iOS'), findsOneWidget);
      expect(find.text('Windows'), findsOneWidget);
      expect(find.text('macOS'), findsOneWidget);
      expect(find.text('Linux'), findsOneWidget);
    });
  });

  group('BackgroundOptimizationPage - navigation', () {
    testWidgets('tapping Android tutorial card navigates to PlatformTutorialPage', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      // Tap the Android tutorial card by its unique subtitle
      await tester.tap(find.text('Android 后台运行优化教程'));
      await tester.pumpAndSettle();

      // Should navigate to PlatformTutorialPage with Android tutorial
      expect(find.text('Android 后台运行教程'), findsOneWidget);
    });

    testWidgets('tapping Windows tutorial card navigates to PlatformTutorialPage', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      await tester.tap(find.text('Windows 后台运行优化教程'));
      await tester.pumpAndSettle();

      // Should navigate to PlatformTutorialPage with Windows tutorial
      expect(find.text('Windows 后台运行教程'), findsOneWidget);
    });
  });
}
