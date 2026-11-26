import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/widgets/code_editor_field.dart';
import 'package:stroom/widgets/constrained_text.dart';

/// Helper to run the formatter as if the user typed [insert] at [cursor]
/// into [old].
TextEditingValue typeInto(
  CodeSmartInputFormatter formatter,
  String old,
  String insert, {
  int? cursor,
}) {
  final sel = TextSelection.collapsed(offset: cursor ?? old.length);
  final oldValue = TextEditingValue(text: old, selection: sel);
  final newText =
      old.substring(0, sel.start) + insert + old.substring(sel.start);
  final newValue = TextEditingValue(
    text: newText,
    selection: TextSelection.collapsed(offset: sel.start + insert.length),
  );
  return formatter.formatEditUpdate(oldValue, newValue);
}

/// Helper to run the formatter as if the user pressed Backspace at [cursor].
TextEditingValue backspaceAt(
  CodeSmartInputFormatter formatter,
  String old,
  int cursor,
) {
  final sel = TextSelection.collapsed(offset: cursor);
  final oldValue = TextEditingValue(text: old, selection: sel);
  final newText = old.substring(0, cursor - 1) + old.substring(cursor);
  final newValue = TextEditingValue(
    text: newText,
    selection: TextSelection.collapsed(offset: cursor - 1),
  );
  return formatter.formatEditUpdate(oldValue, newValue);
}

RenderEditable _findRenderEditable(RenderObject root) {
  final pending = <RenderObject>[root];
  while (pending.isNotEmpty) {
    final current = pending.removeLast();
    if (current is RenderEditable) return current;
    current.visitChildren(pending.add);
  }
  throw StateError('EditableText does not contain a RenderEditable');
}

