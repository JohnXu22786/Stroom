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
}
