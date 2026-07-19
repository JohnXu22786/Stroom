import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/anki/models/card.dart';
import 'package:stroom/anki/models/deck.dart';
import 'package:stroom/anki/models/note.dart';
import 'package:stroom/anki/models/revlog.dart';
import 'package:stroom/anki/models/grave.dart';
import 'package:stroom/anki/models/model.dart';

void main() {
  group('AnkiCard — exact collection.anki2 schema', () {
    test('creates new card with default Anki field values', () {
      final c = AnkiCard.createNew(nid: 1, did: 1);
      expect(c.id, greaterThan(0));
      expect(c.nid, equals(1));
      expect(c.did, equals(1));
      expect(c.ord, equals(0));
      expect(c.type, equals(0)); // new
      expect(c.queue, equals(0)); // new queue
      expect(c.due, equals(0));
      expect(c.ivl, equals(0));
      expect(c.factor, equals(2500)); // 250%
      expect(c.reps, equals(0));
      expect(c.lapses, equals(0));
      expect(c.left, equals(0));
      expect(c.odue, equals(0));
      expect(c.odid, equals(0));
      expect(c.flags, equals(0));
      expect(c.data, equals(''));
    });

    test('toMap/fromMap round-trip preserves all fields', () {
      final c = AnkiCard.createNew(nid: 42, did: 7, ord: 2);
      c.type = 2;
      c.queue = 2;
      c.due = 12345;
      c.ivl = 30;
      c.factor = 2200;
      c.reps = 5;
      c.lapses = 2;
      c.left = 0x0102;
      c.odue = 100;
      c.odid = 3;
      c.flags = 1;
      c.data = '{"extra":1}';
      final map = c.toMap();
      final r = AnkiCard.fromMap(map);
      expect(r.id, c.id);
      expect(r.nid, 42);
      expect(r.did, 7);
      expect(r.ord, 2);
      expect(r.type, 2);
      expect(r.queue, 2);
      expect(r.due, 12345);
      expect(r.ivl, 30);
      expect(r.factor, 2200);
      expect(r.reps, 5);
      expect(r.lapses, 2);
      expect(r.left, 0x0102);
      expect(r.odue, 100);
      expect(r.odid, 3);
      expect(r.flags, 1);
      expect(r.data, '{"extra":1}');
    });

    test('isDue returns false for suspended cards', () {
      final c = AnkiCard.createNew(nid: 1, did: 1);
      c.queue = -1; // suspended
      expect(c.isDue(0), isFalse);
    });

    test('new cards are always due', () {
      final c = AnkiCard.createNew(nid: 1, did: 1);
      expect(c.isDue(0), isTrue);
    });

    test('review card due when due <= nowSec', () {
      final c = AnkiCard.createNew(nid: 1, did: 1);
      c.queue = 2;
      c.due = 100;
      expect(c.isDue(100), isTrue);
      expect(c.isDue(101), isTrue);
      expect(c.isDue(99), isFalse);
    });

    test('startLearning transitions new→learning', () {
      final c = AnkiCard.createNew(nid: 1, did: 1);
      c.startLearning(0, steps: [1, 10]);
      expect(c.queue, equals(1)); // learning
      expect(c.type, equals(1)); // learning
      expect(c.left, equals(2)); // 2 steps remaining
      expect(c.due, equals(1 * 60 * 1000)); // 1 min in ms
    });

    test('answerLearning Again resets to first step', () {
      final c = AnkiCard.createNew(nid: 1, did: 1);
      c.startLearning(0, steps: [1, 10]);
      c.answerLearning(0, steps: [1, 10], answerIdx: 0); // Again
      expect(c.left, equals(2)); // back to full steps
      expect(c.due, equals(1 * 60 * 1000));
    });

    test('answerLearning Good graduates after last step', () {
      final c = AnkiCard.createNew(nid: 1, did: 1);
      c.startLearning(0, steps: [1, 10]);
      c.answerLearning(0, steps: [1, 10], answerIdx: 2); // Good → step 2
      expect(c.queue, equals(1)); // still learning (one step left)

      c.answerLearning(0, steps: [1, 10], answerIdx: 2); // Good → graduate
      expect(c.queue, equals(2)); // review
      expect(c.type, equals(2));
      expect(c.ivl, equals(1)); // graduating interval
      expect(c.reps, equals(1));
      expect(c.left, equals(0));
    });

    test('answerLearning Hard repeats current step', () {
      final c = AnkiCard.createNew(nid: 1, did: 1);
      final t = DateTime.now().millisecondsSinceEpoch;
      c.startLearning(t, steps: [1, 10]);
      final dueBefore = c.due;
      c.answerLearning(t, steps: [1, 10], answerIdx: 1); // Hard
      // Due should be same step (1 min from t)
      expect(c.due, equals(t + 1 * 60 * 1000));
      // But actually startLearning set due = t + 60*1000, and Hard
      // recalculates due from the current step. The result should equal start.
      // Start sets due = t + 1*60*1000. Hard reads stepIdx=0 and sets
      // due = t + steps[0]*60*1000 = t + 60*1000. Same result.
      expect(c.due, equals(dueBefore));
    });

    test('answerLearning Easy graduates immediately with bonus', () {
      final c = AnkiCard.createNew(nid: 1, did: 1);
      c.startLearning(0, steps: [1, 10]);
      c.answerLearning(0, steps: [1, 10], answerIdx: 3); // Easy
      expect(c.queue, equals(2)); // review
      expect(c.ivl, equals(2)); // graduatingIvl * 2
    });

    test('answerReview Again causes lapse', () {
      final c = AnkiCard.createNew(nid: 1, did: 1);
      c.queue = 2;
      c.ivl = 30;
      c.factor = 2500;
      c.answerReview(0, rating: 1); // Again
      expect(c.lapses, equals(1));
      expect(c.queue, equals(1)); // back to learning
      expect(c.type, equals(3)); // relearning
      expect(c.factor, equals(2300)); // -200
    });

    test('answerReview Good updates interval', () {
      final c = AnkiCard.createNew(nid: 1, did: 1);
      c.queue = 2;
      c.ivl = 10;
      c.factor = 2500;
      c.reps = 3;
      c.answerReview(0, rating: 3); // Good
      expect(c.reps, equals(4));
      expect(c.ivl, equals(25)); // 10 * 2500/1000 = 25
    });

    test('answerReview Hard uses multiplier', () {
      final c = AnkiCard.createNew(nid: 1, did: 1);
      c.queue = 2;
      c.ivl = 10;
      c.factor = 2500;
      c.answerReview(0, rating: 2, hardMult: 1.2); // Hard
      expect(c.ivl, equals(12)); // 10 * 1.2
      expect(c.factor, equals(2350)); // -150
    });

    test('answerReview Easy doubles interval and boosts ease', () {
      final c = AnkiCard.createNew(nid: 1, did: 1);
      c.queue = 2;
      c.ivl = 10;
      c.factor = 2500;
      c.answerReview(0, rating: 4); // Easy
      // factor increases to 2650, then _nextIvl(10, 2650) = (10*2650/1000).round() = 27
      // then * 2 = 54
      expect(c.ivl, equals(54));
      expect(c.factor, equals(2650)); // +150
    });

    test('ease factor never goes below 1300', () {
      final c = AnkiCard.createNew(nid: 1, did: 1);
      c.queue = 2;
      c.factor = 1300;
      c.answerReview(0, rating: 1);
      expect(c.factor, equals(1300)); // clamped
    });
  });

  group('AnkiNote — exact collection.anki2 schema', () {
    test('creates with correct defaults', () {
      final n = AnkiNote.createNew(mid: 1, flds: 'Front\x1fBack');
      expect(n.id, greaterThan(0));
      expect(n.guid, isNotEmpty);
      expect(n.mid, equals(1));
      expect(n.flds, equals('Front\x1fBack'));
      expect(n.sfld, equals('Front'));
      expect(n.tags, equals(''));
      expect(n.flags, equals(0));
    });

    test('fieldList splits on 0x1f', () {
      final n = AnkiNote.createNew(mid: 1, flds: 'Q\x1fA\x1fExtra');
      expect(n.fieldList, equals(['Q', 'A', 'Extra']));
    });

    test('toMap/fromMap round-trip', () {
      final n = AnkiNote.createNew(
          mid: 2, flds: 'Hello\x1fWorld', tags: ' tag1 tag2 ');
      final map = n.toMap();
      final r = AnkiNote.fromMap(map);
      expect(r.id, n.id);
      expect(r.mid, 2);
      expect(r.flds, 'Hello\x1fWorld');
      expect(r.tags, ' tag1 tag2 ');
    });

    test('addTag/removeTag', () {
      final n = AnkiNote.createNew(mid: 1, flds: 'A\x1fB');
      n.addTag('test');
      expect(n.tagList, contains('test'));
      n.removeTag('test');
      expect(n.tagList, isNot(contains('test')));
    });
  });

  group('AnkiDeck — JSON matches Anki col blob', () {
    test('createNew has correct defaults', () {
      final d = AnkiDeck.createNew(name: 'My Deck');
      expect(d.name, 'My Deck');
      expect(d.desc, '');
      expect(d.dyn, 0);
      expect(d.conf, 1);
    });

    test('toJson/fromJson round-trip', () {
      final d = AnkiDeck.createNew(name: 'Parent::Child', description: 'notes');
      d.mod = 12345;
      d.usn = 42;
      d.lrnToday = [3, 120];
      final json = d.toJson();
      final r = AnkiDeck.fromJson(json);
      expect(r.name, 'Parent::Child');
      expect(r.desc, 'notes');
      expect(r.mod, 12345);
      expect(r.usn, 42);
      expect(r.lrnToday, [3, 120]);
    });

    test('parentName/childName for nested decks', () {
      final d = AnkiDeck.createNew(name: 'A::B::C');
      expect(d.parentName, 'A::B');
      expect(d.childName, 'C');
    });

    test('parentName null for top-level deck', () {
      final d = AnkiDeck.createNew(name: 'Top');
      expect(d.parentName, isNull);
    });
  });

  group('AnkiRevlog — exact collection.anki2 schema', () {
    test('creates with correct defaults', () {
      final r = AnkiRevlog(cid: 1, ease: 3, ivl: 10, lastIvl: 5, factor: 2500);
      expect(r.cid, 1);
      expect(r.ease, 3);
      expect(r.ivl, 10);
      expect(r.lastIvl, 5);
      expect(r.factor, 2500);
      expect(r.type, 1); // review
    });

    test('toMap/fromMap round-trip', () {
      final r = AnkiRevlog(
          cid: 42,
          ease: 4,
          ivl: 30,
          lastIvl: 10,
          factor: 2600,
          time: 5000,
          type: 2);
      final map = r.toMap();
      final r2 = AnkiRevlog.fromMap(map);
      expect(r2.cid, 42);
      expect(r2.ease, 4);
      expect(r2.ivl, 30);
      expect(r2.factor, 2600);
      expect(r2.time, 5000);
      expect(r2.type, 2);
    });
  });

  group('AnkiGrave', () {
    test('toMap/fromMap round-trip', () {
      final g = AnkiGrave(usn: 1, oid: 123, type: 2); // card
      final map = g.toMap();
      final r = AnkiGrave.fromMap(map);
      expect(r.usn, 1);
      expect(r.oid, 123);
      expect(r.type, 2);
    });
  });

  group('AnkiModel — JSON matches Anki col blob', () {
    test('Basic model has correct structure', () {
      final m = AnkiModel.createBasic();
      expect(m.name, 'Basic');
      expect(m.flds.length, 2);
      expect(m.flds[0].name, 'Front');
      expect(m.flds[1].name, 'Back');
      expect(m.tmpls.length, 1);
      expect(m.tmpls[0].name, 'Card 1');
      expect(m.tmpls[0].qfmt, '{{Front}}');
      expect(m.tmpls[0].afmt, contains('{{FrontSide}}'));
      expect(m.type, 0); // normal
    });

    test('toJson/fromJson round-trip', () {
      final m = AnkiModel.createBasic();
      m.css = 'body { color: red; }';
      m.tags = ['tag1', 'tag2'];
      final json = m.toJson();
      final r = AnkiModel.fromJson(json);
      expect(r.name, 'Basic');
      expect(r.flds.length, 2);
      expect(r.flds[0].name, 'Front');
      expect(r.tmpls.length, 1);
      expect(r.css, 'body { color: red; }');
      expect(r.tags, ['tag1', 'tag2']);
    });
  });
}
