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

  test('reference link labels unescape ASCII punctuation', () {
    expect(
      markdown.markdownToHtml(
        r'[\*]'
        '\n\n'
        r'[*]: /asterisk',
      ),
      '<p><a href="/asterisk">*</a></p>\n',
    );
    expect(
      markdown.markdownToHtml(
        r'[\*][]'
        '\n\n'
        r'[*]: /asterisk',
      ),
      '<p><a href="/asterisk">*</a></p>\n',
    );
  });

  test('reference link labels preserve escaped brackets and backslashes', () {
    expect(markdown.markdownToHtml(r'[\]]'), '<p>[]]</p>\n');
    expect(markdown.markdownToHtml(r'[\\]'), '<p>[\\]</p>\n');
  });

  test(
    'reference link labels do not unescape punctuation after escaped slash',
    () {
      expect(
        markdown.markdownToHtml(
          r'[link][\\*]'
          '\n\n'
          r'[*]: /asterisk',
        ),
        '<p>[link][\\*]</p>\n',
      );
    },
  );

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

  test('GitHub heading anchors preserve Unicode-only headings', () {
    expect(
      markdown.markdownToHtml(
        '## 你好世界',
        extensionSet: markdown.ExtensionSet.gitHubWeb,
      ),
      '<h2 id="你好世界">你好世界</h2>\n',
    );
    expect(
      markdown.markdownToHtml(
        '## कि',
        extensionSet: markdown.ExtensionSet.gitHubWeb,
      ),
      '<h2 id="कि">कि</h2>\n',
    );
  });

  test('GitHub heading anchors preserve Unicode in mixed-script headings', () {
    expect(
      markdown.markdownToHtml(
        '## Hello 世界 123',
        extensionSet: markdown.ExtensionSet.gitHubWeb,
      ),
      '<h2 id="hello-世界-123">Hello 世界 123</h2>\n',
    );
  });

  test(
    'GitHub heading anchors keep ASCII punctuation and spacing behavior',
    () {
      expect(
        markdown.markdownToHtml(
          '## Hello, WORLD!',
          extensionSet: markdown.ExtensionSet.gitHubWeb,
        ),
        '<h2 id="hello-world">Hello, WORLD!</h2>\n',
      );
    },
  );
}
