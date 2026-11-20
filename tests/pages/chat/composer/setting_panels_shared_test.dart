import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/chat/composer/setting_panels_shared.dart';
import 'package:stroom/widgets/constrained_text.dart';

void main() {
  testWidgets(
    'OptionChip keeps standard labels readable in a phone-width wrap',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final label in [
                    'none',
                    'minimal',
                    'low',
                    'medium',
                    'high',
                    'xhigh',
                    'max',
                  ])
                    OptionChip(label: label, selected: false, onTap: () {}),
                ],
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      for (final chip in tester.widgetList<OptionChip>(
        find.byType(OptionChip),
      )) {
        final chipFinder = find.byWidget(chip);
        final chipSize = tester.getSize(
          find.descendant(of: chipFinder, matching: find.byType(InkWell)),
        );
        expect(chipSize.width, lessThan(150));
        expect(
          tester
              .widget<ConstrainedText>(
                find.descendant(
                  of: chipFinder,
                  matching: find.byType(ConstrainedText),
                ),
              )
              .useNaturalWidthLayout,
          isTrue,
        );
      }
      await tester.binding.setSurfaceSize(null);
    },
  );

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
