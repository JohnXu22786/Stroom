import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/mermaid_chart_page.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/text_manifest.dart';

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

    testWidgets('deferred creation timer scheduled without crash',
        (tester) async {
      // Start with initialShowPreview:true — this exercises the deferred
      // WebView creation path. We deliberately do NOT pump past 300ms to
      // avoid triggering InAppWebView creation (which requires a real
      // platform). We just verify the scheduling itself works.
      await tester.pumpWidget(_buildTestApp(initialShowPreview: true));
      await tester.pump();

      // The page should still be functional (no crash from deferred creation)
      expect(find.byType(TextField), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Pump to just before the 300ms timer fires
      await tester.pump(const Duration(milliseconds: 250));

      // Still no crash — the WebView hasn't been created yet
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'switching from edit to preview mode schedules deferred creation',
        (tester) async {
      // Start in edit mode
      await tester.pumpWidget(_buildTestApp(initialShowPreview: false));
      await tester.pump();

      // Verify we're in edit mode with no exceptions
      expect(find.byIcon(Icons.code), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Simulate entering preview mode by rebuilding with initialShowPreview:true
      await tester.pumpWidget(_buildTestApp(initialShowPreview: true));
      await tester.pump();

      // The page should switch to split mode and schedule WebView creation
      // without crashing (we don't pump past 300ms to avoid InAppWebView
      // platform requirement in test mode)
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
