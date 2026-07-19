import '../models/card.dart';
import '../models/collection.dart';
import '../models/revlog.dart';
import 'sm2_scheduler.dart';

/// High-level scheduler that manages the review workflow for a collection.
///
/// This class orchestrates the SM-2 algorithm, coordinating between
/// the collection (data), the SM2Scheduler (algorithm), and the
/// review log (history). It provides a clean API for:
/// - Getting due cards from a deck
/// - Answering cards during study
/// - Tracking review history
class AnkiScheduler {
  final SM2Scheduler _sm2;

  AnkiScheduler({SM2Scheduler? sm2}) : _sm2 = sm2 ?? SM2Scheduler();

  /// Gets all due cards from a specific deck.
  List<AnkiCard> getDueCards(AnkiCollection collection, int deckId) {
    return collection.getDueCards(deckId);
  }

  /// Gets all cards in the new queue for a deck.
  List<AnkiCard> getNewCards(AnkiCollection collection, int deckId) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return collection.cards.values
        .where((c) =>
            c.deckId == deckId &&
            c.queue == CardQueue.newQueue &&
            c.isDue(now))
        .toList();
  }

  /// Gets all cards in the learning queue for a deck.
  List<AnkiCard> getLearningCards(AnkiCollection collection, int deckId) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return collection.cards.values
        .where((c) =>
            c.deckId == deckId &&
            (c.queue == CardQueue.learningQueue ||
                c.queue == CardQueue.dayLearningQueue) &&
            c.isDue(now))
        .toList();
  }

  /// Gets all due review cards for a deck.
  List<AnkiCard> getReviewCards(AnkiCollection collection, int deckId) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return collection.cards.values
        .where((c) =>
            c.deckId == deckId &&
            c.queue == CardQueue.reviewQueue &&
            c.isDue(now))
        .toList();
  }

  /// Counts all due cards in a deck.
  int countDueCards(AnkiCollection collection, int deckId) {
    return getDueCards(collection, deckId).length;
  }

  /// Counts new cards in a deck.
  int countNewCards(AnkiCollection collection, int deckId) {
    return collection.cards.values
        .where((c) => c.deckId == deckId && c.queue == CardQueue.newQueue)
        .length;
  }

  /// Counts cards in learning in a deck.
  int countLearningCards(AnkiCollection collection, int deckId) {
    return collection.cards.values
        .where((c) =>
            c.deckId == deckId &&
            (c.queue == CardQueue.learningQueue ||
                c.queue == CardQueue.dayLearningQueue))
        .length;
  }

  /// Answers a card with the given rating and updates the collection.
  ///
  /// [collection] - The collection containing the card
  /// [cardId] - ID of the card being answered
  /// [now] - Current time
  /// [answerRating] - 1=Again, 2=Hard, 3=Good, 4=Easy
  /// [reviewDuration] - How long the review took (seconds)
  void answerCard(
    AnkiCollection collection,
    int cardId,
    DateTime now, {
    required int answerRating,
    int reviewDuration = 0,
  }) {
    final card = collection.getCard(cardId);
    if (card == null) return;

    final nowMs = now.millisecondsSinceEpoch;
    final nowSec = nowMs ~/ 1000;

    // Record the state before answering for the revlog
    final lastInterval = card.interval;

    // Process the answer based on current queue.
    // For learning queues, map Anki rating (1-4) to learning answerIdx (0-3):
    // Again(1)→0, Hard(2)→1, Good(3)→2, Easy(4)→3
    final learningAnswerIdx = answerRating - 1;
    switch (card.queue) {
      case CardQueue.newQueue:
        _sm2.scheduleLearning(card, nowMs);
        card.answerLearning(nowMs,
            learningSteps: _sm2.learningSteps,
            answerIdx: learningAnswerIdx,
            graduatingInterval: _sm2.graduatingInterval);
        break;
      case CardQueue.learningQueue:
      case CardQueue.dayLearningQueue:
        card.answerLearning(nowMs,
            learningSteps: _sm2.learningSteps,
            answerIdx: learningAnswerIdx,
            graduatingInterval: _sm2.graduatingInterval);
        break;
      case CardQueue.reviewQueue:
        card.answerReview(nowMs,
            answerRating: answerRating,
            hardMultiplier: _sm2.hardMultiplier,
            relearningSteps: _sm2.learningSteps.length,
            relearningStepMinutes:
                _sm2.learningSteps.isNotEmpty ? _sm2.learningSteps[0] : 1);
        break;
      case CardQueue.suspended:
      case CardQueue.userBuried:
      case CardQueue.schedBuried:
        return; // Do nothing for suspended/buried cards
    }

    // Update the card in the collection
    card.modified = nowSec;
    collection.updateCard(card);

    // Record the review in the log
    collection.addRevlogEntry(AnkiRevlog(
      cardId: cardId,
      reviewTime: nowSec,
      rating: answerRating,
      interval: card.interval,
      lastInterval: lastInterval,
      easeFactor: card.easeFactor,
      reviewDuration: reviewDuration,
    ));
  }

  /// Gets the next card to review for a "study session".
  ///
  /// Returns cards in order: learning first, then review, then new.
  AnkiCard? getNextCard(AnkiCollection collection, int deckId) {
    // First, check learning cards (time-sensitive)
    final learningCards = getLearningCards(collection, deckId);
    if (learningCards.isNotEmpty) {
      return learningCards.first;
    }

    // Then, check review cards
    final reviewCards = getReviewCards(collection, deckId);
    if (reviewCards.isNotEmpty) {
      return reviewCards.first;
    }

    // Finally, check new cards
    final newCards = getNewCards(collection, deckId);
    if (newCards.isNotEmpty) {
      return newCards.first;
    }

    return null; // No cards due
  }
}
