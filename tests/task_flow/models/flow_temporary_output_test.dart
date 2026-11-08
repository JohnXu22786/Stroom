import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/task_flow/models/block_type_definition.dart';
import 'package:stroom/task_flow/models/flow_temporary_output.dart';
import 'package:stroom/task_flow/models/io_type.dart';
import 'package:stroom/task_flow/models/task_flow_definition.dart';

void main() {
  test('temporary mode is opt-in and survives flow serialization', () {
    final legacyBlock = TaskFlowBlock(
      id: 'tts',
      typeKey: BlockType.tts,
      params: {'saveFolder': ''},
    );
    expect(isFlowTemporaryOutputEnabled(legacyBlock), isFalse);

    final temporaryBlock = legacyBlock.copyWithParam(
      flowTemporaryOutputParam,
      true,
    );
    final flow = TaskFlowDefinition(
      name: 'temporary output',
      blocks: [temporaryBlock],
    );
    final restored = TaskFlowDefinition.fromMap(flow.toMap()).blocks.single;

    expect(isFlowTemporaryOutputEnabled(restored), isTrue);
    expect(restored.params['saveFolder'], '');
  });

  test('only file-producing non-final blocks are eligible', () {
    final catCatchVideo = TaskFlowBlock(typeKey: BlockType.catcatch);
    final catCatchAudio = catCatchVideo.copyWithParam('audioOutput', true);
    final blocks = [
      catCatchVideo,
      TaskFlowBlock(typeKey: BlockType.tts),
      TaskFlowBlock(typeKey: BlockType.asr),
      TaskFlowBlock(typeKey: BlockType.ocr),
      TaskFlowBlock(typeKey: BlockType.chat),
      catCatchAudio,
    ];

    // The first processing block remains eligible; the final block does not.
    expect(isFlowTemporaryOutputEligible(blocks, 0), isTrue);
    expect(isFlowTemporaryOutputEligible(blocks, 1), isTrue);
    expect(catCatchVideo.getDefinition()?.outputType, IOType.video);
    expect(catCatchAudio.getDefinition()?.outputType, IOType.audio);
    expect(hasFileOutput(catCatchVideo), isTrue);
    expect(hasFileOutput(catCatchAudio), isTrue);
    expect(
      isFlowTemporaryOutputEligible([catCatchAudio, blocks[1]], 0),
      isTrue,
    );
    for (final index in [2, 3, 4, 5, -1, 6]) {
      expect(isFlowTemporaryOutputEligible(blocks, index), isFalse);
    }
    expect(
      isFlowTemporaryOutputEligible(
        [TaskFlowBlock(typeKey: BlockType.tts)],
        0,
      ),
      isFalse,
    );
  });

  test('enabling a final block never makes it temporary', () {
    final blocks = [
      TaskFlowBlock(typeKey: BlockType.tts),
      TaskFlowBlock(
        typeKey: BlockType.audioSeparation,
        params: {flowTemporaryOutputParam: true},
      ),
    ];

    expect(isFlowBlockTemporary(blocks, 0), isFalse);
    expect(isFlowBlockTemporary(blocks, 1), isFalse);
  });
}
