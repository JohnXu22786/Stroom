import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as markdown;

void main() {
  test('a hash in an email autolink stays in the mailto address', () {
    expect(
      markdown.markdownToHtml('<foo#bar@example.com>'),
      '<p><a href="mailto:foo%23bar@example.com">foo#bar@example.com</a></p>\n',
    );
  });

  test('an ordinary email autolink keeps its mailto address', () {
    expect(
      markdown.markdownToHtml('<foo@example.com>'),
      '<p><a href="mailto:foo@example.com">foo@example.com</a></p>\n',
    );
  });
}
