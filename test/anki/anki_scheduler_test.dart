import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/anki/models/card.dart';
import 'package:stroom/anki/scheduler/sm2_scheduler.dart';
import 'package:stroom/anki/scheduler/scheduler.dart';
import 'package:stroom/anki/models/deck.dart';
import 'package:stroom/anki/models/collection.dart';

void main() {
  group('SM2Scheduler', () {
    late SM2Scheduler scheduler;
    late DateTime now;

    setUp(() {
      scheduler = SM2Scheduler();
      now = DateTime.now();
    });

    test('computes initial interval for new cards', () {
      // After first review (graduating from learning), interval should be 1 day
      final interval = scheduler.nextReviewInterval(
        easeFactor: 2500,
        currentInterval: 0,
        reps: 0,
      );
      expect(interval, equals(1)); // First real review = 1 day
    });

    test('computes interval after multiple reviews', () {
      // With EF 250%, after 3 reviews: I(3) = I(2) * EF = 6 * 2.5 = 15
      final interval = scheduler.nextReviewInterval(
        easeFactor: 2500,
        currentInterval: 6,
        reps: 3,
      );
      expect(interval, equals(15));
    });

    test('computes interval with 130% minimum ease factor', () {
      final interval = scheduler.nextReviewInterval(
        easeFactor: 1300,
        currentInterval: 10,
        reps: 5,
      );
      expect(interval, equals(13)); // 10 * 1.3
    });

    test('adjusts ease factor on Good answer', () {
      // Good keeps the same ease factor
      final newEf = scheduler.adjustEaseFactor(2500, 3);
      expect(newEf, equals(2500));
    });

    test('adjusts ease factor on Easy answer', () {
      // Easy increases ease factor
      final newEf = scheduler.adjustEaseFactor(2500, 4);
      expect(newEf, greaterThan(2500));
    });

    test('adjusts ease factor on Again answer', () {
      // Again decreases ease factor
      final newEf = scheduler.adjustEaseFactor(2500, 1);
      expect(newEf, lessThan(2500));
    });

    test('adjusts ease factor on Hard answer', () {
      // Hard decreases ease factor slightly
      final newEf = scheduler.adjustEaseFactor(2500, 2);
      expect(newEf, lessThan(2500));
      expect(newEf, greaterThan(scheduler.adjustEaseFactor(2500, 1)));
    });

    test('ease factor never goes below minimum', () {
      final newEf = scheduler.adjustEaseFactor(1300, 1);
      expect(newEf, equals(1300));
    });

    test('computes due date for card', () {
      final due = scheduler.computeDueDate(now, 10);
      // due is epoch seconds, should be 10 days from now
      expect(due - (now.millisecondsSinceEpoch ~/ 1000), equals(864000));
      // 864000 seconds = 10 days
    });

    test('schedules learning card with correct timing', () {
      final card = AnkiCard.createNew(deckId: 1, noteId: 1, ordinal: 0);
      scheduler.scheduleLearning(card, now.millisecondsSinceEpoch);
      expect(card.queue, equals(CardQueue.learningQueue));
      expect(card.left & 0xFF, equals(2)); // 2 learning steps remaining
    });

    test('schedules review card with correct interval', () {
      final card = AnkiCard.createNew(deckId: 1, noteId: 1, ordinal: 0);
      card.type = CardType.reviewCard;
      card.queue = CardQueue.reviewQueue;
      card.reps = 5;
      card.interval = 30;
      card.easeFactor = 2500;

      scheduler.scheduleReview(card, now.millisecondsSinceEpoch,
          answerRating: 3);
      expect(card.interval, equals(75)); // 30 * 2.5 = 75
      expect(card.reps, equals(6));
    });

    test('handles lapse (Again on review card)', () {
      final card = AnkiCard.createNew(deckId: 1, noteId: 1, ordinal: 0);
      card.type = CardType.reviewCard;
      card.queue = CardQueue.reviewQueue;
      card.interval = 30;
      card.easeFactor = 2500;
      card.lapses = 0;

      scheduler.scheduleReview(card, now.millisecondsSinceEpoch,
          answerRating: 1);
      expect(card.lapses, equals(1));
      expect(
          card.queue, equals(CardQueue.learningQueue)); // Goes back to learning
    });

    test('minimum interval is always at least 1 day', () {
      // Even with very low ease factor and small interval
      final interval = scheduler.nextReviewInterval(
        easeFactor: 1300,
        currentInterval: 0,
        reps: 0,
      );
      expect(interval, greaterThanOrEqualTo(1));
    });

    test('maximum interval is capped', () {
      final interval = scheduler.nextReviewInterval(
        easeFactor: 5000,
        currentInterval: 36500, // 100 years
        reps: 100,
      );
      expect(interval, lessThanOrEqualTo(36500)); // max 100 years
    });

    test('learning steps are properly ordered', () {
      expect(scheduler.learningSteps, hasLength(2));
      expect(scheduler.learningSteps[0], equals(1));
      expect(scheduler.learningSteps[1], equals(10));
    });
  });

  group('AnkiScheduler (high-level)', () {
    late AnkiScheduler scheduler;
    late AnkiCollection collection;
    late int deckId;

    setUp(() {
      scheduler = AnkiScheduler();
      collection = AnkiCollection.createNew();
      deckId = collection.addDeck('Test Deck').id;
    });

    test('gets due cards from deck', () {
      final card = AnkiCard.createNew(deckId: deckId, noteId: 1, ordinal: 0);
      card.due = 0;
      card.queue = CardQueue.newQueue;
      collection.addCard(card);

      final dueCards = scheduler.getDueCards(collection, deckId);
      expect(dueCards, hasLength(1));
    });

    test('does not return non-due cards', () {
      final card = AnkiCard.createNew(deckId: deckId, noteId: 1, ordinal: 0);
      final futureTime =
          DateTime.now().millisecondsSinceEpoch ~/ 1000 + 86400; // tomorrow
      card.due = futureTime;
      card.queue = CardQueue.reviewQueue;
      collection.addCard(card);

      final dueCards = scheduler.getDueCards(collection, deckId);
      expect(dueCards, isEmpty);
    });

    test('counts due cards correctly', () {
      // Add 3 cards to deck
      for (int i = 0; i < 3; i++) {
        final card =
            AnkiCard.createNew(deckId: deckId, noteId: 1 + i, ordinal: 0);
        card.due = 0;
        card.queue = CardQueue.newQueue;
        collection.addCard(card);
      }
      // Add 1 non-due review card (due in the future)
      final card = AnkiCard.createNew(deckId: deckId, noteId: 4, ordinal: 0);
      final futureTime =
          DateTime.now().millisecondsSinceEpoch ~/ 1000 + 86400; // tomorrow
      card.due = futureTime;
      card.queue = CardQueue.reviewQueue;
      collection.addCard(card);

      expect(scheduler.countDueCards(collection, deckId), equals(3));
    });

    test('counts new cards correctly', () {
      for (int i = 0; i < 5; i++) {
        final card =
            AnkiCard.createNew(deckId: deckId, noteId: 1 + i, ordinal: 0);
        card.queue = CardQueue.newQueue;
        collection.addCard(card);
      }

      expect(scheduler.countNewCards(collection, deckId), equals(5));
    });

    test('counts cards in learning correctly', () {
      for (int i = 0; i < 2; i++) {
        final card =
            AnkiCard.createNew(deckId: deckId, noteId: 1 + i, ordinal: 0);
        card.queue = CardQueue.learningQueue;
        card.due =
            DateTime.now().millisecondsSinceEpoch + 60000; // 1 minute from now
        collection.addCard(card);
      }

      expect(scheduler.countLearningCards(collection, deckId), equals(2));
    });

    test('answers card and updates collection', () {
      final card = AnkiCard.createNew(deckId: deckId, noteId: 1, ordinal: 0);
      collection.addCard(card);
      final now = DateTime.now();

      scheduler.answerCard(collection, card.id, now, answerRating: 3);
      final updatedCard = collection.getCard(card.id);
      expect(updatedCard, isNotNull);
      expect(updatedCard!.reps, equals(0)); // Still in learning
      expect(updatedCard.queue, equals(CardQueue.learningQueue));
    });

    test('processes full review cycle correctly', () {
      final card = AnkiCard.createNew(deckId: deckId, noteId: 1, ordinal: 0);
      collection.addCard(card);
      final now = DateTime.now();

      // Step 1: Answer learning (Good, rating 3) - advances to next learning step
      // answerIdx = 3-1 = 2 (Good in learning)
      scheduler.answerCard(collection, card.id, now, answerRating: 3);
      var updatedCard = collection.getCard(card.id)!;
      expect(updatedCard.queue, equals(CardQueue.learningQueue));

      // Step 2: Answer learning (Good, rating 3) - graduates to review
      scheduler.answerCard(collection, card.id, now, answerRating: 3);
      updatedCard = collection.getCard(card.id)!;
      expect(updatedCard.queue, equals(CardQueue.reviewQueue));
      expect(updatedCard.type, equals(CardType.reviewCard));
      expect(updatedCard.interval, equals(1)); // graduating interval

      // Step 3: Answer review (Good, rating 3) - should update review interval
      scheduler.answerCard(collection, card.id, now, answerRating: 3);
      updatedCard = collection.getCard(card.id)!;
      // _nextInterval(1, 2500) = (1 * 2500 / 1000).round() = 3
      expect(updatedCard.interval, equals(3));
      // reps = 1 (from graduation in step 2) + 1 (this review) = 2
      expect(updatedCard.reps, equals(2));
    });
  });
}
