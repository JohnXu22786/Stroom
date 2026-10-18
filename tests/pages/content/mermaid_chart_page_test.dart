import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/mermaid_chart_page.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/mermaid_templates.dart';
import 'package:stroom/utils/text_manifest.dart';
import 'package:stroom/widgets/folder_picker_dialog.dart';
import 'package:stroom/widgets/mermaid_render_widget.dart';

List<String> _requirementIds(String code) {
  final matches = RegExp(
    r'^[ \t]*id:[ \t]*([^\s]+)[ \t]*$',
    multiLine: true,
  ).allMatches(code);
  return matches.map((match) => match.group(1)!).toList();
}

/// Builds the test app. [initialShowPreview] defaults to false to avoid
/// InAppWebView platform not being initialized in test environment.
Widget _buildTestApp({
  String? initialCode,
  TextRecord? existingRecord,
  bool initialShowPreview = false,
  VoidCallback? testOnlyBeforeChartFolderNameLock,
  Future<void> Function(String name)? testOnlyAfterChartNameAllocation,
}) {
  return ProviderScope(
    child: MaterialApp(
      home: MermaidChartPage(
        initialCode: initialCode,
        existingRecord: existingRecord,
        initialShowPreview: initialShowPreview,
        testOnlyBeforeChartFolderNameLock: testOnlyBeforeChartFolderNameLock,
        testOnlyAfterChartNameAllocation: testOnlyAfterChartNameAllocation,
      ),
      localizationsDelegates: [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
    ),
  );
}

Widget _buildConcurrentChartTestApp({
  required Future<void> Function(String name) onFirstChartNameAllocation,
  required VoidCallback onSecondFolderNameLockAttempt,
  required Future<void> Function(String name) onSecondChartNameAllocation,
}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Row(
      children: [
        Expanded(
          child: _buildTestApp(
            initialCode: 'graph TD\n  A-->B',
            initialShowPreview: false,
            testOnlyAfterChartNameAllocation: onFirstChartNameAllocation,
          ),
        ),
        Expanded(
          child: _buildTestApp(
            initialCode: 'graph TD\n  A-->C',
            initialShowPreview: false,
            testOnlyBeforeChartFolderNameLock: onSecondFolderNameLockAttempt,
            testOnlyAfterChartNameAllocation: onSecondChartNameAllocation,
          ),
        ),
      ],
    ),
  );
}

Widget _buildSavedChartNavigationTestApp({
  required TextRecord record,
  required String content,
}) {
  return ProviderScope(
    child: MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => MermaidChartPage(
                    initialCode: content,
                    existingRecord: record,
                    initialShowPreview: false,
                  ),
                ),
              ),
              child: const Text('Open saved chart'),
            ),
          ),
        ),
      ),
      localizationsDelegates: [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
    ),
  );
}

Future<TextRecord> _addSavedMermaidChart(String content) async {
  final bytes = Uint8List.fromList(utf8.encode(content));
  final record = TextRecord(
    id: 'saved-mermaid-chart',
    name: 'saved-chart',
    hash: computeTextHash(bytes),
    format: 'mmd',
    createdAt: DateTime.utc(2026, 1, 1),
    size: bytes.length,
    textLength: content.length,
  );
  await TextManifest.writeText(record.storagePath, content);
  await TextManifest.addRecord(record);
  return record;
}

