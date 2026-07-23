import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/task_flow/models/io_type.dart';
import 'package:stroom/task_flow/models/block_type_definition.dart';
import 'package:stroom/task_flow/models/task_flow_definition.dart';

void main() {
  group('IOType compatibility', () {
    test('same types are compatible', () {
      expect(IOType.audio.isCompatibleWith(IOType.audio), isTrue);
      expect(IOType.text.isCompatibleWith(IOType.text), isTrue);
      expect(IOType.video.isCompatibleWith(IOType.video), isTrue);
      expect(IOType.image.isCompatibleWith(IOType.image), isTrue);
    });

    test('any type is compatible with anything', () {
      expect(IOType.any.isCompatibleWith(IOType.audio), isTrue);
      expect(IOType.any.isCompatibleWith(IOType.text), isTrue);
      expect(IOType.any.isCompatibleWith(IOType.video), isTrue);
    });

    test('incompatible types return false', () {
      expect(IOType.audio.isCompatibleWith(IOType.text), isFalse);
      expect(IOType.text.isCompatibleWith(IOType.audio), isFalse);
      expect(IOType.video.isCompatibleWith(IOType.text), isFalse);
      expect(IOType.image.isCompatibleWith(IOType.audio), isFalse);
    });

    test('url is compatible with text and url', () {
      expect(IOType.url.isCompatibleWith(IOType.url), isTrue);
      expect(IOType.url.isCompatibleWith(IOType.text), isTrue);
      expect(IOType.text.isCompatibleWith(IOType.url), isTrue);
      expect(IOType.url.isCompatibleWith(IOType.audio), isFalse);
      expect(IOType.url.isCompatibleWith(IOType.video), isFalse);
    });
  });

  group('BlockTypeDefinition', () {
    test('creates ASR block type correctly', () {
      final asr = BlockTypeDefinition.asr;
      expect(asr.typeKey, 'asr');
      expect(asr.label, '语音识别');
      expect(asr.inputType, IOType.audio);
      expect(asr.outputType, IOType.text);
      expect(asr.params.isNotEmpty, isTrue);
    });

    test('creates OCR block type correctly', () {
      final ocr = BlockTypeDefinition.ocr;
      expect(ocr.typeKey, 'ocr');
      expect(ocr.inputType, IOType.image);
      expect(ocr.outputType, IOType.text);
    });

    test('creates AudioSeparation block type correctly', () {
      final sep = BlockTypeDefinition.audioSeparation;
      expect(sep.typeKey, 'audioSeparation');
      expect(sep.inputType, IOType.video);
      expect(sep.outputType, IOType.audio);
    });

    test('creates CatCatch block type correctly', () {
      final cc = BlockTypeDefinition.catcatch;
      expect(cc.typeKey, 'catcatch');
      expect(cc.inputType, IOType.text);
      expect(cc.outputType, IOType.video);
    });

    test('creates TTS block type correctly', () {
      final tts = BlockTypeDefinition.tts;
      expect(tts.typeKey, 'tts');
      expect(tts.inputType, IOType.text);
      expect(tts.outputType, IOType.audio);
    });

    test('can get all registered block types', () {
      final all = BlockTypeDefinition.all;
      expect(all.length, greaterThan(0));
      expect(all.any((b) => b.typeKey == 'asr'), isTrue);
      expect(all.any((b) => b.typeKey == 'ocr'), isTrue);
    });

    test('findBlockType returns correct type by key', () {
      final found = BlockTypeDefinition.findBlockType('asr');
      expect(found, isNotNull);
      expect(found!.typeKey, 'asr');
    });

    test('findBlockType returns null for unknown key', () {
      expect(BlockTypeDefinition.findBlockType('nonexistent'), isNull);
    });

    test('getCompatibleNextBlocks filters by input type', () {
      // A block that outputs text (like ASR) should be compatible with
      // blocks that accept text as input (like TTS)
      final outputText = BlockTypeDefinition.asr;
      final compatible = BlockTypeDefinition.getCompatibleNextBlocks(
          outputText.outputType);
      expect(compatible.any((b) => b.typeKey == 'tts'), isTrue);
      // ASR outputs text, so it should NOT be compatible with blocks
      // that need audio as input (like ASR itself)
      expect(compatible.any((b) => b.typeKey == 'asr'), isFalse);
    });

    test('serialization round-trips correctly', () {
      final original = BlockTypeDefinition.asr;
      final map = original.toMap();
      final restored = BlockTypeDefinition.fromMap(map);
      expect(restored.typeKey, original.typeKey);
      expect(restored.label, original.label);
      expect(restored.inputType, original.inputType);
      expect(restored.outputType, original.outputType);
      expect(restored.params.length, original.params.length);
    });
  });

  group('TaskFlowBlock', () {
    test('creates block instance with correct type and default params', () {
      final definition = BlockTypeDefinition.asr;
      final block = TaskFlowBlock(typeKey: 'asr');
      expect(block.id, isNotEmpty);
      expect(block.typeKey, 'asr');
      // Params should contain default values from the definition
      expect(block.params, isNotEmpty);
      expect(block.params.containsKey('saveFolder'), isTrue);
    });

    test('can set custom parameters on block', () {
      final block = TaskFlowBlock(
        typeKey: 'asr',
        params: {'saveFolder': 'my_folder', 'modelIndex': 1},
      );
      expect(block.params['saveFolder'], 'my_folder');
      expect(block.params['modelIndex'], 1);
    });

    test('param override works correctly', () {
      final block = TaskFlowBlock(typeKey: 'asr');
      final updated = block.copyWithParams({'saveFolder': 'custom_folder'});
      expect(updated.params['saveFolder'], 'custom_folder');
      // Other default params should still exist
      expect(updated.params.containsKey('modelIndex'), isTrue);
    });

    test('serialization round-trips', () {
      final original = TaskFlowBlock(
        typeKey: 'asr',
        params: {'saveFolder': 'test', 'modelIndex': 0},
      );
      final map = original.toMap();
      final restored = TaskFlowBlock.fromMap(map);
      expect(restored.id, original.id);
      expect(restored.typeKey, original.typeKey);
      expect(restored.params['saveFolder'], 'test');
    });

    test('getDefinition returns correct BlockTypeDefinition', () {
      final block = TaskFlowBlock(typeKey: 'asr');
      final def = block.getDefinition();
      expect(def, isNotNull);
      expect(def!.typeKey, 'asr');
    });

    test('getDefinition returns null for unknown typeKey', () {
      final block = TaskFlowBlock(typeKey: 'nonexistent');
      expect(block.getDefinition(), isNull);
    });
  });

  group('TaskFlowDefinition', () {
    test('creates flow with no blocks', () {
      final flow = TaskFlowDefinition(name: '测试流程');
      expect(flow.id, isNotEmpty);
      expect(flow.name, '测试流程');
      expect(flow.blocks, isEmpty);
    });

    test('can add blocks to flow', () {
      final flow = TaskFlowDefinition(name: '测试');
      final block1 = TaskFlowBlock(typeKey: 'catcatch');
      final block2 = TaskFlowBlock(typeKey: 'audioSeparation');
      final block3 = TaskFlowBlock(typeKey: 'asr');

      final updated = flow
          .addBlock(block1)
          .addBlock(block2)
          .addBlock(block3);

      expect(updated.blocks.length, 3);
    });

    test('validate checks I/O type compatibility between blocks', () {
      // CatCatch (text→video) → AudioSeparation (video→audio) → ASR (audio→text)
      // This is a valid chain, with input type = text (for CatCatch)
      final flow = TaskFlowDefinition(
        name: '测试',
        inputType: IOType.text,
      );
      final validFlow = flow
          .addBlock(TaskFlowBlock(typeKey: 'catcatch'))
          .addBlock(TaskFlowBlock(typeKey: 'audioSeparation'))
          .addBlock(TaskFlowBlock(typeKey: 'asr'));

      final result = validFlow.validate();
      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
    });

    test('validate detects incompatible connections', () {
      // Initial input is text, first block is ASR (needs audio) → incompatibility
      // ASR (audio→text) → AudioSeparation (video→audio) → also incompatible
      final flow = TaskFlowDefinition(
        name: '测试',
        inputType: IOType.text,
      );
      final invalidFlow = flow
          .addBlock(TaskFlowBlock(typeKey: 'asr'))
          .addBlock(TaskFlowBlock(typeKey: 'audioSeparation'));

      final result = invalidFlow.validate();
      expect(result.isValid, isFalse);
      expect(result.errors, isNotEmpty);
    });

    test('validate detects empty flow', () {
      final flow = TaskFlowDefinition(name: '空流程');
      final result = flow.validate();
      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.contains('至少')), isTrue);
    });

    test('validate detects single-block flow as valid', () {
      // ASR needs audio input, so set inputType accordingly
      final flow = TaskFlowDefinition(name: '单块', inputType: IOType.audio)
          .addBlock(TaskFlowBlock(typeKey: 'asr'));
      // A single block with matching input type is valid
      final result = flow.validate();
      expect(result.isValid, isTrue);
    });

    test('validate catches initial input vs first block mismatch', () {
      // Input type is text but first block (ASR) needs audio
      final flow = TaskFlowDefinition(name: '测试', inputType: IOType.text)
          .addBlock(TaskFlowBlock(typeKey: 'asr'));
      final result = flow.validate();
      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.contains('初始输入')), isTrue);
    });

    test('removeBlock works by index', () {
      final flow = TaskFlowDefinition(name: '测试')
          .addBlock(TaskFlowBlock(typeKey: 'catcatch'))
          .addBlock(TaskFlowBlock(typeKey: 'asr'));
      expect(flow.blocks.length, 2);

      final updated = flow.removeBlock(0);
      expect(updated.blocks.length, 1);
      expect(updated.blocks[0].typeKey, 'asr');
    });

    test('moveBlock reorders blocks correctly', () {
      final flow = TaskFlowDefinition(name: '测试')
          .addBlock(TaskFlowBlock(typeKey: 'catcatch'))
          .addBlock(TaskFlowBlock(typeKey: 'asr'));
      
      final updated = flow.moveBlock(oldIndex: 1, newIndex: 0);
      expect(updated.blocks[0].typeKey, 'asr');
      expect(updated.blocks[1].typeKey, 'catcatch');
    });

    test('serialization round-trips with blocks and params', () {
      final original = TaskFlowDefinition(name: '完整流程', inputType: IOType.text)
          .addBlock(TaskFlowBlock(
            typeKey: 'catcatch',
            params: {'videoFolder': 'videos'},
          ))
          .addBlock(TaskFlowBlock(
            typeKey: 'asr',
            params: {'saveFolder': 'texts', 'modelIndex': 1},
          ));

      final map = original.toMap();
      final restored = TaskFlowDefinition.fromMap(map);

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.inputType, original.inputType);
      expect(restored.blocks.length, original.blocks.length);
      expect(restored.blocks[0].params['videoFolder'], 'videos');
      expect(restored.blocks[1].params['saveFolder'], 'texts');
    });

    test('copyWithNewId creates a new flow with different id', () {
      final original = TaskFlowDefinition(name: '原流程')
          .addBlock(TaskFlowBlock(typeKey: 'asr'));
      final copy = original.copyWithNewId();
      expect(copy.id, isNot(original.id));
      expect(copy.name, original.name);
      expect(copy.blocks.length, original.blocks.length);
    });
  });
}
