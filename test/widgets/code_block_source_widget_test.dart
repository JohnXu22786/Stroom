import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
// The platform interface lives under the package's src/ (not exported
// publicly); extending it is the supported way to fake the save dialog.
// ignore_for_file: implementation_imports
import 'package:file_picker/src/platform/file_picker_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/widgets/code_block_source_widget.dart';

import '../fake_file_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Pumps a standalone [CodeBlockSourceView] in a Scaffold.
  Future<void> pumpCodeBlock(
    WidgetTester tester, {
    String code = 'some code',
    String language = '',
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CodeBlockSourceView(code: code, language: language),
        ),
      ),
    );
  }

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

    testWidgets('toolbar pill hugs its buttons (no trailing blank)',
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
      // on the right. The pill must start exactly where the first button
      // (copy) starts and end exactly where the last button (wrap) ends.
      final pill = find
          .ancestor(
            of: find.byIcon(Icons.wrap_text),
            matching: find.byType(Container),
          )
          .first;
      final copyButton = find
          .ancestor(
            of: find.byIcon(Icons.copy),
            matching: find.byType(InkWell),
          )
          .first;
      final wrapButton = find
          .ancestor(
            of: find.byIcon(Icons.wrap_text),
            matching: find.byType(InkWell),
          )
          .first;
      final pillRect = tester.getRect(pill);
      final copyRect = tester.getRect(copyButton);
      final wrapRect = tester.getRect(wrapButton);
      expect(pillRect.left, equals(copyRect.left),
          reason: 'pill must start where its first button starts');
      expect(pillRect.right, equals(wrapRect.right),
          reason: 'pill must not extend past its last button');
      expect(pillRect.top, equals(copyRect.top),
          reason: 'pill must not extend past its buttons vertically');
      expect(pillRect.bottom, equals(copyRect.bottom));
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

  group('CodeBlockSourceView - default wrap state by language', () {
    /// Pumps a standalone [CodeBlockSourceView] inside a narrow column so
    /// wrap mode is structurally observable (no horizontal scroll view).
    Future<void> pumpWrapped(
      WidgetTester tester, {
      required String language,
      String code = 'line1\nline2',
    }) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              child: CodeBlockSourceView(
                // Key by language so re-pumping a loop iteration forces a
                // fresh State: the wrap default is computed in initState,
                // which would otherwise only run for the first language.
                key: ValueKey(language),
                code: code,
                language: language,
              ),
            ),
          ),
        ),
      );
    }

    Finder horizontalScrollViews() => find.byWidgetPredicate(
        (w) => w is Scrollable && w.axis == Axis.horizontal);

    String? wrapLabel(WidgetTester tester) =>
        tester.widget<Icon>(find.byIcon(Icons.wrap_text)).semanticLabel;

    testWidgets('markdown blocks start wrapped', (tester) async {
      await pumpWrapped(tester, language: 'markdown');
      expect(wrapLabel(tester), '取消换行',
          reason: 'markdown is prose — must wrap by default');
      expect(horizontalScrollViews(), findsNothing,
          reason: 'wrap mode must have no horizontal scroll view');
    });

    testWidgets('md blocks start wrapped (language is case-insensitive)',
        (tester) async {
      await pumpWrapped(tester, language: 'MD');
      expect(wrapLabel(tester), '取消换行');
      expect(horizontalScrollViews(), findsNothing);
    });

    testWidgets('text / plaintext / txt blocks start wrapped', (tester) async {
      for (final language in ['text', 'plaintext', 'txt']) {
        await pumpWrapped(tester, language: language);
        expect(wrapLabel(tester), '取消换行',
            reason: "'$language' is plain text — must wrap by default");
        expect(horizontalScrollViews(), findsNothing,
            reason: "'$language' must have no horizontal scroll view");
      }
    });

    testWidgets('other languages and plain fences start no-wrap',
        (tester) async {
      for (final language in ['python', 'json', '']) {
        await pumpWrapped(tester, language: language);
        expect(wrapLabel(tester), '换行显示',
            reason: "'$language' is code — must NOT wrap by default");
        expect(horizontalScrollViews(), findsOneWidget,
            reason: "'$language' must keep the horizontal scroll view");
      }
    });

    testWidgets('wrap toggle still works from the wrapped default state',
        (tester) async {
      await pumpWrapped(tester, language: 'markdown');
      expect(wrapLabel(tester), '取消换行');

      // Toggle off → no-wrap (horizontal scroll view appears).
      await tester.tap(find.byIcon(Icons.wrap_text));
      await tester.pumpAndSettle();
      expect(wrapLabel(tester), '换行显示');
      expect(horizontalScrollViews(), findsOneWidget);

      // Toggle back on → wrapped again.
      await tester.tap(find.byIcon(Icons.wrap_text));
      await tester.pumpAndSettle();
      expect(wrapLabel(tester), '取消换行');
      expect(horizontalScrollViews(), findsNothing);
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

  group('CodeBlockSourceView - multi-line selection', () {
    testWidgets('no-wrap mode renders the whole code as ONE SelectableText',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CodeBlockSourceView(code: 'l1\nl2\nl3'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The full code (all lines) must live inside a single SelectableText so
      // a drag selection can span multiple lines.
      final selectables = find.byType(SelectableText);
      expect(selectables, findsOneWidget,
          reason: 'the whole code should be one SelectableText');
      expect(
        tester.widget<SelectableText>(selectables).data,
        'l1\nl2\nl3',
        reason: 'the single SelectableText must contain every line',
      );
    });

    testWidgets('wrap mode renders the whole code as ONE SelectableText',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CodeBlockSourceView(code: 'l1\nl2\nl3'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enable wrap.
      await tester.tap(find.byIcon(Icons.wrap_text));
      await tester.pumpAndSettle();

      // Regression: wrap mode used one SelectableText per line, which made it
      // impossible to drag-select across lines. It must be a single
      // SelectableText holding the whole code.
      final selectables = find.byType(SelectableText);
      expect(selectables, findsOneWidget,
          reason: 'wrap mode should still expose one SelectableText');
      expect(
        tester.widget<SelectableText>(selectables).data,
        'l1\nl2\nl3',
        reason: 'the single SelectableText must contain every line',
      );
    });
  });

  group('CodeBlockSourceView - line number alignment', () {
    // Returns the global top of every logical code line as ACTUALLY rendered
    // by the code's SelectableText (via RenderEditable caret rects) — ground
    // truth independent of the widget's own gutter measurement.
    List<double> renderedLineTops(WidgetTester tester, String code) {
      final editable = find
          .descendant(
            of: find.byType(CodeBlockSourceView),
            matching: find.byElementPredicate(
              (e) => e.renderObject is RenderEditable,
            ),
          )
          .first;
      final renderEditable = tester.renderObject<RenderEditable>(editable);
      final editableTop = renderEditable.localToGlobal(Offset.zero).dy;

      final tops = <double>[];
      var offset = 0;
      for (final line in code.split('\n')) {
        final caretRect =
            renderEditable.getLocalRectForCaret(TextPosition(offset: offset));
        tops.add(editableTop + caretRect.top);
        offset += line.length + 1;
      }
      return tops;
    }

    // Asserts each gutter number lines up with the actual rendered line.
    // Caret rects carry a small constant leading offset vs the text box, so
    // compare line-to-line SPACING rather than absolute positions.
    void expectGutterAlignsWithRender(WidgetTester tester, String code) {
      final renderTops = renderedLineTops(tester, code);
      final firstRenderTop = renderTops.first;
      final firstNumTop = tester.getTopLeft(find.text('1')).dy;

      for (var i = 1; i < renderTops.length; i++) {
        final numTop = tester.getTopLeft(find.text('${i + 1}')).dy;
        expect(
          numTop - firstNumTop,
          closeTo(renderTops[i] - firstRenderTop, 0.01),
          reason: 'line number ${i + 1} must align with code line ${i + 1} '
              '(drifts if the gutter uses a hardcoded or wrong line height)',
        );
      }
    }

    testWidgets('no-wrap line numbers align with code lines', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Use a non-trivial text scale so the rendered line height provably
      // differs from any hardcoded constant, keeping this test meaningful
      // regardless of the test font's metrics.
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(
          () => tester.platformDispatcher.clearTextScaleFactorTestValue());

      const code = 'aaaa\nbbbb\ncccc\ndddd';
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

      expectGutterAlignsWithRender(tester, code);
    });

    testWidgets('wrap mode line numbers align with wrapped code lines',
        (tester) async {
      final style = TextStyle(
        fontFamily: 'monospace',
        fontSize: 13,
        height: 1.5,
      );
      final charWidth = (TextPainter(
        text: TextSpan(text: 'x', style: style),
        textDirection: TextDirection.ltr,
      )..layout())
          .width;

      // codeAreaWidth = surfaceWidth - 1 (borders) - 12 (right padding)
      //   - 32 (gutter) - 8 (gap) = surfaceWidth - 53.
      // Search for a surface width where line 1 lands in the
      // (codeAreaWidth - 3, codeAreaWidth] band: it fits the widget's
      // measurement width but the render wraps it (RenderEditable reserves a
      // 3px caret margin). Only such a line exposes wrap-width drift.
      int? bandSurfaceWidth;
      int? lineLength;
      for (var s = 300; s <= 1200; s++) {
        final codeAreaWidth = s - 53.0;
        final n = (codeAreaWidth / charWidth).floor();
        if (n < 1) continue;
        if (n * charWidth > codeAreaWidth - 3.0) {
          bandSurfaceWidth = s;
          lineLength = n;
          break;
        }
      }
      expect(bandSurfaceWidth, isNotNull,
          reason: 'a band-hitting surface width must exist for this font');

      await tester.binding
          .setSurfaceSize(Size(bandSurfaceWidth!.toDouble(), 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final code = '${'x' * lineLength!}\nshort';
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

      await tester.tap(find.byIcon(Icons.wrap_text));
      await tester.pumpAndSettle();

      expectGutterAlignsWithRender(tester, code);
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

  group('CodeBlockSourceView - streaming auto-scroll', () {
    // The vertical code-area scroll view (the outer SingleChildScrollView;
    // no-wrap mode also has a nested horizontal one).
    Finder verticalScrollView() => find.byWidgetPredicate((w) =>
        w is SingleChildScrollView && w.scrollDirection == Axis.vertical);

    ScrollPosition position(WidgetTester tester) => tester
        .widget<SingleChildScrollView>(verticalScrollView())
        .controller!
        .position;

    String longCode(int lines) =>
        List.generate(lines, (i) => 'line $i').join('\n');

    /// Pumps the block in a fixed 200px-high viewport (40 lines overflow
    /// it) and drains the frame so post-frame auto-scroll jumps have run.
    Future<void> pumpBlock(
      WidgetTester tester, {
      required String code,
      required bool isStreaming,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                child: CodeBlockSourceView(
                  code: code,
                  height: 200,
                  isStreaming: isStreaming,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('pins the scroll position to the bottom while the code grows',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpBlock(tester, code: longCode(7), isStreaming: true);
      // Content fits the viewport initially — nothing to scroll yet.
      expect(position(tester).maxScrollExtent, 0);

      // Streaming content grows past the viewport: the block must stay
      // pinned to its bottom edge, with no resume button while following.
      await pumpBlock(tester, code: longCode(40), isStreaming: true);
      expect(position(tester).pixels,
          closeTo(position(tester).maxScrollExtent, 0.5),
          reason: 'growing streaming code must stay pinned to the bottom');
      expect(find.byIcon(Icons.arrow_downward), findsNothing);

      // A further growth keeps the pin.
      await pumpBlock(tester, code: longCode(80), isStreaming: true);
      expect(position(tester).pixels,
          closeTo(position(tester).maxScrollExtent, 0.5));
    });

    testWidgets(
        'shows the resume button after a manual interrupt, resumes on tap, '
        'and re-engages when scrolled back to the bottom', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpBlock(tester, code: longCode(40), isStreaming: true);
      expect(position(tester).pixels,
          closeTo(position(tester).maxScrollExtent, 0.5));

      // The user drags the code area down (scrolling toward the top): the
      // auto-scroll must stop and the resume button must appear.
      await tester.drag(verticalScrollView(), const Offset(0, 150));
      await tester.pump();
      expect(find.byIcon(Icons.arrow_downward), findsOneWidget,
          reason: 'interrupting the auto-scroll must show the resume button');
      expect(position(tester).pixels,
          lessThan(position(tester).maxScrollExtent - 40));

      // Tapping the button resumes the auto-scroll: back to the bottom,
      // button hidden.
      await tester.tap(find.byIcon(Icons.arrow_downward));
      await tester.pump();
      expect(find.byIcon(Icons.arrow_downward), findsNothing);
      expect(position(tester).pixels,
          closeTo(position(tester).maxScrollExtent, 0.5));

      // Interrupt again, then scroll back to the bottom manually: the
      // auto-scroll re-engages and the button hides (mirrors the chat list).
      await tester.drag(verticalScrollView(), const Offset(0, 150));
      await tester.pump();
      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);

      await tester.drag(verticalScrollView(), const Offset(0, -300));
      await tester.pump();
      expect(find.byIcon(Icons.arrow_downward), findsNothing);
      expect(position(tester).pixels,
          closeTo(position(tester).maxScrollExtent, 0.5));
    });

    testWidgets('animates back to the top when the block finishes generating',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpBlock(tester, code: longCode(40), isStreaming: true);
      expect(position(tester).pixels,
          closeTo(position(tester).maxScrollExtent, 0.5));

      // The fence closes — the block is no longer the one being generated.
      await pumpBlock(tester, code: longCode(40), isStreaming: false);
      await tester.pumpAndSettle();

      expect(position(tester).pixels, closeTo(0, 0.5),
          reason: 'a finished block must return to its top (non-linear)');
      expect(find.byIcon(Icons.arrow_downward), findsNothing,
          reason: 'no resume button once generation is complete');
    });

    testWidgets('does not yank an interrupted block to the top on completion',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpBlock(tester, code: longCode(40), isStreaming: true);
      // Interrupt: scroll toward the top and hold there.
      await tester.drag(verticalScrollView(), const Offset(0, 150));
      await tester.pump();
      final interrupted = position(tester).pixels;
      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);

      // The block finishes generating: no forced scroll (the user broke
      // the auto-scroll session), and the resume button is hidden.
      await pumpBlock(tester, code: longCode(40), isStreaming: false);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_downward), findsNothing,
          reason: 'the resume button must not show after generation completes');
      expect(position(tester).pixels, closeTo(interrupted, 0.5),
          reason: 'an interrupted block must keep the user reading position');
    });

    testWidgets('does not re-pin after an interrupt while streaming continues',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpBlock(tester, code: longCode(40), isStreaming: true);
      await tester.drag(verticalScrollView(), const Offset(0, 150));
      await tester.pump();
      final interrupted = position(tester).pixels;

      // The stream keeps growing, but the user interrupted: the block
      // must stay where the user left it (no re-pinning to the bottom).
      await pumpBlock(tester, code: longCode(80), isStreaming: true);
      expect(position(tester).pixels, closeTo(interrupted, 0.5),
          reason: 'a manual interrupt must stop the auto-scroll for good');
      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    });

    testWidgets(
        'does not yank to the top on completion while the finger is held',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpBlock(tester, code: longCode(40), isStreaming: true);
      // The user puts a finger on the block and drags a little — still
      // within the at-bottom window, so the auto-scroll is still engaged,
      // but the block must not fight the finger.
      final gesture =
          await tester.startGesture(tester.getCenter(verticalScrollView()));
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump();
      expect(position(tester).pixels,
          greaterThan(position(tester).maxScrollExtent - 40));

      // The block finishes generating while the finger is down: no forced
      // scroll to the top.
      await pumpBlock(tester, code: longCode(40), isStreaming: false);
      await tester.pumpAndSettle();
      expect(position(tester).pixels,
          closeTo(position(tester).maxScrollExtent, 40),
          reason: 'a held finger must suppress the return-to-top animation');

      await gesture.up();
      await tester.pump();
      expect(find.byIcon(Icons.arrow_downward), findsNothing);
    });

    testWidgets('engages the follow when streaming starts from empty code',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // A freshly opened fence: empty code, "(empty)" placeholder, no
      // scroll view attached yet.
      await pumpBlock(tester, code: '', isStreaming: true);
      // The first code arrives: the scroll view attaches and the block
      // pins to the bottom.
      await pumpBlock(tester, code: longCode(40), isStreaming: true);
      expect(position(tester).pixels,
          closeTo(position(tester).maxScrollExtent, 0.5),
          reason: 'the follow must engage as soon as code starts arriving');
      expect(find.byIcon(Icons.arrow_downward), findsNothing);
    });

    testWidgets(
        'reconciles the button state when metric-only changes move the '
        'position to the bottom', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpBlock(tester, code: longCode(40), isStreaming: true);
      // Interrupt the auto-scroll: button visible, auto-scroll off.
      await tester.drag(verticalScrollView(), const Offset(0, 150));
      await tester.pump();
      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);

      // The content shrinks (e.g. the user toggles wrap mode off and the
      // lines no longer wrap): the position clamps to the new bottom
      // without firing a scroll event. The button must hide again.
      await pumpBlock(tester, code: longCode(7), isStreaming: true);
      expect(find.byIcon(Icons.arrow_downward), findsNothing,
          reason: 'the button must reflect the current metrics, not the '
              'last scroll action');
      expect(position(tester).pixels,
          closeTo(position(tester).maxScrollExtent, 0.5));
    });

    testWidgets('a horizontal drag does not interrupt the vertical follow',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Long lines so no-wrap mode has horizontal overflow to pan.
      final longCodeWithWideLines =
          List.generate(40, (i) => 'line $i ' * 10).join('\n');
      await pumpBlock(tester, code: longCodeWithWideLines, isStreaming: true);
      expect(position(tester).pixels,
          closeTo(position(tester).maxScrollExtent, 0.5));

      final horizontalScrollView = find.byWidgetPredicate((w) =>
          w is SingleChildScrollView && w.scrollDirection == Axis.horizontal);
      expect(horizontalScrollView, findsOneWidget);

      // Hold a horizontal pan (finger down) and let the code grow: the
      // vertical follow must stay engaged — a horizontal pan is not an
      // interrupt of the vertical auto-scroll.
      final gesture =
          await tester.startGesture(tester.getCenter(horizontalScrollView));
      await gesture.moveBy(const Offset(-100, 0));
      await tester.pump();

      await pumpBlock(tester,
          code: '$longCodeWithWideLines\nline extra', isStreaming: true);
      expect(position(tester).pixels,
          closeTo(position(tester).maxScrollExtent, 0.5),
          reason: 'a horizontal pan must not interrupt the vertical follow');
      expect(find.byIcon(Icons.arrow_downward), findsNothing);

      await gesture.up();
      await tester.pump();
    });

    testWidgets(
        'a finished block never re-engages the follow when mislabeled as '
        'generating again', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final code = longCode(40);
      // Streaming (following) → fence closes (completes, returns to top).
      await pumpBlock(tester, code: code, isStreaming: true);
      expect(position(tester).pixels,
          closeTo(position(tester).maxScrollExtent, 0.5));
      await pumpBlock(tester, code: code, isStreaming: false);
      await tester.pumpAndSettle();
      expect(position(tester).pixels, closeTo(0, 0.5));

      // The content-based tail check mislabels the closed block as the
      // still-open trailing block again (identical content): the latch
      // must keep the auto-scroll (and the resume button) off.
      await pumpBlock(tester, code: code, isStreaming: true);
      await tester.pump();
      expect(position(tester).pixels, closeTo(0, 0.5),
          reason: 'a finished block must not re-engage the auto-scroll');
      expect(find.byIcon(Icons.arrow_downward), findsNothing);

      // Further growth stays unpinned and button-free.
      await pumpBlock(tester, code: longCode(80), isStreaming: true);
      expect(position(tester).pixels, closeTo(0, 0.5),
          reason: 'growth must not re-pin a completed block');
      expect(find.byIcon(Icons.arrow_downward), findsNothing);
    });

    testWidgets(
        'a static block re-labeled as generating with unchanged code stays '
        'static', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final code = longCode(40);
      // Born as a static (non-streaming) block — e.g. a closed block in a
      // freshly rebuilt message.
      await pumpBlock(tester, code: code, isStreaming: false);
      expect(position(tester).pixels, 0);

      // The content-based tail check mislabels it as the still-open
      // trailing block with UNCHANGED code: a real generating block always
      // arrives with new code, so this must latch the block as finished —
      // no auto-scroll, no button.
      await pumpBlock(tester, code: code, isStreaming: true);
      await tester.pump();
      expect(position(tester).pixels, 0,
          reason: 'a static block must not start following when re-labeled '
              'with unchanged code');
      expect(find.byIcon(Icons.arrow_downward), findsNothing);

      // Further growth stays unpinned and button-free.
      await pumpBlock(tester, code: longCode(80), isStreaming: true);
      expect(position(tester).pixels, 0);
      expect(find.byIcon(Icons.arrow_downward), findsNothing);
    });

    testWidgets(
        'a re-engaged auto-scroll animates back to the top on completion',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpBlock(tester, code: longCode(40), isStreaming: true);
      // Interrupt, then scroll back to the bottom: the auto-scroll
      // re-engages and the button hides (mirrors the chat list).
      await tester.drag(verticalScrollView(), const Offset(0, 150));
      await tester.pump();
      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
      await tester.drag(verticalScrollView(), const Offset(0, -300));
      await tester.pump();
      expect(find.byIcon(Icons.arrow_downward), findsNothing);
      expect(position(tester).pixels,
          closeTo(position(tester).maxScrollExtent, 0.5));

      // The block finishes generating while the session is re-engaged:
      // it must animate back to the top.
      await pumpBlock(tester, code: longCode(40), isStreaming: false);
      await tester.pumpAndSettle();
      expect(position(tester).pixels, closeTo(0, 0.5),
          reason: 'a re-engaged session must return to the top on completion');
    });

    testWidgets('non-streaming blocks never pin nor show the resume button',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // A normal (already-finished) code block: scrolling is plain.
      await pumpBlock(tester, code: longCode(40), isStreaming: false);
      expect(position(tester).pixels, 0);
      expect(find.byIcon(Icons.arrow_downward), findsNothing);

      // Drag up to scroll the static block down from its top.
      await tester.drag(verticalScrollView(), const Offset(0, -150));
      await tester.pump();
      final scrolled = position(tester).pixels;
      expect(scrolled, greaterThan(0));
      expect(find.byIcon(Icons.arrow_downward), findsNothing,
          reason: 'no resume button outside a streaming session');

      // Growing a static block must not pin it back to the bottom.
      await pumpBlock(tester, code: longCode(80), isStreaming: false);
      expect(position(tester).pixels, closeTo(scrolled, 0.5),
          reason: 'content growth must not move a non-streaming block');
      expect(find.byIcon(Icons.arrow_downward), findsNothing);
    });
  });

  group('CodeBlockSourceView - copy button', () {
    /// Installs a mock platform-channel handler so Clipboard.setData
    /// futures complete (unhandled channels never resolve in tests, which
    /// would stall the copy feedback state change). Records copied texts
    /// into [copiedTexts] when provided.
    void installClipboardMock(WidgetTester tester,
        {List<String>? copiedTexts}) {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (copiedTexts != null && call.method == 'Clipboard.setData') {
            copiedTexts.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));
    }

    testWidgets('toolbar order is copy, save, wrap (left to right)',
        (tester) async {
      await pumpCodeBlock(tester);

      expect(find.byIcon(Icons.copy), findsOneWidget);
      expect(find.byIcon(Icons.save), findsOneWidget);
      expect(find.byIcon(Icons.wrap_text), findsOneWidget);

      final copyPos = tester.getCenter(find.byIcon(Icons.copy));
      final savePos = tester.getCenter(find.byIcon(Icons.save));
      final wrapPos = tester.getCenter(find.byIcon(Icons.wrap_text));
      expect(copyPos.dx, lessThan(savePos.dx),
          reason: 'copy must sit left of save');
      expect(savePos.dx, lessThan(wrapPos.dx),
          reason: 'save must sit left of wrap');
    });

    testWidgets('copy button copies the WHOLE code block to the clipboard',
        (tester) async {
      const code = 'line1\nline2\nline3';
      final copiedTexts = <String>[];
      installClipboardMock(tester, copiedTexts: copiedTexts);

      await pumpCodeBlock(tester, code: code);

      await tester.tap(find.byIcon(Icons.copy));
      await tester.pump();

      expect(copiedTexts, ['line1\nline2\nline3'],
          reason: 'copy must copy every line of the block, not one line');
    });

    testWidgets('copy feedback: checkmark fades in, stays ~1s, then reverts',
        (tester) async {
      installClipboardMock(tester);
      await pumpCodeBlock(tester);

      // Initially the copy icon is shown.
      expect(find.byIcon(Icons.copy), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNothing);

      await tester.tap(find.byIcon(Icons.copy));
      await tester.pump();
      // Let the fade-in complete (the outgoing copy icon lingers while
      // it fades out during the 200ms transition).
      await tester.pump(const Duration(milliseconds: 300));

      // Feedback is active: the checkmark replaces the copy icon.
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.byIcon(Icons.copy), findsNothing);

      // Still shown 500ms later (mid-hold of the 1s window).
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byIcon(Icons.check), findsOneWidget);

      // The 1s hold expires and the icon fades back to copy.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byIcon(Icons.copy), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNothing);
    });

    testWidgets('copy feedback icon swap uses a fade transition',
        (tester) async {
      installClipboardMock(tester);
      await pumpCodeBlock(tester);

      // The copy button hosts an AnimatedSwitcher so the copy/check swap
      // fades instead of popping.
      final switcher = find
          .descendant(
            of: find.byType(InkWell),
            matching: find.byType(AnimatedSwitcher),
          )
          .first;
      expect(switcher, findsOneWidget);

      await tester.tap(find.byIcon(Icons.copy));
      await tester.pump();

      // Mid-fade (50ms of a 200ms swap): a FadeTransition must actually
      // be in flight (opacity strictly between 0 and 1), not an instant
      // icon pop. An idle AnimatedSwitcher sits at opacity 1.0.
      await tester.pump(const Duration(milliseconds: 50));
      final fadeOpacities = tester
          .widgetList<FadeTransition>(find.byType(FadeTransition))
          .map((f) => f.opacity.value)
          .toList();
      expect(fadeOpacities.any((v) => v > 0.0 && v < 1.0), isTrue,
          reason: 'the copy/check swap must fade, not pop');

      // Let the 1s hold pass and the fade back complete.
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byIcon(Icons.copy), findsOneWidget);
    });

    testWidgets('failed clipboard write reverts the checkmark and reports',
        (tester) async {
      // A rejecting clipboard (e.g. web permission denial) must not leave
      // the checkmark stuck or throw an unhandled async error.
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            throw PlatformException(code: 'denied');
          }
          return null;
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));

      await pumpCodeBlock(tester);

      await tester.tap(find.byIcon(Icons.copy));
      await tester.pump();

      // The checkmark reverts and an error snackbar appears.
      expect(find.byIcon(Icons.check), findsNothing);
      expect(find.byIcon(Icons.copy), findsOneWidget);
      expect(find.textContaining('复制失败'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('re-tapping copy while feedback shows restarts the 1s hold',
        (tester) async {
      installClipboardMock(tester);
      await pumpCodeBlock(tester);

      await tester.tap(find.byIcon(Icons.copy));
      await tester.pump();

      // Second tap 500ms later: the hold window must restart, so the
      // checkmark must still be visible at t=1200ms even though the first
      // 1s timer would have fired at t=1000ms.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byIcon(Icons.check));
      await tester.pump();
      expect(find.byIcon(Icons.check), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byIcon(Icons.check), findsOneWidget,
          reason: 'a re-tap must reset the 1s hold window');

      // After the reset window expires the copy icon returns.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byIcon(Icons.copy), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNothing);
    });

    testWidgets('copy feedback icons carry semantic labels', (tester) async {
      installClipboardMock(tester);
      await pumpCodeBlock(tester);

      final copyIcon = tester.widget<Icon>(find.byIcon(Icons.copy));
      expect(copyIcon.semanticLabel, '复制');

      await tester.tap(find.byIcon(Icons.copy));
      await tester.pump();

      final checkIcon = tester.widget<Icon>(find.byIcon(Icons.check));
      expect(checkIcon.semanticLabel, '已复制');

      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 300));
    });
  });

  group('CodeBlockSourceView - save button', () {
    testWidgets('save opens the file save panel with the whole code content',
        (tester) async {
      const code = 'print("hello")\nprint("world")';
      final picker = FakeFilePicker();
      final originalPicker = FilePickerPlatform.instance;
      FilePickerPlatform.instance = picker;
      addTearDown(() => FilePickerPlatform.instance = originalPicker);

      await pumpCodeBlock(tester, code: code);

      await tester.tap(find.byIcon(Icons.save));
      await tester.pump();

      expect(picker.lastBytes, isNotNull);
      expect(utf8.decode(picker.lastBytes!), code,
          reason: 'the saved content must be the whole code block');
      expect(picker.lastFileName, 'code.txt',
          reason: 'an unknown language defaults to a .txt name');
      expect(picker.lastType, FileType.custom,
          reason: 'custom type is required for extension filtering');
      expect(picker.lastAllowedExtensions, isNotEmpty);
      expect(picker.lastDialogTitle, isNotEmpty);
    });

    testWidgets('save uses the language for the default name and format list',
        (tester) async {
      final picker = FakeFilePicker();
      final originalPicker = FilePickerPlatform.instance;
      FilePickerPlatform.instance = picker;
      addTearDown(() => FilePickerPlatform.instance = originalPicker);

      await pumpCodeBlock(tester, code: 'void main() {}', language: 'dart');

      await tester.tap(find.byIcon(Icons.save));
      await tester.pump();

      expect(picker.lastFileName, 'code.dart');
      expect(picker.lastAllowedExtensions!.first, 'dart',
          reason: 'the language extension must be the default format');
      expect(picker.lastAllowedExtensions, containsAll(['dart', 'txt', 'md']));
    });

    testWidgets('successful save confirms the destination in a snackbar',
        (tester) async {
      final picker = FakeFilePicker(result: 'D:/docs/code.dart');
      final originalPicker = FilePickerPlatform.instance;
      FilePickerPlatform.instance = picker;
      addTearDown(() => FilePickerPlatform.instance = originalPicker);

      await pumpCodeBlock(tester, code: 'void main() {}', language: 'dart');

      await tester.tap(find.byIcon(Icons.save));
      await tester.pump();

      expect(find.text('已保存到: D:/docs/code.dart'), findsOneWidget);
    });

    testWidgets('cancelling the save panel shows no snackbar', (tester) async {
      final picker = FakeFilePicker(result: null);
      final originalPicker = FilePickerPlatform.instance;
      FilePickerPlatform.instance = picker;
      addTearDown(() => FilePickerPlatform.instance = originalPicker);

      await pumpCodeBlock(tester);

      await tester.tap(find.byIcon(Icons.save));
      await tester.pump();

      expect(picker.lastBytes, isNotNull,
          reason: 'the save panel was opened with content');
      expect(find.byType(SnackBar), findsNothing,
          reason: 'a cancelled save must not claim success');
    });

    testWidgets('failed save shows an error snackbar', (tester) async {
      final picker = FakeFilePicker()..throwError = Exception('disk full');
      final originalPicker = FilePickerPlatform.instance;
      FilePickerPlatform.instance = picker;
      addTearDown(() => FilePickerPlatform.instance = originalPicker);

      await pumpCodeBlock(tester);

      await tester.tap(find.byIcon(Icons.save));
      await tester.pump();

      expect(find.textContaining('保存失败'), findsOneWidget);
    });

    testWidgets('save on empty code hints and skips the save panel',
        (tester) async {
      final picker = FakeFilePicker();
      final originalPicker = FilePickerPlatform.instance;
      FilePickerPlatform.instance = picker;
      addTearDown(() => FilePickerPlatform.instance = originalPicker);

      await pumpCodeBlock(tester, code: '');

      await tester.tap(find.byIcon(Icons.save));
      await tester.pump();

      expect(picker.lastBytes, isNull,
          reason: 'no save dialog should open for empty code');
      expect(find.text('代码为空，无法保存'), findsOneWidget);
    });

    testWidgets('double-tapping save opens the panel only once',
        (tester) async {
      final completer = Completer<String?>();
      final picker = FakeFilePicker(completer: completer);
      final originalPicker = FilePickerPlatform.instance;
      FilePickerPlatform.instance = picker;
      addTearDown(() => FilePickerPlatform.instance = originalPicker);

      await pumpCodeBlock(tester);

      // Hold the dialog open (completer unresolved), tap twice.
      await tester.tap(find.byIcon(Icons.save));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.save));
      await tester.pump();

      expect(picker.saveCallCount, 1,
          reason: 'a second tap while the dialog is open must be ignored');

      // Completing the dialog shows the success snackbar exactly once.
      completer.complete('C:/docs/code.txt');
      await tester.pump();
      await tester.pump();
      expect(find.text('已保存到: C:/docs/code.txt'), findsOneWidget);
    });

    testWidgets('unmounting while the save panel is open does not crash',
        (tester) async {
      // Regression: the save flow crosses an async gap (the native dialog).
      // If the widget is gone when the dialog resolves, the result must be
      // dropped silently — no snackbar, no exception.
      final completer = Completer<String?>();
      final picker = FakeFilePicker(completer: completer);
      final originalPicker = FilePickerPlatform.instance;
      FilePickerPlatform.instance = picker;
      addTearDown(() => FilePickerPlatform.instance = originalPicker);

      await pumpCodeBlock(tester);

      await tester.tap(find.byIcon(Icons.save));
      await tester.pump();

      // Unmount the code block while the dialog is still "open".
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox())),
      );
      completer.complete('C:/docs/code.txt');
      await tester.pump();

      expect(tester.takeException(), isNull,
          reason: 'completing the dialog after unmount must not throw');
    });
  });
}
