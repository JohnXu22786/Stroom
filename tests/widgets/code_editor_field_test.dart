import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/widgets/code_editor_field.dart';

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
}
