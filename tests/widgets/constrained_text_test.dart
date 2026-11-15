import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/widgets/constrained_text.dart';

void main() {
  testWidgets('keeps fitting text in its normal Text widget', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 240,
            child: ConstrainedText(
              'Short label',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Short label'), findsOneWidget);
  });

  testWidgets('keeps clipped text discoverable while it scrolls', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 80,
            child: ConstrainedText(
              'A deliberately long value that will scroll',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );

    expect(find.text('A deliberately long value that will scroll'),
        findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('A deliberately long value that will scroll'),
        findsOneWidget);
  });
}
