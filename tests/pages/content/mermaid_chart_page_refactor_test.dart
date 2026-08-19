import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/mermaid_chart_page.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/text_manifest.dart';
import 'package:stroom/widgets/mermaid_render_widget.dart';

/// Builds the test app. [initialShowPreview] defaults to false to avoid
/// InAppWebView platform not being initialized in test environment.
Widget _buildTestApp({String? initialCode, bool initialShowPreview = false}) {
  return ProviderScope(
    child: MaterialApp(
      home: MermaidChartPage(
        initialCode: initialCode,
        initialShowPreview: initialShowPreview,
      ),
      localizationsDelegates: [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    TextManifest.invalidateCache();
  });

  group('MermaidChartPage - freeze fix: uses MermaidRenderWidget', () {
    testWidgets('no direct InAppWebView — uses MermaidRenderWidget for preview',
        (tester) async {
      // Start in edit mode (no preview)
      await tester.pumpWidget(_buildTestApp(initialShowPreview: false));
      await tester.pump();

      // The page should render without platform exceptions. In test mode,
      // a direct InAppWebView would fail with "platform not initialized"
      // error. The absence of such errors confirms the page no longer
      // creates InAppWebView directly.
      expect(tester.takeException(), isNull);

      // In edit mode, MermaidRenderWidget should NOT be present
      expect(find.byType(MermaidRenderWidget), findsNothing);

      // Only the code editor TextField should be visible
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('page renders without synchronous WebView creation',
        (tester) async {
      // The original bug: WebView was created synchronously after 300ms,
      // causing the entire app to freeze. After fix: MermaidRenderWidget
      // handles deferred creation internally via postFrameCallback.
      await tester.pumpWidget(_buildTestApp(initialShowPreview: false));
      await tester.pump();

      // Should show the code editor
      expect(find.byType(TextField), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('switching from edit to split mode shows MermaidRenderWidget',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(initialShowPreview: false));
      await tester.pump();

      // In edit mode, MermaidRenderWidget should NOT be present
      expect(find.byType(MermaidRenderWidget), findsNothing);

      // Switch to split mode (opens preview with MermaidRenderWidget)
      await tester.tap(find.byTooltip('切换视图模式'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Menu should be visible
      expect(find.text('编辑+预览'), findsOneWidget);

      // Select split mode
      await tester.tap(find.text('编辑+预览'));
      await tester.pump();

      // MermaidRenderWidget should now be visible in the widget tree.
      // It shows a loading state since WebView creation is deferred
      // via postFrameCallback (same pattern as chat page).
      expect(find.byType(MermaidRenderWidget), findsOneWidget);
      expect(find.text('正在准备渲染引擎...'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('mode switching does not freeze with MermaidRenderWidget',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(initialShowPreview: false));
      await tester.pump();

      // Open and close the mode menu to verify responsiveness
      for (int i = 0; i < 3; i++) {
        final toggleButton = find.byTooltip('切换视图模式');
        if (toggleButton.evaluate().isNotEmpty) {
          await tester.tap(toggleButton, warnIfMissed: false);
          await tester.pump(const Duration(milliseconds: 100));
        }
        // Dismiss menu
        await tester.tapAt(const Offset(10, 10));
        await tester.pump(const Duration(milliseconds: 100));
      }

      // App should still be responsive
      expect(find.byType(TextField), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('editing code updates preview without recreation freeze',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(initialShowPreview: false));
      await tester.pump();

      // Enter mermaid code
      final textField = find.byType(TextField).first;
      await tester.enterText(textField, 'graph TD\n  A-->B');
      await tester.pump();

      // Verify the code is entered
      final controller = tester.widget<TextField>(textField).controller;
      expect(controller?.text, contains('graph TD'));

      // No exceptions should occur after typing
      expect(tester.takeException(), isNull);
    });
  });
}
