import 'package:markdown/markdown.dart' as markdown;
import 'package:test/test.dart';

void main() {
  test('supplementary punctuation before emphasis opens a delimiter', () {
    expect(
      markdown.markdownToHtml('𐄀_text_ word'),
      '<p>𐄀<em>text</em> word</p>\n',
    );
  });

  test('supplementary punctuation around strong emphasis is recognized', () {
    expect(
      markdown.markdownToHtml('\u{10D6E}__text__\u{10D6E}'),
      '<p>\u{10D6E}<strong>text</strong>\u{10D6E}</p>\n',
    );
  });
}
