import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/mermaid_templates.dart';

void main() {
  group('MermaidTemplates - getTemplate with unknown type', () {
    test('returns empty string for unknown type', () {
      final template = MermaidTemplates.getTemplate('unknown');
      expect(template, isEmpty);
    });
  });

  group('MermaidTemplates - requirement diagram relationships', () {
    test('uses direction arrows in the template and relationship snippets', () {
      final template = MermaidTemplates.getTemplate('requirement');
      expect(template, contains('用户登录 - satisfies -> 登录页面'));
      expect(template, contains('用户登录 - verifiedBy -> 认证服务'));

      final snippets = MermaidTemplates.getSnippets('requirement');
      expect(
        snippets.map((snippet) => snippet.$2),
        containsAll([
          '  需求A - satisfies -> 元素B',
          '  需求A - verifiedBy -> 元素B',
        ]),
      );
    });
  });

  group('MermaidTemplates - Gantt dependencies', () {
    test(
      'dependency task snippet references a task defined in the template',
      () {
        final template = MermaidTemplates.getTemplate('gantt');
        final dependencySnippet = MermaidTemplates.getSnippets('gantt')
            .singleWhere((snippet) => snippet.$1 == '添加依赖任务')
            .$2;

        expect(template, contains(':a1,'));
        expect(dependencySnippet, contains('after a1,'));
      },
    );
  });

  group('MermaidTemplates - mindmap snippets', () {
    test(
      'adds a topic under the existing root without adding another root',
      () {
        final template = MermaidTemplates.getTemplate('mindmap');
        final addTopicSnippet = MermaidTemplates.getSnippets(
          'mindmap',
        ).singleWhere((snippet) => snippet.$1 == '添加主题').$2;
        final insertedCode = MermaidTemplates.insertSnippet(
          template,
          addTopicSnippet,
        );
        final rootDeclarations = insertedCode
            .split('\n')
            .where((line) => RegExp(r'^\s*root\(').hasMatch(line));

        expect(rootDeclarations, hasLength(1));
        expect(insertedCode, endsWith('\n    新主题'));
      },
    );
  });
}
