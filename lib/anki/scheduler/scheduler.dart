import '../database/col_dao.dart';
import '../database/card_dao.dart';
import '../models/card.dart';
import '../models/revlog.dart';
import 'sm2_scheduler.dart';

/// High-level scheduler that coordinates the review workflow using DAOs.
///
/// Uses [SM2Scheduler] for algorithm and [ColDao] / [CardDao] for persistence.
class AnkiScheduler {
  final SM2Scheduler _sm2;

  AnkiScheduler({SM2Scheduler? sm2}) : _sm2 = sm2 ?? SM2Scheduler();

  /// Gets the next card to study in a deck (learning → review → new).
  Future<Card?> getNextCard(ColDao col, CardDao cards, int did) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // 1. Learning cards (time-sensitive)
    final learn = await cards.listByQueue(did, 1);
    for (final c in learn) {
      if (c.isDue(now)) return c;
    }
    final dayLearn = await cards.listByQueue(did, 3);
    for (final c in dayLearn) {
      if (c.isDue(now)) return c;
    }

    // 2. Review cards
    final review = await cards.listByQueue(did, 2);
    for (final c in review) {
      if (c.isDue(now)) return c;
    }

    // 3. New cards
    final newCards = await cards.listByQueue(did, 0);
    if (newCards.isNotEmpty) return newCards.first;

    return null;
  }

  /// Answers a card and persists the result.
  Future<void> answerCard(
    ColDao col,
    CardDao cards,
    int cid,
    int rating, {
    int reviewDuration = 0,
  }) async {
    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;
    final nowSec = nowMs ~/ 1000;
    final card = await cards.get(cid);
    if (card == null) return;

    final lastIvl = card.interval;

    switch (card.queue.value) {
      case 0: // new
        _sm2.scheduleLearning(card, nowMs);
        card.answerLearning(nowMs,
            steps: _sm2.learningSteps,
            answerIdx: (rating - 1).clamp(0, 3),
            graduatingIvl: _sm2.graduatingInterval);
        break;
      case 1: // learning
      case 3: // day learning
        card.answerLearning(nowMs,
            steps: _sm2.learningSteps,
            answerIdx: (rating - 1).clamp(0, 3),
            graduatingIvl: _sm2.graduatingInterval);
        break;
      case 2: // review
        card.answerReview(nowMs,
            rating: rating,
            hardMult: _sm2.hardMultiplier,
            relearnSteps: _sm2.learningSteps.length,
            relearnMin:
                _sm2.learningSteps.isNotEmpty ? _sm2.learningSteps[0] : 1);
        break;
      default:
        return; // suspended / buried
    }

    card.mtime = nowSec;
    await cards.update(card);

    // Log the review
    await col.revlog.insert(RevlogEntry(
      cid: cid,
      button_chosen: rating,
      interval: card.interval,
      last_interval: lastIvl,
      ease_factor: card.ease_factor,
      taken_millis: reviewDuration,
      review_kind:
          card.ctype == CardType.learn || card.ctype == CardType.relearn
              ? RevlogReviewKind.relearning
              : RevlogReviewKind.review,
    ));

    await col.save();
  }

  Future<int> countDue(ColDao col, CardDao cardDao, int did) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return cardDao.countDue(did, now);
  }
}
