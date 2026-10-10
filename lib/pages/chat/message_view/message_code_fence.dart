/// Resolves a fence from current Flutter-owned source, never JS-supplied code.
({String code, String language, bool complete, bool generating})?
    messageCodeFence(String text, Object? start, Object? end,
        {bool streaming = false}) {
  if (start is! int ||
      end is! int ||
      start < 0 ||
      end <= start ||
      end > text.length) return null;
  var source = text.substring(start, end);
  final lineStart = start == 0 ? 0 : text.lastIndexOf('\n', start - 1) + 1;
  final prefix = text.substring(lineStart, start);
  final quotes = '>'.allMatches(prefix).length;
  final indent = prefix.replaceAll(RegExp(r' {0,3}> ?'), '').length;
  final lines = source.split('\n');
  for (var i = 1; i < lines.length; i++) {
    var line = lines[i];
    for (var q = 0; q < quotes; q++) {
      line = line.replaceFirst(RegExp(r'^ {0,3}> ?'), '');
    }
    if (indent > 0 && line.startsWith(' ' * indent))
      line = line.substring(indent);
    lines[i] = line;
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
