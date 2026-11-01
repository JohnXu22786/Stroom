/// Converts integral indexes returned by the WebView bridge to Dart ints.
/// JavaScript numbers can arrive as doubles on Flutter Web/Wasm.
int? messageWebInteger(Object? value) {
  if (value is int) return value;
  if (value is! num || !value.isFinite) return null;
  const maxSafeJavaScriptInteger = 9007199254740991;
  if (value < -maxSafeJavaScriptInteger || value > maxSafeJavaScriptInteger) {
    return null;
  }
  final asDouble = value.toDouble();
  if (asDouble.truncateToDouble() != asDouble) return null;
  return asDouble.toInt();
}

/// Resolves a fence from current Flutter-owned source, never JS-supplied code.
({String code, String language, bool complete, bool generating})?
    messageCodeFence(String text, Object? start, Object? end,
        {bool streaming = false}) {
  final startOffset = messageWebInteger(start);
  final endOffset = messageWebInteger(end);
  if (startOffset == null ||
      endOffset == null ||
      startOffset < 0 ||
      endOffset <= startOffset ||
      endOffset > text.length) return null;
  var source = text.substring(startOffset, endOffset).replaceAll('\r\n', '\n');
  final lineStart =
      startOffset == 0 ? 0 : text.lastIndexOf('\n', startOffset - 1) + 1;
  final prefix = text.substring(lineStart, startOffset);
  final quotes = '>'.allMatches(prefix).length;
  // Removing a quote also consumes any outer list indentation. Only the
  // container prefix after the last quote remains to be stripped.
  final quoteEnd = prefix.lastIndexOf('>') + 1;
  final quoteColumn = _codeColumns(prefix.substring(0, quoteEnd));
  final tail = prefix.substring(quoteEnd);
  final optionalSpace = tail.startsWith(' ') || tail.startsWith('\t') ? 1 : 0;
  final indent = quotes == 0
      ? _codeColumns(prefix)
      : _codeColumns(_stripCodeIndent(tail, optionalSpace, quoteColumn),
          quoteColumn + optionalSpace);
  final lines = source.split('\n');
  for (var i = 1; i < lines.length; i++) {
    var line = lines[i];
    var column = 0;
    for (var q = 0; q < quotes; q++) {
      final quote = RegExp(r'^[ \t]*>').firstMatch(line);
      if (quote == null) break;
      column += _codeColumns(quote.group(0)!, column);
      line = line.substring(quote.end);
      if (line.startsWith(' ') || line.startsWith('\t')) {
        line = _stripCodeIndent(line, 1, column);
        column++;
      }
    }
    lines[i] = _stripCodeIndent(line, indent, column);
  }
  source = lines.join('\n');
  final opening = RegExp(r'^ {0,3}(`{3,}|~{3,})([^\n]*)\n').firstMatch(source);
  if (opening == null) {
    // Markdown also has indented code blocks without a fence.
    if (!source.startsWith('    ') && !source.startsWith('\t')) return null;
    final code = source
        .split('\n')
        .map((line) => line.replaceFirst(RegExp(r'^( {4}|\t)'), ''))
        .join('\n');
    return (code: code, language: '', complete: true, generating: streaming);
  }
  final fence = opening.group(1)!;
  final closing = RegExp(
          '^ {0,3}${RegExp.escape(fence[0])}{${fence.length},}[ \\t]*\$',
          multiLine: true)
      .firstMatch(source.substring(opening.end));
  final body = source.substring(opening.end);
  final code = closing == null
      ? body
      : body.substring(0, closing.start).replaceFirst(RegExp(r'\n$'), '');
  final language =
      opening.group(2)!.trim().split(RegExp(r'\s+')).first.toLowerCase();
  return (
    code: code,
    language: language,
    complete: closing != null,
    generating: streaming && closing == null
  );
}

int _codeColumns(String text, [int column = 0]) {
  final start = column;
  for (final unit in text.codeUnits) {
    column += unit == 9 ? 4 - column % 4 : 1;
  }
  return column - start;
}

String _stripCodeIndent(String line, int width, [int column = 0]) {
  var consumed = 0;
  var offset = 0;
  while (offset < line.length && consumed < width) {
    final unit = line.codeUnitAt(offset);
    if (unit != 32 && unit != 9) break;
    final step = unit == 9 ? 4 - (column + consumed) % 4 : 1;
    consumed += step;
    offset++;
  }
  // A tab can cross the container boundary; keep its remaining code columns.
  final remainder = consumed > width ? ' ' * (consumed - width) : '';
  return remainder + line.substring(offset);
}
