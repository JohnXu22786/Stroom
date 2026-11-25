import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as markdown;

void main() {
  test('supplementary punctuation before emphasis opens a delimiter', () {
    expect(
      markdown.markdownToHtml('𐄀_text_ word'),
      '<p>𐄀<em>text</em> word</p>\n',
    );
  });

  test('Unicode 17 supplementary punctuation surrounds strong emphasis', () {
    expect(
      markdown.markdownToHtml('\u{10D6E}__text__\u{10D6E}'),
      '<p>\u{10D6E}<strong>text</strong>\u{10D6E}</p>\n',
    );
  });

  test('custom delimiter syntax accepts immutable tags and sorts a copy', () {
    final tags = const [
      markdown.DelimiterTag('strong', 2),
      markdown.DelimiterTag('em', 1),
    ];
    final syntax = markdown.DelimiterSyntax(
      r'%+',
      requiresDelimiterRun: true,
      startCharacter: 37,
      tags: tags,
    );

    expect(
      markdown.markdownToHtml('%%%text%%%', inlineSyntaxes: [syntax]),
      '<p><em><strong>text</strong></em></p>\n',
    );
    expect(tags.map((tag) => tag.indicatorLength), [2, 1]);
  });
}
