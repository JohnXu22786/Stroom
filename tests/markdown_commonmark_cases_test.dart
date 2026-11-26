import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as markdown;

void main() {
  test('autolinks accept digits in a valid scheme and enforce its length', () {
    expect(
      markdown.markdownToHtml('<x1:target>'),
      '<p><a href="x1:target">x1:target</a></p>\n',
    );

    final overlongScheme = 'a${'b' * 32}';
    expect(
      markdown.markdownToHtml('<$overlongScheme:target>'),
      '<p>&lt;$overlongScheme:target&gt;</p>\n',
    );
  });

  test('unmatched contiguous backtick runs remain literal', () {
    expect(
      markdown.markdownToHtml('before `` after'),
      '<p>before `` after</p>\n',
    );
    expect(
      markdown.markdownToHtml('before ```` after'),
      '<p>before ```` after</p>\n',
    );
    expect(
      markdown.markdownToHtml('before ````code after'),
      '<p>before ````code after</p>\n',
    );
  });

  test('separate matching backtick runs still form code spans', () {
    expect(
      markdown.markdownToHtml('before `` `` after'),
      '<p>before <code> </code> after</p>\n',
    );
    expect(
      markdown.markdownToHtml('before ``code`` after'),
      '<p>before <code>code</code> after</p>\n',
    );
  });

  test('tabs separate fenced code language from metadata', () {
    expect(
      markdown.markdownToHtml('```dart\tmeta\ncode\n```'),
      '<pre data-metadata="meta"><code class="language-dart">code\n'
      '</code></pre>\n',
    );
  });

  test('long runs of adjacent short HTML blocks parse without recursion', () {
    const block = '<script></script>';
    final source = List.filled(10000, block).join('\n');

    expect(markdown.markdownToHtml(source), '$source\n');
  });

  test('renderer reuse does not trim later plain text', () {
    final renderer = markdown.HtmlRenderer();
    renderer.render([
      markdown.Element('p', [markdown.Text('block')]),
    ]);

    expect(renderer.render([markdown.Text('  leading')]), '  leading');
  });
}
