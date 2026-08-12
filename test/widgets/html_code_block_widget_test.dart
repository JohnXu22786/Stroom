import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/widgets/code_block_source_widget.dart';
import 'package:stroom/widgets/html_code_block_widget.dart';

/// Helper: taps the "查看代码" card button to reveal the raw source view.
Future<void> _showCodeView(WidgetTester tester) async {
  await tester.tap(find.text('查看代码'));
  await tester.pumpAndSettle();
}

/// The root sizing SizedBox of the code block display (first descendant
/// box of [CodeBlockSourceView], independent of unrelated boxes above it).
Finder _codeBlockSizeBox() => find
    .descendant(
      of: find.byType(CodeBlockSourceView),
      matching: find.byType(SizedBox),
    )
    .first;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HtmlCodeBlockWidget - card preview (default)', () {
    testWidgets('shows a card with language badge, inline title and two '
        'action buttons', (tester) async {
      const html = '<html><head><title>My Cool Page</title></head>'
          '<body><h1>Hello World</h1></body></html>';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HtmlCodeBlockWidget(htmlCode: html),
          ),
        ),
      );

      // The language badge (the fence info string) is shown top-left.
      expect(find.text('html'), findsOneWidget);
      // The extracted <title> is displayed inline as a centered line ABOVE
      // the action buttons (no separate 标题 button anymore).
      expect(find.text('My Cool Page'), findsOneWidget);
      final titleY = tester.getTopLeft(find.text('My Cool Page')).dy;
      final fullscreenY =
          tester.getTopLeft(find.widgetWithText(OutlinedButton, '全屏查看')).dy;
      expect(titleY, lessThan(fullscreenY));
      // The two remaining action buttons.
      expect(find.text('标题'), findsNothing);
      expect(find.text('全屏查看'), findsOneWidget);
      expect(find.text('查看代码'), findsOneWidget);
      // The raw HTML is NOT shown by default — the card replaces the code.
      expect(find.text('<h1>Hello World</h1>'), findsNothing);
    });

    testWidgets('while generating shows 正在生成中 and disables 全屏查看',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HtmlCodeBlockWidget(
              htmlCode: '<h1>Hello</h1>',
              isStreaming: true,
            ),
          ),
        ),
      );

      expect(find.textContaining('正在生成中'), findsOneWidget);

      // 全屏查看 is disabled while generating; 查看代码 stays enabled.
      final fullscreenBtn = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, '全屏查看'),
      );
      expect(fullscreenBtn.onPressed, isNull,
          reason: 'full-screen preview must be disabled while generating');
      final codeBtn = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, '查看代码'),
      );
      expect(codeBtn.onPressed, isNotNull);
    });

    testWidgets('finished card shows no 正在生成中 and enables 全屏查看',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HtmlCodeBlockWidget(htmlCode: '<h1>Hello</h1>'),
          ),
        ),
      );

      expect(find.textContaining('正在生成中'), findsNothing);
      final fullscreenBtn = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, '全屏查看'),
      );
      expect(fullscreenBtn.onPressed, isNotNull);
    });

    testWidgets('card does not overflow in a narrow bubble', (tester) async {
      // Narrow surface (~phone width): the two buttons must fit (wrapping
      // onto a second row if needed) instead of overflowing the card.
      await tester.binding.setSurfaceSize(const Size(320, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HtmlCodeBlockWidget(htmlCode: '<h1>Hello</h1>'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull,
          reason: 'no RenderFlex/overflow exception in a narrow bubble');
      expect(find.text('全屏查看'), findsOneWidget);
      expect(find.text('查看代码'), findsOneWidget);
    });

    testWidgets('badge shows the fence language as-is', (tester) async {
      // ```HTML (uppercase) must render as a card with an "HTML" badge,
      // not a plain code block.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HtmlCodeBlockWidget(
              htmlCode: '<h1>Hello</h1>',
              language: 'HTML',
            ),
          ),
        ),
      );

      expect(find.text('HTML'), findsOneWidget);
      expect(find.text('html'), findsNothing);
    });

    testWidgets('finished empty card shows the (empty) hint directly',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HtmlCodeBlockWidget(htmlCode: ''),
          ),
        ),
      );

      // A finalized empty html block must hint emptiness without requiring
      // the user to open the code view.
      expect(find.text('(empty)'), findsOneWidget);
      // And while generating, the streaming indicator wins over the hint.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HtmlCodeBlockWidget(htmlCode: '', isStreaming: true),
          ),
        ),
      );
      expect(find.text('(empty)'), findsNothing);
      expect(find.textContaining('正在生成中'), findsOneWidget);
    });
  });

  group('HtmlCodeBlockWidget - code view toggle', () {
    testWidgets('查看代码 reveals the raw code with an EYE preview icon',
        (tester) async {
      const html = '<h1>Hello World</h1>';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HtmlCodeBlockWidget(htmlCode: html),
          ),
        ),
      );

      await _showCodeView(tester);

      // Raw code is now visible.
      expect(find.text(html), findsOneWidget);
      // HTML code view uses the EYE icon (preview), not fullscreen.
      expect(find.byIcon(Icons.visibility), findsOneWidget);
      expect(find.byIcon(Icons.fullscreen), findsNothing,
          reason: 'HTML-only: the code view preview must be an eye icon');
      // A way back to the card exists.
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      // Card buttons are gone.
      expect(find.text('查看代码'), findsNothing);
    });

    testWidgets('eye icon carries the 预览 semantic label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HtmlCodeBlockWidget(htmlCode: '<p>test</p>'),
          ),
        ),
      );

      await _showCodeView(tester);

      final eyeIcon = tester.widget<Icon>(find.byIcon(Icons.visibility));
      expect(eyeIcon.semanticLabel, '预览');
    });

    testWidgets('返回卡片 switches back to the card view', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HtmlCodeBlockWidget(htmlCode: '<p>test</p>'),
          ),
        ),
      );

      await _showCodeView(tester);
      expect(find.text('查看代码'), findsNothing);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('查看代码'), findsOneWidget);
      expect(find.byIcon(Icons.visibility), findsNothing);
    });

    testWidgets('code view survives a streaming -> finished rebuild',
        (tester) async {
      // While the user is viewing the raw code, the stream finishes and
      // the widget rebuilds with isStreaming: false. The code view must
      // NOT silently reset back to the card.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HtmlCodeBlockWidget(
              htmlCode: '<p>growing</p>',
              isStreaming: true,
            ),
          ),
        ),
      );

      await _showCodeView(tester);
      expect(find.byIcon(Icons.visibility), findsOneWidget);

      // Simulate the stream finishing: same widget position, new flags.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HtmlCodeBlockWidget(
              htmlCode: '<p>growing</p>',
              isStreaming: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.visibility), findsOneWidget,
          reason: 'code view must persist across a streaming->finished '
              'rebuild');
      expect(find.text('查看代码'), findsNothing);
    });
  });

  group('HtmlCodeBlockWidget - code view behavior (regressions)', () {
    testWidgets('wrap toggle still works in the code view', (tester) async {
      const html = '<div>\n  <p>Line 1</p>\n</div>';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HtmlCodeBlockWidget(htmlCode: html),
          ),
        ),
      );

      await _showCodeView(tester);

      var wrapIcon = tester.widget<Icon>(find.byIcon(Icons.wrap_text));
      expect(wrapIcon.semanticLabel, '换行显示');

      await tester.tap(find.byIcon(Icons.wrap_text));
      await tester.pumpAndSettle();

      wrapIcon = tester.widget<Icon>(find.byIcon(Icons.wrap_text));
      expect(wrapIcon.semanticLabel, '取消换行');
    });

    testWidgets('line numbers are shown in the code view', (tester) async {
      const html = '<div>\n  <p>Line 1</p>\n</div>';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HtmlCodeBlockWidget(htmlCode: html),
          ),
        ),
      );

      await _showCodeView(tester);

      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('shows (empty) for empty HTML code', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HtmlCodeBlockWidget(htmlCode: ''),
          ),
        ),
      );

      await _showCodeView(tester);

      expect(find.text('(empty)'), findsOneWidget);
      expect(find.text('1'), findsNothing);
    });
  });

  group('HtmlCodeBlockWidget - title display', () {
    testWidgets('shows the extracted document title as a centered single '
        'line', (tester) async {
      const html = '<html><head><title>My Cool Page</title></head>'
          '<body><h1>Hi</h1></body></html>';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HtmlCodeBlockWidget(htmlCode: html),
          ),
        ),
      );

      final titleText = tester.widget<Text>(find.text('My Cool Page'));
      expect(titleText.textAlign, TextAlign.center);
      expect(titleText.maxLines, 1);
      expect(titleText.overflow, TextOverflow.ellipsis);
      // The old 标题 button is gone.
      expect(find.text('标题'), findsNothing);
    });

    testWidgets('shows no title line when the HTML has no title',
        (tester) async {
      const html = '<body><p>no title here</p></body>';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HtmlCodeBlockWidget(htmlCode: html),
          ),
        ),
      );

      expect(find.text('（无标题）'), findsNothing,
          reason: 'no fallback placeholder for a missing title');
      expect(find.text('标题'), findsNothing);
      // The two action buttons still render.
      expect(find.text('全屏查看'), findsOneWidget);
      expect(find.text('查看代码'), findsOneWidget);
    });

    testWidgets('long titles are ellipsized instead of wrapping',
        (tester) async {
      final longTitle = List.filled(30, 'title').join(' ');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HtmlCodeBlockWidget(
              htmlCode: '<title>$longTitle</title>',
            ),
          ),
        ),
      );

      final titleText = tester.widget<Text>(find.text(longTitle));
      expect(titleText.maxLines, 1);
      expect(titleText.overflow, TextOverflow.ellipsis);
    });
  });

  group('HtmlCodeBlockWidget.extractHtmlTitle', () {
    test('extracts a plain title tag', () {
      expect(
        HtmlCodeBlockWidget.extractHtmlTitle(
            '<html><head><title>My Page</title></head></html>'),
        'My Page',
      );
    });

    test('trims surrounding whitespace', () {
      expect(
        HtmlCodeBlockWidget.extractHtmlTitle('<title>   Spaced   </title>'),
        'Spaced',
      );
    });

    test('is case-insensitive', () {
      expect(
        HtmlCodeBlockWidget.extractHtmlTitle('<TiTlE>Case Insensitive</tItLe>'),
        'Case Insensitive',
      );
    });

    test('returns empty when no title exists', () {
      expect(HtmlCodeBlockWidget.extractHtmlTitle('<body>no title</body>'), '');
      expect(HtmlCodeBlockWidget.extractHtmlTitle('<title>unclosed'), '');
      expect(HtmlCodeBlockWidget.extractHtmlTitle(''), '');
    });
  });

  group('HtmlCodeBlockWidget - height behavior', () {
    testWidgets('caps the code view height at 15 visible lines',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final lines = List.generate(50, (i) => '<p>Line $i</p>').join('\n');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: HtmlCodeBlockWidget(htmlCode: lines),
            ),
          ),
        ),
      );

      await _showCodeView(tester);

      final sizedBoxWidget = tester.widget<SizedBox>(_codeBlockSizeBox());
      const expected = 15 * 13.0 * 1.5 + 40.0 + 12.0;
      expect(sizedBoxWidget.height, equals(expected),
          reason: 'Tall HTML should be capped at 15 lines, not 4:3 of width');
    });

    testWidgets('short code stays compact in the code view', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: HtmlCodeBlockWidget(htmlCode: '<p>Hello</p>'),
            ),
          ),
        ),
      );

      await _showCodeView(tester);

      final sizedBoxWidget = tester.widget<SizedBox>(_codeBlockSizeBox());
      expect(sizedBoxWidget.height, equals(1 * 13.0 * 1.5 + 40.0 + 12.0),
          reason: 'Short code must not be stretched to the 15-line cap');
    });

    testWidgets('respects custom height property in the code view',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: HtmlCodeBlockWidget(
                htmlCode: '<p>Hello</p>',
                height: 200,
              ),
            ),
          ),
        ),
      );

      await _showCodeView(tester);

      final sizedBoxWidget = tester.widget<SizedBox>(_codeBlockSizeBox());
      expect(sizedBoxWidget.height, equals(200),
          reason: 'Custom height should override adaptive sizing');
    });
  });
}
