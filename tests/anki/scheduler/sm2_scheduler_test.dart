import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/anki/models/card.dart';
import 'package:stroom/anki/scheduler/sm2_scheduler.dart';

void main() {
  test('scheduleReview keeps the due value as a collection day ordinal', () {
    final card = Card.createNew(note_id: 1, deck_id: 1)
      ..queue = CardQueue.review
      ..interval = 10
      ..ease_factor = 2500;

    SM2Scheduler().scheduleReview(
      card,
      1800000000000,
      dayOrdinal: 6000,
      rating: 3,
    );

    expect(card.queue, CardQueue.review);
    expect(card.interval, 25);
    expect(card.due, 6025);
  });

  test(
    'relearning graduation uses the configured lapse interval multiplier',
    () {
      final card = Card.createNew(note_id: 1, deck_id: 1)
        ..queue = CardQueue.review
        ..interval = 30
        ..ease_factor = 2500;
      final scheduler = SM2Scheduler(
        learningSteps: const [1],
        lapseIntervalMultiplier: 0.5,
      );

      scheduler.scheduleReview(
        card,
        1800000000000,
        dayOrdinal: 6000,
        rating: 1,
      );
      card.answerLearning(
        1800000060000,
        dayOrdinal: 6001,
        steps: scheduler.learningSteps,
        answerIdx: 2,
      );

      expect(card.queue, CardQueue.review);
      expect(card.interval, 15);
      expect(card.due, 6016);
      expect(card.ease_factor, 2300);
    },
  );

  test('relearning graduation caps the multiplied interval', () {
    final card = Card.createNew(note_id: 1, deck_id: 1)
      ..queue = CardQueue.review
      ..interval = 30000
      ..ease_factor = 2500;
    final scheduler = SM2Scheduler(
      learningSteps: const [1],
      lapseIntervalMultiplier: 2,
    );

    scheduler.scheduleReview(card, 1800000000000, dayOrdinal: 6000, rating: 1);
    card.answerLearning(
      1800000060000,
      dayOrdinal: 6001,
      steps: scheduler.learningSteps,
      answerIdx: 2,
    );

    expect(card.interval, SM2Scheduler.maxInterval);
    expect(card.due, 6001 + SM2Scheduler.maxInterval);
  });
}
