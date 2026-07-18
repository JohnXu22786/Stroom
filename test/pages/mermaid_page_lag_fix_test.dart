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

  group('MermaidChartPage - lag fix: deferred WebView', () {
    testWidgets('page renders without WebView initially for smooth transition',
        (tester) async {
      // When initialShowPreview is false (edit mode), no WebView is created
      await tester.pumpWidget(_buildTestApp(initialShowPreview: false));
      await tester.pump();

      // Should show the code editor
      expect(find.byType(TextField), findsOneWidget);
      // Should show edit mode icon
      expect(find.byIcon(Icons.code), findsOneWidget);
      // No exceptions should occur
      expect(tester.takeException(), isNull);
    });

    testWidgets('split mode shows MermaidRenderWidget without platform crash',
        (tester) async {
      // Start with initialShowPreview:true — this shows the preview pane
      // with MermaidRenderWidget. The WebView creation is deferred via
      // postFrameCallback, so the initial frame shows only a loading
      // state without creating an InAppWebView (which would require a
      // real platform implementation not available in test mode).
      await tester.pumpWidget(_buildTestApp(initialShowPreview: true));

      // Only pump once — MermaidRenderWidget shows its loading state.
      // The postFrameCallback fires during pumpWidget but the queued
      // rebuild (creating InAppWebView) would only happen on a second
      // pump, which we deliberately avoid in the test environment.
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(MermaidRenderWidget), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Verify the loading state is shown (no WebView created yet)
      expect(find.text('正在准备渲染引擎...'), findsOneWidget);
    });

    testWidgets('switching from edit to split mode shows MermaidRenderWidget',
        (tester) async {
      // Start in edit mode
      await tester.pumpWidget(_buildTestApp(initialShowPreview: false));
      await tester.pump();

      // Verify we're in edit mode with no exceptions
      expect(find.byIcon(Icons.code), findsOneWidget);
      expect(find.byType(MermaidRenderWidget), findsNothing);
      expect(tester.takeException(), isNull);

      // Open mode menu and select split mode
      await tester.tap(find.byTooltip('切换视图模式'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('编辑+预览'), findsOneWidget);
      await tester.tap(find.text('编辑+预览'));
      await tester.pump();

      // MermaidRenderWidget should now be visible in split mode
      expect(find.byType(MermaidRenderWidget), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('mode switching does not freeze', (tester) async {
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
  });

  group('MermaidChartPage - error handling', () {
    testWidgets('save with empty content shows error', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      // Clear the text field
      final textField = find.byType(TextField).first;
      await tester.enterText(textField, '');
      await tester.pump();

      // Try to save
      await tester.tap(find.byIcon(Icons.save));
      await tester.pump();

      // Should show error snackbar
      expect(find.text('图表内容为空，无法保存'), findsOneWidget);
    });
  });

  group('MermaidChartPage - code editor stability', () {
    testWidgets('editing code does not cause widget tree rebuild loop',
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

      // No exceptions should occur
      expect(tester.takeException(), isNull);
    });
  });
}
