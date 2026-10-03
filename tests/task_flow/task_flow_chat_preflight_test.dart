import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/assistant.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/services/chat_protocol.dart' show maxAttachmentBytes;
import 'package:stroom/task_flow/models/block_type_definition.dart';
import 'package:stroom/task_flow/models/flow_payload.dart';
import 'package:stroom/task_flow/models/io_type.dart';
import 'package:stroom/task_flow/models/task_flow_definition.dart';
import 'package:stroom/task_flow/models/task_flow_execution.dart';
import 'package:stroom/task_flow/services/task_flow_validator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('flow_chat_preflight_');
  });
  tearDown(() async => directory.delete(recursive: true));

  final anthropic = ProviderEntriesState(
    entries: [
      ProviderEntry(
        name: 'LLM',
        type: 'llm',
        configs: [
          ProviderConfigItem(
            providerName: 'Claude',
            host: 'https://example.com',
            key: 'test',
            models: [
              ModelConfig(
                name: 'Claude',
                modelId: 'claude',
                endpointType: 'anthropic',
              ),
            ],
          ),
        ],
      ),
    ],
  );
  final boundAssistant = Assistant(
    id: 'assistant',
    name: 'Assistant',
    prompt: 'Help',
    defaultModelId: 'claude',
    defaultProviderName: 'Claude',
  );
  final unboundAssistant = Assistant(
    id: 'assistant',
    name: 'Assistant',
    prompt: 'Help',
  );

  TaskFlowDefinition chatFlow(IOType inputType) => TaskFlowDefinition(
        name: 'Chat',
        inputType: inputType,
        blocks: [
          TaskFlowBlock(
            id: 'chat-block',
            typeKey: BlockType.chat,
            params: {'assistantId': 'assistant'},
          ),
        ],
      );

  test(
    'Anthropic rejects a later DOCX batch input before submission',
    () async {
      final pdf = await File('${directory.path}/notes.pdf')
          .writeAsBytes(utf8.encode('%PDF-1.7\nexample'));
      final docx = await File('${directory.path}/notes.docx').writeAsBytes([1]);
      await expectLater(
        validateTaskFlow(
          chatFlow(IOType.file),
          [FlowRunInput(text: pdf.path), FlowRunInput(text: docx.path)],
          providers: anthropic,
          assistants: [boundAssistant],
        ),
        throwsA(
          isA<TaskFlowValidationException>()
              .having((e) => e.blockIndex, 'first chat block', 0)
              .having((e) => e.inputIndex, 'second input', 1)
              .having((e) => e.message, 'unsupported file', contains('PDF')),
        ),
      );
    },
  );

  test('renamed provider still resolves the assistant by stable model ID',
      () async {
    final renamed = ProviderEntriesState(entries: [
      ProviderEntry(name: 'LLM', type: 'llm', configs: [
        ProviderConfigItem(
            providerName: 'Renamed Claude',
            host: 'https://example.com',
            key: 'test',
            models: [
              ModelConfig(
                  name: 'Claude', modelId: 'claude', endpointType: 'anthropic')
            ])
      ])
    ]);
    await validateTaskFlow(
        chatFlow(IOType.text), [const FlowRunInput(text: 'Hello')],
        providers: renamed, assistants: [boundAssistant]);
    final audio = await File('${directory.path}/speech.mp3')
        .writeAsBytes([0x49, 0x44, 0x33, 4, 0, 0, 0, 0, 0, 0]);
    await expectLater(
        validateTaskFlow(
            chatFlow(IOType.audio), [FlowRunInput(text: audio.path)],
            providers: renamed, assistants: [boundAssistant]),
        throwsA(isA<TaskFlowValidationException>().having(
            (e) => e.message, 'bound endpoint', contains('Anthropic'))));
  });

  test('initial file preflight accepts PDF content with other names', () async {
    for (final name in ['report', 'report.docx']) {
      final pdf = await File('${directory.path}/$name')
          .writeAsBytes(utf8.encode('%PDF-1.7\nexample'));
      await validateTaskFlow(
        chatFlow(IOType.file),
        [FlowRunInput(text: pdf.path)],
        providers: anthropic,
        assistants: [boundAssistant],
      );
    }
  });

  test('initial file preflight rejects non-PDF content named PDF', () async {
    final spoofed = await File('${directory.path}/fake.pdf')
        .writeAsBytes([0x50, 0x4b, 0x03, 0x04, 1, 2]);
    await expectLater(
      validateTaskFlow(
        chatFlow(IOType.file),
        [FlowRunInput(text: spoofed.path)],
        providers: anthropic,
        assistants: [boundAssistant],
      ),
      throwsA(
        isA<TaskFlowValidationException>()
            .having((e) => e.blockIndex, 'chat block', 0)
            .having((e) => e.inputIndex, 'spoofed input', 0)
            .having((e) => e.message, 'unsupported file', contains('PDF')),
      ),
    );
  });

  test('Anthropic checks detected audio in a generic file input', () async {
    final disguisedAudio = await File('${directory.path}/recording.bin')
        .writeAsBytes([0x49, 0x44, 0x33, 4, 0, 0, 0, 0, 0, 0]);
    expect(
      flowFileType(
        disguisedAudio.path,
        headerBytes: await disguisedAudio.readAsBytes(),
      ),
      IOType.audio,
    );
    await expectLater(
      validateTaskFlow(
        chatFlow(IOType.file),
        [FlowRunInput(text: disguisedAudio.path)],
        providers: anthropic,
        assistants: [boundAssistant],
      ),
      throwsA(
        isA<TaskFlowValidationException>()
            .having((e) => e.blockIndex, 'first chat block', 0)
            .having((e) => e.inputIndex, 'first input', 0)
            .having((e) => e.message, 'unsupported audio', contains('音频')),
      ),
    );
  });

  test('Anthropic reports the input index for declared audio too', () async {
    final audio = await File('${directory.path}/recording.mp3')
        .writeAsBytes([0x49, 0x44, 0x33, 4, 0, 0, 0, 0, 0, 0]);
    await expectLater(
      validateTaskFlow(
        chatFlow(IOType.audio),
        [FlowRunInput(text: audio.path)],
        providers: anthropic,
        assistants: [boundAssistant],
      ),
      throwsA(
        isA<TaskFlowValidationException>()
            .having((e) => e.blockIndex, 'first chat block', 0)
            .having((e) => e.inputIndex, 'first input', 0)
            .having((e) => e.isInputError, 'input error', true),
      ),
    );
  });

  test('unbound assistant follows the current Anthropic endpoint', () async {
    final docx = await File('${directory.path}/notes.docx').writeAsBytes([1]);
    await expectLater(
      validateTaskFlow(
        chatFlow(IOType.file),
        [FlowRunInput(text: docx.path)],
        providers: const ProviderEntriesState(),
        assistants: [unboundAssistant],
        fallbackChatEndpointType: 'anthropic',
      ),
      throwsA(
        isA<TaskFlowValidationException>()
            .having((e) => e.inputIndex, 'first input', 0)
            .having((e) => e.message, 'unsupported file', contains('PDF')),
      ),
    );
  });

  test('first chat block rejects a non-image attachment over 10 MB', () async {
    final audio = File('${directory.path}/long.wav');
    final handle = await audio.open(mode: FileMode.write);
    await handle.writeFrom([0x52, 0x49, 0x46, 0x46]);
    await handle.truncate(maxAttachmentBytes + 1);
    await handle.close();
    await expectLater(
      validateTaskFlow(
        chatFlow(IOType.audio),
        [FlowRunInput(text: audio.path)],
        providers: const ProviderEntriesState(),
        assistants: [unboundAssistant],
      ),
      throwsA(
        isA<TaskFlowValidationException>()
            .having((e) => e.blockIndex, 'first chat block', 0)
            .having((e) => e.inputIndex, 'first input', 0)
            .having((e) => e.message, 'attachment size', contains('10 MB')),
      ),
    );
  });

  test(
    'image inputs keep the chat pipeline image compression allowance',
    () async {
      final image = File('${directory.path}/photo.png');
      final handle = await image.open(mode: FileMode.write);
      await handle.writeFrom([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
      await handle.truncate(maxAttachmentBytes + 1);
      await handle.close();
      await validateTaskFlow(
        chatFlow(IOType.image),
        [FlowRunInput(text: image.path)],
        providers: const ProviderEntriesState(),
        assistants: [unboundAssistant],
      );
    },
  );

  test('generic file input also allows a large detected image', () async {
    final image = File('${directory.path}/generic-image.png');
    final handle = await image.open(mode: FileMode.write);
    await handle.writeFrom([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
    await handle.truncate(maxAttachmentBytes + 1);
    await handle.close();
    await validateTaskFlow(
      chatFlow(IOType.file),
      [FlowRunInput(text: image.path)],
      providers: const ProviderEntriesState(),
      assistants: [unboundAssistant],
    );
  });
}
