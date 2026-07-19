import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/anki/models/card.dart';
import 'package:stroom/anki/models/note.dart';
import 'package:stroom/anki/models/deck.dart';
import 'package:stroom/anki/models/collection.dart';

void main() {
  group('AnkiCollection Integration', () {
    late AnkiCollection collection;

    setUp(() {
      collection = AnkiCollection.createNew();
    });

    test('full CRUD: add, read, update, delete card', () {
      final deck = collection.addDeck('Test Deck');
      final noteId = collection.addNote(AnkiNote.createNew(
        modelId: 1,
        fields: ['Question', 'Answer'],
      ));
      final card = AnkiCard.createNew(
        deckId: deck.id,
        noteId: noteId,
        ordinal: 0,
      );
      collection.addCard(card);

      // Read
      expect(collection.getCard(card.id), isNotNull);

      // Update
      card.easeFactor = 2000;
      collection.updateCard(card);
      expect(collection.getCard(card.id)!.easeFactor, equals(2000));

      // Delete
      collection.removeCard(card.id);
      expect(collection.getCard(card.id), isNull);
    });

    test('getCardsByDeck returns correct cards', () {
      final deck1 = collection.addDeck('Deck 1');
      final deck2 = collection.addDeck('Deck 2');
      final noteId = collection.addNote(
        AnkiNote.createNew(modelId: 1, fields: ['Q', 'A']),
      );

      collection.addCard(AnkiCard.createNew(deckId: deck1.id, noteId: noteId, ordinal: 0));
      collection.addCard(AnkiCard.createNew(deckId: deck1.id, noteId: noteId, ordinal: 1));
      collection.addCard(AnkiCard.createNew(deckId: deck2.id, noteId: noteId, ordinal: 0));

      expect(collection.getCardsByDeck(deck1.id), hasLength(2));
      expect(collection.getCardsByDeck(deck2.id), hasLength(1));
    });

    test('getNotesByModel returns correct notes', () {
      collection.addNote(AnkiNote.createNew(modelId: 1, fields: ['Q1', 'A1']));
      collection.addNote(AnkiNote.createNew(modelId: 1, fields: ['Q2', 'A2']));
      collection.addNote(AnkiNote.createNew(modelId: 2, fields: ['Q3', 'A3']));

      expect(collection.getNotesByModel(1), hasLength(2));
      expect(collection.getNotesByModel(2), hasLength(1));
    });

    test('getDueCards returns only due cards', () {
      final deck = collection.addDeck('Test');
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final noteId = collection.addNote(
        AnkiNote.createNew(modelId: 1, fields: ['Q', 'A']),
      );

      final dueCard = AnkiCard.createNew(deckId: deck.id, noteId: noteId, ordinal: 0);
      dueCard.due = 0;
      dueCard.queue = CardQueue.newQueue;
      collection.addCard(dueCard);

      final notDueCard = AnkiCard.createNew(deckId: deck.id, noteId: noteId, ordinal: 1);
      notDueCard.due = now + 86400; // Tomorrow
      notDueCard.queue = CardQueue.reviewQueue;
      collection.addCard(notDueCard);

      final dueCards = collection.getDueCards(deck.id);
      expect(dueCards, hasLength(1));
      expect(dueCards.first.id, equals(dueCard.id));
    });

    test('deck statistics are accurate', () {
      final deck = collection.addDeck('Stats');
      final noteId = collection.addNote(
        AnkiNote.createNew(modelId: 1, fields: ['Q', 'A']),
      );

      // Add cards in different states
      final newCard = AnkiCard.createNew(deckId: deck.id, noteId: noteId, ordinal: 0);
      newCard.queue = CardQueue.newQueue;
      collection.addCard(newCard);

      final learningCard = AnkiCard.createNew(deckId: deck.id, noteId: noteId, ordinal: 1);
      learningCard.queue = CardQueue.learningQueue;
      learningCard.due = DateTime.now().millisecondsSinceEpoch + 60000;
      collection.addCard(learningCard);

      final reviewCard = AnkiCard.createNew(deckId: deck.id, noteId: noteId, ordinal: 2);
      reviewCard.queue = CardQueue.reviewQueue;
      reviewCard.due = 0;
      collection.addCard(reviewCard);

      final stats = collection.getDeckStats(deck.id);
      expect(stats.newCount, equals(1));
      expect(stats.learningCount, equals(1));
      expect(stats.reviewCount, equals(1));
      expect(stats.totalCount, equals(3));
    });

    test('empty collection returns zero stats', () {
      final deck = collection.addDeck('Empty');
      final stats = collection.getDeckStats(deck.id);
      expect(stats.totalCount, equals(0));
      expect(stats.newCount, equals(0));
      expect(stats.learningCount, equals(0));
      expect(stats.reviewCount, equals(0));
    });

    test('serializes entire collection to and from JSON', () {
      final deck = collection.addDeck('Full Deck');
      final noteId = collection.addNote(
        AnkiNote.createNew(modelId: 1, fields: ['Q', 'A'], tags: ['tag']),
      );
      final card = AnkiCard.createNew(deckId: deck.id, noteId: noteId, ordinal: 0);
      card.reps = 5;
      card.interval = 30;
      collection.addCard(card);

      final json = collection.toJson();
      final restored = AnkiCollection.fromJson(json);

      expect(restored.decks, hasLength(1));
      expect(restored.notes, hasLength(1));
      expect(restored.cards, hasLength(1));
      expect(restored.getDeck(deck.id)!.name, equals('Full Deck'));
      expect(restored.getCard(card.id)!.reps, equals(5));
      final note = restored.notes.values.first;
      expect(note.tags, contains('tag'));
    });
  });
}
