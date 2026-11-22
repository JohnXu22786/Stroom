import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/widgets/modal_bottom_sheet_constraints.dart';

void main() {
  testWidgets('keeps compact viewport width unconstrained', (tester) async {
    final constraints = await _constraintsAt(tester, 599);

    expect(constraints, isNull);
  });

  testWidgets('leaves 24 dp gutters at the wide viewport threshold', (
    tester,
  ) async {
    final constraints = await _constraintsAt(tester, 600);

    expect(constraints, const BoxConstraints(maxWidth: 552));
  });

  testWidgets('uses the available width minus gutters below the cap', (
    tester,
  ) async {
    final constraints = await _constraintsAt(tester, 620);

    expect(constraints, const BoxConstraints(maxWidth: 572));
  });

  testWidgets('caps wide viewport panels at 640 dp', (tester) async {
    final constraints = await _constraintsAt(tester, 800);

    expect(constraints, const BoxConstraints(maxWidth: 640));
  });
}

Future<BoxConstraints?> _constraintsAt(
  WidgetTester tester,
  double availableWidth,
) async {
  late BoxConstraints? constraints;

  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: Size(availableWidth, 800)),
        child: Builder(
          builder: (context) {
            constraints = modalBottomSheetWidthConstraints(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );

  return constraints;
}
