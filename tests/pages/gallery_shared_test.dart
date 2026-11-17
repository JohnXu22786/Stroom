import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/gallery_shared.dart';

void main() {
  testWidgets('format badge keeps its label in a constrained text widget', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 36, child: buildFormatIcon('verylongformat')),
        ),
      ),
    );

    expect(find.text('VERYLONGFORMAT'), findsOneWidget);
  });
}
