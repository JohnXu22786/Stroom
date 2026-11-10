import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations_en.dart';
import 'package:stroom/l10n/app_localizations_es.dart';
import 'package:stroom/l10n/app_localizations_ja.dart';
import 'package:stroom/l10n/app_localizations_zh.dart';
import 'package:stroom/utils/mermaid_templates.dart';

void main() {
  group('Mermaid catalog localization', () {
    test('Spanish and Japanese starter templates keep Mermaid syntax', () {
      final syntaxByType = <String, List<String>>{
        'flowchart': ['graph TD', 'A --> B'],
        'sequenceDiagram': ['sequenceDiagram', 'participant ', '->>'],
        'classDiagram': ['classDiagram', 'class ', '--|>'],
        'stateDiagram': ['stateDiagram-v2', 'state ', '-->'],
        'erDiagram': ['erDiagram', '||--o{', ' PK'],
        'gantt': ['gantt', 'dateFormat  YYYY-MM-DD', 'section '],
        'pie': ['pie showData', 'title '],
        'journey': ['journey', 'title ', 'section '],
        'gitGraph': ['gitGraph', 'commit id:', 'branch ', 'merge '],
        'mindmap': ['mindmap', 'root(('],
        'timeline': ['timeline', 'title '],
        'block': ['block-beta', 'columns 3', '-->'],
        'requirement': ['requirementDiagram', 'requirement ', '- satisfies ->'],
      };
      final locales = [AppLocalizationsEs(), AppLocalizationsJa()];

      for (final strings in locales) {
        for (final entry in syntaxByType.entries) {
          final template = MermaidTemplates.getTemplate(
            entry.key,
            strings: strings,
          );

          for (final syntax in entry.value) {
            expect(
              template,
              contains(syntax),
              reason: '${strings.localeName} ${entry.key} template',
            );
          }
        }
      }

      expect(
        MermaidTemplates.getTemplate(
          'flowchart',
          strings: AppLocalizationsEs(),
        ),
        contains('A[Inicio]'),
      );
      expect(
        MermaidTemplates.getTemplate(
          'flowchart',
          strings: AppLocalizationsJa(),
        ),
        contains('A[開始]'),
      );
    });

    test(
      'localizes diagram type labels and descriptions in English and Chinese',
      () {
        final english = MermaidTemplates.getAllTypes(AppLocalizationsEnUs());
        final chinese = MermaidTemplates.getAllTypes(AppLocalizationsZhCn());
        final englishFlowchart = english.singleWhere(
          (type) => type.id == 'flowchart',
        );
        final chineseFlowchart = chinese.singleWhere(
          (type) => type.id == 'flowchart',
        );

        expect(englishFlowchart.label, 'Flowchart');
        expect(
          englishFlowchart.description,
          contains('steps, branches, and loops'),
        );
        expect(chineseFlowchart.label, '流程图');
        expect(chineseFlowchart.description, contains('展示步骤'));
        expect(englishFlowchart.id, chineseFlowchart.id);
        expect(englishFlowchart.keyword, chineseFlowchart.keyword);
      },
    );

    test(
        'localizes starter and inserted snippet text while keeping syntax and IDs',
        () {
      final english = AppLocalizationsEnUs();
      final chinese = AppLocalizationsZhCn();
      final englishTemplate = MermaidTemplates.getTemplate(
        'flowchart',
        strings: english,
      );
      final chineseTemplate = MermaidTemplates.getTemplate(
        'flowchart',
        strings: chinese,
      );
      final englishSnippet = MermaidTemplates.getSnippets(
        'flowchart',
        strings: english,
      ).first.$2;
      final chineseSnippet = MermaidTemplates.getSnippets(
        'flowchart',
        strings: chinese,
      ).first.$2;

      expect(englishTemplate, contains('graph TD'));
      expect(englishTemplate, contains('A[Start]'));
      expect(englishTemplate, contains('A --> B'));
      expect(chineseTemplate, contains('A[开始]'));
      expect(chineseTemplate, contains('A --> B'));
      final englishStateTemplate = MermaidTemplates.getTemplate(
        'stateDiagram',
        strings: english,
      );
      expect(englishStateTemplate, contains('state "Pending" as 待处理'));
      expect(englishStateTemplate, contains('待处理 --> 处理中'));
      expect(
        MermaidTemplates.getTemplate('sequenceDiagram', strings: english),
        contains('participant "User" as 用户'),
      );
      final englishJourneyTemplate = MermaidTemplates.getTemplate(
        'journey',
        strings: english,
      );
      expect(englishJourneyTemplate, contains(': 5: User'));
      expect(englishJourneyTemplate, contains(': 3: System'));
      final englishSubgraphSnippet = MermaidTemplates.getSnippets(
        'flowchart',
        strings: english,
      ).elementAt(3).$2;
      expect(englishSubgraphSnippet, contains('subgraph 子图名称 [Subgraph]'));
      expect(englishSnippet, '  NewNode[New node]');
      expect(chineseSnippet, '  NewNode[新节点]');
      expect(
        MermaidTemplates.getSnippets(
          'sequenceDiagram',
          strings: english,
        ).first.$2,
        'participant "New participant" as 新参与者',
      );
      expect(
        MermaidTemplates.getSnippets('classDiagram', strings: english).first.$2,
        contains('class "New class" as 新类'),
      );
      expect(
        MermaidTemplates.getSnippets('classDiagram', strings: english).first.$2,
        contains('+String attribute'),
      );
      expect(
        MermaidTemplates.getSnippets(
          'classDiagram',
          strings: english,
        ).elementAt(2).$2,
        contains('class "Class A" as 类A'),
      );
      expect(
        MermaidTemplates.getSnippets(
          'classDiagram',
          strings: english,
        ).elementAt(3).$2,
        contains('class "Whole" as 整体'),
      );
      expect(
        MermaidTemplates.getSnippets(
          'stateDiagram',
          strings: english,
        ).elementAt(1).$2,
        contains('state "State 1" as 状态1'),
      );
      expect(
        MermaidTemplates.getSnippets(
          'classDiagram',
          strings: english,
        ).elementAt(1).$2,
        contains('class "Child" as 子类'),
      );
      expect(
        MermaidTemplates.getSnippets(
          'journey',
          strings: english,
        ).elementAt(2).$2,
        contains(': 5: System'),
      );
      expect(
        MermaidTemplates.getTemplate('unknown', strings: english),
        isEmpty,
      );
    });

    test('localizing catalog does not rewrite user-authored Mermaid code', () {
      const userCode = 'graph TD\n  KeepMyNode[My saved label]';
      final inserted = MermaidTemplates.insertSnippet(
        userCode,
        MermaidTemplates.getSnippets(
          'flowchart',
          strings: AppLocalizationsEnUs(),
        ).first.$2,
      );

      expect(inserted, startsWith(userCode));
      expect(inserted, contains('KeepMyNode[My saved label]'));
    });
  });

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

    test('relationship snippets use declared nodes in a custom diagram', () {
      const code = '''requirementDiagram
  functionalRequirement account_access {
    id: 1
    text: A user can access the account
    risk: low
    verifyMethod: test
  }
  element web_portal {
    type: UI
  }
  element auth_api {
    type: Service
  }''';
      final snippets = MermaidTemplates.getSnippets('requirement', code: code);
      final relationshipSnippet =
          snippets.singleWhere((snippet) => snippet.$1 == '添加关联').$2;
      final verificationSnippet =
          snippets.singleWhere((snippet) => snippet.$1 == '添加验证').$2;

      expect(relationshipSnippet, '  web_portal - satisfies -> account_access');
      expect(verificationSnippet, '  auth_api - verifies -> account_access');
      expect(relationshipSnippet, isNot(contains('用户登录')));
      expect(verificationSnippet, isNot(contains('认证服务')));
    });

    test('omits relationship snippets when an endpoint class is missing', () {
      const diagrams = [
        '''requirementDiagram
  requirement account_access {
    id: 1
    text: Account access
    risk: low
    verifyMethod: test
  }''',
        '''requirementDiagram
  element web_portal {
    type: UI
  }''',
      ];

      for (final code in diagrams) {
        final snippets = MermaidTemplates.getSnippets(
          'requirement',
          code: code,
        );
        final labels = snippets.map((snippet) => snippet.$1);

        expect(labels, isNot(contains('添加关联')));
        expect(labels, isNot(contains('添加验证')));
      }
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

  group('MermaidTemplates - Gantt snippet date format', () {
    test('task and milestone snippets use the chart date format', () {
      const code = '''gantt
  dateFormat  YYYY/MM/DD''';
      final snippets = MermaidTemplates.getSnippets('gantt', code: code);
      final taskSnippet =
          snippets.singleWhere((snippet) => snippet.$1 == '添加任务').$2;
      final milestoneSnippet =
          snippets.singleWhere((snippet) => snippet.$1 == '添加里程碑').$2;

      expect(taskSnippet, matches(RegExp(r'^  新任务 :\d{4}/\d{2}/\d{2}, 7d$')));
      expect(
        milestoneSnippet,
        matches(RegExp(r'^  里程碑 :milestone, \d{4}/\d{2}/\d{2}, 0d$')),
      );
    });

    test('task and milestone snippets preserve ordinal day tokens', () {
      const code = '''gantt
  dateFormat  Do MMM YYYY''';
      final snippets = MermaidTemplates.getSnippets('gantt', code: code);
      final taskSnippet =
          snippets.singleWhere((snippet) => snippet.$1 == '添加任务').$2;
      final milestoneSnippet =
          snippets.singleWhere((snippet) => snippet.$1 == '添加里程碑').$2;
      const ordinalDate = r'\d{1,2}(?:st|nd|rd|th) [A-Z][a-z]{2} \d{4}';

      expect(taskSnippet, matches(RegExp('^  新任务 :$ordinalDate, 7d\$')));
      expect(
        milestoneSnippet,
        matches(RegExp('^  里程碑 :milestone, $ordinalDate, 0d\$')),
      );
    });
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

    test(
      'merge snippet targets an existing branch for each GitGraph setup',
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
  commit id: "初始提交"
  branch feature
  checkout feature''',
            expectedTarget: 'trunk',
            existingBranches: <String>{'trunk', 'feature'},
          ),
          (
            code:
                '''%%{init: { 'gitGraph': { 'mainBranchName': 'develop' } } }%%
gitGraph
  commit id: "初始提交"
  branch feature''',
            expectedTarget: 'feature',
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
  commit id: "初始提交"
  branch feature
  checkout feature''',
            expectedTarget: 'trunk',
            existingBranches: <String>{'trunk', 'feature'},
          ),
          (
            code: '''---
config: { gitGraph: { mainBranchName: trunk } }
---
gitGraph
  commit id: "初始提交"
  branch feature
  checkout feature''',
            expectedTarget: 'trunk',
            existingBranches: <String>{'trunk', 'feature'},
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
      },
    );

    test('merge snippet avoids the first declared branch when checked out', () {
      const code = '''gitGraph
  branch develop
  checkout develop
  branch feature''';
      final mergeSnippet = MermaidTemplates.getSnippets(
        'gitGraph',
        code: code,
      ).singleWhere((snippet) => snippet.$1 == '合并分支').$2;
      final mergeTarget = mergeSnippet.trim().split(RegExp(r'\s+')).last;

      expect({'main', 'develop', 'feature'}, contains(mergeTarget));
      expect(mergeTarget, isNot('develop'));
    });

    test('omits merge snippet when there is no alternate branch', () {
      const code = '''gitGraph
  checkout main''';
      final snippets = MermaidTemplates.getSnippets('gitGraph', code: code);

      expect(snippets.map((snippet) => snippet.$1), isNot(contains('合并分支')));
    });
  });

  group('MermaidTemplates - mindmap snippets', () {
    test(
      'adds a topic under the existing root without adding another root',
      () {
        final template = MermaidTemplates.getTemplate('mindmap');
        final addTopicSnippet = MermaidTemplates.getSnippets('mindmap')
            .singleWhere((snippet) => snippet.$1 == '添加主题')
            .$2;
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
