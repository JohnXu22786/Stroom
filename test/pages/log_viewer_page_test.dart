import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/log_viewer_page.dart';
import 'package:stroom/services/app_log_service.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/web_file_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    WebFileStore.enableTestMode();
    AppLogService.enableFileLogging();
  });

  // ==================================================================
  // Widget structure tests (no file I/O needed)
  // ==================================================================
  //
  // LogViewerPage calls AppLogService._loadLogFiles() in initState,
  // which uses real file I/O. In testWidgets' fake async zone, file
  // I/O futures never complete, so _loadLogFiles hangs. These tests
  // verify widget structure without depending on async completion.

  group('LogViewerPage — widget structure', () {
    testWidgets('shows AppBar with title 应用日志', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LogViewerPage()));
      expect(find.text('应用日志'), findsOneWidget);
    });

    testWidgets('contains refresh button in AppBar', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LogViewerPage()));
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('contains cleanup old logs button in AppBar', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LogViewerPage()));
      expect(find.byIcon(Icons.delete_sweep), findsOneWidget);
    });

    testWidgets('shows loading indicator while fetching logs', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LogViewerPage()));
      // _loadLogFiles starts with synchronous setState to show loading
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  // ==================================================================
  // LogContentPage — auto-scroll behavior
  // ==================================================================
  //
  // Requirement: the page scrolls to the bottom exactly once when it
  // is entered (so the newest log lines at the end of the file are
  // visible). Switching between the rendered (structured) and plain
  // text (raw) views must NOT re-scroll to the bottom — that would
  // yank the reader away from the lines they were reading.

  /// Build a log file body with [lineCount] well-formed log lines
  /// (each ending with a newline, as the log writer produces).
  String buildLogContent(int lineCount) {
    final buffer = StringBuffer();
    for (var i = 0; i < lineCount; i++) {
      buffer.writeln('[2024-01-01 00:00:00] [INFO] [TestSource] line $i');
    }
    return buffer.toString();
  }

  /// The scroll position of the page's own scrollable (the ListView or
  /// SingleChildScrollView). SelectableText lines contain inner scrollables,
  /// so the outermost one (first in tree order) is the page scrollable.
  ScrollPosition currentPosition(WidgetTester tester) =>
      tester.state<ScrollableState>(find.byType(Scrollable).first).position;

  /// A point inside the view's left padding strip, where a drag reliably
  /// reaches the scrollable — dragging on a SelectableText row would hand
  /// the gesture to the text's own recognizer instead of the scrollable.
  /// The x is derived from the view's actual padding so the drag keeps
  /// working if the padding changes.
  Offset paddingStripPoint(WidgetTester tester, Finder viewFinder) {
    final Widget view = tester.widget(viewFinder);
    final EdgeInsetsGeometry? padding = switch (view) {
      ListView listView => listView.padding,
      SingleChildScrollView scrollView => scrollView.padding,
      _ => null,
    };
    final double padLeft = padding?.resolve(TextDirection.ltr).left ?? 0;
    return tester.getTopLeft(viewFinder) + Offset(padLeft / 2, 200);
  }

  group('LogContentPage — auto-scroll behavior', () {
    testWidgets('structured view scrolls to bottom on entry', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LogContentPage(
            fileName: 'app_2024-01-01-00.log',
            content: buildLogContent(500),
          ),
        ),
      );

      final position = currentPosition(tester);
      expect(position.maxScrollExtent, greaterThan(0),
          reason: '500 lines must overflow the viewport');
      expect(
        position.pixels,
        greaterThanOrEqualTo(position.maxScrollExtent - 2),
        reason: 'After entering the page, the view must be scrolled '
            'to the bottom (latest log lines)',
      );
    });

    testWidgets('first toggle to raw view keeps the reading position',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LogContentPage(
            fileName: 'app_2024-01-01-00.log',
            content: buildLogContent(500),
          ),
        ),
      );
      // Entry auto-scroll: structured view is at the bottom.
      final bottomOffset = currentPosition(tester).pixels;

      // Scroll the structured view up to the middle so the reading
      // position is far from the bottom. (Drag DOWN = positive dy.)
      await tester.dragFrom(
        paddingStripPoint(tester, find.byType(ListView)),
        const Offset(0, 4000),
      );
      await tester.pump();
      final structuredOffset = currentPosition(tester).pixels;
      expect(structuredOffset, lessThan(bottomOffset - 3000),
          reason: 'the drag must move the reading position away from '
              'the bottom');

      await tester.tap(find.byTooltip('原始视图'));
      await tester.pump();

      final position = currentPosition(tester);
      expect(position.maxScrollExtent, greaterThan(0),
          reason: 'raw content must overflow the viewport for this test');
      // The raw view was never shown before: it maps proportionally to
      // the structured reading position — it must not be yanked to the
      // top of the file nor to the bottom (latest logs).
      expect(position.pixels, greaterThan(0),
          reason: 'switching modes must not jump to the top of the file');
      expect(position.pixels, lessThan(position.maxScrollExtent - 2000),
          reason: 'switching modes must not scroll to the bottom — only '
              'the initial page entry may auto-scroll');
      final expectedProportional =
          structuredOffset / bottomOffset * position.maxScrollExtent;
      expect(
        (position.pixels - expectedProportional).abs(),
        lessThan(300),
        reason: 'a never-shown view should open at the same log region '
            'the user was reading',
      );
    });

    testWidgets('toggling back to structured view keeps its scroll position',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LogContentPage(
            fileName: 'app_2024-01-01-00.log',
            content: buildLogContent(500),
          ),
        ),
      );
      // Entry auto-scrolled to the bottom.
      final bottomOffset = currentPosition(tester).pixels;

      // Scroll well away from the bottom so that a buggy "re-scroll to
      // bottom" on mode switch is clearly detectable. (Lazy lists refine
      // their maxScrollExtent as items build, so keep assertions to a
      // generous tolerance.) Note: dragging DOWN (positive dy) scrolls
      // toward the top.
      await tester.dragFrom(
        paddingStripPoint(tester, find.byType(ListView)),
        const Offset(0, 4000),
      );
      await tester.pump();
      final draggedOffset = currentPosition(tester).pixels;
      expect(draggedOffset, lessThan(bottomOffset - 3000),
          reason: 'the drag must move the view well away from the bottom');

      await tester.tap(find.byTooltip('原始视图'));
      await tester.pump();
      await tester.tap(find.byTooltip('结构化视图'));
      await tester.pump();

      final restoredOffset = currentPosition(tester).pixels;
      expect(
        (restoredOffset - draggedOffset).abs(),
        lessThan(100),
        reason: 'Mode switches must never move the scroll position',
      );
      expect(restoredOffset, lessThan(bottomOffset - 3000),
          reason: 'after toggling back, the view must still be far from '
              'the bottom — it must not be yanked to the latest logs');
    });

    testWidgets('raw view restores its scroll position after toggling back',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LogContentPage(
            fileName: 'app_2024-01-01-00.log',
            content: buildLogContent(500),
          ),
        ),
      );
      // Entry auto-scroll happened in the structured view; the first raw
      // toggle maps proportionally to it (the bottom of the file).
      await tester.tap(find.byTooltip('原始视图'));
      await tester.pump();
      final rawBottom = currentPosition(tester).pixels;
      expect(rawBottom, greaterThan(0),
          reason: 'first raw view must open at the structured position');

      // Scroll the raw view up to the middle. (Drag DOWN = positive dy
      // scrolls toward the top.)
      await tester.dragFrom(
        paddingStripPoint(tester, find.byType(SingleChildScrollView)),
        const Offset(0, 4000),
      );
      await tester.pump();
      final rawOffset = currentPosition(tester).pixels;
      expect(rawOffset, lessThan(rawBottom - 3000),
          reason: 'the drag must move the raw view away from the bottom');

      await tester.tap(find.byTooltip('结构化视图'));
      await tester.pump();
      await tester.tap(find.byTooltip('原始视图'));
      await tester.pump();

      final restoredRawOffset = currentPosition(tester).pixels;
      expect(
        (restoredRawOffset - rawOffset).abs(),
        lessThan(100),
        reason: 'the raw view must be restored to the position the user '
            'was reading, not to the top or the bottom',
      );
    });
  });

  // ==================================================================
  // LogContentPage — layout
  // ==================================================================

  group('LogContentPage — layout', () {
    testWidgets('raw (plain text) view has generous edge padding',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LogContentPage(
            fileName: 'app_2024-01-01-00.log',
            content: buildLogContent(5),
          ),
        ),
      );
      await tester.tap(find.byTooltip('原始视图'));
      await tester.pump();

      final scrollView = tester
          .widget<SingleChildScrollView>(find.byType(SingleChildScrollView));
      final padding = scrollView.padding!.resolve(TextDirection.ltr);
      expect(padding.left, greaterThanOrEqualTo(20),
          reason: 'plain text mode needs roomy left edge whitespace');
      expect(padding.right, greaterThanOrEqualTo(20),
          reason: 'plain text mode needs roomy right edge whitespace');
    });

    testWidgets('structured view renders level icons for a large mixed log',
        (tester) async {
      final buffer = StringBuffer();
      for (var i = 0; i < 5000; i++) {
        switch (i % 4) {
          case 0:
            buffer.writeln('[2024-01-01 00:00:00] [ERROR] [S] boom $i');
          case 1:
            buffer.writeln('[2024-01-01 00:00:01] [WARN] [S] warn $i');
          case 2:
            buffer.writeln('[2024-01-01 00:00:02] [INFO] [S] info $i');
          default:
            buffer.writeln('[2024-01-01 00:00:03] [DEBUG] [S] debug $i');
        }
      }
      // A stack-trace style line with no level marker.
      buffer.writeln('   at package:stroom/src.dart line 42');
      // A blank line (must be skipped without error).
      buffer.writeln();

      await tester.pumpWidget(
        MaterialApp(
          home: LogContentPage(
            fileName: 'app_2024-01-01-00.log',
            content: buffer.toString(),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.error_outline), findsWidgets);
      expect(find.byIcon(Icons.warning_amber_rounded), findsWidgets);
      expect(find.byIcon(Icons.info_outline), findsWidgets);
      expect(find.byIcon(Icons.bug_report_outlined), findsWidgets);
      // Level colors are mapped by the parser — assert on whichever
      // ERROR/WARN lines happen to be visible after the entry auto-scroll.
      SelectableText firstVisibleLevelLine(String level) => tester.widget(
            find
                .byWidgetPredicate((w) =>
                    w is SelectableText && w.data?.contains('[$level]') == true)
                .first,
          );
      expect(firstVisibleLevelLine('ERROR').style?.color, Colors.red);
      expect(firstVisibleLevelLine('WARN').style?.color, Colors.orange);
    });
  });

  // ==================================================================
  // LogContentPage — actions
  // ==================================================================

  group('LogContentPage — actions', () {
    testWidgets('shows line count in the AppBar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LogContentPage(
            fileName: 'app_2024-01-01-00.log',
            content: buildLogContent(500),
          ),
        ),
      );
      // 500 written lines + trailing newline must report exactly 500.
      expect(find.text('共 500 行'), findsOneWidget);
    });

    testWidgets(
        'line count handles empty content and missing trailing '
        'newline', (tester) async {
      // Empty content: 0 lines.
      await tester.pumpWidget(
        MaterialApp(
          home: LogContentPage(fileName: 'f.log', content: ''),
        ),
      );
      expect(find.text('共 0 行'), findsOneWidget);
    });

    testWidgets('line count without trailing newline is exact', (tester) async {
      // No trailing newline: 'a\nb' is exactly 2 lines.
      await tester.pumpWidget(
        MaterialApp(
          home: LogContentPage(fileName: 'f.log', content: 'a\nb'),
        ),
      );
      expect(find.text('共 2 行'), findsOneWidget);
    });

    testWidgets('copy action copies the full content to the clipboard',
        (tester) async {
      final content = buildLogContent(3);
      final platformCalls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          platformCalls.add(call);
          return null;
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));

      await tester.pumpWidget(
        MaterialApp(
          home: LogContentPage(
            fileName: 'app_2024-01-01-00.log',
            content: content,
          ),
        ),
      );

      await tester.tap(find.byTooltip('复制全文'));
      await tester.pump();

      final copyCall = platformCalls
          .where((c) => c.method == 'Clipboard.setData')
          .lastOrNull;
      expect(copyCall, isNotNull,
          reason: 'copy button must write to the clipboard');
      expect((copyCall!.arguments as Map)['text'], content);
      expect(find.text('已复制全部日志内容'), findsOneWidget);
    });
  });
}
