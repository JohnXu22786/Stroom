import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stroom/anki/database/anki_database.dart';
import 'package:stroom/anki/models/card.dart';
import 'package:stroom/anki/models/note.dart';
import 'package:stroom/anki/models/revlog.dart';
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

  test('preview-repeat cards are not advertised as normal study due work',
      () async {
    final note = Note.createNew(
      notetype_id: collection.col.modelList.first.id,
      fields: ['front', 'back'],
    );
    await collection.notes.insert(note);
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final dueCard = Card.createNew(note_id: note.id, deck_id: 1)
      ..ctype = CardType.review
      ..queue = CardQueue.previewRepeat
      ..due = nowSec - 1;
    final futureCard = Card.createNew(note_id: note.id, deck_id: 1)
      ..ctype = CardType.review
      ..queue = CardQueue.previewRepeat
      ..due = nowSec + 60;
    await collection.cards.insert(dueCard);
    await collection.cards.insert(futureCard);

    final today = collection.col.dayOrdinalAt(nowSec);
    expect(
      await collection.cards.listDue(1, nowSec, dayOrdinal: today),
      isEmpty,
    );
    expect(
      await collection.cards.listDueInDeck(1, nowSec, dayOrdinal: today),
      isEmpty,
    );
    expect(
      await AnkiScheduler().countDue(collection.col, collection.cards, 1),
      0,
    );
    expect(
      (await AnkiScheduler().getNextCard(
        collection.col,
        collection.cards,
        1,
      ))
          ?.id,
      isNull,
    );
  });

  test('review selection treats imported due values as collection day ordinals',
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
      ..queue = CardQueue.review
      ..due = today + 1;
    await collection.cards.insert(card);
    final scheduler = AnkiScheduler();

    expect(await scheduler.getNextCard(collection.col, collection.cards, 1),
        isNull);
    expect(await scheduler.countDue(collection.col, collection.cards, 1), 0);

    card.due = today;
    await collection.cards.update(card);
    expect(
      (await scheduler.getNextCard(collection.col, collection.cards, 1))?.id,
      card.id,
    );
    expect(await scheduler.countDue(collection.col, collection.cards, 1), 1);
  });

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
      await collection.db.update('col', {'mod': 1}, where: 'id = 1');
      final today = collection.col.dayOrdinalAt(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

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
      expect(answered.due, today + 25);
      expect(await collection.revlog.listByCard(card.id), hasLength(1));
      expect(
        (await collection.db.query(
          'col',
          columns: ['mod'],
          where: 'id = 1',
        )).single['mod'],
        greaterThan(1),
      );
    },
  );

  test('learning answer that remains in learning is logged as learning',
      () async {
    final note = Note.createNew(
      notetype_id: collection.col.modelList.first.id,
      fields: ['front', 'back'],
    );
    await collection.notes.insert(note);
    final card = Card.createNew(note_id: note.id, deck_id: 1)
      ..ctype = CardType.learn
      ..queue = CardQueue.learn
      ..remaining_steps = 2;
    await collection.cards.insert(card);

    await AnkiScheduler()
        .answerCard(collection.col, collection.cards, card.id, 3);

    expect((await collection.cards.get(card.id))!.queue, CardQueue.learn);
    expect(
      (await collection.revlog.listByCard(card.id)).single.review_kind,
      RevlogReviewKind.learning,
    );
  });

  test('learning answer that graduates is logged as learning', () async {
    final note = Note.createNew(
      notetype_id: collection.col.modelList.first.id,
      fields: ['front', 'back'],
    );
    await collection.notes.insert(note);
    final card = Card.createNew(note_id: note.id, deck_id: 1)
      ..ctype = CardType.learn
      ..queue = CardQueue.learn
      ..remaining_steps = 0x100;
    await collection.cards.insert(card);

    await AnkiScheduler()
        .answerCard(collection.col, collection.cards, card.id, 3);

    expect((await collection.cards.get(card.id))!.ctype, CardType.review);
    expect(
      (await collection.revlog.listByCard(card.id)).single.review_kind,
      RevlogReviewKind.learning,
    );
  });

  test('Again on a review card is logged as review', () async {
    final note = Note.createNew(
      notetype_id: collection.col.modelList.first.id,
      fields: ['front', 'back'],
    );
    await collection.notes.insert(note);
    final card = Card.createNew(note_id: note.id, deck_id: 1)
      ..ctype = CardType.review
      ..queue = CardQueue.review
      ..interval = 10
      ..reps = 2;
    await collection.cards.insert(card);

    await AnkiScheduler()
        .answerCard(collection.col, collection.cards, card.id, 1);

    expect((await collection.cards.get(card.id))!.ctype, CardType.relearn);
    expect(
      (await collection.revlog.listByCard(card.id)).single.review_kind,
      RevlogReviewKind.review,
    );
  });

  test('relearning answer is logged as relearning', () async {
    final note = Note.createNew(
      notetype_id: collection.col.modelList.first.id,
      fields: ['front', 'back'],
    );
    await collection.notes.insert(note);
    final card = Card.createNew(note_id: note.id, deck_id: 1)
      ..ctype = CardType.relearn
      ..queue = CardQueue.learn
      ..remaining_steps = 2;
    await collection.cards.insert(card);

    await AnkiScheduler()
        .answerCard(collection.col, collection.cards, card.id, 3);

    expect(
      (await collection.revlog.listByCard(card.id)).single.review_kind,
      RevlogReviewKind.relearning,
    );
  });

  test('collection save failure rolls back card, revlog, and col mod',
      () async {
    final note = Note.createNew(
      notetype_id: collection.col.modelList.first.id,
      fields: ['front', 'back'],
    );
    await collection.notes.insert(note);
    final card = Card.createNew(note_id: note.id, deck_id: 1)
      ..ctype = CardType.review
      ..queue = CardQueue.review
      ..due = 1
      ..interval = 10
      ..ease_factor = 2500
      ..reps = 2;
    await collection.cards.insert(card);
    await collection.db.update('col', {'mod': 1}, where: 'id = 1');
    final beforeCard = (await collection.cards.get(card.id))!.toMap();
    final beforeModified = (await collection.db.query(
      'col',
      columns: ['mod'],
      where: 'id = 1',
    ))
        .single['mod'];
    await collection.db.execute('''
      CREATE TRIGGER fail_collection_save
      BEFORE UPDATE OF decks ON col
      BEGIN
        SELECT RAISE(ABORT, 'injected collection save failure');
      END
    ''');

    await expectLater(
      AnkiScheduler().answerCard(collection.col, collection.cards, card.id, 3),
      throwsA(
        predicate(
          (error) =>
              error.toString().contains('injected collection save failure'),
        ),
      ),
    );

    expect((await collection.cards.get(card.id))!.toMap(), beforeCard);
    expect(await collection.revlog.listByCard(card.id), isEmpty);
    expect(
      (await collection.db.query(
        'col',
        columns: ['mod'],
        where: 'id = 1',
      ))
          .single['mod'],
      beforeModified,
    );
  });

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
