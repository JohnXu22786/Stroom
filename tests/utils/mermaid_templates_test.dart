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
    test(
      'uses supported element-to-requirement relationships in the template',
      () {
        final template = MermaidTemplates.getTemplate('requirement');
        expect(template, contains('登录页面 - satisfies -> 用户登录'));
        expect(template, contains('认证服务 - verifies -> 用户登录'));
        expect(template, isNot(contains('verifiedBy')));
      },
    );

    test('relationship snippet connects declared template nodes', () {
      final template = MermaidTemplates.getTemplate('requirement');
      final relationshipSnippet = MermaidTemplates.getSnippets('requirement')
          .singleWhere((snippet) => snippet.$1 == '添加关联')
          .$2;

      expect(template, contains('requirement 用户登录 {'));
      expect(template, contains('element 登录页面 {'));
      expect(relationshipSnippet, '  登录页面 - satisfies -> 用户登录');
    });

    test('verification snippet connects declared template nodes', () {
      final template = MermaidTemplates.getTemplate('requirement');
      final verificationSnippet = MermaidTemplates.getSnippets('requirement')
          .singleWhere((snippet) => snippet.$1 == '添加验证')
          .$2;

      expect(template, contains('requirement 用户登录 {'));
      expect(template, contains('element 认证服务 {'));
      expect(verificationSnippet, '  认证服务 - verifies -> 用户登录');
    });
  });

  group('MermaidTemplates - requirement diagram verification method', () {
    test('uses the Mermaid-supported verification method field', () {
      final template = MermaidTemplates.getTemplate('requirement');

      expect(template, contains('verifyMethod: test'));
      expect(template, isNot(contains('verifiedMethod')));
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

  group('MermaidTemplates - GitGraph snippets', () {
    test('merge snippet targets a branch defined in the default template', () {
      final template = MermaidTemplates.getTemplate('gitGraph');
      final mergeSnippet = MermaidTemplates.getSnippets('gitGraph')
          .singleWhere((snippet) => snippet.$1 == '合并分支')
          .$2;
      final mergeTarget = mergeSnippet.trim().split(RegExp(r'\s+')).last;

      expect(mergeSnippet, startsWith('  merge '));
      expect(template.split('\n'), contains('  branch $mergeTarget'));
    });

    test('merge snippet targets an existing branch for each GitGraph setup',
        () {
      final scenarios = [
        (
          code: '''gitGraph
  commit id: "初始提交"
  branch feature
  checkout main''',
          expectedTarget: 'feature',
          existingBranches: <String>{'main', 'feature'},
        ),
        (
          code: '''%%{init: { 'gitGraph': { 'mainBranchName': 'trunk' } } }%%
gitGraph
  commit id: "初始提交"''',
          expectedTarget: 'trunk',
          existingBranches: <String>{'trunk'},
        ),
        (
          code: '''%%{init: { 'gitGraph': { 'mainBranchName': 'develop' } } }%%
gitGraph
  commit id: "初始提交"
  branch feature''',
          expectedTarget: 'develop',
          existingBranches: <String>{'develop', 'feature'},
        ),
        (
          code: '''%% mainBranchName: develop
gitGraph
  commit id: "mainBranchName: develop"
  branch feature
  checkout main''',
          expectedTarget: 'feature',
          existingBranches: <String>{'main', 'feature'},
        ),
        (
          code: '''---
config:
  gitGraph:
    mainBranchName: trunk
---
gitGraph
  commit id: "初始提交"''',
          expectedTarget: 'trunk',
          existingBranches: <String>{'trunk'},
        ),
        (
          code: '''---
config: { gitGraph: { mainBranchName: trunk } }
---
gitGraph
  commit id: "初始提交"''',
          expectedTarget: 'trunk',
          existingBranches: <String>{'trunk'},
        ),
      ];

      for (final scenario in scenarios) {
        final mergeSnippet = MermaidTemplates.getSnippets(
          'gitGraph',
          code: scenario.code,
        ).singleWhere((snippet) => snippet.$1 == '合并分支').$2;
        final insertedCode = MermaidTemplates.insertSnippet(
          scenario.code,
          mergeSnippet,
        );
        final mergeCommand = insertedCode
            .split('\n')
            .singleWhere((line) => line.trim().startsWith('merge '));
        final mergeTarget = mergeCommand.trim().split(RegExp(r'\s+')).last;

        expect(scenario.code, isNot(contains('branch develop')));
        expect(scenario.existingBranches, contains(mergeTarget));
        expect(mergeTarget, scenario.expectedTarget);
      }
    });
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
