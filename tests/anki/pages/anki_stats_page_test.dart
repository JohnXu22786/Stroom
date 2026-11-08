import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stroom/anki/database/anki_database.dart';
import 'package:stroom/anki/pages/anki_stats_page.dart';
import 'package:stroom/anki/providers/anki_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    sqflite.databaseFactory = databaseFactoryFfi;
  });

  testWidgets('uses compact radius for the statistics icon plate', (
    tester,
  ) async {
    final directory = await Directory.systemTemp.createTemp('anki_stats_');
    final database = AnkiDatabase(basePath: directory.path);
    await database.open();

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [ankiDatabaseProvider.overrideWith((_) async => database)],
          child: const MaterialApp(home: AnkiStatsPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('总卡片数'), findsOneWidget);
      final plate = tester.widget<Container>(
        find
            .ancestor(
              of: find.byIcon(Icons.auto_stories),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = plate.decoration! as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(8));
    } finally {
      await database.close();
      await directory.delete(recursive: true);
    }
  });
}
