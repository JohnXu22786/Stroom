import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as markdown;

void main() {
  test('reference links fold supplementary-plane letters', () {
    expect(
      markdown.markdownToHtml('[text][𐐨]\n\n[𐐀]: /target'),
      '<p><a href="/target">text</a></p>\n',
    );
  });

  test('numeric references replace surrogate code points only', () {
    expect(
      markdown.markdownToHtml('&#55296; &#xDFFF; &#1; &#128512; &#x1F600;'),
      '<p>� � \u0001 😀 😀</p>\n',
    );
  });

  test('a reference label ending in an escape stays literal', () {
    expect(markdown.markdownToHtml(r'[foo\'), '<p>[foo\\</p>\n');
  });

  test('a bracketed destination ending in an escape stays literal', () {
    expect(
      markdown.markdownToHtml(r'[foo]: <bar\'),
      '<p>[foo]: &lt;bar\\</p>\n',
    );
  });

  test('inline bracketed destinations reject unescaped opening angles', () {
    expect(markdown.markdownToHtml('[x](<<foo>)'), '<p>[x](&lt;<foo>)</p>\n');
    expect(
      markdown.markdownToHtml(r'[x](<\<foo>)'),
      '<p><a href="%3Cfoo">x</a></p>\n',
    );
  });

  test('a bare destination ending in an escape is accepted as a reference', () {
    expect(
      markdown.markdownToHtml('[text][foo]\n\n[foo]: bar\\'),
      '<p><a href="bar%5C">text</a></p>\n',
    );
  });

  test(
    'an unmatched closing parenthesis invalidates a bare reference target',
    () {
      expect(
        markdown.markdownToHtml('[text][foo]\n\n[foo]: target)'),
        '<p>[text][foo]</p>\n<p>[foo]: target)</p>\n',
      );
    },
  );

  test('a reference title ending in an escape stays literal', () {
    expect(
      markdown.markdownToHtml(r'[foo]: bar "baz\'),
      '<p>[foo]: bar &quot;baz\\</p>\n',
    );
  });
}
