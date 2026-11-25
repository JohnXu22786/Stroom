import 'package:markdown/markdown.dart' as markdown;
import 'package:test/test.dart';

void main() {
  test('task markers at end of line render as checked and unchecked items', () {
    expect(
      markdown.markdownToHtml(
        '- [x]\n- [ ]\n- [x] Existing task\n',
        extensionSet: markdown.ExtensionSet.gitHubWeb,
      ),
      '<ul class="contains-task-list">\n'
      '<li class="task-list-item"><input type="checkbox" checked="true"></input></li>\n'
      '<li class="task-list-item"><input type="checkbox"></input></li>\n'
      '<li class="task-list-item"><input type="checkbox" checked="true"></input>Existing task</li>\n'
      '</ul>\n',
    );
  });
}
