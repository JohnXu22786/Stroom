import 'package:markdown/markdown.dart';
import 'package:test/test.dart';

void main() {
  group('CommonMark code spans', () {
    test('strips ASCII spaces around a non-breaking space', () {
      expect(markdownToHtml('` \u00a0 `'), '<p><code>\u00a0</code></p>\n');
    });

    test('does not strip an all-space code span', () {
      expect(markdownToHtml('`   `'), '<p><code>   </code></p>\n');
    });

    test('strips surrounding ASCII spaces and preserves tabs as content', () {
      expect(markdownToHtml('` \t `'), '<p><code>\t</code></p>\n');
    });
  });
}
