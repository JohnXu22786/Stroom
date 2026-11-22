import 'dart:convert';
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
      'addCard rolls back the note and collection update when card creation fails',
      () async {
    await collection.db.update(
        'col',
        {
          'models': '{}',
          'mod': 1,
        },
        where: 'id = 1');
    await collection.col.reload();
    expect(collection.col.modelList, isEmpty);
    final defaultDeck = collection.col.deckList.first;
    defaultDeck
      ..name = 'Pending edit'
      ..mtimeSecs = 1
      ..usn = 5;

    await collection.db.update('col', {'mod': 1}, where: 'id = 1');
    final initialCollection = (await collection.db.query(
      'col',
      columns: ['mod'],
      where: 'id = 1',
    ))
        .single['mod'];
    await collection.db.execute('''
      CREATE TRIGGER fail_card_insert
      BEFORE INSERT ON cards
      BEGIN
        SELECT RAISE(ABORT, 'injected card insert failure');
      END
    ''');

    final container = ProviderContainer(
      overrides: [
        ankiColDaoProvider.overrideWith((ref) async => collection.col),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(ankiActionsProvider).addCard(1, 'front', 'back'),
      throwsA(isA<Exception>()),
    );

    expect(await collection.notes.all(), isEmpty);
    expect(await collection.cards.all(), isEmpty);
    expect(collection.col.modelList, isEmpty);
    expect(
      identical(collection.col.getDeck(defaultDeck.id), defaultDeck),
      isTrue,
    );
    expect(collection.col.getDeck(defaultDeck.id)!.name, 'Pending edit');
    expect(collection.col.getDeck(defaultDeck.id)!.mtimeSecs, 1);
    expect(collection.col.getDeck(defaultDeck.id)!.usn, 5);
    final collectionAfterFailure = await collection.db.query(
      'col',
      columns: ['mod', 'models'],
      where: 'id = 1',
    );
    expect(collectionAfterFailure.single['mod'], initialCollection);
    expect(collectionAfterFailure.single['models'], '{}');
  });

  test(
    'failed queued addCard keeps model state consistent with a later success',
    () async {
      await collection.db.update('col', {'models': '{}'}, where: 'id = 1');
      await collection.col.reload();
      expect(collection.col.modelList, isEmpty);
      await collection.db.execute('''
      CREATE TRIGGER fail_selected_card_insert
      BEFORE INSERT ON cards
      WHEN (SELECT flds FROM notes WHERE id = NEW.nid) LIKE 'fail%'
      BEGIN
        SELECT RAISE(ABORT, 'injected selected card insert failure');
      END
    ''');

      final container = ProviderContainer(
        overrides: [
          ankiColDaoProvider.overrideWith((ref) async => collection.col),
        ],
      );
      addTearDown(container.dispose);
      final actions = container.read(ankiActionsProvider);

      final successfulCreation = actions.addCard(1, 'first', 'card');
      final failedCreation = actions.addCard(1, 'fail after first', 'card');
      await successfulCreation;
      await expectLater(failedCreation, throwsA(isA<Exception>()));

      expect(await collection.notes.all(), hasLength(1));
      expect(await collection.cards.all(), hasLength(1));
      expect(collection.col.modelList, hasLength(2));

      await collection.db.update('col', {'models': '{}'}, where: 'id = 1');
      await collection.col.reload();
      expect(collection.col.modelList, isEmpty);

      final failedBeforeSuccess =
          actions.addCard(1, 'fail before success', 'card');
      final successfulAfterFailure = actions.addCard(1, 'second', 'card');
      await expectLater(failedBeforeSuccess, throwsA(isA<Exception>()));
      await successfulAfterFailure;

      expect(await collection.notes.all(), hasLength(2));
      expect(await collection.cards.all(), hasLength(2));
      expect(collection.col.modelList, hasLength(2));
      expect(
        collection.col.modelList.every((model) => model.usn == -1),
        isTrue,
      );
      final persistedModels = jsonDecode(
        (await collection.db.query(
          'col',
          columns: ['models'],
          where: 'id = 1',
        ))
            .single['models'] as String,
      ) as Map<String, dynamic>;
      expect(
        persistedModels.values.every((model) => model['usn'] == -1),
        isTrue,
      );
    },
  );

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
