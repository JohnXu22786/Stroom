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
}
