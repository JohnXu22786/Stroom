import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stroom/anki/database/anki_database.dart';
import 'package:stroom/anki/models/card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory workDir;
  late AnkiDatabase database;

  setUpAll(() {
    sqfliteFfiInit();
    sqflite.databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    workDir = await Directory.systemTemp.createTemp('stroom_anki_due_stats_');
    database = AnkiDatabase(basePath: workDir.path);
    await database.open();
  });

  tearDown(() async {
    await database.close();
    await workDir.delete(recursive: true);
  });

  test(
    'counts only due review cards, including cards due at the boundary',
    () async {
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final cards = [
        Card(note_id: 1, deck_id: 1, queue: CardQueue.review, due: nowSec - 60),
        Card(note_id: 2, deck_id: 1, queue: CardQueue.review, due: nowSec),
        Card(
          note_id: 3,
          deck_id: 1,
          queue: CardQueue.review,
          due: nowSec + 3600,
        ),
        Card(note_id: 4, deck_id: 1, queue: CardQueue.learn, due: nowSec - 60),
      ];
      for (final card in cards) {
        await database.cards.insert(card);
      }

      expect(await database.cards.countDueReviewAll(nowSec), 2);
    },
  );
}
