import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/widgets/constrained_text.dart';

/// Verifies that a production hint's measured text fits or exceeds its real
/// rendered slot at the active locale and text scale.
void expectHintMeasurement(
  WidgetTester tester, {
  required String hint,
  required bool clipped,
  int occurrence = 0,
}) {
  final hintFinder = find.byWidgetPredicate(
    (widget) => widget is ConstrainedInputHint && widget.data == hint,
  );
  expect(hintFinder, findsWidgets);
  final measuredHintFinder = hintFinder.at(occurrence);
  final hintWidget = tester.widget<ConstrainedInputHint>(measuredHintFinder);
  final textFinder = find.descendant(
    of: measuredHintFinder,
    matching: find.byType(ConstrainedText),
  );
  final text = tester.widget<ConstrainedText>(textFinder);
  final slot = tester.getSize(textFinder);
  final painter = TextPainter(
    text: TextSpan(text: hint, style: text.style),
    textDirection: Directionality.of(tester.element(textFinder)),
    textScaler: MediaQuery.textScalerOf(tester.element(textFinder)),
    locale: Localizations.localeOf(tester.element(textFinder)),
    maxLines: hintWidget.maxLines,
  )..layout(maxWidth: slot.width);
  expect(
    painter.didExceedMaxLines,
    clipped,
    reason: 'Expected "$hint" to ${clipped ? 'exceed' : 'fit'} in $slot.',
  );
}

void expectNativeHintMeasurement(
  WidgetTester tester, {
  required String hint,
  required bool clipped,
  int occurrence = 0,
}) {
  final hintFinder = find.text(hint).at(occurrence);
  final text = tester.widget<Text>(hintFinder);
  final paragraph = tester.renderObject<RenderParagraph>(hintFinder);
  debugPrint(
    'Round 11 native hint=$hint slot=${paragraph.size} '
    'maxLines=${text.maxLines} '
    'didExceedMaxLines=${paragraph.didExceedMaxLines}',
  );
  expect(text.maxLines, 5);
  expect(
    paragraph.didExceedMaxLines,
    clipped,
    reason: 'Expected "$hint" to ${clipped ? 'exceed' : 'fit'} natively.',
  );
}
