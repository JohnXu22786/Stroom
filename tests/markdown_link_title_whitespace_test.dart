import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as markdown;

void main() {
  test('tabs and vertical tabs separate an inline link title', () {
    for (final separator in ['\t', '\v']) {
      expect(
        markdown.markdownToHtml('[link](https://example.com$separator"title")'),
        '<p><a href="https://example.com" title="title">link</a></p>\n',
      );
    }
  });
}
