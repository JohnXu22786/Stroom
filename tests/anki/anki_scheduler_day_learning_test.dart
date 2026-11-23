import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stroom/anki/database/anki_database.dart';
import 'package:stroom/anki/models/card.dart';
import 'package:stroom/anki/models/note.dart';
import 'package:stroom/anki/scheduler/scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory workDir;
  late AnkiDatabase collection;

  setUpAll(() {
    sqfliteFfiInit();
    sqflite.databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    workDir = await Directory.systemTemp.createTemp('stroom_anki_scheduler_');
    collection = AnkiDatabase(basePath: workDir.path);
    await collection.open();
    await collection.col.load();
  });

  tearDown(() async {
    await collection.close();
    await workDir.delete(recursive: true);
  });

  test(
    'collection day ordinal waits a full day after creation across midnight',
    () {
      final created =
          DateTime.utc(2026, 1, 1, 23, 59).millisecondsSinceEpoch ~/ 1000;
      collection.col.creationDate = created;

      expect(collection.col.dayOrdinalAt(created + 60), 0);
      expect(collection.col.dayOrdinalAt(created + 86400 - 1), 0);
      expect(collection.col.dayOrdinalAt(created + 86400), 1);
    },
  );

  test(
    'day-learning selection and counts use the collection day ordinal',
    () async {
      final note = Note.createNew(
        notetype_id: collection.col.modelList.first.id,
        fields: ['front', 'back'],
      );
      await collection.notes.insert(note);
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final today = collection.col.dayOrdinalAt(nowSec);
      final card = Card.createNew(note_id: note.id, deck_id: 1)
        ..ctype = CardType.review
        ..queue = CardQueue.dayLearn
        ..due = today + 1;
      await collection.cards.insert(card);
      final scheduler = AnkiScheduler();

      expect(
        await scheduler.getNextCard(collection.col, collection.cards, 1),
        isNull,
      );
      expect(await scheduler.countDue(collection.col, collection.cards, 1), 0);

      card.due = today;
      await collection.cards.update(card);

      expect(
        (await scheduler.getNextCard(collection.col, collection.cards, 1))?.id,
        card.id,
      );
      expect(await scheduler.countDue(collection.col, collection.cards, 1), 1);
    },
  );

  test(
    'answering a day-learning card applies review scheduling and persists',
    () async {
      final note = Note.createNew(
        notetype_id: collection.col.modelList.first.id,
        fields: ['front', 'back'],
      );
      await collection.notes.insert(note);
      final card = Card.createNew(note_id: note.id, deck_id: 1)
        ..ctype = CardType.review
        ..queue = CardQueue.dayLearn
        ..due = 1
        ..interval = 10
        ..reps = 2;
      await collection.cards.insert(card);

      await AnkiScheduler().answerCard(
        collection.col,
        collection.cards,
        card.id,
        3,
      );

      final answered = (await collection.cards.get(card.id))!;
      expect(answered.queue, CardQueue.review);
      expect(answered.ctype, CardType.review);
      expect(answered.reps, 3);
      expect(answered.interval, 25);
      expect(await collection.revlog.listByCard(card.id), hasLength(1));
    },
  );

  test(
    'Again on a day-learning card follows review lapse scheduling',
    () async {
      final note = Note.createNew(
        notetype_id: collection.col.modelList.first.id,
        fields: ['front', 'back'],
      );
      await collection.notes.insert(note);
      final card = Card.createNew(note_id: note.id, deck_id: 1)
        ..ctype = CardType.review
        ..queue = CardQueue.dayLearn
        ..due = 1
        ..interval = 10
        ..reps = 2;
      await collection.cards.insert(card);

      await AnkiScheduler().answerCard(
        collection.col,
        collection.cards,
        card.id,
        1,
      );

      final answered = (await collection.cards.get(card.id))!;
      expect(answered.queue, CardQueue.learn);
      expect(answered.ctype, CardType.relearn);
      expect(answered.lapses, 1);
      expect(answered.reps, 2);
      expect(answered.ease_factor, 2300);
      expect(await collection.revlog.listByCard(card.id), hasLength(1));
    },
  );
}