void main() {
  const formatter = CodeSmartInputFormatter();

  group('CodeSmartInputFormatter - bracket auto-close', () {
    test('typing { inserts {} with cursor between', () {
      final r = typeInto(formatter, '', '{');
      expect(r.text, '{}');
      expect(r.selection.baseOffset, 1);
    });

    test('typing ( and [ auto-close', () {
      expect(typeInto(formatter, '', '(').text, '()');
      expect(typeInto(formatter, '', '[').text, '[]');
    });

    test('typing opener before an existing closer does not duplicate', () {
      // `{}` + cursor between + `{` -> `{{}` (existing } serves as closer)
      final r = typeInto(formatter, '{}', '{', cursor: 1);
      expect(r.text, '{{}');
      expect(r.selection.baseOffset, 2);
    });

    test('typing a closing bracket skips over an existing one', () {
      final r = typeInto(formatter, '{}', '}', cursor: 1);
      expect(r.text, '{}');
      expect(r.selection.baseOffset, 2);
    });

    test('typing a closer at end of text inserts it plainly', () {
      final r = typeInto(formatter, '{"a": 1', '}');
      expect(r.text, '{"a": 1}');
      expect(r.selection.baseOffset, r.text.length);
    });

    test('typing over a selection wraps it in brackets', () {
      final oldValue = TextEditingValue(
        text: 'ab',
        selection: TextSelection(baseOffset: 1, extentOffset: 2),
      );
      final newValue = TextEditingValue(
        text: 'a{',
        selection: TextSelection.collapsed(offset: 2),
      );
      final r = formatter.formatEditUpdate(oldValue, newValue);
      expect(r.text, 'a{b}');
      expect(r.selection.start, 2);
      expect(r.selection.end, 3);
    });
  });

  group('CodeSmartInputFormatter - quote pairing', () {
    test('typing " at start of text pairs', () {
      final r = typeInto(formatter, '', '"');
      expect(r.text, '""');
      expect(r.selection.baseOffset, 1);
    });

    test('typing " after a starter (e.g. {) pairs', () {
      final r = typeInto(formatter, '{', '"', cursor: 1);
      expect(r.text, '{""');
      expect(r.selection.baseOffset, 2);
    });

    test('typing " after a word char does not pair (plain insert)', () {
      final r = typeInto(formatter, 'ab', '"');
      expect(r.text, 'ab"');
      expect(r.selection.baseOffset, 3);
    });

    test('typing " inside an empty pair skips over the closing quote', () {
      final r = typeInto(formatter, '""', '"', cursor: 1);
      expect(r.text, '""');
      expect(r.selection.baseOffset, 2);
    });

    test('typing " at the start of an indented line pairs', () {
      // After `{` + Enter + auto-indent, a fresh line must pair quotes too.
      final r = typeInto(formatter, '{\n  ', '"', cursor: 4);
      expect(r.text, '{\n  ""');
      expect(r.selection.baseOffset, 5);
    });
  });

  group('CodeSmartInputFormatter - Enter auto indent', () {
    test('Enter after { indents one level', () {
      final r = typeInto(formatter, '{', '\n', cursor: 1);
      expect(r.text, '{\n  ');
      expect(r.selection.baseOffset, 4);
    });

    test('Enter keeps existing indentation on a plain line', () {
      final r = typeInto(formatter, '  "a": 1', '\n');
      expect(r.text, '  "a": 1\n  ');
      expect(r.selection.baseOffset, r.text.length);
    });

    test('Enter before a closing bracket aligns to the parent level', () {
      // cursor right after `{\n`, before `}`: new line stays at parent level
      final r = typeInto(formatter, '{\n}', '\n', cursor: 2);
      expect(r.text, '{\n\n}');
      expect(r.selection.baseOffset, 3);
    });

    test('Enter after [ indents (array context)', () {
      final r = typeInto(formatter, '[', '\n', cursor: 1);
      expect(r.text, '[\n  ');
    });
  });

  group('CodeSmartInputFormatter - auto unindent on closer', () {
    test('typing } on a whitespace-only line removes one indent level', () {
      final r = typeInto(formatter, '{\n  ', '}', cursor: 4);
      expect(r.text, '{\n}');
      expect(r.selection.baseOffset, 3);
    });

    test('typing ] on a 4-space line unindents to 2 spaces', () {
      final r = typeInto(formatter, '[\n    ', ']', cursor: 6);
      expect(r.text, '[\n  ]');
    });
  });

  group('CodeSmartInputFormatter - backspace pair delete', () {
    test('backspace between a matched pair deletes both', () {
      final r = backspaceAt(formatter, '{}', 1);
      expect(r.text, '');
      expect(r.selection.baseOffset, 0);
    });

    test('backspace deletes a quote pair', () {
      final r = backspaceAt(formatter, '""', 1);
      expect(r.text, '');
    });

    test('backspace with content between brackets keeps content', () {
      final r = backspaceAt(formatter, '{a}', 1);
      expect(r.text, 'a}');
      expect(r.selection.baseOffset, 0);
    });

    test('forward delete (Del key) between a pair does NOT delete both', () {
      // Del at caret 1 in `{}`: deletes the char AT the caret, selection
      // stays at deletePos + 1 (unlike backspace). Regression: the pair
      // delete branch used to wipe both chars on Del.
      final oldValue = TextEditingValue(
        text: '{}',
        selection: TextSelection.collapsed(offset: 1),
      );
      final newValue = TextEditingValue(
        text: '}',
        selection: TextSelection.collapsed(offset: 1),
      );
      final r = formatter.formatEditUpdate(oldValue, newValue);
      expect(r.text, '}');
      expect(r.selection.baseOffset, 1);
    });

    test('Del key real engine shape: deletes char at caret only', () {
      // 真实 Del 事件：`{}` 光标 1 → 删除光标处字符 `}` → 文本 `{`，光标 1。
      final oldValue = TextEditingValue(
        text: '{}',
        selection: TextSelection.collapsed(offset: 1),
      );
      final newValue = TextEditingValue(
        text: '{',
        selection: TextSelection.collapsed(offset: 1),
      );
      final r = formatter.formatEditUpdate(oldValue, newValue);
      expect(r.text, '{');
      expect(r.selection.baseOffset, 1);
    });
  });

  group('CodeSmartInputFormatter - safe passthrough', () {
    test('plain letter insertion is untouched', () {
      final r = typeInto(formatter, 'ab', 'c', cursor: 1);
      expect(r.text, 'acb');
    });

    test('multi-char paste is untouched', () {
      final r = typeInto(formatter, 'a', 'bc');
      expect(r.text, 'abc');
    });

    test('IME composing input is untouched', () {
      const oldValue = TextEditingValue(
        text: 'a',
        selection: TextSelection.collapsed(offset: 1),
      );
      const newValue = TextEditingValue(
        text: 'a中',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 1, end: 2),
      );
      final r = formatter.formatEditUpdate(oldValue, newValue);
      expect(r.text, 'a中');
      expect(r.composing, const TextRange(start: 1, end: 2));
    });

    test('selection replacement without brackets is untouched', () {
      final oldValue = TextEditingValue(
        text: 'ab',
        selection: TextSelection(baseOffset: 0, extentOffset: 2),
      );
      final newValue = TextEditingValue(
        text: 'x',
        selection: TextSelection.collapsed(offset: 1),
      );
      final r = formatter.formatEditUpdate(oldValue, newValue);
      expect(r.text, 'x');
    });
  });

  group('isValidParamName', () {
    test('plain names are valid', () {
      expect(isValidParamName('top_k'), isTrue);
    });

    test('dotted nested names are valid', () {
      expect(isValidParamName('provider.only'), isTrue);
    });

    test('empty name / empty segments are invalid', () {
      expect(isValidParamName(''), isFalse);
      expect(isValidParamName('   '), isFalse);
      expect(isValidParamName('.only'), isFalse);
      expect(isValidParamName('provider.'), isFalse);
      expect(isValidParamName('provider..only'), isFalse);
    });

    test('segments with inner whitespace are invalid', () {
      // 整名首尾空白会被 trim 归一化，但分段内部空白会使请求键与
      // 预览不一致，必须拒绝。
      expect(isValidParamName('provider .only'), isFalse);
      expect(isValidParamName('provider. only'), isFalse);
    });
  });

  Widget localizedApp(
    Widget home, {
    Locale locale = const Locale('de'),
    ThemeData? theme,
    TextScaler? textScaler,
  }) =>
      MaterialApp(
        locale: locale,
        theme: theme,
        builder: textScaler == null
            ? null
            : (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: textScaler,
                  ),
                  child: child!,
                ),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: home,
      );

  testWidgets(
      'line-number rows follow scaled and wrapped lines while editing and scrolling',
      (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final longLine = 'long line ${List.filled(80, 'x').join()}';
    final controller = TextEditingController(
      text: [
        longLine,
        '',
        '',
        ...List.generate(497, (index) => 'line ${index + 4}'),
      ].join('\n'),
    );
    addTearDown(controller.dispose);

    for (final scale in [1.0, 2.0]) {
      await tester.pumpWidget(
        localizedApp(
          Directionality(
            textDirection: scale == 2 ? TextDirection.rtl : TextDirection.ltr,
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 280,
                  height: 120,
                  child: CodeEditorField(controller: controller),
                ),
              ),
            ),
          ),
          textScaler: TextScaler.linear(scale),
        ),
      );
      await tester.pumpAndSettle();

      final lineNumber = find.text('1');
      final lineSlot =
          find.ancestor(of: lineNumber, matching: find.byType(SizedBox)).first;
      final editorFinder = find.byType(TextField);
      final wrappedRenderEditable = _findRenderEditable(
        tester.renderObject(find.byType(EditableText)),
      );
      final renderedBoxes = wrappedRenderEditable.getBoxesForSelection(
        TextSelection(baseOffset: 0, extentOffset: longLine.length),
      );
      expect(renderedBoxes.length, greaterThan(1));
      final firstLineTop = wrappedRenderEditable
          .getLocalRectForCaret(const TextPosition(offset: 0))
          .top;
      final nextLineTop = wrappedRenderEditable
          .getLocalRectForCaret(TextPosition(offset: longLine.length + 1))
          .top;
      final expectedWrappedHeight = nextLineTop - firstLineTop;
      expect(
        tester.getSize(lineSlot).height,
        closeTo(expectedWrappedHeight, 0.01),
        reason: 'the gutter row must include scaled soft-wrapped text lines',
      );
      expect(
        tester.getRect(find.text('2')).top - tester.getRect(lineNumber).top,
        closeTo(expectedWrappedHeight, 0.01),
        reason:
            'the next line number must start after all wrapped visual lines',
      );

      final updatedText = '${controller.text}\nnew line';
      await tester.enterText(find.byType(EditableText), updatedText);
      await tester.pumpAndSettle();
      final updatedLineCount = updatedText.split('\n').length;
      expect(controller.text, updatedText);
      expect(find.text('$updatedLineCount'), findsOneWidget);

      final editor = tester.widget<TextField>(editorFinder);
      final scrollController = editor.scrollController!;
      expect(scrollController.position.maxScrollExtent, greaterThan(0));
      scrollController.jumpTo(scrollController.position.maxScrollExtent);
      await tester.pumpAndSettle();

      final lastLineNumber = tester.getRect(find.text('$updatedLineCount'));
      final editorRect = tester.getRect(find.byType(TextField));
      expect(lastLineNumber.top, greaterThanOrEqualTo(editorRect.top));
      expect(lastLineNumber.bottom, lessThanOrEqualTo(editorRect.bottom));
      final renderEditable = _findRenderEditable(
        tester.renderObject(find.byType(EditableText)),
      );
      final firstLineCaret = renderEditable.localToGlobal(
        renderEditable
            .getLocalRectForCaret(const TextPosition(offset: 0))
            .topLeft,
      );
      final secondLineCaret = renderEditable.localToGlobal(
        renderEditable
            .getLocalRectForCaret(TextPosition(offset: longLine.length + 1))
            .topLeft,
      );
      final firstLineNumber = tester.getTopLeft(find.text('1'));
      final secondLineNumber = tester.getTopLeft(find.text('2'));
      expect(
        secondLineNumber.dy - firstLineNumber.dy,
        closeTo(secondLineCaret.dy - firstLineCaret.dy, 1),
      );
      expect(editor.controller, same(controller));
      expect(tester.takeException(), isNull);
    }

    // Unit owner: vertical_gutter_width_scale.
    final longCountController = TextEditingController(
      text: List<String>.filled(1234, 'x').join('\n'),
    );
    addTearDown(longCountController.dispose);
    double? normalGutterWidth;
    for (final scale in [1.0, 2.0]) {
      await tester.pumpWidget(
        localizedApp(
          Directionality(
            textDirection: scale == 1 ? TextDirection.ltr : TextDirection.rtl,
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 280,
                  height: 120,
                  child: CodeEditorField(controller: longCountController),
                ),
              ),
            ),
          ),
          textScaler: TextScaler.linear(scale),
        ),
      );
      await tester.pumpAndSettle();

      final number = find.text('1234');
      expect(number, findsOneWidget);
      final gutter =
          find.ancestor(of: number, matching: find.byType(OverflowBox)).first;
      final gutterWidth = tester.getSize(gutter).width;
      final actualNumber = TextPainter(
        text: const TextSpan(
          text: '1234',
          style: TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.3),
        ),
        textDirection: scale == 1 ? TextDirection.ltr : TextDirection.rtl,
        textScaler: TextScaler.linear(scale),
      )..layout();
      expect(
        actualNumber.width,
        lessThanOrEqualTo(gutterWidth - 12),
        reason: 'the complete four-digit editor number must fit at ${scale}x',
      );
      if (scale == 1) {
        normalGutterWidth = gutterWidth;
        expect(
          gutterWidth,
          greaterThanOrEqualTo(52),
          reason: 'the original 1x width remains the minimum',
        );
      } else {
        expect(
          gutterWidth,
          greaterThan(normalGutterWidth!),
          reason: 'the 2x gutter expands to fit the scaled number',
        );
      }
      actualNumber.dispose();
    }

    const dialogValue = '''{
  "name": "local example",
  "enabled": true,
  "count": 3,
  "options": {
    "first": "alpha",
    "second": "beta"
  }
}''';
    await tester.pumpWidget(
      localizedApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showJsonValueEditorDialog(
              context,
              initialValue: dialogValue,
              hintText: '',
              type: 'json',
              onSave: (_) {},
            ),
            child: const Text('open dialog'),
          ),
        ),
        locale: const Locale('de'),
        theme: ThemeData(useMaterial3: true),
        textScaler: const TextScaler.linear(2),
      ),
    );
    await tester.tap(find.text('open dialog'));
    await tester.pumpAndSettle();

    final dialogEditor = tester.widget<TextField>(find.byType(TextField));
    final dialogText = dialogEditor.controller!.text;
    final wrappedLineStart = dialogText.indexOf('"second"');
    final nextLogicalLineStart =
        dialogText.indexOf('\n  }', wrappedLineStart) + 1;
    final dialogWrappedMetrics = TextPainter(
      text: TextSpan(
        text: dialogText.split('\n')[6],
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          height: 1.3,
        ),
      ),
      textDirection: TextDirection.ltr,
      textScaler: const TextScaler.linear(2),
    )..layout(maxWidth: tester.getRect(find.byType(TextField)).width - 16);
    addTearDown(dialogWrappedMetrics.dispose);
    final dialogWrappedLines = dialogWrappedMetrics.computeLineMetrics();
    expect(dialogWrappedLines.length, greaterThan(1));
    final dialogRenderEditable = _findRenderEditable(
      tester.renderObject(find.byType(EditableText)),
    );
    final wrappedLineTop = dialogRenderEditable.localToGlobal(
      dialogRenderEditable
          .getLocalRectForCaret(TextPosition(offset: wrappedLineStart))
          .topLeft,
    );
    final nextLogicalLineTop = dialogRenderEditable.localToGlobal(
      dialogRenderEditable
          .getLocalRectForCaret(TextPosition(offset: nextLogicalLineStart))
          .topLeft,
    );
    final wrappedNumberTop = tester.getTopLeft(find.text('7'));
    final nextNumberTop = tester.getTopLeft(find.text('8'));
    final editorLineDistance = nextLogicalLineTop.dy - wrappedLineTop.dy;
    expect(
      editorLineDistance,
      closeTo(
        dialogWrappedLines.fold<double>(
          0,
          (height, line) => height + line.height,
        ),
        1,
      ),
    );
    expect(
      nextNumberTop.dy - wrappedNumberTop.dy,
      closeTo(editorLineDistance, 1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('controller replacement rebinds line-number updates', (
    tester,
  ) async {
    final oldController = TextEditingController(text: 'old\ncontroller');
    final newController = TextEditingController(
      text: 'new\ncontroller\nthree',
    );
    addTearDown(oldController.dispose);
    addTearDown(newController.dispose);

    late StateSetter updateEditor;
    var controller = oldController;
    await tester.pumpWidget(
      localizedApp(
        StatefulBuilder(
          builder: (context, setState) {
            updateEditor = setState;
            return Scaffold(
              body: SizedBox(
                width: 320,
                height: 160,
                child: CodeEditorField(controller: controller),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);

    updateEditor(() => controller = newController);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller,
        same(newController));
    expect(oldController.hasListeners, isFalse);
    expect(find.text('3'), findsOneWidget);

    newController.text = 'new\ncontroller\nthree\nfour';
    await tester.pumpAndSettle();
    expect(find.text('4'), findsOneWidget);

    oldController.text = 'old\ncontroller\nshould not update';
    await tester.pumpAndSettle();
    expect(find.text('4'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('JSON editor title stays bounded beside dialog controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      localizedApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showJsonValueEditorDialog(
              context,
              initialValue: '{"a":1}',
              hintText: '',
              type: 'json',
              onSave: (_) {},
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final title = AppLocalizations.of(tester.element(find.byType(Dialog)))!
        .codeEditorTitle;
    expect(
      find.byWidgetPredicate(
        (widget) => widget is ConstrainedText && widget.data == title,
      ),
      findsOneWidget,
    );
    expect(find.text('JSON'), findsOneWidget);
    expect(find.byIcon(Icons.format_align_left), findsOneWidget);
    expect(find.byTooltip('Abbrechen'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(Container());
    tester.view.physicalSize = const Size(700, 640);
    await tester.pumpWidget(
      localizedApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showJsonValueEditorDialog(
              context,
              initialValue: '{"a":1}',
              hintText: '',
              type: 'json',
              onSave: (_) {},
            ),
            child: const Text('open'),
          ),
        ),
        locale: const Locale('en'),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final fittingTitle = find.byWidgetPredicate(
      (widget) =>
          widget is ConstrainedText &&
          widget.data ==
              AppLocalizations.of(tester.element(find.byType(Dialog)))!
                  .codeEditorTitle,
    );
    final titleRect = tester.getRect(fittingTitle);
    final badgeRect = tester.getRect(find.text('JSON'));
    expect(badgeRect.left - titleRect.right, inInclusiveRange(8, 24));
    await tester.pump(const Duration(seconds: 3));
    expect(tester.getRect(fittingTitle).topLeft, titleRect.topLeft);

    await tester.pumpWidget(Container());
    tester.view.physicalSize = const Size(320, 640);
    await tester.pumpWidget(
      localizedApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showJsonValueEditorDialog(
              context,
              initialValue: '{"a":1}',
              hintText: '',
              type: 'json',
              onSave: (_) {},
            ),
            child: const Text('open'),
          ),
        ),
        theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('JSON'), findsOneWidget);
    expect(find.byIcon(Icons.format_align_left), findsOneWidget);
    expect(find.byTooltip('Abbrechen'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalid JSON status wraps beside actions in a narrow layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      localizedApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showJsonValueEditorDialog(
              context,
              initialValue: '{ invalid',
              hintText: '',
              type: 'json',
              onSave: (_) {},
            ),
            child: const Text('open'),
          ),
        ),
        locale: const Locale('fr'),
        theme: ThemeData(useMaterial3: true),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(
      find.text(AppLocalizations.of(tester.element(find.byType(Dialog)))!
          .codeEditorInvalidJson),
      findsOneWidget,
    );
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '{ invalid');
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    expect(find.byTooltip('Annuler'), findsOneWidget);
    final dialogFinder = find.byType(Dialog);
    final dialogSurface = find
        .descendant(of: dialogFinder, matching: find.byType(Material))
        .first;
    final statusText = AppLocalizations.of(tester.element(dialogFinder))!
        .codeEditorInvalidJson;
    final statusFinder = find.text(statusText);
    final dialogRect = tester.getRect(dialogSurface);
    final statusRect = tester.getRect(statusFinder);
    expect(tester.widget<Text>(statusFinder).maxLines, isNull);
    expect(tester.widget<Text>(statusFinder).overflow, isNull);
    expect(statusRect.top, greaterThanOrEqualTo(dialogRect.top));
    expect(statusRect.bottom, lessThanOrEqualTo(dialogRect.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalid JSON status stays visible with large text and keyboard',
      (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => tester.view.viewInsets = FakeViewPadding.zero);

    await tester.pumpWidget(
      localizedApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showJsonValueEditorDialog(
              context,
              initialValue: '{ invalid',
              hintText: '',
              type: 'json',
              onSave: (_) {},
            ),
            child: const Text('open'),
          ),
        ),
        locale: const Locale('fr'),
        theme: ThemeData(useMaterial3: true),
        textScaler: const TextScaler.linear(2),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final dialogFinder = find.byType(Dialog);
    final dialogSurfaceFinder = find
        .descendant(
          of: dialogFinder,
          matching: find.byType(Material),
        )
        .first;
    final status = AppLocalizations.of(tester.element(dialogFinder))!
        .codeEditorInvalidJson;
    final statusFinder = find.text(status);
    await tester.ensureVisible(statusFinder);
    await tester.pumpAndSettle();
    final statusRect = tester.getRect(statusFinder);
    final dialogSurfaceRect = tester.getRect(dialogSurfaceFinder);
    expect(statusRect.top, greaterThanOrEqualTo(dialogSurfaceRect.top));
    expect(statusRect.bottom, lessThanOrEqualTo(dialogSurfaceRect.bottom));
    expect(dialogSurfaceRect.bottom, lessThanOrEqualTo(640 - 240));
    final cancelButton = find.widgetWithText(
      TextButton,
      AppLocalizations.of(tester.element(dialogFinder))!.codeEditorCancel,
    );
    await tester.ensureVisible(cancelButton);
    await tester.pumpAndSettle();
    final cancelRect = tester.getRect(cancelButton);
    expect(cancelRect.top, greaterThanOrEqualTo(dialogSurfaceRect.top));
    expect(cancelRect.bottom, lessThanOrEqualTo(dialogSurfaceRect.bottom));
    final confirmFinder = find.byType(FilledButton);
    await tester.ensureVisible(confirmFinder);
    await tester.pumpAndSettle();
    final confirmRect = tester.getRect(confirmFinder);
    expect(confirmRect.top, greaterThanOrEqualTo(dialogSurfaceRect.top));
    expect(confirmRect.bottom, lessThanOrEqualTo(dialogSurfaceRect.bottom));
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '{ invalid');
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    expect(find.byTooltip('Annuler'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'JSON editor supports keyboard editing, formatting, save and close',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      String? saved;

      await tester.pumpWidget(
        localizedApp(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showJsonValueEditorDialog(
                context,
                initialValue: '{"a":1}',
                hintText: '',
                type: 'json',
                onSave: (value) => saved = value,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final editor = find.byType(TextField);
      await tester.tap(editor);
      await tester.showKeyboard(editor);
      await tester.enterText(editor, '{"b":2}');
      await tester.pump();
      expect(tester.testTextInput.isVisible, isTrue);
      expect(find.byIcon(Icons.format_align_left), findsOneWidget);

      await tester.tap(find.byIcon(Icons.format_align_left));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(editor).controller!.text,
        '{\n  "b": 2\n}',
      );
      await tester.tap(find.byIcon(Icons.check));
      await tester.pumpAndSettle();
      expect(saved, '{\n  "b": 2\n}');

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final reopenedEditor = find.byType(TextField);
      await tester.tap(reopenedEditor);
      await tester.showKeyboard(reopenedEditor);
      await tester.enterText(reopenedEditor, '{"c":3}');
      await tester.pump();
      await tester.tap(find.byTooltip('Abbrechen'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(saved, '{\n  "b": 2\n}');
    },
  );
}
