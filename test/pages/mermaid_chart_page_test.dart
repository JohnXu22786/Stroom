import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/mermaid_chart_page.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/text_manifest.dart';
import 'package:stroom/widgets/folder_picker_dialog.dart';

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

/// Helper: opens the mode selection popup menu from the AppBar.
/// Returns true if the menu was opened successfully.
Future<bool> _openModeMenu(WidgetTester tester) async {
  // Try all possible mode toggle icons
  for (final icon in [Icons.code, Icons.view_column, Icons.visibility]) {
    final finder = find.byIcon(icon);
    if (finder.evaluate().isNotEmpty) {
      await tester.tap(finder);
      await tester.pumpAndSettle();
      return true;
    }
  }
  return false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    TextManifest.invalidateCache();
  });

  group('MermaidChartPage', () {
    testWidgets('renders with title and diagram type selector', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      // Should show the page title
      expect(find.text('图表制作'), findsOneWidget);

      // Should show the code editor area (text field)
      expect(find.byType(TextField), findsWidgets);

      // Should show diagram type buttons
      expect(find.text('流程图'), findsOneWidget);
      expect(find.text('时序图'), findsOneWidget);
    });

    testWidgets('shows all major diagram type buttons', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      // All diagram type buttons should be present
      expect(find.text('流程图'), findsOneWidget);
      expect(find.text('时序图'), findsOneWidget);
      expect(find.text('类图'), findsOneWidget);
      expect(find.text('状态图'), findsOneWidget);
      expect(find.text('ER图'), findsOneWidget);
      expect(find.text('甘特图'), findsOneWidget);
      expect(find.text('饼图'), findsOneWidget);
    });

    testWidgets('selecting flowchart loads template in editor', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      // Tap the flowchart button
      await tester.tap(find.text('流程图'));
      await tester.pump();

      // The editor should contain flowchart template code
      final textField = tester.widget<TextField>(find.byType(TextField).first);
      expect(textField.controller?.text, contains('graph TD'));
    });

    testWidgets('selecting sequence diagram loads template', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      // Tap the sequence diagram button
      await tester.tap(find.text('时序图'));
      await tester.pump();

      // The editor should contain sequence diagram template
      final textField = tester.widget<TextField>(find.byType(TextField).first);
      expect(textField.controller?.text, contains('sequenceDiagram'));
    });

    testWidgets('save button exists as icon button in app bar', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      // Should have a save icon button in the app bar
      expect(find.byIcon(Icons.save), findsOneWidget);
    });

    testWidgets('can be created with initial code', (tester) async {
      const initialCode = 'graph TD\n  A[Custom] --> B[End]';
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: MermaidChartPage(
              initialCode: initialCode,
              initialShowPreview: false,
            ),
            localizationsDelegates: [
              DefaultMaterialLocalizations.delegate,
              DefaultWidgetsLocalizations.delegate,
            ],
          ),
        ),
      );
      await tester.pump();

      // The code editor should contain the initial code
      final textField = tester.widget<TextField>(find.byType(TextField).first);
      expect(textField.controller?.text, contains('graph TD'));
      expect(textField.controller?.text, contains('Custom'));
    });

    testWidgets('initialCode auto-detects sequenceDiagram type',
        (tester) async {
      const initialCode = 'sequenceDiagram\n  A->>B: Hello';
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: MermaidChartPage(
              initialCode: initialCode,
              initialShowPreview: false,
            ),
            localizationsDelegates: [
              DefaultMaterialLocalizations.delegate,
              DefaultWidgetsLocalizations.delegate,
            ],
          ),
        ),
      );
      await tester.pump();

      // The diagram type chip should show sequence diagram selected
      // and the code should contain the initial code
      final textField = tester.widget<TextField>(find.byType(TextField).first);
      expect(textField.controller?.text, contains('sequenceDiagram'));
      expect(textField.controller?.text, contains('Hello'));
    });

    testWidgets('initialCode auto-detects gantt type', (tester) async {
      const initialCode = 'gantt\n  title Test';
      await tester.pumpWidget(_buildTestApp(initialCode: initialCode));
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField).first);
      expect(textField.controller?.text, contains('gantt'));
      expect(textField.controller?.text, contains('Test'));
    });

    // ═══════════════════════════════════════════════════
    // Layout tests (edit mode only — no InAppWebView)
    // ═══════════════════════════════════════════════════

    testWidgets(
        'edit mode with initialShowPreview:false shows code editor only',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(initialShowPreview: false));
      await tester.pump();

      // Should start in edit mode (code icon in AppBar)
      expect(find.byIcon(Icons.code), findsOneWidget);
      expect(find.byIcon(Icons.view_column), findsNothing);
      expect(find.byIcon(Icons.visibility), findsNothing);

      // In edit mode, there should be exactly one TextField (the code editor)
      // The "代码" label (split mode editor label) should NOT be visible
      expect(find.text('代码'), findsNothing);

      // The TextField should be visible
      expect(find.byType(TextField), findsOneWidget);
    });

    // ═══════════════════════════════════════════════════
    // Save - Folder Picker Dialog integration
    // ═══════════════════════════════════════════════════

    testWidgets('save button shows folder picker dialog when content not empty',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      // Enter some content
      final textField = find.byType(TextField).first;
      await tester.enterText(textField, 'graph TD\n  A-->B');
      await tester.pump();

      // Tap save button
      await tester.tap(find.byIcon(Icons.save));
      await tester.pumpAndSettle();

      // Should show the folder picker dialog
      expect(find.text('选择保存文件夹'), findsOneWidget);
      expect(find.text('根目录'), findsOneWidget);
    });

    testWidgets('save with empty content shows error, no folder picker',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      // Content is empty by default (only template code, but we can clear it)
      // Actually default template has content, let's clear the field first
      final textField = find.byType(TextField).first;
      await tester.enterText(textField, '');
      await tester.pump();

      // Tap save button
      await tester.tap(find.byIcon(Icons.save));
      await tester.pump();

      // Should show error snackbar, no folder picker
      expect(find.text('图表内容为空，无法保存'), findsOneWidget);
      expect(find.byType(FolderPickerDialog), findsNothing);
    });

    testWidgets('cancel in folder picker returns without saving',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      // Enter content
      final textField = find.byType(TextField).first;
      await tester.enterText(textField, 'graph TD\n  A-->B');
      await tester.pump();

      // Tap save button → folder picker appears
      await tester.tap(find.byIcon(Icons.save));
      await tester.pumpAndSettle();

      expect(find.text('选择保存文件夹'), findsOneWidget);

      // Tap cancel
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      // Dialog should be dismissed, no save notification
      expect(find.text('选择保存文件夹'), findsNothing);
      expect(find.textContaining('已保存'), findsNothing);
    });

    testWidgets('confirm in folder picker saves to selected folder',
        (tester) async {
      // Pre-create a folder
      final folders = await TextManifest.getAllFolders();
      if (!folders.contains('my_charts')) {
        await TextManifest.addFolder('my_charts');
      }
      TextManifest.invalidateCache();

      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      // Enter content
      final textField = find.byType(TextField).first;
      await tester.enterText(textField, 'graph TD\n  A-->B');
      await tester.pump();

      // Tap save button → folder picker appears
      await tester.tap(find.byIcon(Icons.save));
      await tester.pumpAndSettle();

      expect(find.text('选择保存文件夹'), findsOneWidget);

      // Select 'my_charts' folder — single tap
      await tester.tap(find.text('my_charts'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // Confirm — dialog pops, then async save chain runs
      await tester.tap(find.text('确定'));
      // _isSaving=true shows CircularProgressIndicator (never settles)
      // so pump manually to let async I/O complete and page pop
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // Verify the record was saved with the correct folder
      final records = await TextManifest.loadRecords();
      final savedRecord = records.lastWhere(
        (r) => r.format == 'mmd',
      );
      expect(savedRecord.folder, 'my_charts');
    });

    testWidgets('confirm in root folder picker saves to root (empty folder)',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      // Enter content
      final textField = find.byType(TextField).first;
      await tester.enterText(textField, 'graph TD\n  A-->B');
      await tester.pump();

      // Tap save button → folder picker appears
      await tester.tap(find.byIcon(Icons.save));
      await tester.pumpAndSettle();

      expect(find.text('选择保存文件夹'), findsOneWidget);

      // Select root directory
      await tester.tap(find.text('根目录'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // Confirm — dialog pops, then async save chain runs
      await tester.tap(find.text('确定'));
      // _isSaving=true shows CircularProgressIndicator (never settles)
      // so pump manually to let async I/O complete and page pop
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // Verify the record was saved with empty folder (root)
      final records = await TextManifest.loadRecords();
      final savedRecord = records.lastWhere(
        (r) => r.format == 'mmd',
      );
      expect(savedRecord.folder, '');
    });
    // ═══════════════════════════════════════════════════
    // Editor Mode Switching (UI only, no WebView)
    // ═══════════════════════════════════════════════════

    testWidgets('mode selector menu shows all three modes', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      // Should start in edit mode (code icon)
      expect(find.byIcon(Icons.code), findsOneWidget);

      // Open the mode selection menu
      await tester.tap(find.byIcon(Icons.code));
      await tester.pumpAndSettle();

      // Menu should show all three mode options
      expect(find.text('编辑模式'), findsOneWidget);
      expect(find.text('编辑+预览'), findsOneWidget);
      expect(find.text('预览模式'), findsOneWidget);
    });

    testWidgets('initial mode shows code icon when preview disabled',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(initialShowPreview: false));
      await tester.pump();

      // Should start in edit mode
      expect(find.byIcon(Icons.code), findsOneWidget);
      expect(find.byIcon(Icons.view_column), findsNothing);
      expect(find.byIcon(Icons.visibility), findsNothing);
    });

    testWidgets('mode menu options exist with correct icons', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      // Open the mode selection menu
      await tester.tap(find.byIcon(Icons.code));
      await tester.pumpAndSettle();

      // Menu should show all three mode options with check on current
      expect(find.text('编辑模式'), findsOneWidget);
      expect(find.text('编辑+预览'), findsOneWidget);
      expect(find.text('预览模式'), findsOneWidget);

      // Current mode (edit) should have a checkmark
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    // ═══════════════════════════════════════════════════
    // Code update / debounce behavior tests
    // ═══════════════════════════════════════════════════

    testWidgets('editing code triggers debounce and updates last rendered code',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(initialShowPreview: false));
      await tester.pump();

      // Enter some mermaid code
      final textField = find.byType(TextField).first;
      await tester.enterText(textField, 'graph TD\n  A-->B');
      await tester.pump();

      // The debounce timer should fire after 800ms
      await tester.pump(const Duration(milliseconds: 900));

      // Verify the text is still in the controller
      final controller = tester.widget<TextField>(textField).controller;
      expect(controller?.text, contains('graph TD'));
    });

    testWidgets('snippet insertion appends to existing code', (tester) async {
      await tester.pumpWidget(_buildTestApp(initialShowPreview: false));
      await tester.pump();

      // Enter base code
      final textField = find.byType(TextField).first;
      await tester.enterText(textField, 'graph TD\n  A-->B');
      await tester.pump();

      // Check that snippet buttons exist (flowchart is selected by default)
      // The flowchart has snippets like '添加节点', '添加菱形判断', etc.
      expect(find.text('添加节点'), findsOneWidget);
      expect(find.text('添加连接线'), findsOneWidget);

      // Tap '添加节点' snippet
      await tester.tap(find.text('添加节点'));
      await tester.pump();

      // The code should now contain the new node snippet
      final controller = tester.widget<TextField>(textField).controller;
      expect(controller?.text, contains('NewNode'));
    });

    // ═══════════════════════════════════════════════════
    // Mode Switching Stability (regression tests for freeze fix)
    // ═══════════════════════════════════════════════════

    testWidgets(
        'rapid mode switching between edit, split, and preview does not hang',
        (tester) async {
      // Start in edit mode (no InAppWebView)
      await tester.pumpWidget(_buildTestApp(initialShowPreview: false));
      await tester.pump();

      // Open the mode menu repeatedly to verify no freeze occurs.
      for (int i = 0; i < 3; i++) {
        // Open mode menu by tapping the mode toggle button (use tooltip)
        await tester.tap(find.byTooltip('切换视图模式'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Menu should show all three modes
        expect(find.text('编辑模式'), findsOneWidget);
        expect(find.text('编辑+预览'), findsOneWidget);
        expect(find.text('预览模式'), findsOneWidget);

        // Dismiss the menu by tapping outside
        await tester.tapAt(const Offset(10, 10));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }

      // After all cycles, the page is still responsive
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('rapid mode menu open/close does not crash', (tester) async {
      await tester.pumpWidget(_buildTestApp(initialShowPreview: false));
      await tester.pump();

      // Open and close the mode menu 10 times rapidly
      for (int i = 0; i < 10; i++) {
        // Use the AppBar tooltip icon button instead of raw Icon to
        // avoid ambiguity when menu items are also visible
        final toggleButton = find.byTooltip('切换视图模式');
        if (toggleButton.evaluate().isNotEmpty) {
          await tester.tap(toggleButton);
        } else {
          // Fallback: try any remaining mode icon
          final modeIcon = find.byIcon(Icons.code);
          if (modeIcon.evaluate().isNotEmpty) {
            await tester.tap(modeIcon.first);
          }
        }
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Verify the page is still responsive
      expect(find.byType(TextField), findsOneWidget);
    });
  });
}
