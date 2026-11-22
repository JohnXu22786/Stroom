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
}
