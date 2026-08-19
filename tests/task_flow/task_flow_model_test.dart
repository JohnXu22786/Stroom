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
      expect(asr.typeKey, BlockType.asr);
      expect(asr.label, '语音识别');
      expect(asr.inputType, IOType.audio);
      expect(asr.outputType, IOType.text);
      expect(asr.params.isNotEmpty, isTrue);
    });

    test('creates OCR block type correctly', () {
      final ocr = BlockTypeDefinition.ocr;
      expect(ocr.typeKey, BlockType.ocr);
      expect(ocr.inputType, IOType.image);
      expect(ocr.outputType, IOType.text);
    });

    test('creates AudioSeparation block type correctly', () {
      final sep = BlockTypeDefinition.audioSeparation;
      expect(sep.typeKey, BlockType.audioSeparation);
      expect(sep.inputType, IOType.video);
      expect(sep.outputType, IOType.audio);
    });

    test('creates CatCatch block type correctly', () {
      final cc = BlockTypeDefinition.catcatch;
      expect(cc.typeKey, BlockType.catcatch);
      expect(cc.inputType, IOType.text);
      expect(cc.outputType, IOType.video);
    });

    test('creates TTS block type correctly', () {
      final tts = BlockTypeDefinition.tts;
      expect(tts.typeKey, BlockType.tts);
      expect(tts.inputType, IOType.text);
      expect(tts.outputType, IOType.audio);
    });

    test('can get all registered block types', () {
      final all = BlockTypeDefinition.all;
      expect(all.length, greaterThan(0));
      expect(all.any((b) => b.typeKey == BlockType.asr), isTrue);
      expect(all.any((b) => b.typeKey == BlockType.ocr), isTrue);
    });

    test('findBlockType returns correct type by key', () {
      final found = BlockTypeDefinition.findBlockType(BlockType.asr);
      expect(found, isNotNull);
      expect(found!.typeKey, BlockType.asr);
    });

    test('findBlockType returns null for unknown key', () {
      expect(BlockTypeDefinition.findBlockType(BlockType.custom), isNull);
    });

    test('getCompatibleNextBlocks filters by input type', () {
      // A block that outputs text (like ASR) should be compatible with
      // blocks that accept text as input (like TTS)
      final outputText = BlockTypeDefinition.asr;
      final compatible =
          BlockTypeDefinition.getCompatibleNextBlocks(outputText.outputType);
      expect(compatible.any((b) => b.typeKey == BlockType.tts), isTrue);
      // ASR outputs text, so it should NOT be compatible with blocks
      // that need audio as input (like ASR itself)
      expect(compatible.any((b) => b.typeKey == BlockType.asr), isFalse);
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
      final block = TaskFlowBlock(typeKey: BlockType.asr);
      expect(block.id, isNotEmpty);
      expect(block.typeKey, BlockType.asr);
      // Params should contain default values from the definition
      expect(block.params, isNotEmpty);
      expect(block.params.containsKey('saveFolder'), isTrue);
    });

    test('can set custom parameters on block', () {
      final block = TaskFlowBlock(
        typeKey: BlockType.asr,
        params: {'saveFolder': 'my_folder', 'modelIndex': 1},
      );
      expect(block.params['saveFolder'], 'my_folder');
      expect(block.params['modelIndex'], 1);
    });

    test('param override works correctly', () {
      final block = TaskFlowBlock(typeKey: BlockType.asr);
      final updated = block.copyWithParams({'saveFolder': 'custom_folder'});
      expect(updated.params['saveFolder'], 'custom_folder');
      // Other default params should still exist
      expect(updated.params.containsKey('modelIndex'), isTrue);
    });

    test('serialization round-trips', () {
      final original = TaskFlowBlock(
        typeKey: BlockType.asr,
        params: {'saveFolder': 'test', 'modelIndex': 0},
      );
      final map = original.toMap();
      final restored = TaskFlowBlock.fromMap(map);
      expect(restored.id, original.id);
      expect(restored.typeKey, original.typeKey);
      expect(restored.params['saveFolder'], 'test');
    });

    test('getDefinition returns correct BlockTypeDefinition', () {
      final block = TaskFlowBlock(typeKey: BlockType.asr);
      final def = block.getDefinition();
      expect(def, isNotNull);
      expect(def!.typeKey, BlockType.asr);
    });

    test('getDefinition returns null for unknown typeKey', () {
      final block = TaskFlowBlock(typeKey: BlockType.custom);
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
      final block1 = TaskFlowBlock(typeKey: BlockType.catcatch);
      final block2 = TaskFlowBlock(typeKey: BlockType.audioSeparation);
      final block3 = TaskFlowBlock(typeKey: BlockType.asr);

      final updated = flow.addBlock(block1).addBlock(block2).addBlock(block3);

      expect(updated.blocks.length, 3);
    });

    test('serialization round-trips with blocks and params', () {
      final original = TaskFlowDefinition(name: '完整流程', inputType: IOType.text)
          .addBlock(TaskFlowBlock(
            typeKey: BlockType.catcatch,
            params: {'videoFolder': 'videos'},
          ))
          .addBlock(TaskFlowBlock(
            typeKey: BlockType.asr,
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
      final original = TaskFlowDefinition(name: '复制测试')
          .addBlock(TaskFlowBlock(typeKey: BlockType.asr));
      final copy = original.copyWithNewId();
      expect(copy.id, isNot(original.id));
      expect(copy.name, original.name);
      expect(copy.blocks.length, original.blocks.length);
    });
  });

  group('getReplacementCandidates', () {
    Set<BlockType> keys(List<BlockTypeDefinition> defs) =>
        defs.map((d) => d.typeKey).toSet();

    test('text input, no next block: offers text/any-input blocks only', () {
      final result = BlockTypeDefinition.getReplacementCandidates(
        prevOutput: IOType.text,
      );
      expect(result, isNotEmpty);
      expect(result.every((b) => IOType.text.isCompatibleWith(b.inputType)),
          isTrue);
    });

    test('subsumes same-I/O swaps: audio→text chain position', () {
      // Replace a block whose previous output is audio and whose next
      // block needs text — ASR (audio→text) and chat (any→text) qualify.
      final result = BlockTypeDefinition.getReplacementCandidates(
        prevOutput: IOType.audio,
        nextInput: IOType.text,
      );
      expect(keys(result), containsAll({BlockType.asr, BlockType.chat}));
      expect(result.any((b) => b.typeKey == BlockType.ocr), isFalse);
      expect(
          result.any((b) => b.typeKey == BlockType.audioSeparation), isFalse);
    });

    test('last block has no next-input constraint', () {
      final result = BlockTypeDefinition.getReplacementCandidates(
        prevOutput: IOType.image,
      );
      expect(keys(result), containsAll({BlockType.ocr, BlockType.chat}));
    });

    test('next block constraint filters by output compatibility', () {
      // Previous output is video; next block needs audio. AudioSeparation
      // (video→audio) qualifies; chat (any→text) does not (text is not
      // compatible with the next block's audio input).
      final result = BlockTypeDefinition.getReplacementCandidates(
        prevOutput: IOType.video,
        nextInput: IOType.audio,
      );
      expect(keys(result), {BlockType.audioSeparation});
    });

    test('excludes the current block type', () {
      final result = BlockTypeDefinition.getReplacementCandidates(
        prevOutput: IOType.text,
        exclude: BlockType.chat,
      );
      expect(result.any((b) => b.typeKey == BlockType.chat), isFalse);
    });
  });
}
