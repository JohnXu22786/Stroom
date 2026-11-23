import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Keeps the established gutter size when it fits, expanding only when the
/// active text metrics need more room for the final line number.
double codeLineNumberGutterWidth({
  required String lineNumber,
  required TextStyle textStyle,
  required TextScaler textScaler,
  required TextDirection textDirection,
  required double minimumWidth,
  required double horizontalPadding,
  Locale? locale,
}) {
  final painter = TextPainter(
    text: TextSpan(text: lineNumber, style: textStyle),
    textDirection: textDirection,
    textScaler: textScaler,
    locale: locale,
  )..layout();
  final measuredWidth = painter.width + horizontalPadding;
  painter.dispose();
  return math.max(minimumWidth, measuredWidth);
}
