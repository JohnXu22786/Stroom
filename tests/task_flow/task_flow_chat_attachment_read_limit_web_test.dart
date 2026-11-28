import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/services/attachment_storage.dart';
import 'package:stroom/services/openai_protocol.dart';
import 'package:stroom/task_flow/models/flow_payload.dart';
import 'package:stroom/task_flow/models/io_type.dart';
import 'package:stroom/task_flow/services/block_executors/chat_executor.dart';
import 'package:stroom/utils/web_file_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const validKey = 'attachments/web-flow-valid.wav';

  tearDown(() async {
    WebFileStore.readBlobOverrideForTesting = null;
    await WebFileStore.delete(validKey);
  });

  test('valid web attachments still reach the chat protocol', () async {
    final bytes = Uint8List.fromList([
      0x52,
      0x49,
      0x46,
      0x46,
      0x04,
      0x00,
      0x00,
      0x00,
      0x57,
      0x41,
      0x56,
      0x45,
      1,
      2,
      3,
      4,
    ]);
    await WebFileStore.write(validKey, bytes);

    final message = await prepareFlowChatMessage(
      const FlowPayload.file(
        fileReference: validKey,
        type: IOType.audio,
        fileName: 'speech.wav',
      ),
      'conversation',
    );

    expect(message.attachments, hasLength(1));
    expect(
      await AttachmentStorage.readFile(message.attachments.single.storagePath),
      orderedEquals(bytes),
    );
    final request = await const OpenAIProtocol().buildRequest(
      history: [message],
    );
    final content = request.messages.single['content'] as List;
    expect(content.last['type'], 'input_audio');
  }, skip: !kIsWeb);
}
