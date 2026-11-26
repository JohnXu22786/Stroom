import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as markdown;

void main() {
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
