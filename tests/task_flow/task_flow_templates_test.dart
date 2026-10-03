import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/task_flow/models/block_type_definition.dart';
import 'package:stroom/task_flow/models/task_flow_templates.dart';

void main() {
  test(
      'template drafts keep independent identities and require real configuration',
      () {
    for (final template in taskFlowTemplates) {
      final first = template.createDraft();
      final second = template.createDraft();
      expect(first.id, isNot(second.id));
      expect(
          first.blocks
              .map((block) => block.id)
              .toSet()
              .intersection(second.blocks.map((block) => block.id).toSet()),
          isEmpty);
      for (final block in first.blocks) {
        if ([BlockType.asr, BlockType.ocr, BlockType.tts]
            .contains(block.typeKey)) {
          expect(block.params['modelRef'], anyOf(isNull, isEmpty));
        }
        if (block.typeKey == BlockType.chat) {
          expect(block.params['assistantId'], isEmpty);
        }
        block.params['configuredLater'] = {
          'model': ['changed']
        };
      }
      expect(
          second.blocks
              .any((block) => block.params.containsKey('configuredLater')),
          isFalse);
      expect(
          template
              .createDraft()
              .blocks
              .any((block) => block.params.containsKey('configuredLater')),
          isFalse);
    }
  });
}
