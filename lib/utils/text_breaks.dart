import 'package:flutter/material.dart';

/// Adds emergency grapheme breaks only to unbroken segments wider than the
/// available width. Segments that fit keep their original shaping.
String breakOverlongWords(
  String text, {
  required double maxWidth,
  required TextStyle style,
  required TextDirection textDirection,
  required TextScaler textScaler,
  Locale? locale,
}) {
  if (!maxWidth.isFinite || maxWidth <= 0) return text;

  final painter = TextPainter(
    textDirection: textDirection,
    textScaler: textScaler,
    locale: locale,
    maxLines: 1,
  );
  final buffer = StringBuffer();
  const breakPunctuation = r'/\\:.-';
  final chunks = RegExp('\\s+|[$breakPunctuation]+|[^\\s$breakPunctuation]+');
  for (final match in chunks.allMatches(text)) {
    final chunk = match.group(0)!;
    if (chunk.trim().isEmpty) {
      buffer.write(chunk);
      continue;
    }

    painter
      ..text = TextSpan(text: chunk, style: style)
      ..layout();
    buffer.write(
      painter.width > maxWidth
          ? _insertEmergencyBreaks(
              chunk,
              maxWidth: maxWidth,
              style: style,
              painter: painter,
            )
          : chunk,
    );
  }
  return buffer.toString();
}

String _insertEmergencyBreaks(
  String text, {
  required double maxWidth,
  required TextStyle style,
  required TextPainter painter,
}) {
  final graphemes = text.characters.toList();
  final buffer = StringBuffer();
  var start = 0;
  while (start < graphemes.length) {
    var lastFittingEnd = start;
    var candidate = '';
    for (var end = start; end < graphemes.length; end++) {
      candidate += graphemes[end];
      painter
        ..text = TextSpan(text: candidate, style: style)
        ..layout();
      if (painter.width <= maxWidth || end == start) {
        lastFittingEnd = end + 1;
      } else {
        break;
      }
    }

    buffer.write(graphemes.skip(start).take(lastFittingEnd - start).join());
    start = lastFittingEnd;
    if (start < graphemes.length) buffer.write('\u200B');
  }
  return buffer.toString();
}
