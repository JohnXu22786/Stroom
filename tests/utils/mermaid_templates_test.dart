import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/mermaid_templates.dart';

void main() {
  group('MermaidTemplates - getTemplate with unknown type', () {
    test('returns empty string for unknown type', () {
      final template = MermaidTemplates.getTemplate('unknown');
      expect(template, isEmpty);
    });
  });
}
