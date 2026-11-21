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
      painter.width > maxWidth ? chunk.characters.join('\u200B') : chunk,
    );
  }
  return buffer.toString();
}
