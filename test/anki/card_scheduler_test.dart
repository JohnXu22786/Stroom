import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/anki/models/card.dart';
import 'package:stroom/anki/models/deck.dart';
import 'package:stroom/anki/models/note.dart';
import 'package:stroom/anki/models/revlog.dart';
import 'package:stroom/anki/models/grave.dart';
import 'package:stroom/anki/models/model.dart';

void main() {
  group('Card — upstream Card struct mapping', () {
    test('creates new card with default Anki field values', () {
      final c = Card.createNew(note_id: 1, deck_id: 1);
      expect(c.id, greaterThan(0));
      expect(c.note_id, equals(1));
      expect(c.deck_id, equals(1));
      expect(c.template_idx, equals(0));
      expect(c.ctype, equals(CardType.new_));
      expect(c.queue, equals(CardQueue.new_));
      expect(c.due, equals(0));
      expect(c.interval, equals(0));
      expect(c.ease_factor, equals(2500)); // 250%
      expect(c.reps, equals(0));
      expect(c.lapses, equals(0));
      expect(c.remaining_steps, equals(0));
      expect(c.original_due, equals(0));
      expect(c.original_deck_id, equals(0));
      expect(c.flags, equals(0));
      expect(c.custom_data, equals(''));
    });

    test('toMap/fromMap round-trip preserves all fields', () {
      final c = Card.createNew(note_id: 42, deck_id: 7, template_idx: 2);
      c.ctype = CardType.review;
      c.queue = CardQueue.review;
      c.due = 12345;
      c.interval = 30;
      c.ease_factor = 2200;
      c.reps = 5;
      c.lapses = 2;
      c.remaining_steps = 0x0102;
      c.original_due = 100;
      c.original_deck_id = 3;
      c.flags = 1;
      c.custom_data = '{"extra":1}';
      final map = c.toMap();
      final r = Card.fromMap(map);
      expect(r.id, c.id);
      expect(r.note_id, 42);
      expect(r.deck_id, 7);
      expect(r.template_idx, 2);
      expect(r.ctype, CardType.review);
      expect(r.queue, CardQueue.review);
      expect(r.due, 12345);
      expect(r.interval, 30);
      expect(r.ease_factor, 2200);
      expect(r.reps, 5);
      expect(r.lapses, 2);
      expect(r.remaining_steps, 0x0102);
      expect(r.original_due, 100);
      expect(r.original_deck_id, 3);
      expect(r.flags, 1);
      expect(r.custom_data, '{"extra":1}');
    });

    test('isDue returns false for suspended cards', () {
      final c = Card.createNew(note_id: 1, deck_id: 1);
      c.queue = CardQueue.suspended;
      expect(c.isDue(0), isFalse);
    });

    test('new cards are always due', () {
      final c = Card.createNew(note_id: 1, deck_id: 1);
      expect(c.isDue(0), isTrue);
    });

    test('review card due when due <= nowSec', () {
      final c = Card.createNew(note_id: 1, deck_id: 1);
      c.queue = CardQueue.review;
      c.due = 100;
      expect(c.isDue(100), isTrue);
      expect(c.isDue(101), isTrue);
      expect(c.isDue(99), isFalse);
    });

    test('startLearning transitions new→learning', () {
      final c = Card.createNew(note_id: 1, deck_id: 1);
      c.startLearning(0, steps: [1, 10]);
      expect(c.queue, equals(CardQueue.learn));
      expect(c.ctype, equals(CardType.learn));
      expect(c.remaining_steps, equals(2)); // 2 steps remaining
      expect(c.due, equals(1 * 60)); // 1 min in seconds
    });

    test('answerLearning Again resets to first step', () {
      final c = Card.createNew(note_id: 1, deck_id: 1);
      c.startLearning(0, steps: [1, 10]);
      c.answerLearning(0, steps: [1, 10], answerIdx: 0); // Again
      expect(c.remaining_steps, equals(2)); // back to full steps
      expect(c.due, equals(1 * 60));
    });

    test('answerLearning Good graduates after last step', () {
      final c = Card.createNew(note_id: 1, deck_id: 1);
      c.startLearning(0, steps: [1, 10]);
      c.answerLearning(0, steps: [1, 10], answerIdx: 2); // Good → step 2
      expect(
          c.queue, equals(CardQueue.learn)); // still learning (one step left)

      c.answerLearning(0, steps: [1, 10], answerIdx: 2); // Good → graduate
      expect(c.queue, equals(CardQueue.review));
      expect(c.ctype, equals(CardType.review));
      expect(c.interval, equals(1)); // graduating interval
      expect(c.reps, equals(1));
      expect(c.remaining_steps, equals(0));
    });

    test('answerLearning Hard repeats current step', () {
      final c = Card.createNew(note_id: 1, deck_id: 1);
      final t = DateTime.now().millisecondsSinceEpoch;
      c.startLearning(t, steps: [1, 10]);
      final dueBefore = c.due;
      c.answerLearning(t, steps: [1, 10], answerIdx: 1); // Hard
      // Due is in epoch seconds, step=0 => t~/1000 + 1*60
      expect(c.due, equals(t ~/ 1000 + 1 * 60));
      // Same as startLearning's due (same step)
      expect(c.due, equals(dueBefore));
    });

    test('answerLearning Easy graduates immediately with bonus', () {
      final c = Card.createNew(note_id: 1, deck_id: 1);
      c.startLearning(0, steps: [1, 10]);
      c.answerLearning(0, steps: [1, 10], answerIdx: 3); // Easy
      expect(c.queue, equals(CardQueue.review));
      // Anki easyBonus: graduatingIvl * 1.3 = 1 * 1.3 = 1 (rounded)
      expect(c.interval, equals(1));
    });

    test('answerReview Again causes lapse', () {
      final c = Card.createNew(note_id: 1, deck_id: 1);
      c.queue = CardQueue.review;
      c.interval = 30;
      c.ease_factor = 2500;
      c.answerReview(0, rating: 1); // Again
      expect(c.lapses, equals(1));
      expect(c.queue, equals(CardQueue.learn));
      expect(c.ctype, equals(CardType.relearn));
      expect(c.ease_factor, equals(2300)); // -200
    });

    test('answerReview Good updates interval', () {
      final c = Card.createNew(note_id: 1, deck_id: 1);
      c.queue = CardQueue.review;
      c.interval = 10;
      c.ease_factor = 2500;
      c.reps = 3;
      c.answerReview(0, rating: 3); // Good
      expect(c.reps, equals(4));
      expect(c.interval, equals(25)); // 10 * 2500/1000 = 25
    });

    test('answerReview Hard uses multiplier', () {
      final c = Card.createNew(note_id: 1, deck_id: 1);
      c.queue = CardQueue.review;
      c.interval = 10;
      c.ease_factor = 2500;
      c.answerReview(0, rating: 2, hardMult: 1.2); // Hard
      expect(c.interval, equals(12)); // 10 * 1.2
      expect(c.ease_factor, equals(2350)); // -150
    });

    test('answerReview Easy uses 1.3x bonus', () {
      final c = Card.createNew(note_id: 1, deck_id: 1);
      c.queue = CardQueue.review;
      c.interval = 10;
      c.ease_factor = 2500;
      c.answerReview(0, rating: 4); // Easy
      // factor: 2500 + 150 = 2650
      // _nextIvl(10, 2650) = (10*2650/1000).round() = 27
      // Easy bonus: 27 * 1.3 = 35.1 -> 35
      expect(c.interval, equals(35));
      expect(c.ease_factor, equals(2650)); // +150
    });

    test('ease factor never goes below 1300', () {
      final c = Card.createNew(note_id: 1, deck_id: 1);
      c.queue = CardQueue.review;
      c.ease_factor = 1300;
      c.answerReview(0, rating: 1);
      expect(c.ease_factor, equals(1300)); // clamped
    });
  });

  group('Note — upstream Note struct mapping', () {
    test('creates with correct defaults', () {
      final n = Note.createNew(notetype_id: 1, fields: ['Front', 'Back']);
      expect(n.id, greaterThan(0));
      expect(n.guid, isNotEmpty);
      expect(n.notetype_id, equals(1));
      expect(n.fields, equals(['Front', 'Back']));
      expect(n.sort_field, equals('Front'));
      expect(n.tags, equals(<String>[]));
      expect(n.flags, equals(0));
    });

    test('toMap/fromMap round-trip', () {
      final n = Note.createNew(
          notetype_id: 2, fields: ['Hello', 'World'], tags: ['tag1', 'tag2']);
      final map = n.toMap();
      final r = Note.fromMap(map);
      expect(r.id, n.id);
      expect(r.notetype_id, 2);
      expect(r.fields, ['Hello', 'World']);
      expect(r.tags, ['tag1', 'tag2']);
    });

    test('addTag/removeTag', () {
      final n = Note.createNew(notetype_id: 1, fields: ['A', 'B']);
      n.addTag('test');
      expect(n.tags, contains('test'));
      n.removeTag('test');
      expect(n.tags, isNot(contains('test')));
    });

    test('fromMap handles legacy flds format', () {
      final map = <String, dynamic>{
        'id': 123,
        'guid': 'abc',
        'mid': 1,
        'mod': 1000,
        'usn': -1,
        'tags': ' tag1 tag2 ',
        'flds': 'Front\x1fBack',
        'sfld': 'Front',
        'csum': 42,
        'flags': 0,
        'data': '',
      };
      final n = Note.fromMap(map);
      expect(n.fields, equals(['Front', 'Back']));
      expect(n.tags, equals(['tag1', 'tag2']));
    });
  });

  group('Deck — upstream Deck struct mapping', () {
    test('createNew has correct defaults', () {
      final d = Deck.createNew(name: 'My Deck');
      expect(d.name, 'My Deck');
      expect(d.normalInfo?.description, '');
      expect(d.kind, DeckKind.normal);
    });

    test('toJson/fromJson round-trip', () {
      final d = Deck.createNew(name: 'Parent::Child', description: 'notes');
      d.mtimeSecs = 12345;
      d.usn = 42;
      d.common = DeckCommon(
        learningStudied: 3,
        lastDayStudied: 120,
      );
      final json = d.toJson();
      final r = Deck.fromJson(json);
      expect(r.name, 'Parent::Child');
      expect(r.normalInfo?.description, 'notes');
      expect(r.mtimeSecs, 12345);
      expect(r.usn, 42);
      expect(r.common.learningStudied, 3);
    });

    test('parentName/childName for nested decks', () {
      final d = Deck.createNew(name: 'A::B::C');
      expect(d.parentName, 'A::B');
      expect(d.childName, 'C');
    });

    test('parentName null for top-level deck', () {
      final d = Deck.createNew(name: 'Top');
      expect(d.parentName, isNull);
    });
  });

  group('RevlogEntry — upstream RevlogEntry struct mapping', () {
    test('creates with correct defaults', () {
      final r = RevlogEntry(
          cid: 1,
          button_chosen: 3,
          interval: 10,
          last_interval: 5,
          ease_factor: 2500);
      expect(r.cid, 1);
      expect(r.button_chosen, 3);
      expect(r.interval, 10);
      expect(r.last_interval, 5);
      expect(r.ease_factor, 2500);
      expect(r.review_kind, RevlogReviewKind.review);
    });

    test('toMap/fromMap round-trip', () {
      final r = RevlogEntry(
          cid: 42,
          button_chosen: 4,
          interval: 30,
          last_interval: 10,
          ease_factor: 2600,
          taken_millis: 5000,
          review_kind: RevlogReviewKind.relearning);
      final map = r.toMap();
      final r2 = RevlogEntry.fromMap(map);
      expect(r2.cid, 42);
      expect(r2.button_chosen, 4);
      expect(r2.interval, 30);
      expect(r2.ease_factor, 2600);
      expect(r2.taken_millis, 5000);
      expect(r2.review_kind, RevlogReviewKind.relearning);
    });
  });

  group('Grave', () {
    test('toMap/fromMap round-trip', () {
      final g = Grave(usn: 1, oid: 123, type: 2); // card
      final map = g.toMap();
      final r = Grave.fromMap(map);
      expect(r.usn, 1);
      expect(r.oid, 123);
      expect(r.type, 2);
    });
  });

  group('Notetype — JSON matches Anki col blob', () {
    test('Basic model has correct structure', () {
      final m = Notetype.createBasic();
      expect(m.name, 'Basic');
      expect(m.fields.length, 2);
      expect(m.fields[0].name, 'Front');
      expect(m.fields[1].name, 'Back');
      expect(m.templates.length, 1);
      expect(m.templates[0].name, 'Card 1');
      expect(m.templates[0].qfmt, '{{Front}}');
      expect(m.templates[0].afmt, contains('{{FrontSide}}'));
      expect(m.type, 0); // normal
    });

    test('toJson/fromJson round-trip', () {
      final m = Notetype.createBasic();
      m.css = 'body { color: red; }';
      m.tags = ['tag1', 'tag2'];
      final json = m.toJson();
      final r = Notetype.fromJson(json);
      expect(r.name, 'Basic');
      expect(r.fields.length, 2);
      expect(r.fields[0].name, 'Front');
      expect(r.templates.length, 1);
      expect(r.css, 'body { color: red; }');
      expect(r.tags, ['tag1', 'tag2']);
    });
  });
}
