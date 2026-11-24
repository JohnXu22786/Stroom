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

  test('numeric references remap Windows-1252 C1 values', () {
    expect(
      markdown.markdownToHtml(
        '&#128; &#129; &#130; &#141; &#157; &#159; &#x80; &#x9F;',
      ),
      '<p>€ \u0081 ‚ \u008D \u009D Ÿ € Ÿ</p>\n',
    );
  });

  test('long numeric references outside Unicode are replaced safely', () {
    final decimal = '9' * 1000;
    final hexadecimal = 'f' * 1000;
    expect(
      markdown.markdownToHtml('&#$decimal; &#x$hexadecimal;'),
      '<p>� �</p>\n',
    );
  });

  test('a space followed by a tab dedents to the next tab stop', () {
    expect(
      markdown.markdownToHtml(' \tcode'),
      '<pre><code>code\n</code></pre>\n',
    );
  });

  test('GFM tagfilter escapes disallowed tags with attributes', () {
    expect(
      markdown.markdownToHtml(
        '<SCRIPT src=x>safe text</script >',
        enableTagfilter: true,
      ),
      '&lt;SCRIPT src=x>safe text&lt;/script >\n',
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

  test('bare destinations require balanced opening parentheses', () {
    expect(
      markdown.markdownToHtml('[text][foo]\n\n[foo]: target('),
      '<p>[text][foo]</p>\n<p>[foo]: target(</p>\n',
    );
    expect(
      markdown.markdownToHtml('[text][balanced]\n\n[balanced]: target(foo)'),
      '<p><a href="target(foo)">text</a></p>\n',
    );
    expect(
      markdown.markdownToHtml('[text][escaped]\n\n[escaped]: target\\(foo\\)'),
      '<p><a href="target(foo)">text</a></p>\n',
    );
  });

  test('a reference title ending in an escape stays literal', () {
    expect(
      markdown.markdownToHtml(r'[foo]: bar "baz\'),
      '<p>[foo]: bar &quot;baz\\</p>\n',
    );
  });
}
