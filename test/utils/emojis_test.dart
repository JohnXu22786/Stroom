import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/emojis.dart';

void main() {
  group('EmojiCategories', () {
    test('has at least 6 categories', () {
      expect(EmojiCategories.categories.length, greaterThanOrEqualTo(6));
    });

    test('every category has a non-empty label', () {
      for (final cat in EmojiCategories.categories) {
        expect(cat.label.isNotEmpty, isTrue,
            reason: 'Category label should not be empty');
      }
    });

    test('every category has at least 10 emojis', () {
      for (final cat in EmojiCategories.categories) {
        expect(cat.emojis.length, greaterThanOrEqualTo(10),
            reason: 'Category "${cat.label}" has too few emojis');
      }
    });

    test('all emojis are valid strings', () {
      for (final cat in EmojiCategories.categories) {
        for (final emoji in cat.emojis) {
          expect(emoji.isNotEmpty, isTrue,
              reason: 'Emoji should not be empty in category "${cat.label}"');
          // Emojis can have ZWJ sequences (e.g. 🐻‍❄️) or tag sequences (e.g. flags)
          expect(emoji.isNotEmpty && emoji.length <= 16, isTrue,
              reason:
                  'Emoji "$emoji" (len=${emoji.length}) seems too long in category "${cat.label}"');
        }
      }
    });

    test('default emoji 🤖 is present in at least one category', () {
      bool found = false;
      for (final cat in EmojiCategories.categories) {
        if (cat.emojis.contains('🤖')) {
          found = true;
          break;
        }
      }
      expect(found, isTrue, reason: 'Default emoji 🤖 should be in the list');
    });

    test('total emoji count is at least 100', () {
      int total = 0;
      for (final cat in EmojiCategories.categories) {
        total += cat.emojis.length;
      }
      expect(total, greaterThanOrEqualTo(100),
          reason: 'Should have at least 100 emojis total');
    });

    test('no duplicate emojis across categories', () {
      final allEmojis = <String>{};
      for (final cat in EmojiCategories.categories) {
        for (final emoji in cat.emojis) {
          expect(allEmojis.contains(emoji), isFalse,
              reason:
                  'Duplicate emoji "$emoji" found in category "${cat.label}"');
          allEmojis.add(emoji);
        }
      }
    });

    test('category labels match expected standard categories', () {
      final labels = EmojiCategories.categories.map((c) => c.label).toSet();
      expect(labels.contains('表情'), isTrue);
      expect(labels.contains('动物'), isTrue);
      expect(labels.contains('食物'), isTrue);
      expect(labels.contains('活动'), isTrue);
      expect(labels.contains('旅行'), isTrue);
      expect(labels.contains('物品'), isTrue);
    });
  });
}