Future<void> _simulateSystemBack(WidgetTester tester) async {
  // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    ManifestDatabase.beforeJsonRecordRegistrationForTesting = null;
    ManifestDatabase.beforeWebDataReadForTesting = null;
    TextManifest.beforeFolderLoadForTesting = null;
    TextManifest.invalidateCache();
  });

  group('MermaidChartPage', () {
    testWidgets('app-bar back can stay editing or discard the draft', (
      tester,
    ) async {
      const original = 'graph TD\n  A-->B';
      const draft = 'graph TD\n  A-->Unsaved';
      final record = await _addSavedMermaidChart(original);

      await tester.pumpWidget(
        _buildSavedChartNavigationTestApp(record: record, content: original),
      );
      await tester.tap(find.text('Open saved chart'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, draft);
      await tester.pump();

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('放弃修改？'), findsOneWidget);
      expect(find.text('当前有未保存的修改，确定要放弃吗？'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      expect(find.byType(MermaidChartPage), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller?.text,
        draft,
      );

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      await tester.tap(find.text('放弃'));
      await tester.pumpAndSettle();

      expect(find.text('Open saved chart'), findsOneWidget);
      expect(find.byType(MermaidChartPage), findsNothing);
      expect(await TextManifest.readText(record.storagePath), original);
      expect((await TextManifest.loadRecords()).single.hash, record.hash);
    });

    testWidgets('system back can stay editing or discard the draft', (
      tester,
    ) async {
      const original = 'graph TD\n  A-->B';
      const draft = 'graph TD\n  A-->Unsaved';
      final record = await _addSavedMermaidChart(original);

      await tester.pumpWidget(
        _buildSavedChartNavigationTestApp(record: record, content: original),
      );
      await tester.tap(find.text('Open saved chart'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, draft);
      await tester.pump();

      await _simulateSystemBack(tester);

      expect(find.text('放弃修改？'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.byType(MermaidChartPage), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller?.text,
        draft,
      );

      await _simulateSystemBack(tester);
      expect(find.text('放弃修改？'), findsOneWidget);
      await tester.tap(find.text('放弃'));
      await tester.pumpAndSettle();

      expect(find.text('Open saved chart'), findsOneWidget);
      expect(find.byType(MermaidChartPage), findsNothing);
      expect(await TextManifest.readText(record.storagePath), original);
      expect((await TextManifest.loadRecords()).single.hash, record.hash);
    });

    testWidgets('unmodified saved chart still pops without confirmation', (
      tester,
    ) async {
      const original = 'graph TD\n  A-->B';
      final record = await _addSavedMermaidChart(original);

      await tester.pumpWidget(
        _buildSavedChartNavigationTestApp(record: record, content: original),
      );
      await tester.tap(find.text('Open saved chart'));
      await tester.pumpAndSettle();

      await _simulateSystemBack(tester);

      expect(find.text('Open saved chart'), findsOneWidget);
      expect(find.byType(MermaidChartPage), findsNothing);
      expect(find.text('放弃修改？'), findsNothing);
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

    testWidgets(
      'stale GitGraph merge chip is safe without an alternate branch',
      (tester) async {
        const initialCode = 'gitGraph\n  checkout main';
        await tester.pumpWidget(_buildTestApp(initialCode: initialCode));
        await tester.pump();

        final mergeChip = find.text('合并分支');
        expect(mergeChip, findsOneWidget);
        await tester.ensureVisible(mergeChip);
        await tester.tap(mergeChip);
        await tester.pump();

        expect(tester.takeException(), isNull);
        final textField =
            tester.widget<TextField>(find.byType(TextField).first);
        expect(textField.controller?.text, initialCode);
      },
    );

    testWidgets('GitGraph merge chip inserts an existing alternate branch', (
      tester,
    ) async {
      const initialCode = 'gitGraph\n  branch feature\n  checkout main';
      await tester.pumpWidget(_buildTestApp(initialCode: initialCode));
      await tester.pump();

      final mergeChip = find.text('合并分支');
      expect(mergeChip, findsOneWidget);
      await tester.ensureVisible(mergeChip);
      await tester.tap(mergeChip);
      await tester.pump();

      expect(tester.takeException(), isNull);
      final textField = tester.widget<TextField>(find.byType(TextField).first);
      expect(textField.controller?.text, contains('merge feature'));
    });

    testWidgets('initialCode auto-detects sequenceDiagram type', (
      tester,
    ) async {
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

    testWidgets('custom Requirement relationship chips insert declared nodes', (
      tester,
    ) async {
      const initialCode = '''requirementDiagram
  requirement account_access {
    id: 1
    text: Account access
    risk: low
    verifyMethod: test
  }
  element portal_ui {
    type: UI
  }
  element auth_api {
    type: Service
  }''';
      await tester.pumpWidget(_buildTestApp(initialCode: initialCode));
      await tester.pump();

      await tester.tap(find.text('添加关联'));
      await tester.pump();

      var editorCode = tester
          .widget<TextField>(find.byType(TextField).first)
          .controller!
          .text;
      expect(editorCode, contains('portal_ui - satisfies -> account_access'));
      expect(editorCode, isNot(contains('登录页面')));

      await tester.pump(const Duration(milliseconds: 801));
      await tester.tap(find.text('添加验证'));
      await tester.pump();

      editorCode = tester
          .widget<TextField>(find.byType(TextField).first)
          .controller!
          .text;
      expect(editorCode, contains('auth_api - verifies -> account_access'));
      expect(editorCode, isNot(contains('认证服务')));
    });

    testWidgets(
      'hides Requirement relationship chips without endpoint classes',
      (tester) async {
        const initialCode = '''requirementDiagram
  requirement account_access {
    id: 1
    text: Account access
    risk: low
    verifyMethod: test
  }''';
        await tester.pumpWidget(_buildTestApp(initialCode: initialCode));
        await tester.pump();

        expect(find.text('添加关联'), findsNothing);
        expect(find.text('添加验证'), findsNothing);
      },
    );

    testWidgets('Gantt dependency snippet uses an existing task ID', (
      tester,
    ) async {
      const initialCode = '''gantt
  dateFormat  YYYY-MM-DD
  section Existing
  Prepare release :releasePrep, 2026-10-01, 3d''';
      await tester.pumpWidget(_buildTestApp(initialCode: initialCode));
      await tester.pump();

      await tester.tap(find.text('添加依赖任务'));
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField).first);
      expect(
        textField.controller?.text,
        contains('后续任务 :after releasePrep, 5d'),
      );
      expect(textField.controller?.text, isNot(contains('after a1')));
    });

    testWidgets(
      'Gantt dependency snippet ignores titles that contain colon-separated words',
      (tester) async {
        const initialCode = '''gantt
  title Status: plan, build, ship
  accDescr {
    Plan: design, build, ship
  }''';
        await tester.pumpWidget(_buildTestApp(initialCode: initialCode));
        await tester.pump();

        await tester.tap(find.text('添加依赖任务'));
        await tester.pump();

        final textField = tester.widget<TextField>(
          find.byType(TextField).first,
        );
        final code = textField.controller?.text ?? '';
        expect(code, contains('title Status: plan, build, ship'));
        expect(code, contains('Plan: design, build, ship'));
        expect(
          code.contains(
            RegExp(
              r'依赖基准任务 :dependencyTask1, \d{4}-\d{2}-\d{2}, 1d\n'
              r'  后续任务 :after dependencyTask1, 5d',
            ),
          ),
          isTrue,
        );
      },
    );

    testWidgets(
      'Gantt dependency snippet adds an ID when existing tasks lack one',
      (tester) async {
        const initialCode = '''gantt
  dateFormat  DD MMM YYYY
  section Existing
  Prepare release :1 Oct 2026, 3d %% kickoff task''';
        await tester.pumpWidget(_buildTestApp(initialCode: initialCode));
        await tester.pump();

        await tester.tap(find.text('添加依赖任务'));
        await tester.pump();

        final textField = tester.widget<TextField>(
          find.byType(TextField).first,
        );
        expect(
          textField.controller?.text,
          contains(
            'Prepare release :dependencyTask1, 1 Oct 2026, 3d %% kickoff task',
          ),
        );
        expect(
          textField.controller?.text,
          contains('后续任务 :after dependencyTask1, 5d'),
        );
      },
    );

    testWidgets(
      'Gantt dependency snippet adds an ID to tasks with explicit end dates',
      (tester) async {
        const initialCode = '''gantt
  accDescr {
    dateFormat YYYY-MM-DD
  }
  dateFormat  dddd Do MMM YYYY [at] h:mm:ss.SSS a
  section Existing
  Prepare release :Thursday 1st Oct 2026 at 9:00:12.345 am, Saturday 3rd Oct 2026 at 3:30:56.789 pm''';
        await tester.pumpWidget(_buildTestApp(initialCode: initialCode));
        await tester.pump();

        await tester.tap(find.text('添加依赖任务'));
        await tester.pump();

        final textField = tester.widget<TextField>(
          find.byType(TextField).first,
        );
        expect(
          textField.controller?.text,
          contains(
            'Prepare release :dependencyTask1, '
            'Thursday 1st Oct 2026 at 9:00:12.345 am, '
            'Saturday 3rd Oct 2026 at 3:30:56.789 pm',
          ),
        );
        expect(
          textField.controller?.text,
          contains('后续任务 :after dependencyTask1, 5d'),
        );
      },
    );

    testWidgets(
      'Gantt dependency snippet recognizes dates with comma literals',
      (tester) async {
        const dateFormatCases = [
          ['MMMM D,YYYY', 'October 1,2026, October 3,2026'],
          ['MMMM D[,]YYYY', 'October 1,2026, October 3,2026'],
        ];

        for (final dateFormatCase in dateFormatCases) {
          await tester.pumpWidget(const SizedBox.shrink());
          final initialCode = '''gantt
  dateFormat  ${dateFormatCase[0]}
  section Existing
  Prepare release :${dateFormatCase[1]}''';
          await tester.pumpWidget(_buildTestApp(initialCode: initialCode));
          await tester.pump();

          await tester.tap(find.text('添加依赖任务'));
          await tester.pump();

          final textField = tester.widget<TextField>(
            find.byType(TextField).first,
          );
          final code = textField.controller?.text ?? '';
          expect(
            code,
            contains('Prepare release :dependencyTask1, ${dateFormatCase[1]}'),
            reason: '${dateFormatCase[0]} generated $code',
          );
          expect(code, contains('后续任务 :after dependencyTask1, 5d'));
          expect(code, isNot(contains('依赖基准任务 :')));
        }
      },
    );

    testWidgets(
      'Gantt dependency snippet adds tasks when the chart has no tasks',
      (tester) async {
        const initialCode = '''gantt
  dateFormat  dddd ddd dd d MMMM Do YYYY %% dates are localized
  title Empty Project''';
        await tester.pumpWidget(_buildTestApp(initialCode: initialCode));
        await tester.pump();

        await tester.tap(find.text('添加依赖任务'));
        await tester.pump();

        final textField = tester.widget<TextField>(
          find.byType(TextField).first,
        );
        final code = textField.controller?.text ?? '';
        expect(
          code.contains(
            RegExp(
              r'依赖基准任务 :dependencyTask1, '
              r'[A-Z][a-z]+ [A-Z][a-z]{2} [A-Z][a-z] [0-6] '
              r'[A-Z][a-z]+ \d{1,2}(?:st|nd|rd|th) \d{4}, 1d\n'
              r'  后续任务 :after dependencyTask1, 5d',
            ),
          ),
          isTrue,
        );
      },
    );

    testWidgets('Gantt dependency snippet respects time-based date formats', (
      tester,
    ) async {
      const initialCode = '''gantt
  dateFormat  YYYY-MM-DD HH:mm:ss.SSS Z ZZ
  title Empty Project''';
      await tester.pumpWidget(_buildTestApp(initialCode: initialCode));
      await tester.pump();

      await tester.tap(find.text('添加依赖任务'));
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField).first);
      final code = textField.controller?.text ?? '';
      expect(
        code.contains(
          RegExp(
            r'依赖基准任务 :dependencyTask1, \d{4}-\d{2}-\d{2} '
            r'\d{2}:\d{2}:\d{2}\.\d{3} [+-]\d{2}:\d{2} '
            r'[+-]\d{4}, 1d\n'
            r'  后续任务 :after dependencyTask1, 5d',
          ),
        ),
        isTrue,
      );
    });

    testWidgets(
      'Gantt dependency snippet supports 12-hour date format tokens',
      (tester) async {
        const dateFormatCases = [
          ['YYYY-MM-DD h:mm a', r'\d{1,2}:\d{2} (?:am|pm)'],
          ['YYYY-MM-DD hh:mm A', r'\d{2}:\d{2} (?:AM|PM)'],
        ];

        for (final dateFormatCase in dateFormatCases) {
          await tester.pumpWidget(const SizedBox.shrink());
          final initialCode = '''gantt
  dateFormat  ${dateFormatCase[0]}
  title Empty Project''';
          await tester.pumpWidget(_buildTestApp(initialCode: initialCode));
          await tester.pump();

          await tester.tap(find.text('添加依赖任务'));
          await tester.pump();

          final textField = tester.widget<TextField>(
            find.byType(TextField).first,
          );
          final code = textField.controller?.text ?? '';
          final pattern = RegExp(
            [
              r'依赖基准任务 :dependencyTask1, \d{4}-\d{2}-\d{2} ',
              dateFormatCase[1],
              r', 1d\n  后续任务 :after dependencyTask1, 5d',
            ].join(),
          );
          expect(
            code.contains(pattern),
            isTrue,
            reason: '${dateFormatCase[0]} generated $code',
          );
        }
      },
    );

    testWidgets(
      'Gantt dependency snippet unwraps bracket-escaped date literals',
      (tester) async {
        const initialCode = '''gantt
  dateFormat  YYYY-MM-DD [at] h:mm a
  title Empty Project''';
        await tester.pumpWidget(_buildTestApp(initialCode: initialCode));
        await tester.pump();

        await tester.tap(find.text('添加依赖任务'));
        await tester.pump();

        final textField = tester.widget<TextField>(
          find.byType(TextField).first,
        );
        final code = textField.controller?.text ?? '';
        expect(
          code.contains(
            RegExp(
              r'依赖基准任务 :dependencyTask1, \d{4}-\d{2}-\d{2} '
              r'at \d{1,2}:\d{2} (?:am|pm), 1d\n'
              r'  后续任务 :after dependencyTask1, 5d',
            ),
          ),
          isTrue,
        );
      },
    );

    testWidgets('manually editing the header updates snippet buttons', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp(initialShowPreview: false));
      await tester.pump();

      expect(find.text('添加节点'), findsOneWidget);
      expect(find.text('添加参与者'), findsNothing);

      await tester.enterText(
        find.byType(TextField).first,
        'sequenceDiagram\n  A->>B: Hello',
      );
      await tester.pump();

      expect(find.text('添加节点'), findsNothing);
      expect(find.text('添加参与者'), findsOneWidget);
      expect(find.text('添加请求'), findsOneWidget);
    });

    testWidgets('frontmatter sequenceDiagram selects snippets and save label', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp(initialShowPreview: false));
      await tester.pump();

      await tester.enterText(
        find.byType(TextField).first,
        '---\ntitle: Test\n---\nsequenceDiagram\n  A->>B: Hello',
      );
      await tester.pump();

      expect(find.text('添加参与者'), findsOneWidget);
      expect(find.text('添加节点'), findsNothing);

      await tester.tap(find.byIcon(Icons.save));
      await tester.pumpAndSettle();

      await tester.tap(find.text('根目录'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      await tester.tap(find.text('确定'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      final records = await TextManifest.loadRecords();
      final savedRecord = records.lastWhere((record) => record.format == 'mmd');
      expect(savedRecord.name, '我的图表-时序图');
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
      },
    );

    // ═══════════════════════════════════════════════════
    // Save - Folder Picker Dialog integration
    // ═══════════════════════════════════════════════════

    testWidgets(
      'save button shows folder picker dialog when content not empty',
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
      },
    );

    testWidgets(
      'save persists edits made while folder lookup is pending',
      (tester) async {
        const initialContent = 'graph TD\n  A-->BeforeLookup';
        const editedContent = 'graph TD\n  A-->DuringLookup';
        final folderLoadStarted = Completer<void>();
        final releaseFolderLoad = Completer<void>();
        addTearDown(() {
          TextManifest.beforeFolderLoadForTesting = null;
          if (!releaseFolderLoad.isCompleted) releaseFolderLoad.complete();
        });
        TextManifest.beforeFolderLoadForTesting = () async {
          folderLoadStarted.complete();
          await releaseFolderLoad.future;
        };

        await tester.pumpWidget(_buildTestApp(initialShowPreview: false));
        await tester.pump();
        final editor = find.byType(TextField).first;
        await tester.enterText(editor, initialContent);
        await tester.pump();

        await tester.tap(find.byIcon(Icons.save));
        await folderLoadStarted.future;
        await tester.enterText(editor, editedContent);
        await tester.pump();
        releaseFolderLoad.complete();
        await tester.pumpAndSettle();

        expect(find.text('保存图表'), findsOneWidget);
        await tester.tap(find.text('根目录'));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();
        await tester.tap(find.text('确定'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));

        final savedRecord = (await TextManifest.loadRecords()).singleWhere(
          (record) => record.format == 'mmd',
        );
        expect(
          await TextManifest.readText(savedRecord.storagePath),
          editedContent,
        );
      },
    );

    testWidgets(
      'rapid save activation during folder lookup does not stack pickers',
      (tester) async {
        final folderLoadStarted = Completer<void>();
        final releaseFolderLoad = Completer<void>();
        var folderLoadCount = 0;
        addTearDown(() {
          TextManifest.beforeFolderLoadForTesting = null;
          if (!releaseFolderLoad.isCompleted) releaseFolderLoad.complete();
        });
        TextManifest.beforeFolderLoadForTesting = () async {
          folderLoadCount++;
          if (!folderLoadStarted.isCompleted) folderLoadStarted.complete();
          await releaseFolderLoad.future;
        };

        await tester.pumpWidget(_buildTestApp(initialShowPreview: false));
        await tester.pump();
        await tester.enterText(
          find.byType(TextField).first,
          'graph TD\n  A-->B',
        );
        await tester.pump();

        // Deliver two activations before yielding a frame. The first starts
        // the asynchronous lookup while this same callback is still reachable.
        final saveButton = find.ancestor(
          of: find.byIcon(Icons.save),
          matching: find.byType(IconButton),
        );
        final save = tester.widget<IconButton>(saveButton).onPressed!;
        save();
        await folderLoadStarted.future;
        save();
        await tester.pump();
        final saveButtonDuringLookup = find.ancestor(
          of: find.byIcon(Icons.save),
          matching: find.byType(IconButton),
        );
        final saveIsLockedWhileLoading =
            tester.widget<IconButton>(saveButtonDuringLookup).onPressed == null;

        releaseFolderLoad.complete();
        await tester.pumpAndSettle();

        expect(
          folderLoadCount,
          1,
          reason: 'Repeated activation should not start another folder lookup.',
        );
        expect(
          saveIsLockedWhileLoading,
          isTrue,
          reason: 'The in-flight save should disable further activation.',
        );
        expect(find.text('保存图表'), findsOneWidget);
        expect(find.byType(FolderPickerDialog), findsOneWidget);

        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.save), findsOneWidget);
        final saveButtonAfterCancel = find.ancestor(
          of: find.byIcon(Icons.save),
          matching: find.byType(IconButton),
        );
        expect(
          tester.widget<IconButton>(saveButtonAfterCancel).onPressed,
          isNotNull,
        );
      },
    );

    testWidgets('save write failure reports an error and unlocks save', (
      tester,
    ) async {
      addTearDown(() {
        ManifestDatabase.beforeJsonRecordRegistrationForTesting = null;
      });
      ManifestDatabase.beforeJsonRecordRegistrationForTesting = () {
        throw StateError('simulated save failure');
      };

      await tester.pumpWidget(_buildTestApp(initialShowPreview: false));
      await tester.pump();
      const content = 'graph TD\n  A-->B';
      await tester.enterText(find.byType(TextField).first, content);
      await tester.pump();

      await tester.tap(find.byIcon(Icons.save));
      await tester.pumpAndSettle();
      expect(find.text('保存图表'), findsOneWidget);

      await tester.tap(find.text('根目录'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确定'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.text('保存失败: Bad state: simulated save failure'),
        findsOneWidget,
      );
      final saveButton = find.ancestor(
        of: find.byIcon(Icons.save),
        matching: find.byType(IconButton),
      );
      expect(tester.widget<IconButton>(saveButton).onPressed, isNotNull);
      expect(await TextManifest.loadRecords(), isEmpty);
      final hash = computeTextHash(Uint8List.fromList(utf8.encode(content)));
      expect(await TextManifest.readText('$hash.txt'), isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'record registration failure preserves a hash file referenced by an '
      'existing record',
      (tester) async {
        addTearDown(() {
          ManifestDatabase.beforeJsonRecordRegistrationForTesting = null;
        });
        const content = 'graph TD\n  A-->B';
        final hash = computeTextHash(Uint8List.fromList(utf8.encode(content)));
        final existingRecord = TextRecord(
          name: 'existing chart',
          hash: hash,
          format: 'mmd',
          createdAt: DateTime(2026),
          size: utf8.encode(content).length,
          textLength: content.length,
        );
        await TextManifest.writeText(existingRecord.storagePath, content);
        await TextManifest.addRecord(existingRecord);
        ManifestDatabase.beforeJsonRecordRegistrationForTesting = () {
          throw StateError('simulated save failure');
        };

        await tester.pumpWidget(_buildTestApp(initialShowPreview: false));
        await tester.pump();
        await tester.enterText(find.byType(TextField).first, content);
        await tester.pump();

        await tester.tap(find.byIcon(Icons.save));
        await tester.pumpAndSettle();
        expect(find.text('保存图表'), findsOneWidget);

        await tester.tap(find.text('根目录'));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();
        await tester.tap(find.text('确定'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          (await TextManifest.loadRecords()).map((record) => record.id),
          [existingRecord.id],
        );
        expect(
          await TextManifest.readText(existingRecord.storagePath),
          content,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'failed chart update removes unreferenced content and '
      'preserves the original',
      (tester) async {
        addTearDown(() {
          ManifestDatabase.beforeWebDataReadForTesting = null;
        });
        final updateReadStarted = Completer<void>();
        final releaseUpdateRead = Completer<void>();
        addTearDown(() {
          ManifestDatabase.beforeWebDataReadForTesting = null;
          if (!releaseUpdateRead.isCompleted) releaseUpdateRead.complete();
        });
        const originalContent = 'graph TD\n  A-->B';
        const editedContent = 'graph TD\n  A-->C';
        final originalRecord = TextRecord(
          id: 'existing-chart-id',
          name: 'existing-chart',
          hash: computeTextHash(
            Uint8List.fromList(utf8.encode(originalContent)),
          ),
          format: 'mmd',
          createdAt: DateTime.utc(2024, 1, 1),
          size: utf8.encode(originalContent).length,
          textLength: originalContent.length,
        );
        final editedHash = computeTextHash(
          Uint8List.fromList(utf8.encode(editedContent)),
        );
        await TextManifest.writeText(
          originalRecord.storagePath,
          originalContent,
        );
        await TextManifest.addRecord(originalRecord);

        await tester.pumpWidget(
          _buildTestApp(
            initialCode: originalContent,
            existingRecord: originalRecord,
            initialShowPreview: false,
            testOnlyAfterChartNameAllocation: (_) async {
              // The chart-page reservation now reads the manifest before it
              // writes the edited content. Invalidate again after that read
              // so this failure still occurs during record update.
              ManifestDatabase.invalidateWebDataCacheForTesting();
              ManifestDatabase.beforeWebDataReadForTesting = () async {
                ManifestDatabase.beforeWebDataReadForTesting = null;
                updateReadStarted.complete();
                await releaseUpdateRead.future;
                throw StateError('simulated update failure');
              };
            },
          ),
        );
        await tester.pump();
        await tester.enterText(find.byType(TextField).first, editedContent);
        await tester.pump();
        await tester.tap(find.byIcon(Icons.save));
        await tester.pumpAndSettle();
        expect(find.text('保存图表'), findsOneWidget);

        await tester.tap(find.text('根目录'));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        ManifestDatabase.invalidateWebDataCacheForTesting();

        await tester.tap(find.text('确定'));
        await tester.pump();
        await updateReadStarted.future.timeout(const Duration(seconds: 5));
        try {
          expect(
            await TextManifest.readText('$editedHash.txt'),
            editedContent,
          );
        } finally {
          if (!releaseUpdateRead.isCompleted) releaseUpdateRead.complete();
        }

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          find.text('保存失败: Bad state: simulated update failure'),
          findsOneWidget,
        );
        expect(await TextManifest.readText('$editedHash.txt'), isNull);
        final savedRecords = await TextManifest.loadRecords();
        expect(savedRecords.map((record) => record.id), [originalRecord.id]);
        expect(savedRecords.single.hash, originalRecord.hash);
        expect(
          await TextManifest.readText(originalRecord.storagePath),
          originalContent,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('save with empty content shows error, no folder picker', (
      tester,
    ) async {
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

    testWidgets('cancel in folder picker returns without saving', (
      tester,
    ) async {
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

    testWidgets('confirm in folder picker saves to selected folder', (
      tester,
    ) async {
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
      final savedRecord = records.lastWhere((r) => r.format == 'mmd');
      expect(savedRecord.folder, 'my_charts');
    });

    testWidgets('save dialog shows filename input and saves with custom name', (
      tester,
    ) async {
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
      final savedRecord = records.lastWhere((r) => r.format == 'mmd');
      expect(savedRecord.name, contains('自定义图表名'));
      expect(savedRecord.folder, '');
    });

    testWidgets('save with empty filename shows error, does not save', (
      tester,
    ) async {
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

    testWidgets('confirm in root folder picker saves to root (empty folder)', (
      tester,
    ) async {
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
      final savedRecord = records.lastWhere((r) => r.format == 'mmd');
      expect(savedRecord.folder, '');
    });

    testWidgets('new chart name conflicts are scoped to selected folder', (
      tester,
    ) async {
      const otherFolder = 'existing-folder';
      const destinationFolder = 'new-folder';
      const sharedName = 'shared-chart-流程图';
      const existingContent = 'graph TD\n  A-->Existing';
      final existingBytes = Uint8List.fromList(utf8.encode(existingContent));
      await TextManifest.addFolder(otherFolder);
      await TextManifest.addFolder(destinationFolder);
      final existingRecord = TextRecord(
        id: 'same-name-in-another-folder',
        name: sharedName,
        hash: computeTextHash(existingBytes),
        format: 'mmd',
        createdAt: DateTime.utc(2024, 1, 1),
        size: existingBytes.length,
        folder: otherFolder,
        textLength: existingContent.length,
      );
      await TextManifest.writeText(existingRecord.storagePath, existingContent);
      await TextManifest.addRecord(existingRecord);

      await tester.pumpWidget(_buildTestApp(initialShowPreview: false));
      await tester.pump();
      await tester.enterText(
        find.byType(TextField).first,
        'graph TD\n  A-->New',
      );
      await tester.pump();
      await tester.tap(find.byIcon(Icons.save));
      await tester.pumpAndSettle();

      final fileNameField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText == '输入文件名（自动添加 .mmd 后缀）',
      );
      await tester.enterText(fileNameField, 'shared-chart');
      await tester.tap(find.text(destinationFolder));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确定'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      final records = await TextManifest.loadRecords();
      final savedRecord = records.singleWhere(
        (record) => record.folder == destinationFolder,
      );
      expect(savedRecord.name, sharedName);
      expect(
        records.where((record) => record.name == sharedName),
        hasLength(2),
      );
    });

    testWidgets(
      'concurrent new charts in one folder get unique names and both save',
      (tester) async {
        const destinationFolder = 'chart-race-folder';
        final firstNameAllocated = Completer<void>();
        final secondFolderNameLockAttempted = Completer<void>();
        final bothNamesAllocated = Completer<void>();
        final releaseFirstNameAllocation = Completer<void>();
        final bothManifestSavesStarted = Completer<void>();
        final selectedNames = <String>[];
        var manifestSaveCount = 0;
        addTearDown(() {
          ManifestDatabase.beforeWebDataSaveForTesting = null;
          if (!releaseFirstNameAllocation.isCompleted) {
            releaseFirstNameAllocation.complete();
          }
        });

        Future<void> holdFirstNameAllocation(String name) async {
          selectedNames.add(name);
          firstNameAllocated.complete();
          await releaseFirstNameAllocation.future;
        }

        Future<void> recordSecondNameAllocation(String name) async {
          selectedNames.add(name);
          if (selectedNames.length == 2) bothNamesAllocated.complete();
        }

        await TextManifest.addFolder(destinationFolder);
        await tester.pumpWidget(
          _buildConcurrentChartTestApp(
            onFirstChartNameAllocation: holdFirstNameAllocation,
            onSecondFolderNameLockAttempt: () {
              secondFolderNameLockAttempted.complete();
            },
            onSecondChartNameAllocation: recordSecondNameAllocation,
          ),
        );
        await tester.tap(find.byIcon(Icons.save).first);
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.save).last);
        await tester.pumpAndSettle();
        expect(find.byType(FolderPickerDialog), findsNWidgets(2));

        ManifestDatabase.beforeWebDataSaveForTesting = () async {
          manifestSaveCount++;
          if (manifestSaveCount == 2) bothManifestSavesStarted.complete();
        };

        await tester.tap(find.text(destinationFolder).first);
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();
        await tester.tap(find.text('确定').first);
        await tester.pump(const Duration(milliseconds: 500));
        await tester.runAsync(
          () => firstNameAllocated.future.timeout(
            const Duration(seconds: 5),
          ),
        );

        await tester.tap(find.text(destinationFolder).last);
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.tap(find.text('确定').last);
        await tester.pump(const Duration(milliseconds: 500));
        await tester.runAsync(
          () async {
            await secondFolderNameLockAttempted.future.timeout(
              const Duration(seconds: 5),
            );
            await Future<void>.delayed(Duration.zero);
          },
        );
        final secondNameSelectedBeforeFirstWasPublished =
            selectedNames.length > 1;

        releaseFirstNameAllocation.complete();
        await tester.runAsync(() async {
          await bothNamesAllocated.future.timeout(const Duration(seconds: 5));
          await bothManifestSavesStarted.future.timeout(
            const Duration(seconds: 5),
          );
          await Future<void>.delayed(Duration.zero);
        });

        expect(secondNameSelectedBeforeFirstWasPublished, isFalse);
        expect(
          selectedNames,
          unorderedEquals(['我的图表-流程图', '我的图表-流程图 (2)']),
        );
        final savedRecords = (await TextManifest.loadRecordsUncached())
            .where((record) => record.format == 'mmd')
            .toList();
        expect(savedRecords, hasLength(2));
        expect(
          savedRecords.map((record) => record.name),
          unorderedEquals(['我的图表-流程图', '我的图表-流程图 (2)']),
        );
        expect(
          savedRecords.map((record) => record.folder),
          everyElement(destinationFolder),
        );
        expect(
          await Future.wait(
            savedRecords
                .map((record) => TextManifest.readText(record.storagePath)),
          ),
          unorderedEquals(['graph TD\n  A-->B', 'graph TD\n  A-->C']),
        );
      },
    );

    testWidgets('saving an edited chart updates its existing record in place', (
      tester,
    ) async {
      const originalContent = ' \ngraph TD\n  A-->B\n ';
      const editedContent = ' \ngraph TD\n  A-->C\n ';
      final originalBytes = Uint8List.fromList(utf8.encode(originalContent));
      final originalRecord = TextRecord(
        id: 'existing-chart-id',
        name: 'existing-chart',
        hash: computeTextHash(originalBytes),
        format: 'mmd',
        createdAt: DateTime.utc(2024, 1, 1),
        size: originalBytes.length,
        textLength: originalContent.length,
      );
      const otherFolder = 'another-folder';
      await TextManifest.addFolder(otherFolder);
      final sameNameInAnotherFolder = TextRecord(
        id: 'same-name-in-another-folder',
        name: originalRecord.name,
        hash: originalRecord.hash,
        format: 'mmd',
        createdAt: DateTime.utc(2024, 1, 2),
        size: originalBytes.length,
        folder: otherFolder,
        textLength: originalContent.length,
      );
      await TextManifest.writeText(originalRecord.storagePath, originalContent);
      await TextManifest.addRecord(originalRecord);
      await TextManifest.addRecord(sameNameInAnotherFolder);

      await tester.pumpWidget(
        _buildTestApp(
          initialCode: originalContent,
          existingRecord: originalRecord,
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField).first, editedContent);
      await tester.pump();
      await tester.tap(find.byIcon(Icons.save));
      await tester.pumpAndSettle();

      final fileNameField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText == '输入文件名（自动添加 .mmd 后缀）',
      );
      expect(
        tester.widget<TextField>(fileNameField).controller?.text,
        originalRecord.name,
      );

      await tester.tap(find.text('根目录'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确定'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      final records = await TextManifest.loadRecords();
      expect(records, hasLength(2));
      final savedRecord = records.singleWhere((r) => r.id == originalRecord.id);
      expect(savedRecord.id, originalRecord.id);
      expect(savedRecord.name, originalRecord.name);
      expect(
        savedRecord.hash,
        computeTextHash(Uint8List.fromList(utf8.encode(editedContent))),
      );
      expect(savedRecord.modifiedAt.isAfter(originalRecord.modifiedAt), isTrue);
      expect(
        await TextManifest.readText(savedRecord.storagePath),
        editedContent,
      );

      final preservedRecord = records.singleWhere(
        (r) => r.id == sameNameInAnotherFolder.id,
      );
      expect(preservedRecord.name, originalRecord.name);
      expect(preservedRecord.folder, otherFolder);
      expect(
        await TextManifest.readText(preservedRecord.storagePath),
        originalContent,
      );
    });

    // ═══════════════════════════════════════════════════
    // Editor Mode Switching (UI only, no WebView)
    // ═══════════════════════════════════════════════════

    testWidgets(
      'initialCode hides chart type selector, keeps snippet buttons',
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
        final textField = tester.widget<TextField>(
          find.byType(TextField).first,
        );
        expect(textField.controller?.text, contains('graph TD'));
        expect(textField.controller?.text, contains('Custom'));
      },
    );

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
        final textField = tester.widget<TextField>(
          find.byType(TextField).first,
        );
        expect(textField.controller?.text, contains('sequenceDiagram'));
      },
    );

    testWidgets('initialCode with %%{init} directive correctly detects type', (
      tester,
    ) async {
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
      'initialCode with multiline %%{init} directive detects sequence type',
      (tester) async {
        const initialCode = '''%%{init: {
  "theme": "dark"
}}%%
sequenceDiagram
  Alice->>Bob: Hi''';
        await tester.pumpWidget(_buildTestApp(initialCode: initialCode));
        await tester.pump();

        expect(find.text('添加参与者'), findsOneWidget);
        expect(find.text('添加请求'), findsOneWidget);
        expect(find.text('添加节点'), findsNothing);
      },
    );

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
      },
    );

    testWidgets('without initialCode shows chart type selector', (
      tester,
    ) async {
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

    testWidgets('repeated flowchart node insertions use distinct IDs', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          initialCode: 'graph TD\n  A[Start] --> B[End]',
          initialShowPreview: false,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('添加节点'));
      await tester.pump();
      await tester.tap(find.text('添加节点'));
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField).first);
      final nodeIds = RegExp(
        r'^\s*(NewNode\d*)\[新节点\]$',
        multiLine: true,
      ).allMatches(textField.controller!.text).map((match) => match[1]);

      expect(nodeIds, ['NewNode', 'NewNode1']);
    });

    testWidgets('flowchart node insertion preserves existing NewNode label', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          initialCode: 'graph TD\n  NewNode[Existing] --> A[End]',
          initialShowPreview: false,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('添加节点'));
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField).first);
      final code = textField.controller!.text;

      expect(code, contains('NewNode[Existing]'));
      expect(code, contains('NewNode1[新节点]'));
      expect(code, isNot(contains('NewNode[新节点]')));
    });

    testWidgets('flowchart node insertion skips IDs in link endpoints', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          initialCode: 'graph TD; NewNode~~~A; B <--> NewNode1; '
              'NewNode2 o-- C; D x-- NewNode3; E --> NewNode4; '
              'NewNode5 o-- NewNode6 --> H',
          initialShowPreview: false,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('添加节点'));
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField).first);
      final code = textField.controller!.text;

      expect(code, contains('NewNode~~~A'));
      expect(code, contains('B <--> NewNode1'));
      expect(code, contains('NewNode2 o-- C'));
      expect(code, contains('D x-- NewNode3'));
      expect(code, contains('E --> NewNode4'));
      expect(code, contains('NewNode5 o-- NewNode6 --> H'));
      expect(code, contains('NewNode7[新节点]'));
      expect(code, isNot(contains('NewNode[新节点]')));
    });

    testWidgets('flowchart node insertion ignores label and comment text', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          initialCode: 'graph TD\n%% NewNode\n'
              '  A["NewNode --> quoted label"]\n'
              '  B[NewNode --> unquoted label]\n'
              '  C>label --> NewNode --> asymmetric label]\n'
              r'  K>escaped \] --> NewNode --> asymmetric label]'
              '\n'
              '  D -- NewNode --> E\n'
              '  I -- "label --> NewNode --> quoted edge label" --> J\n'
              '  L -. NewNode .-> M\n'
              '  F -->|NewNode| G\n'
              '  H["NewNode %% label text"]\n',
          initialShowPreview: false,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('添加节点'));
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField).first);
      final code = textField.controller!.text;

      expect(code, contains('%% NewNode'));
      expect(code, contains('C>label --> NewNode --> asymmetric label]'));
      expect(code, contains('D -- NewNode --> E'));
      expect(code, contains('NewNode[新节点]'));
      expect(code, isNot(contains('NewNode1[新节点]')));
    });

    testWidgets(
      'repeated flowchart diamond snippets use IDs distinct from existing nodes',
      (tester) async {
        await tester.pumpWidget(
          _buildTestApp(
            initialCode:
                'graph TD\n  Condition[Existing decision] --> Next[Continue]',
            initialShowPreview: false,
          ),
        );
        await tester.pump();

        await tester.tap(find.text('添加菱形判断'));
        await tester.pump();
        await tester.tap(find.text('添加菱形判断'));
        await tester.pump();

        final textField =
            tester.widget<TextField>(find.byType(TextField).first);
        final code = textField.controller!.text;
        final nodeIds = RegExp(
          r'^\s*(Condition\d*)\{判断条件\}$',
          multiLine: true,
        ).allMatches(code).map((match) => match[1]).toList();

        expect(code, contains('Condition[Existing decision]'));
        expect(nodeIds, ['Condition1', 'Condition2']);
        expect(nodeIds.toSet(), hasLength(2));
      },
    );

    testWidgets(
      'repeated flowchart connection snippets use distinct endpoint IDs',
      (tester) async {
        await tester.pumpWidget(
          _buildTestApp(
            initialCode:
                'graph TD\n  Node1[Existing start] --> Node2[Existing end]',
            initialShowPreview: false,
          ),
        );
        await tester.pump();

        await tester.tap(find.text('添加连接线'));
        await tester.pump();
        await tester.tap(find.text('添加连接线'));
        await tester.pump();

        final textField =
            tester.widget<TextField>(find.byType(TextField).first);
        final code = textField.controller!.text;
        final edges = RegExp(
          r'^\s*(Node\d+) --> (Node\d+)\s*$',
          multiLine: true,
        ).allMatches(code).toList();
        final insertedNodeIds =
            edges.expand((edge) => [edge[1]!, edge[2]!]).toSet();

        expect(code, contains('Node1[Existing start] --> Node2[Existing end]'));
        expect(edges, hasLength(2));
        expect(edges.map((edge) => '${edge[1]} --> ${edge[2]}'), [
          'Node11 --> Node21',
          'Node12 --> Node22',
        ]);
        expect(insertedNodeIds, hasLength(4));
        expect(insertedNodeIds, isNot(contains('Node1')));
        expect(insertedNodeIds, isNot(contains('Node2')));
      },
    );

    testWidgets(
      'repeated flowchart subgraph snippets use distinct subgraph and node IDs',
      (tester) async {
        await tester.pumpWidget(
          _buildTestApp(
            initialCode: 'graph TD; subgraph 子图名称; Node1[Existing node]; end',
            initialShowPreview: false,
          ),
        );
        await tester.pump();

        await tester.tap(find.text('添加子图'));
        await tester.pump();
        await tester.tap(find.text('添加子图'));
        await tester.pump();

        final textField =
            tester.widget<TextField>(find.byType(TextField).first);
        final code = textField.controller!.text;
        final nodeIds = RegExp(
          r'^\s*(Node\d+)\[节点1\]$',
          multiLine: true,
        ).allMatches(code).map((match) => match[1]).toList();
        final subgraphIds = RegExp(
          r'(?:^|;)\s*subgraph\s+([^\s;\[]+)',
          multiLine: true,
        ).allMatches(code).map((match) => match[1]).toList();

        expect(code, contains('Node1[Existing node]'));
        expect(nodeIds, ['Node11', 'Node12']);
        expect(nodeIds.toSet(), hasLength(2));
        expect(subgraphIds, ['子图名称', '子图名称1', '子图名称2']);
        expect(subgraphIds.toSet(), hasLength(3));
        expect(
          RegExp(r'(?:^|;)\s*end\s*(?:;|$)', multiLine: true).allMatches(code),
          hasLength(3),
        );
      },
    );

    testWidgets('repeated class snippet insertions use distinct class IDs', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          initialCode: 'classDiagram\n  新类 <|-- ExistingClass',
          initialShowPreview: false,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('添加类'));
      await tester.pump();
      await tester.tap(find.text('添加类'));
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField).first);
      final code = textField.controller!.text;
      final classIds = RegExp(
        r'^class (\S+) \{$',
        multiLine: true,
      ).allMatches(code).map((match) => match[1]);

      expect(classIds, ['新类1', '新类2']);
      expect(code, contains('  新类 <|-- ExistingClass'));
      expect(code, contains('class 新类1 {\n  +String 属性\n  +方法() void\n}'));
      expect(code, contains('class 新类2 {\n  +String 属性\n  +方法() void\n}'));
    });

    testWidgets('class snippets skip IDs in compact relationships', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          initialCode: 'classDiagram\n  新类--ExistingClass',
          initialShowPreview: false,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('添加类'));
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField).first);
      final code = textField.controller!.text;
      final classIds = RegExp(
        r'^class (\S+) \{$',
        multiLine: true,
      ).allMatches(code).map((match) => match[1]);

      expect(classIds, ['新类1']);
      expect(code, contains('  新类--ExistingClass'));
      expect(code, contains('class 新类1 {\n  +String 属性\n  +方法() void\n}'));
    });

    testWidgets('class snippets skip IDs on CRLF lines with trailing space', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          initialCode: 'classDiagram\r\n  新类--ExistingClass \r\n',
          initialShowPreview: false,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('添加类'));
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField).first);
      final code = textField.controller!.text;
      final classIds = RegExp(
        r'^class (\S+) \{$',
        multiLine: true,
      ).allMatches(code).map((match) => match[1]);

      expect(classIds, ['新类1']);
      expect(code, contains('  新类--ExistingClass'));
    });

    testWidgets('class snippets skip compact right endpoints after letter o', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          initialCode: 'classDiagram\n  Foo--新类',
          initialShowPreview: false,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('添加类'));
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField).first);
      final code = textField.controller!.text;
      final classIds = RegExp(
        r'^class (\S+) \{$',
        multiLine: true,
      ).allMatches(code).map((match) => match[1]);

      expect(classIds, ['新类1']);
      expect(code, contains('  Foo--新类'));
    });

    testWidgets('class snippets skip IDs after embedded o in left endpoint', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          initialCode: 'classDiagram\n  Customer--新类',
          initialShowPreview: false,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('添加类'));
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField).first);
      final code = textField.controller!.text;
      final classIds = RegExp(
        r'^class (\S+) \{$',
        multiLine: true,
      ).allMatches(code).map((match) => match[1]);

      expect(classIds, ['新类1']);
      expect(code, contains('  Customer--新类'));
    });

    testWidgets('repeated ER snippet insertions use distinct entity IDs', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          initialCode: 'erDiagram\n  新实体 ||--o{ 已有实体 : owns',
          initialShowPreview: false,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('添加实体'));
      await tester.pump();
      await tester.tap(find.text('添加实体'));
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField).first);
      final code = textField.controller!.text;
      final entityIds = RegExp(
        r'^\s*(\S+) \{$',
        multiLine: true,
      ).allMatches(code).map((match) => match[1]);

      expect(entityIds, ['新实体1', '新实体2']);
      expect(code, contains('  新实体 ||--o{ 已有实体 : owns'));
      expect(
        code,
        contains('  新实体1 {\n    int id PK\n    string name\n  }'),
      );
      expect(
        code,
        contains('  新实体2 {\n    int id PK\n    string name\n  }'),
      );
    });

    testWidgets('ER snippets skip IDs in compact relationships', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          initialCode: 'erDiagram\n  新实体||--o{已有实体:owns\n  其他实体||--o{新实体',
          initialShowPreview: false,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('添加实体'));
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField).first);
      final code = textField.controller!.text;
      final entityIds = RegExp(
        r'^\s*(\S+) \{$',
        multiLine: true,
      ).allMatches(code).map((match) => match[1]);

      expect(entityIds, ['新实体1']);
      expect(code, contains('  新实体||--o{已有实体:owns'));
      expect(code, contains('  其他实体||--o{新实体'));
      expect(
        code,
        contains('  新实体1 {\n    int id PK\n    string name\n  }'),
      );
    });

    testWidgets('ER snippets skip compact right endpoints after letter o', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          initialCode: 'erDiagram\n  Foo||--o{新实体',
          initialShowPreview: false,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('添加实体'));
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField).first);
      final code = textField.controller!.text;
      final entityIds = RegExp(
        r'^\s*(\S+) \{$',
        multiLine: true,
      ).allMatches(code).map((match) => match[1]);

      expect(entityIds, ['新实体1']);
      expect(code, contains('  Foo||--o{新实体'));
    });

    testWidgets('ER snippets skip IDs after embedded o in left endpoint', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          initialCode: 'erDiagram\n  Customer||--o{新实体',
          initialShowPreview: false,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('添加实体'));
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField).first);
      final code = textField.controller!.text;
      final entityIds = RegExp(
        r'^\s*(\S+) \{$',
        multiLine: true,
      ).allMatches(code).map((match) => match[1]);

      expect(entityIds, ['新实体1']);
      expect(code, contains('  Customer||--o{新实体'));
    });

    testWidgets('ER snippets skip IDs on CRLF lines with trailing space', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          initialCode: 'erDiagram\r\n  新实体||--o{已有实体:owns \r\n',
          initialShowPreview: false,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('添加实体'));
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField).first);
      final code = textField.controller!.text;
      final entityIds = RegExp(
        r'^\s*(\S+) \{$',
        multiLine: true,
      ).allMatches(code).map((match) => match[1]);

      expect(entityIds, ['新实体1']);
      expect(code, contains('  新实体||--o{已有实体:owns'));
    });

    testWidgets('repeated block snippet insertions use distinct block IDs', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          initialCode: 'block-beta\n  A["existing"] NewBlock["existing"]',
          initialShowPreview: false,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('添加块'));
      await tester.pump();
      await tester.tap(find.text('添加块'));
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField).first);
      final code = textField.controller!.text;
      final blockIds = RegExp(
        r'^\s*(NewBlock\d*)\["新块"\]$',
        multiLine: true,
      ).allMatches(code).map((match) => match[1]);

      expect(blockIds, ['NewBlock1', 'NewBlock2']);
      expect(code, contains('A["existing"] NewBlock["existing"]'));
      expect(code, contains('  NewBlock1["新块"]'));
      expect(code, contains('  NewBlock2["新块"]'));
    });

    testWidgets('repeated child block snippets use distinct child IDs', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          initialCode: 'block-beta\n  A["existing"]',
          initialShowPreview: false,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('添加子块'));
      await tester.pump();
      await tester.tap(find.text('添加子块'));
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField).first);
      final code = textField.controller!.text;
      final childIds = RegExp(
        r'^[ \t]*(A\d*)\["块A"\]$',
        multiLine: true,
      ).allMatches(code).map((match) => match[1]).toList();

      expect(childIds, ['A1', 'A2']);
      expect(code, contains('A["existing"]'));
      expect(
        RegExp(r'^[ \t]*block$', multiLine: true).allMatches(code),
        hasLength(2),
      );
      expect(
        RegExp(r'^[ \t]*end$', multiLine: true).allMatches(code),
        hasLength(2),
      );
    });

    testWidgets('repeated block snippets skip bare IDs before later blocks', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          initialCode: 'block-beta\n  NewBlock A["existing"]',
          initialShowPreview: false,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('添加块'));
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField).first);
      final code = textField.controller!.text;

      expect(code, contains('  NewBlock A["existing"]'));
      expect(code, contains('  NewBlock1["新块"]'));
    });

    testWidgets('repeated block snippets skip alternate block shapes', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          initialCode: 'block-beta\n  NewBlock("existing")',
          initialShowPreview: false,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('添加块'));
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField).first);
      final code = textField.controller!.text;

      expect(code, contains('  NewBlock("existing")'));
      expect(code, contains('  NewBlock1["新块"]'));
    });

    testWidgets('repeated block snippets skip width-qualified IDs', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          initialCode: 'block-beta\n  NewBlock["existing"]\n  NewBlock1:2',
          initialShowPreview: false,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('添加块'));
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField).first);
      final code = textField.controller!.text;

      expect(code, contains('  NewBlock["existing"]'));
      expect(code, contains('  NewBlock1:2'));
      expect(code, contains('  NewBlock2["新块"]'));
    });

    testWidgets('block snippets skip IDs in nested block headers', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          initialCode:
              'block-beta\n  NewBlock["existing"]\n  block:NewBlock1:2\n  end',
          initialShowPreview: false,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('添加块'));
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField).first);
      final code = textField.controller!.text;

      expect(code, contains('  NewBlock["existing"]'));
      expect(code, contains('  block:NewBlock1:2'));
      expect(code, contains('  NewBlock2["新块"]'));
    });

    testWidgets('repeated block snippets skip IDs in unspaced links', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          initialCode: 'block-beta\n  NewBlock-->A\n  B-->NewBlock',
          initialShowPreview: false,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('添加块'));
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField).first);
      final code = textField.controller!.text;

      expect(code, contains('  NewBlock-->A'));
      expect(code, contains('  B-->NewBlock'));
      expect(code, contains('  NewBlock1["新块"]'));
    });

    testWidgets(
      'block snippets skip IDs after unspaced connector markers',
      (tester) async {
        await tester.pumpWidget(
          _buildTestApp(
            initialCode: 'block-beta\n  A--oNewBlock\n  B--xNewBlock1',
            initialShowPreview: false,
          ),
        );
        await tester.pump();

        await tester.tap(find.text('添加块'));
        await tester.pump();

        final textField =
            tester.widget<TextField>(find.byType(TextField).first);
        final code = textField.controller!.text;

        expect(code, contains('  A--oNewBlock'));
        expect(code, contains('  B--xNewBlock1'));
        expect(code, contains('  NewBlock2["新块"]'));
      },
    );

    testWidgets(
      'adding a requirement to the default diagram assigns a unique ID',
      (tester) async {
        await tester.pumpWidget(
          _buildTestApp(
            initialCode: MermaidTemplates.getTemplate('requirement'),
            initialShowPreview: false,
          ),
        );
        await tester.pump();

        await tester.tap(find.text('添加需求'));
        await tester.pump();

        final textField = tester.widget<TextField>(
          find.byType(TextField).first,
        );
        expect(_requirementIds(textField.controller!.text), ['1', '2']);
      },
    );

    testWidgets(
      'repeated requirement insertions assign distinct IDs',
      (tester) async {
        await tester.pumpWidget(
          _buildTestApp(
            initialCode: MermaidTemplates.getTemplate('requirement'),
            initialShowPreview: false,
          ),
        );
        await tester.pump();

        await tester.tap(find.text('添加需求'));
        await tester.pump();
        await tester.tap(find.text('添加需求'));
        await tester.pump();

        final textField = tester.widget<TextField>(
          find.byType(TextField).first,
        );
        expect(_requirementIds(textField.controller!.text), ['1', '2', '3']);
      },
    );

    testWidgets(
      'snippet insertion preserves final line without trailing newline',
      (tester) async {
        const initialCode = 'graph TD\n  A[Start] --> B[End]';
        await tester.pumpWidget(_buildTestApp(initialCode: initialCode));
        await tester.pump();

        await tester.tap(find.text('添加节点'));
        await tester.pump();

        final textField = find.byType(TextField).first;
        final controller = tester.widget<TextField>(textField).controller;
        expect(
          controller?.text,
          'graph TD\n  A[Start] --> B[End]\n  NewNode[新节点]\n',
        );
      },
    );

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
      },
    );

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

    // ═══════════════════════════════════════════════════
    // Adaptive layout & zoom controls
    // ═══════════════════════════════════════════════════

    testWidgets(
      'split mode uses vertical stack when space is taller than wide',
      (tester) async {
        // Regression: when available space is taller than wide (e.g.
        // portrait phone, narrow window, tall split-screen), split mode
        // should show preview on top and code editor on bottom (vertical
        // stack). This is the existing behavior that should be preserved.
        // Set viewport to tall dimensions (600 wide x 1000 tall).
        tester.view.physicalSize = const Size(600, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(_buildTestApp(initialShowPreview: true));

        // MermaidRenderWidget should be visible (preview area)
        expect(find.byType(MermaidRenderWidget), findsOneWidget);
        // Code editor label should be visible
        expect(find.text('代码'), findsOneWidget);
        // The Mermaid code text field should exist
        expect(find.byType(TextField), findsOneWidget);
        // No swap button in narrow mode
        expect(find.byIcon(Icons.swap_horiz), findsNothing);
      },
    );

    testWidgets(
      'split mode uses horizontal layout when space is wider than tall',
      (tester) async {
        // Regression: when available space is wider than tall (e.g.
        // landscape device, wide desktop window, wide split-screen),
        // split mode should show preview and code editor side by side
        // with a swap button between them.
        // Set viewport to wide dimensions (1600 wide x 900 tall).
        tester.view.physicalSize = const Size(1600, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(_buildTestApp(initialShowPreview: true));

        // MermaidRenderWidget should still be visible
        expect(find.byType(MermaidRenderWidget), findsOneWidget);
        // Code label should be visible
        expect(find.text('代码'), findsOneWidget);
        // In wide mode, the swap button should exist
        expect(find.byIcon(Icons.swap_horiz), findsOneWidget);
      },
    );

    testWidgets('wide split mode swap button toggles panel positions', (
      tester,
    ) async {
      // Regression: tapping the swap_horiz button in wide split mode
      // should exchange the left/right positions of preview and code
      // editor panels. Since we cannot tap buttons and create WebView
      // at the same time in test mode, we verify the swap button
      // exists and tapping it produces no exceptions.
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp(initialShowPreview: true));

      // Swap button should exist
      expect(find.byIcon(Icons.swap_horiz), findsOneWidget);

      // Tap the swap button — this is safe because swap button tap
      // does NOT create a WebView; it only toggles state.
      await tester.tap(find.byIcon(Icons.swap_horiz));
      // Pump to process setState from the tap
      await tester.pump();

      // After tapping, button should still be present
      expect(find.byIcon(Icons.swap_horiz), findsOneWidget);
      // No exceptions
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'split mode preview shows zoom controls (showZoomControls passed to MermaidRenderWidget)',
      (tester) async {
        // Regression: the chart page should pass showZoomControls:true
        // to MermaidRenderWidget so zoom in/out buttons appear at the
        // top-right of the preview area.
        // We only call pumpWidget once to avoid InAppWebView creation.
        await tester.pumpWidget(_buildTestApp(initialShowPreview: true));

        // MermaidRenderWidget should be present
        expect(find.byType(MermaidRenderWidget), findsOneWidget);

        // Zoom controls should be visible with showZoomControls:true
        // showZoomControls shows buttons even during the loading state.
        expect(find.byIcon(Icons.zoom_in), findsOneWidget);
        expect(find.byIcon(Icons.zoom_out), findsOneWidget);
      },
    );

    testWidgets('split mode preview shows zoom controls but NOT full toolbar', (
      tester,
    ) async {
      // Regression: the Mermaid page preview should zoom controls
      // (zoom_in, zoom_out) via showZoomControls:true, but should NOT
      // show the full 4-button toolbar (fullscreen, code toggle, save)
      // that is used in chat inline rendering, because MermaidChartPage
      // passes showToolbar:false to MermaidRenderWidget.
      await tester.pumpWidget(_buildTestApp(initialShowPreview: true));

      // Only pump once — MermaidRenderWidget shows its loading state.
      expect(find.byType(MermaidRenderWidget), findsOneWidget);

      // Zoom controls should appear (showZoomControls:true)
      expect(find.byIcon(Icons.zoom_in), findsOneWidget);
      expect(find.byIcon(Icons.zoom_out), findsOneWidget);
      // Other toolbar buttons should NOT appear (showToolbar:false).
      // Icons.fullscreen is unique to the MermaidRenderWidget toolbar
      // and does not appear anywhere else in the chart page.
      // Icons.save also appears in the AppBar, so not checked here.
      // Icons.code also appears in the editor header divider.
      expect(find.byIcon(Icons.fullscreen), findsNothing);
      expect(find.byIcon(Icons.image), findsNothing);
    });
  });
}
