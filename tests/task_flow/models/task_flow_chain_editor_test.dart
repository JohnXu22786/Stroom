import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/task_flow/models/block_type_definition.dart';
import 'package:stroom/task_flow/models/io_type.dart';
import 'package:stroom/task_flow/models/task_flow_chain_editor.dart';
import 'package:stroom/task_flow/models/task_flow_definition.dart';

TaskFlowBlock _block(BlockType type, String id) => TaskFlowBlock(
      id: id,
      typeKey: type,
      params: {
        'configured': id,
        'modelRef': {'configId': 'provider-$id', 'modelId': 'model-$id'},
        'nested': [
          {'value': id}
        ],
      },
    );

void main() {
  test('assistant link validation rejects unspecified any input', () {
    final editor = TaskFlowChainEditor(
      blocks: [_block(BlockType.chat, 'chat')],
      inputType: IOType.any,
    );
    expect(editor.issues.single.blockId, 'chat');
    expect(editor.issues.single.message, contains('明确'));
    expect(editor.insertionCandidates(0).map((block) => block.typeKey),
        isNot(contains(BlockType.chat)));
    editor.changeInputType(IOType.audio);
    expect(editor.issues, isEmpty);
  });

  test('middle insertion preserves the configured suffix and checks both links',
      () {
    final editor = TaskFlowChainEditor(blocks: [
      _block(BlockType.tts, 'tts'),
      _block(BlockType.asr, 'asr'),
      _block(BlockType.chat, 'chat'),
    ]);
    final suffix = editor.blocks.skip(1).toList();
    expect(editor.insertionCandidates(1).map((type) => type.typeKey),
        isNot(contains(BlockType.chat)));
    expect(editor.insertionCandidates(2).map((type) => type.typeKey),
        contains(BlockType.chat));
    editor.insert(1, BlockType.chat);
    expect(editor.blocks.map((block) => block.id).toList().sublist(2),
        ['asr', 'chat']);
    expect(editor.blocks[2], same(suffix.first));
    expect(editor.blocks[3].params['configured'], 'chat');
    expect(editor.issues.map((issue) => issue.blockIndex), [2]);
    expect(editor.issues.single.message, contains('语音识别'));
    expect(editor.undo(), isTrue);
    expect(editor.blocks.map((block) => block.id), ['tts', 'asr', 'chat']);
    expect(editor.issues, isEmpty);
  });

  test('middle deletion keeps every remaining block and undo restores it', () {
    final editor = TaskFlowChainEditor(blocks: [
      _block(BlockType.catcatch, 'video'),
      _block(BlockType.audioSeparation, 'audio'),
      _block(BlockType.asr, 'asr'),
      _block(BlockType.chat, 'chat'),
    ]);
    editor.select('audio');
    editor.remove(1);
    expect(editor.blocks.map((block) => block.id), ['video', 'asr', 'chat']);
    expect(editor.selectedBlockId, 'asr');
    expect(editor.issues.single.blockIndex, 1);
    expect(editor.issues.single.message, contains('视频'));
    editor.undo();
    expect(editor.blocks.map((block) => block.id),
        ['video', 'audio', 'asr', 'chat']);
    expect(editor.selectedBlockId, 'audio');
    expect(editor.blocks[1].params['configured'], 'audio');
    expect(editor.issues, isEmpty);
  });

  test('duplicate receives a new ID and independent nested parameter values',
      () {
    final original = _block(BlockType.chat, 'original');
    final editor = TaskFlowChainEditor(blocks: [original]);
    editor.duplicate(0);
    final duplicate = editor.blocks[1];
    expect(duplicate.id, isNot('original'));
    expect(editor.selectedBlockId, duplicate.id);
    expect(duplicate.params, editor.blocks.first.params);
    (duplicate.params['modelRef'] as Map)['modelId'] = 'changed';
    ((duplicate.params['nested'] as List).single as Map)['value'] = 'changed';
    expect((editor.blocks.first.params['modelRef'] as Map)['modelId'],
        'model-original');
    expect(((original.params['nested'] as List).single as Map)['value'],
        'original');
    editor.undo();
    expect(editor.blocks.single.id, 'original');
    expect(
        ((editor.blocks.single.params['nested'] as List).single
            as Map)['value'],
        'original');
  });

  test('reordering preserves identity and validates the whole moved chain', () {
    final editor = TaskFlowChainEditor(blocks: [
      _block(BlockType.tts, 'tts'),
      _block(BlockType.asr, 'asr'),
      _block(BlockType.chat, 'chat'),
    ]);
    final originals = List<TaskFlowBlock>.from(editor.blocks);
    editor.select('tts');
    expect(editor.move(2, 0), isTrue);
    expect(editor.blocks, [originals[2], originals[0], originals[1]]);
    expect(editor.blocks[1], same(originals[0]));
    expect(editor.selectedBlockId, 'tts');
    expect(editor.issues, isEmpty);
    editor.move(2, 0);
    expect(editor.issues.map((issue) => issue.blockIndex), [0]);
    editor.undo();
    expect(editor.blocks.map((block) => block.id), ['chat', 'tts', 'asr']);
    expect(editor.issues, isEmpty);
  });

  test('nested parameter changes and input changes undo as complete snapshots',
      () {
    final editor = TaskFlowChainEditor(
        blocks: [_block(BlockType.asr, 'asr')], inputType: IOType.audio);
    editor.select('asr');
    final changed = TaskFlowChainEditor.copyBlock(editor.blocks.single);
    ((changed.params['nested'] as List).single as Map)['value'] = 'edited';
    editor.updateParams('asr', changed.params);
    ((changed.params['nested'] as List).single as Map)['value'] = 'later';
    expect(
        ((editor.blocks.single.params['nested'] as List).single
            as Map)['value'],
        'edited');
    editor.changeInputType(IOType.video);
    expect(editor.issues.single.blockIndex, 0);
    editor.undo();
    expect(editor.inputType, IOType.audio);
    expect(editor.issues, isEmpty);
    editor.undo();
    expect(
        ((editor.blocks.single.params['nested'] as List).single
            as Map)['value'],
        'asr');
    expect(editor.selectedBlockId, 'asr');
    expect(editor.canUndo, isFalse);
  });

  test('unsupported blocks remain visible and no-op edits add no undo entry',
      () {
    final editor = TaskFlowChainEditor(blocks: [
      _block(BlockType.custom, 'unknown'),
      _block(BlockType.chat, 'chat'),
    ]);
    expect(editor.issues.single.blockId, 'unknown');
    expect(editor.move(0, 0), isFalse);
    expect(editor.remove(-1), isFalse);
    expect(editor.changeInputType(IOType.text), isFalse);
    expect(editor.updateParams('chat', editor.blocks.last.params), isFalse);
    expect(editor.canUndo, isFalse);
    editor.select('chat');
    editor.remove(1);
    editor.remove(0);
    expect(editor.selectedBlockId, isNull);
    expect(editor.blocks, isEmpty);
    editor.undo();
    expect(editor.selectedBlockId, 'unknown');
  });
}
