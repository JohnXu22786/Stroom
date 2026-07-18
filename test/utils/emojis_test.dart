import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/emojis.dart';

void main() {
  group('EmojiCategories', () {
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
  });
}
