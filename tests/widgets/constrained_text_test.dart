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
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: ConstrainedText(
                'Short label',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Short label'), findsOneWidget);
    expect(tester.getSize(find.byType(ConstrainedText)).width, lessThan(240));
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

    expect(
      find.text('A deliberately long value that will scroll'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(
      find.text('A deliberately long value that will scroll'),
      findsOneWidget,
    );
  });

  testWidgets('lays out safely inside dropdown items', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          body: SizedBox(
            width: 180,
            child: DropdownButton<String>(
              isExpanded: true,
              value: 'format',
              items: [
                DropdownMenuItem(
                  value: 'format',
                  child: ConstrainedText(
                    'A short dropdown label',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
