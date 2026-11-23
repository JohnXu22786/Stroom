import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/widgets/code_line_number_gutter.dart';

void main() {
  // Unit owner: vertical_gutter_width_scale.
  test('measures scaled line numbers while preserving the minimum width', () {
    const style = TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.5);
    for (final scale in [1.0, 2.0]) {
      final painter = TextPainter(
        text: const TextSpan(text: '1234', style: style),
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.linear(scale),
        locale: const Locale('de', 'DE'),
      )..layout();
      final expectedWidth = painter.width + 12;
      painter.dispose();

      final actualWidth = codeLineNumberGutterWidth(
        lineNumber: '1234',
        textStyle: style,
        textScaler: TextScaler.linear(scale),
        textDirection: TextDirection.ltr,
        locale: const Locale('de', 'DE'),
        minimumWidth: 44,
        horizontalPadding: 12,
      );

      expect(actualWidth, greaterThanOrEqualTo(44));
      expect(actualWidth, expectedWidth > 44 ? expectedWidth : 44);
    }
  });
}
