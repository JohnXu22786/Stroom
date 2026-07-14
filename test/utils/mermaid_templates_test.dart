import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/mermaid_templates.dart';

void main() {
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
}
