import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/mermaid_templates.dart';

void main() {
  group('MermaidTemplates - flowchart', () {
    test('generates basic flowchart template', () {
      final template = MermaidTemplates.getTemplate('flowchart');
      expect(template, contains('graph TD'));
      expect(template, contains('开始'));
      expect(template, contains('结束'));
    });
  });

  group('MermaidTemplates - sequence diagram', () {
    test('generates sequence diagram template', () {
      final template = MermaidTemplates.getTemplate('sequenceDiagram');
      expect(template, contains('sequenceDiagram'));
      expect(template, contains('用户'));
      expect(template, contains('系统'));
    });
  });

  group('MermaidTemplates - class diagram', () {
    test('generates class diagram template', () {
      final template = MermaidTemplates.getTemplate('classDiagram');
      expect(template, contains('classDiagram'));
      expect(template, contains('class'));
    });
  });

  group('MermaidTemplates - state diagram', () {
    test('generates state diagram template', () {
      final template = MermaidTemplates.getTemplate('stateDiagram');
      expect(template, contains('stateDiagram-v2'));
    });
  });

  group('MermaidTemplates - er diagram', () {
    test('generates ER diagram template', () {
      final template = MermaidTemplates.getTemplate('erDiagram');
      expect(template, contains('erDiagram'));
      expect(template, contains('CUSTOMER'));
      expect(template, contains('ORDER'));
    });
  });

  group('MermaidTemplates - gantt chart', () {
    test('generates gantt chart template', () {
      final template = MermaidTemplates.getTemplate('gantt');
      expect(template, contains('gantt'));
      expect(template, contains('dateFormat'));
    });
  });

  group('MermaidTemplates - pie chart', () {
    test('generates pie chart template', () {
      final template = MermaidTemplates.getTemplate('pie');
      expect(template, contains('pie'));
    });
  });

  group('MermaidTemplates - journey diagram', () {
    test('generates user journey template', () {
      final template = MermaidTemplates.getTemplate('journey');
      expect(template, contains('journey'));
      expect(template, contains('title'));
    });
  });

  group('MermaidTemplates - gitgraph', () {
    test('generates gitgraph template', () {
      final template = MermaidTemplates.getTemplate('gitGraph');
      expect(template, contains('gitGraph'));
      expect(template, contains('commit'));
    });
  });

  group('MermaidTemplates - mindmap', () {
    test('generates mindmap template', () {
      final template = MermaidTemplates.getTemplate('mindmap');
      expect(template, contains('mindmap'));
    });
  });

  group('MermaidTemplates - timeline', () {
    test('generates timeline template', () {
      final template = MermaidTemplates.getTemplate('timeline');
      expect(template, contains('timeline'));
      expect(template, contains('title'));
    });
  });

  group('MermaidTemplates - block diagram', () {
    test('generates block diagram template', () {
      final template = MermaidTemplates.getTemplate('block');
      expect(template, contains('block-beta'));
    });
  });

  group('MermaidTemplates - requirement diagram', () {
    test('generates requirement diagram template', () {
      final template = MermaidTemplates.getTemplate('requirement');
      expect(template, contains('requirementDiagram'));
    });
  });

  group('MermaidTemplates - getAllTypes', () {
    test('returns all supported diagram types', () {
      final types = MermaidTemplates.getAllTypes();
      expect(types.length, equals(13));
      expect(types.any((t) => t.id == 'flowchart'), isTrue);
      expect(types.any((t) => t.id == 'sequenceDiagram'), isTrue);
      expect(types.any((t) => t.id == 'classDiagram'), isTrue);
      expect(types.any((t) => t.id == 'stateDiagram'), isTrue);
      expect(types.any((t) => t.id == 'erDiagram'), isTrue);
      expect(types.any((t) => t.id == 'gantt'), isTrue);
      expect(types.any((t) => t.id == 'pie'), isTrue);
      expect(types.any((t) => t.id == 'journey'), isTrue);
      expect(types.any((t) => t.id == 'gitGraph'), isTrue);
      expect(types.any((t) => t.id == 'mindmap'), isTrue);
      expect(types.any((t) => t.id == 'timeline'), isTrue);
      expect(types.any((t) => t.id == 'block'), isTrue);
      expect(types.any((t) => t.id == 'requirement'), isTrue);
    });

    test('each type has Chinese label, icon, and keyword', () {
      final types = MermaidTemplates.getAllTypes();
      for (final type in types) {
        expect(type.label, isNotEmpty);
        expect(type.icon, isNotNull);
        expect(type.keyword, isNotEmpty);
      }
    });
  });

  group('MermaidTemplates - getTemplate with unknown type', () {
    test('returns empty string for unknown type', () {
      final template = MermaidTemplates.getTemplate('unknown');
      expect(template, isEmpty);
    });
  });

  group('MermaidTemplates - insertSnippet', () {
    test('appends snippet to existing code', () {
      final result = MermaidTemplates.insertSnippet(
        'graph TD\n  A[Start]',
        '  B[End]',
      );
      expect(result, 'graph TD\n  A[Start]\n  B[End]');
    });

    test('returns snippet if code is empty', () {
      final result = MermaidTemplates.insertSnippet('', '  B[End]');
      expect(result, '  B[End]');
    });
  });
}
