import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stroom/anki/database/anki_database.dart';
import 'package:stroom/anki/pages/card_browser.dart';
import 'package:stroom/anki/providers/anki_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    sqflite.databaseFactory = databaseFactoryFfi;
  });

  testWidgets('uses compact radius for the search field', (tester) async {
    final directory = await Directory.systemTemp.createTemp('anki_browser_');
    final database = AnkiDatabase(basePath: directory.path);
    await database.open();

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ankiCardDaoProvider.overrideWith((_) async => database.cards),
          ],
          child: const MaterialApp(home: AnkiCardBrowser()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('无卡片'), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField));
      final border = field.decoration!.border! as OutlineInputBorder;
      expect(border.borderRadius, BorderRadius.circular(8));
    } finally {
      await database.close();
      await directory.delete(recursive: true);
    }
  });
}
