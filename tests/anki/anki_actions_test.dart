import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stroom/anki/database/anki_database.dart';
import 'package:stroom/anki/models/card.dart' as anki;
import 'package:stroom/anki/models/note.dart';
import 'package:stroom/anki/models/revlog.dart';
import 'package:stroom/anki/providers/anki_actions.dart';
import 'package:stroom/anki/providers/anki_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory workDir;
  late AnkiDatabase collection;

  setUpAll(() {
    sqfliteFfiInit();
    sqflite.databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    workDir = await Directory.systemTemp.createTemp('stroom_anki_actions_');
    collection = AnkiDatabase(basePath: workDir.path);
    await collection.open();
    await collection.col.load();
  });

  tearDown(() async {
    await collection.close();
    await workDir.delete(recursive: true);
  });

  test(
    'removeNote rolls back all note data when deleting a dependent card fails',
    () async {
      final note = Note.createNew(
        notetype_id: collection.col.modelList.first.id,
        fields: ['front', 'back'],
      );
      await collection.notes.insert(note);
      final cards = [
        anki.Card.createNew(note_id: note.id, deck_id: 1),
        anki.Card.createNew(note_id: note.id, deck_id: 1),
      ];
      for (final card in cards) {
        await collection.cards.insert(card);
        await collection.db.insert(
          'revlog',
          RevlogEntry(cid: card.id, button_chosen: 3, interval: 1).toMap(),
        );
      }
      await collection.db.execute('''
      CREATE TRIGGER fail_second_card_grave
      BEFORE INSERT ON graves
      WHEN NEW.oid = ${cards.last.id} AND NEW.type = 0
      BEGIN
        SELECT RAISE(ABORT, 'injected card grave failure');
      END
    ''');

      final container = ProviderContainer(
        overrides: [
          ankiCardDaoProvider.overrideWith((ref) async => collection.cards),
          ankiNoteDaoProvider.overrideWith((ref) async => collection.notes),
        ],
      );
      addTearDown(container.dispose);

      await expectLater(
        container.read(ankiActionsProvider).removeNote(note.id),
        throwsA(isA<Exception>()),
      );

      expect(await collection.notes.get(note.id), isNotNull);
      for (final card in cards) {
        expect(await collection.cards.get(card.id), isNotNull);
        expect(
          await collection.db.query(
            'revlog',
            where: 'cid = ?',
            whereArgs: [card.id],
          ),
          hasLength(1),
        );
      }
      expect(await collection.db.query('graves'), isEmpty);
    },
  );
}
