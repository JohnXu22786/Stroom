import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/chat/composer/setting_panels_shared.dart';

void main() {
  testWidgets('OptionChip uses compact radius for its surface and ripple', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OptionChip(label: 'Reasoning', selected: false, onTap: () {}),
        ),
      ),
    );

    final chip = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer),
    );
    final decoration = chip.decoration! as BoxDecoration;
    expect(decoration.borderRadius, BorderRadius.circular(8));

    final ripple = tester.widget<InkWell>(find.byType(InkWell));
    expect(ripple.borderRadius, BorderRadius.circular(8));
  });
}
