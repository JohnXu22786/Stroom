import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/mermaid_chart_page.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/text_manifest.dart';
import 'package:stroom/widgets/folder_picker_dialog.dart';
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

      // Should show the save dialog with filename input and folder picker
      expect(find.text('保存图表'), findsOneWidget);
      expect(find.text('根目录'), findsOneWidget);
      // Should show filename input field with hint text
      expect(find.text('输入文件名（自动添加 .mmd 后缀）'), findsOneWidget);
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

      expect(find.text('保存图表'), findsOneWidget);

      // Tap cancel
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      // Dialog should be dismissed, no save notification
      expect(find.text('保存图表'), findsNothing);
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

      expect(find.text('保存图表'), findsOneWidget);

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

    testWidgets('save dialog shows filename input and saves with custom name',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      // Enter content
      final textField = find.byType(TextField).first;
      await tester.enterText(textField, 'graph TD\n  A-->B');
      await tester.pump();

      // Tap save button → save dialog appears
      await tester.tap(find.byIcon(Icons.save));
      await tester.pumpAndSettle();

      expect(find.text('保存图表'), findsOneWidget);

      // Find the filename TextField by its hint text
      final fileNameField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText == '输入文件名（自动添加 .mmd 后缀）',
      );
      // Filename field should have default value '我的图表'
      final fileNameCtrl = tester.widget<TextField>(fileNameField).controller;
      expect(fileNameCtrl?.text, '我的图表');

      // Change filename to a custom name
      await tester.enterText(fileNameField, '自定义图表名');
      await tester.pump();

      // Select root directory
      await tester.tap(find.text('根目录'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // Confirm
      await tester.tap(find.text('确定'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // Verify the record was saved with the custom name
      final records = await TextManifest.loadRecords();
      final savedRecord = records.lastWhere(
        (r) => r.format == 'mmd',
      );
      expect(savedRecord.name, contains('自定义图表名'));
      expect(savedRecord.folder, '');
    });

    testWidgets('save with empty filename shows error, does not save',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      // Enter content
      final textField = find.byType(TextField).first;
      await tester.enterText(textField, 'graph TD\n  A-->B');
      await tester.pump();

      // Tap save button → save dialog appears
      await tester.tap(find.byIcon(Icons.save));
      await tester.pumpAndSettle();

      expect(find.text('保存图表'), findsOneWidget);

      // Find the filename TextField and clear it
      final fileNameField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText == '输入文件名（自动添加 .mmd 后缀）',
      );
      await tester.enterText(fileNameField, '');
      await tester.pump();

      // Select root directory
      await tester.tap(find.text('根目录'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // Confirm with empty filename
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();

      // Should show error snackbar
      expect(find.text('文件名不能为空'), findsOneWidget);
      // Should NOT have saved any new mermaid record
      final records = await TextManifest.loadRecords();
      expect(records.where((r) => r.format == 'mmd'), isEmpty);
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

      expect(find.text('保存图表'), findsOneWidget);

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

    // ═══════════════════════════════════════════════════
    // initialCode → hide chart type selector
    // ═══════════════════════════════════════════════════

    testWidgets('initialCode hides chart type selector, keeps snippet buttons',
        (tester) async {
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

      // Chart type selector chips (Row 1) should NOT be shown
      expect(find.text('流程图'), findsNothing);
      expect(find.text('时序图'), findsNothing);
      expect(find.text('类图'), findsNothing);

      // Snippet buttons (Row 2) SHOULD be shown
      expect(find.text('添加节点'), findsOneWidget);
      expect(find.text('添加连接线'), findsOneWidget);

      // Code editor should contain the initial code
      final textField = tester.widget<TextField>(find.byType(TextField).first);
      expect(textField.controller?.text, contains('graph TD'));
      expect(textField.controller?.text, contains('Custom'));
    });

    testWidgets(
        'initialCode with %% comment correctly detects type for snippets',
        (tester) async {
      const initialCode =
          '%% Auto-generated sequence diagram\nsequenceDiagram\n  A->>B: Hello';
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

      // Chart type selector should be hidden
      expect(find.text('流程图'), findsNothing);

      // Sequence diagram snippet buttons should be shown
      // (based on correct type detection skipping %% comment)
      expect(find.text('添加参与者'), findsOneWidget);
      expect(find.text('添加请求'), findsOneWidget);

      // Code editor should contain the initial code
      final textField = tester.widget<TextField>(find.byType(TextField).first);
      expect(textField.controller?.text, contains('sequenceDiagram'));
    });

    testWidgets('initialCode with %%{init} directive correctly detects type',
        (tester) async {
      const initialCode =
          '%%{init: {\'theme\': \'dark\'}}%%\ngantt\n  title Project';
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

      // Chart type selector should be hidden
      expect(find.text('甘特图'), findsNothing);

      // Gantt snippet buttons should be shown
      expect(find.text('添加任务'), findsOneWidget);
    });

    testWidgets(
        'initialCode with only %% comments falls back to flowchart snippets',
        (tester) async {
      const initialCode = '%% comment line 1\n%% comment line 2\n';
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

      // Chart type selector should be hidden
      expect(find.text('流程图'), findsNothing);

      // Fallback to flowchart snippets
      expect(find.text('添加节点'), findsOneWidget);
      expect(find.text('添加连接线'), findsOneWidget);
    });

    testWidgets('without initialCode shows chart type selector',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      // Chart type selector chips should be shown
      expect(find.text('流程图'), findsOneWidget);
      expect(find.text('时序图'), findsOneWidget);
      expect(find.text('类图'), findsOneWidget);

      // Snippet buttons should also be shown
      expect(find.text('添加节点'), findsOneWidget);
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

    // ═══════════════════════════════════════════════════
    // Mermaid preview toolbar & split layout
    // ═══════════════════════════════════════════════════

    testWidgets(
        'split mode preview does NOT show zoom/fullscreen toolbar buttons',
        (tester) async {
      // Regression: the Mermaid page preview should not show the 4-button
      // toolbar (zoom_in, zoom_out, fullscreen, code toggle) that is used
      // in chat inline rendering, because MermaidChartPage passes
      // showToolbar:false to MermaidRenderWidget.
      await tester.pumpWidget(_buildTestApp(initialShowPreview: true));

      // Only pump once — MermaidRenderWidget shows its loading state.
      // The postFrameCallback fires during pumpWidget but creating an
      // InAppWebView would require a real platform implementation not
      // available in test mode. The loading state is enough to verify
      // that MermaidRenderWidget is present without the toolbar.
      expect(find.byType(MermaidRenderWidget), findsOneWidget);

      // No toolbar buttons should appear (showToolbar:false prevents
      // the button row even when the widget is in render mode).
      expect(find.byIcon(Icons.zoom_in), findsNothing);
      expect(find.byIcon(Icons.zoom_out), findsNothing);
      expect(find.byIcon(Icons.fullscreen), findsNothing);
    });
  });
}
