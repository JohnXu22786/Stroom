import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as markdown;

void main() {
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
