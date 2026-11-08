import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/anki/pages/card_browser.dart';
import 'package:stroom/anki/providers/anki_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('uses compact radius for the search field', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ankiCardDaoProvider.overrideWith((_) async {
            throw StateError('Card loading is not needed to inspect the field');
          }),
        ],
        child: const MaterialApp(home: AnkiCardBrowser()),
      ),
    );

    final field = tester.widget<TextField>(find.byType(TextField));
    final border = field.decoration!.border! as OutlineInputBorder;
    expect(border.borderRadius, BorderRadius.circular(8));
  });
}
