import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/anki/models/card.dart';
import 'package:stroom/anki/models/note.dart';
import 'package:stroom/anki/models/deck.dart';
import 'package:stroom/anki/models/revlog.dart';
import 'package:stroom/anki/models/collection.dart';

void main() {
  group('AnkiCard', () {
    test('creates a new card with default values', () {
      final card = AnkiCard.createNew(deckId: 1, noteId: 1, ordinal: 0);
      expect(card.id, greaterThan(0));
      expect(card.deckId, equals(1));
      expect(card.noteId, equals(1));
      expect(card.ordinal, equals(0));
      expect(card.type, equals(CardType.newCard));
      expect(card.queue, equals(CardQueue.newQueue));
      expect(card.due, equals(0));
      expect(card.interval, equals(0));
      expect(card.easeFactor, equals(2500));
      expect(card.reps, equals(0));
      expect(card.lapses, equals(0));
    });

    test('serializes to and from JSON', () {
      final card = AnkiCard.createNew(deckId: 1, noteId: 1, ordinal: 0);
      final json = card.toJson();
      final restored = AnkiCard.fromJson(json);
      expect(restored.id, equals(card.id));
      expect(restored.deckId, equals(card.deckId));
      expect(restored.noteId, equals(card.noteId));
      expect(restored.type, equals(card.type));
      expect(restored.queue, equals(card.queue));
      expect(restored.easeFactor, equals(card.easeFactor));
    });

    test('creates a learning card from new card with initial learning step',
        () {
      final card = AnkiCard.createNew(deckId: 1, noteId: 1, ordinal: 0);
      final now = DateTime.now().millisecondsSinceEpoch;
      card.startLearning(now);
      expect(card.queue, equals(CardQueue.learningQueue));
      expect(card.due, greaterThan(0));
      // left = remaining steps, starting with 2 learning steps
      expect(card.left, greaterThan(0));
    });

    test('advances through learning steps correctly', () {
      final card = AnkiCard.createNew(deckId: 1, noteId: 1, ordinal: 0);
      final now = DateTime.now().millisecondsSinceEpoch;
      card.startLearning(now);
      final stepsRemainingBefore =
          card.left & 0xFF; // Low byte = remaining steps
      // Answer Good (idx 2) during learning - advances to next step
      card.answerLearning(now, learningSteps: [1, 10], answerIdx: 2);
      // Should have fewer remaining steps (low byte) after advancing
      expect(card.left & 0xFF, lessThan(stepsRemainingBefore));
    });

    test('graduates from learning when last step answered correctly', () {
      final card = AnkiCard.createNew(deckId: 1, noteId: 1, ordinal: 0);
      final now = DateTime.now().millisecondsSinceEpoch;
      card.startLearning(now);
      // Keep answering Good (idx 2) until graduated
      while (card.queue == CardQueue.learningQueue) {
        card.answerLearning(now, learningSteps: [1, 10], answerIdx: 2);
      }
      expect(card.queue, equals(CardQueue.reviewQueue));
      expect(card.type, equals(CardType.reviewCard));
    });

    test('resets learning on Again during learning', () {
      final card = AnkiCard.createNew(deckId: 1, noteId: 1, ordinal: 0);
      final now = DateTime.now().millisecondsSinceEpoch;
      card.startLearning(now);
      card.answerLearning(now, learningSteps: [1, 10], answerIdx: 0); // Again
      // Left should be reset to full learning steps
      expect(card.left & 0xFF, equals(2)); // low byte = remaining steps
      expect(card.lapses, equals(0)); // lapses only increment for review cards
    });

    test('calculates correct review interval on Good answer', () {
      final card = AnkiCard.createNew(deckId: 1, noteId: 1, ordinal: 0);
      final now = DateTime.now().millisecondsSinceEpoch;
      card.startLearning(now);
      // Graduate to review (use Good idx 2 to advance)
      while (card.queue == CardQueue.learningQueue) {
        card.answerLearning(now, learningSteps: [1, 10], answerIdx: 2);
      }
      // Now it's a review card - answer Good
      card.answerReview(now, answerRating: 3); // Good
      expect(card.reps, equals(2)); // 1 learning grad + 1 review
      expect(card.interval, greaterThan(0));
      expect(card.due, greaterThan(0));
    });

    test('decreases ease factor on Again answer during review', () {
      final card = AnkiCard.createNew(deckId: 1, noteId: 1, ordinal: 0);
      final now = DateTime.now().millisecondsSinceEpoch;
      card.startLearning(now);
      while (card.queue == CardQueue.learningQueue) {
        card.answerLearning(now, learningSteps: [1, 10], answerIdx: 2);
      }
      final efBefore = card.easeFactor;
      card.answerReview(now, answerRating: 1); // Again
      expect(card.easeFactor, equals(efBefore - 200)); // -200 = 20%
      expect(card.lapses, equals(1));
    });

    test('maps CardType enum values correctly', () {
      expect(CardType.newCard.index, equals(0));
      expect(CardType.learningCard.index, equals(1));
      expect(CardType.reviewCard.index, equals(2));
      expect(CardType.relearningCard.index, equals(3));
    });

    test('maps CardQueue enum values correctly', () {
      expect(CardQueue.newQueue.value, equals(0));
      expect(CardQueue.learningQueue.value, equals(1));
      expect(CardQueue.reviewQueue.value, equals(2));
      expect(CardQueue.dayLearningQueue.value, equals(3));
      expect(CardQueue.suspended.value, equals(-1));
      expect(CardQueue.userBuried.value, equals(-2));
      expect(CardQueue.schedBuried.value, equals(-3));
    });

    test('isDue returns true for card due now or earlier', () {
      final card = AnkiCard.createNew(deckId: 1, noteId: 1, ordinal: 0);
      card.due = 100;
      card.queue = CardQueue.reviewQueue;
      expect(card.isDue(150), isTrue);
      expect(card.isDue(100), isTrue);
      expect(card.isDue(50), isFalse);
    });
  });

  group('AnkiNote', () {
    test('creates a new note with default values', () {
      final note = AnkiNote.createNew(modelId: 1, fields: ['Front', 'Back']);
      expect(note.id, greaterThan(0));
      expect(note.modelId, equals(1));
      expect(note.fields, equals(['Front', 'Back']));
      expect(note.tags, isEmpty);
      expect(note.guid, isNotEmpty);
    });

    test('serializes to and from JSON', () {
      final note = AnkiNote.createNew(
        modelId: 1,
        fields: ['Q: What is 2+2?', 'A: 4'],
        tags: ['math', 'easy'],
      );
      final json = note.toJson();
      final restored = AnkiNote.fromJson(json);
      expect(restored.id, equals(note.id));
      expect(restored.fields, equals(note.fields));
      expect(restored.tags, equals(note.tags));
    });

    test('sortField returns first field text', () {
      final note = AnkiNote.createNew(
        modelId: 1,
        fields: ['What is Dart?', 'A programming language'],
      );
      expect(note.sortField, equals('What is Dart?'));
    });

    test('handles empty fields list', () {
      final note = AnkiNote.createNew(modelId: 1, fields: []);
      expect(note.fields, isEmpty);
      expect(note.sortField, equals(''));
    });

    test('adds and removes tags', () {
      final note = AnkiNote.createNew(modelId: 1, fields: ['F', 'B']);
      note.addTag('test-tag');
      expect(note.tags, contains('test-tag'));
      note.removeTag('test-tag');
      expect(note.tags, isNot(contains('test-tag')));
    });

    test('hasTag returns correct boolean', () {
      final note = AnkiNote.createNew(
        modelId: 1,
        fields: ['F', 'B'],
        tags: ['tag1', 'tag2'],
      );
      expect(note.hasTag('tag1'), isTrue);
      expect(note.hasTag('nonexistent'), isFalse);
    });
  });

  group('AnkiDeck', () {
    test('creates a new deck with default values', () {
      final deck = AnkiDeck.createNew(name: 'Default');
      expect(deck.id, greaterThan(0));
      expect(deck.name, equals('Default'));
      expect(deck.description, isEmpty);
      expect(deck.isDynamic, isFalse);
    });

    test('serializes to and from JSON', () {
      final deck = AnkiDeck.createNew(
        name: 'My Deck',
        description: 'A test deck',
      );
      final json = deck.toJson();
      final restored = AnkiDeck.fromJson(json);
      expect(restored.name, equals(deck.name));
      expect(restored.description, equals(deck.description));
    });

    test('creates a subdeck with :: separator', () {
      final parent = AnkiDeck.createNew(name: 'Parent');
      final child = AnkiDeck.createNew(name: 'Parent::Child');
      expect(parent.isParentOf('Parent::Child'), isTrue);
      expect(parent.isParentOf('Other'), isFalse);
    });

    test('gets child deck names correctly', () {
      final deck = AnkiDeck.createNew(name: 'Parent::Child');
      expect(deck.childName, equals('Child'));
    });

    test(
        'gets parent deck names correctly',
        () => () {
              final deck1 = AnkiDeck.createNew(name: 'A::B::C');
              final deck2 = AnkiDeck.createNew(name: 'X');
              expect(deck1.parentName, equals('A::B'));
              expect(deck2.parentName, isNull);
            }());
  });

  group('AnkiRevlog', () {
    test('creates a review log entry', () {
      final entry = AnkiRevlog(
        cardId: 1,
        reviewTime: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        rating: 3,
        interval: 10,
        lastInterval: 0,
        easeFactor: 2500,
        reviewDuration: 5,
      );
      expect(entry.id, greaterThan(0));
      expect(entry.cardId, equals(1));
      expect(entry.rating, equals(3));
      expect(entry.interval, equals(10));
    });

    test('serializes to and from JSON', () {
      final entry = AnkiRevlog(
        cardId: 1,
        reviewTime: 1000000,
        rating: 3,
        interval: 10,
        lastInterval: 0,
        easeFactor: 2500,
        reviewDuration: 5,
      );
      final json = entry.toJson();
      final restored = AnkiRevlog.fromJson(json);
      expect(restored.cardId, equals(entry.cardId));
      expect(restored.rating, equals(entry.rating));
    });
  });

  group('AnkiCollection', () {
    test('creates a collection with default config', () {
      final collection = AnkiCollection.createNew();
      expect(collection.id, equals(1));
      expect(collection.creationDate, greaterThan(0));
      expect(collection.nextCardId, greaterThan(0));
      expect(collection.nextNoteId, greaterThan(0));
    });

    test('manages decks correctly', () {
      final collection = AnkiCollection.createNew();
      final deck = collection.addDeck('Default');
      expect(deck.name, equals('Default'));
      expect(collection.decks, hasLength(1));

      final retrieved = collection.getDeck(deck.id);
      expect(retrieved?.name, equals('Default'));
    });

    test('renames deck updates name correctly', () {
      final collection = AnkiCollection.createNew();
      final deck = collection.addDeck('Old Name');
      collection.renameDeck(deck.id, 'New Name');
      final renamed = collection.getDeck(deck.id);
      expect(renamed?.name, equals('New Name'));
    });

    test('removes deck and its cards', () {
      final collection = AnkiCollection.createNew();
      final deck = collection.addDeck('To Remove');
      collection.removeDeck(deck.id);
      expect(collection.getDeck(deck.id), isNull);
    });

    test('gets available deck statistics', () {
      final collection = AnkiCollection.createNew();
      final deck = collection.addDeck('Stats Deck');
      final stats = collection.getDeckStats(deck.id);
      expect(stats, isNotNull);
      expect(stats.deckName, equals('Stats Deck'));
    });

    test('gets all deck names', () {
      // Unique IDs are guaranteed by different names (addDeck returns existing if same name)
      // or by time-based IDs if created in different microseconds
      final collection = AnkiCollection.createNew();
      collection.addDeck('Deck A');
      collection.addDeck('Deck B');
      collection.addDeck('Deck C');
      final names = collection.deckNames;
      expect(names, hasLength(3));
      expect(names, containsAll(['Deck A', 'Deck B', 'Deck C']));
    });
  });
}
