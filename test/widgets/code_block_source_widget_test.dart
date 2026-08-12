import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/widgets/code_block_source_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CodeBlockSourceView - widget rendering', () {
    testWidgets('shows raw code as text', (tester) async {
      const code = 'print("hello")';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CodeBlockSourceView(code: code),
          ),
        ),
      );

      // The raw code should be visible as text
      expect(find.text(code), findsOneWidget);
    });

    testWidgets('shows line numbers for multiline code', (tester) async {
      const code = 'line1\nline2\nline3';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CodeBlockSourceView(code: code),
          ),
        ),
      );

      // Should have line numbers 1, 2, 3
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('shows line number 1 for single line code', (tester) async {
      const code = 'single line';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CodeBlockSourceView(code: code),
          ),
        ),
      );

      expect(find.text(code), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('shows wrap toggle as a pure icon (no text label)',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CodeBlockSourceView(code: 'some code'),
          ),
        ),
      );

      // Regression: toolbar buttons are icon-only — no text labels.
      expect(find.text('换行显示'), findsNothing);
      expect(find.text('取消换行'), findsNothing);
      expect(find.byIcon(Icons.wrap_text), findsOneWidget);
      // Accessibility is preserved via the icon semantic label.
      final wrapIcon = tester.widget<Icon>(find.byIcon(Icons.wrap_text));
      expect(wrapIcon.semanticLabel, isNotNull);
    });

    testWidgets('wrap toggle switches between wrap and no-wrap state',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CodeBlockSourceView(code: 'line1\nline2'),
          ),
        ),
      );

      // Initially shows '换行显示' semantic label (wrap off)
      var wrapIcon = tester.widget<Icon>(find.byIcon(Icons.wrap_text));
      expect(wrapIcon.semanticLabel, '换行显示');

      // Tap the wrap toggle icon
      await tester.tap(find.byIcon(Icons.wrap_text));
      await tester.pumpAndSettle();

      // After tap, semantic label becomes '取消换行' (wrap on)
      wrapIcon = tester.widget<Icon>(find.byIcon(Icons.wrap_text));
      expect(wrapIcon.semanticLabel, '取消换行');

      // Tap again to toggle back
      await tester.tap(find.byIcon(Icons.wrap_text));
      await tester.pumpAndSettle();

      // Should be back to '换行显示'
      wrapIcon = tester.widget<Icon>(find.byIcon(Icons.wrap_text));
      expect(wrapIcon.semanticLabel, '换行显示');
    });

    testWidgets('shows (empty) for empty code', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CodeBlockSourceView(code: ''),
          ),
        ),
      );

      expect(find.text('(empty)'), findsOneWidget);
      // No line numbers for empty code
      expect(find.text('1'), findsNothing);
    });

    testWidgets('toolbar buttons are compact circles, not oversized pills',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CodeBlockSourceView(code: 'some code'),
          ),
        ),
      );

      // Regression: the wrap toggle was a 38x50 rounded-rect pill. It must
      // be a small circle (CircleBorder, equal width/height well under 40).
      final wrapInkWell = tester.widget<InkWell>(
        find
            .ancestor(
              of: find.byIcon(Icons.wrap_text),
              matching: find.byType(InkWell),
            )
            .first,
      );
      expect(wrapInkWell.customBorder, isA<CircleBorder>(),
          reason: 'toolbar button must be circular, not a rounded pill');

      final btnRect = tester.getRect(
        find
            .ancestor(
              of: find.byIcon(Icons.wrap_text),
              matching: find.byType(InkWell),
            )
            .first,
      );
      expect(btnRect.height, lessThan(40),
          reason: 'toolbar button must be compact (was 50px tall)');
      expect(btnRect.width, equals(btnRect.height),
          reason: 'a circular button has equal width and height');
    });

    testWidgets('single-button toolbar hugs its button (no trailing blank)',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CodeBlockSourceView(code: 'some code'),
          ),
        ),
      );

      // Regression: the pill container was forced to minWidth 48 while the
      // single wrap-toggle button was only 38px wide, leaving a blank gap
      // on the right. The pill must end exactly where the button ends.
      final pill = find
          .ancestor(
            of: find.byIcon(Icons.wrap_text),
            matching: find.byType(Container),
          )
          .first;
      final button = find
          .ancestor(
            of: find.byIcon(Icons.wrap_text),
            matching: find.byType(InkWell),
          )
          .first;
      final pillRect = tester.getRect(pill);
      final btnRect = tester.getRect(button);
      expect(pillRect.width, equals(btnRect.width),
          reason: 'pill must not extend past its single button');
      expect(pillRect.height, equals(btnRect.height),
          reason: 'pill must not extend past its single button vertically');
    });

    testWidgets('action buttons appear after wrap toggle button',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CodeBlockSourceView(
              code: 'test',
              actionButtons: [
                TextButton(
                  onPressed: () {},
                  child: const Text('ExtraBtn'),
                ),
              ],
            ),
          ),
        ),
      );

      // Both the wrap toggle and the custom button should be visible
      expect(find.byIcon(Icons.wrap_text), findsOneWidget);
      expect(find.text('ExtraBtn'), findsOneWidget);

      // Wrap toggle must be positioned LEFT of the additional action
      // buttons (common/shared buttons sit on the right).
      final wrapPos = tester.getCenter(find.byIcon(Icons.wrap_text));
      final extraPos = tester.getCenter(find.text('ExtraBtn'));
      expect(wrapPos.dx, lessThan(extraPos.dx),
          reason: 'wrap toggle should be left of additional action buttons');
    });

    testWidgets('handles code with trailing newline', (tester) async {
      const code = 'line1\nline2\n';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CodeBlockSourceView(code: code),
          ),
        ),
      );

      // Three lines: 'line1', 'line2', ''
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });
  });

  group('CodeBlockSourceView - language label', () {
    testWidgets('shows the language label in the top-left corner',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CodeBlockSourceView(code: 'print("hi")', language: 'python'),
          ),
        ),
      );

      // The language string from the opening fence is shown as-is.
      expect(find.text('python'), findsOneWidget);
    });

    testWidgets('hides the language label when language is empty',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CodeBlockSourceView(code: 'plain block'),
          ),
        ),
      );

      // Plain fences (no info string) must not show a phantom label.
      expect(find.text('python'), findsNothing);
      // A phantom empty badge (empty Text) must not render either.
      expect(find.text(''), findsNothing);
      // The label badge container only exists when a language is set:
      // the code content and toolbar are still rendered.
      expect(find.text('plain block'), findsOneWidget);
      expect(find.byIcon(Icons.wrap_text), findsOneWidget);
    });

    testWidgets('hides the language label while the code is empty',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CodeBlockSourceView(code: '', language: 'python'),
          ),
        ),
      );

      // Regression: an empty tagged block (transient mid-stream) must not
      // paint the badge over the "(empty)" placeholder.
      expect(find.text('(empty)'), findsOneWidget);
      expect(find.text('python'), findsNothing);
    });
  });

  group('CodeBlockSourceView - height behavior', () {
    testWidgets('no-wrap mode scrolls horizontally, wrap mode does not',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const code = 'line1\nline2\nline3';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CodeBlockSourceView(code: code),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final horizontalScrollables = find.byWidgetPredicate(
          (w) => w is Scrollable && w.axis == Axis.horizontal);
      expect(horizontalScrollables, findsWidgets,
          reason: 'No-wrap mode should have horizontal scroll');

      await tester.tap(find.byIcon(Icons.wrap_text));
      await tester.pumpAndSettle();

      final horizontalScrollablesAfter = find.byWidgetPredicate(
          (w) => w is Scrollable && w.axis == Axis.horizontal);
      expect(horizontalScrollablesAfter, findsNothing,
          reason: 'Wrap mode should have no horizontal scroll');
    });

    testWidgets('caps height at 15 visible lines for tall code',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // 50 lines — far beyond the 15-line cap. lineHeight = 13 * 1.5,
      // top toolbar padding 40 + bottom 12.
      final code = List.generate(50, (i) => 'line $i').join('\n');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CodeBlockSourceView(code: code),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 50 lines — far beyond the 15-line cap. lineHeight = 13 * 1.5,
      // top toolbar padding 40 + bottom 12.
      final sizedBox = find
          .descendant(
            of: find.byType(CodeBlockSourceView),
            matching: find.byType(SizedBox),
          )
          .first;
      final sizedBoxWidget = tester.widget<SizedBox>(sizedBox);
      const expected = 15 * 13.0 * 1.5 + 40.0 + 12.0;
      expect(sizedBoxWidget.height, equals(expected),
          reason: 'Height should be capped at 15 lines (was 4:3 aspect)');
    });

    testWidgets('short code stays compact (not padded to 15 lines)',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CodeBlockSourceView(code: 'one line'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1 line: 19.5 + 52 padding — far below the 15-line cap.
      final sizedBox = find
          .descendant(
            of: find.byType(CodeBlockSourceView),
            matching: find.byType(SizedBox),
          )
          .first;
      final sizedBoxWidget = tester.widget<SizedBox>(sizedBox);
      expect(sizedBoxWidget.height, equals(1 * 13.0 * 1.5 + 40.0 + 12.0),
          reason: 'Short code must not be stretched to the 15-line cap');
    });

    testWidgets('respects explicit height property', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CodeBlockSourceView(
                code: 'short code',
                height: 200,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the SizedBox - should use 200
      final sizedBox = find.byType(SizedBox).first;
      final sizedBoxWidget = tester.widget<SizedBox>(sizedBox);

      expect(sizedBoxWidget.height, equals(200),
          reason: 'Explicit height should be respected');
    });
  });
}
