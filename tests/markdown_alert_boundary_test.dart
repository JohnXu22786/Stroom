import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as markdown;

void main() {
  test('only recognizes documented GitHub alert markers', () {
    for (final type in ['NOTE', 'TIP', 'IMPORTANT', 'CAUTION', 'WARNING']) {
      expect(
        markdown.markdownToHtml(
          '> [!$type]',
          extensionSet: markdown.ExtensionSet.gitHubWeb,
        ),
        contains('class="markdown-alert markdown-alert-${type.toLowerCase()}"'),
      );
    }

    for (final source in [
      r'> \[!NOTE\]',
      '>   [!NOTE]',
      '> [!NOTE] ',
      '\t> [!NOTE]',
    ]) {
      final html = markdown.markdownToHtml(
        source,
        extensionSet: markdown.ExtensionSet.gitHubWeb,
      );

      expect(html, isNot(contains('markdown-alert')), reason: source);
      if (!source.startsWith('\t')) {
        expect(html, contains('<blockquote>'), reason: source);
      }
    }
  });

  test('preserves indented code inside GitHub alert blockquotes', () {
    const source = '> [!NOTE]\n>     code';
    final alert = markdown.Document(
      extensionSet: markdown.ExtensionSet.gitHubWeb,
    ).parse(source).single as markdown.Element;
    final codeBlock = alert.children![1] as markdown.Element;

    expect(codeBlock.tag, 'pre');
    expect(
        (codeBlock.children!.single as markdown.Element).textContent, 'code\n');
    expect(
      markdown.markdownToHtml(
        source,
        extensionSet: markdown.ExtensionSet.gitHubWeb,
      ),
      contains('<pre><code>code\n</code></pre>'),
    );

    final tabSeparatedAlert = markdown.Document(
      extensionSet: markdown.ExtensionSet.gitHubWeb,
    ).parse('> [!NOTE]\n>\ttext').single as markdown.Element;
    expect((tabSeparatedAlert.children![1] as markdown.Element).tag, 'p');
    expect(tabSeparatedAlert.children![1].textContent, 'text');
  });
  test('blank blockquote content ends before indented code', () {
    expect(
      markdown.markdownToHtml('>\n    code'),
      '<blockquote>\n'
      '</blockquote>\n'
      '<pre><code>code\n</code></pre>\n',
    );
  });

  test('empty alert ends before indented code', () {
    expect(
      markdown.markdownToHtml(
        '> [!NOTE]\n    code',
        extensionSet: markdown.ExtensionSet.gitHubWeb,
      ),
      "<div class=\"markdown-alert markdown-alert-note\">\n"
      "<p class=\"markdown-alert-title\">Note</p>\n"
      '</div>\n'
      '<pre><code>code\n</code></pre>\n',
    );
  });

  test('alerts stop at interrupting blocks and keep lazy paragraph lines', () {
    expect(
      markdown.markdownToHtml(
        '> [!NOTE]\n> Alert text\n# Outside',
        extensionSet: markdown.ExtensionSet.gitHubWeb,
      ),
      '<div class="markdown-alert markdown-alert-note">\n'
      '<p class="markdown-alert-title">Note</p>\n'
      '<p>Alert text</p>\n'
      '</div>\n'
      '<h1 id="outside">Outside</h1>\n',
    );

    expect(
      markdown.markdownToHtml(
        '> [!NOTE]\ncontinued',
        extensionSet: markdown.ExtensionSet.gitHubWeb,
      ),
      '<div class="markdown-alert markdown-alert-note">\n'
      '<p class="markdown-alert-title">Note</p>\n'
      '<p>continued</p>\n'
      '</div>\n',
    );

    expect(
      markdown.markdownToHtml(
        '> [!NOTE]\n> Alert text\ncontinued',
        extensionSet: markdown.ExtensionSet.gitHubWeb,
      ),
      '<div class="markdown-alert markdown-alert-note">\n'
      '<p class="markdown-alert-title">Note</p>\n'
      '<p>Alert text\ncontinued</p>\n'
      '</div>\n',
    );
  });
}
