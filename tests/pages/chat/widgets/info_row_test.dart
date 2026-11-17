import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/chat/widgets/info_row.dart';

void main() {
  testWidgets('keeps a long value available in its constrained text slot', (
    tester,
  ) async {
    const value =
        'A long file metadata value that can exceed the two line display area';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 220,
            child: InfoRow(label: 'Name', value: value),
          ),
        ),
      ),
    );

    expect(find.text(value), findsOneWidget);
  });
}
