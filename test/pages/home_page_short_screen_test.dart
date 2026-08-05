import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stroom/pages/home_page.dart';

void main() {
  testWidgets('home page does not overflow on short screens', (tester) async {
    for (final size in const [
      Size(568, 320),
      Size(568, 360),
      Size(568, 400),
      Size(375, 667),
      Size(320, 480),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: HomePage()),
        ),
      );
      await tester.pumpAndSettle();
      // No RenderFlex overflow exception should be thrown.
      expect(tester.takeException(), isNull,
          reason: 'home page overflowed at $size');
    }
  });

  testWidgets(
      'dragging on the module grid scrolls the page '
      '(no scroll dead-zone)', (tester) async {
    // 375x667: the body viewport (below the 80px NavigationBar) shows the
    // grid's first rows, so a drag starting on a card must scroll the page.
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: HomePage()),
      ),
    );
    await tester.pumpAndSettle();

    // Drag upward from a point inside the module grid (starts ≈312px;
    // the body viewport bottom is ≈587px on this size).
    await tester.dragFrom(const Offset(50, 500), const Offset(0, -120));
    await tester.pumpAndSettle();

    // The page (SingleChildScrollView) must have scrolled.
    final scrollable = find.byType(SingleChildScrollView).first;
    final position = tester
        .state<ScrollableState>(
          find
              .descendant(
                of: scrollable,
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position;
    expect(position.pixels, greaterThan(0),
        reason: 'drag on the grid must scroll the page, not dead-zone');
  });
}
