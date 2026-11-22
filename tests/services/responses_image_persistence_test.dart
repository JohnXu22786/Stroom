import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/providers/chat_api_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/services/chat_service.dart';
import 'package:stroom/services/chat_stream_manager.dart';
import 'package:stroom/services/attachment_storage.dart';

class _TestPathProvider extends PathProviderPlatform {
  _TestPathProvider(this.root);

  final String root;

  @override
  Future<String> getApplicationDocumentsPath() async => root;

  @override
  Future<String> getTemporaryPath() async => root;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'generated images persist as attachment files and reload without base64 JSON',
      () async {
    final directory = await Directory.systemTemp.createTemp('responses-image-');
    final priorPlatform = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _TestPathProvider(directory.path);
    try {
      final bytes = Uint8List.fromList([137, 80, 78, 71, 1, 2, 3]);
      final fileName = 'generated.png';
      final storagePath = await AttachmentStorage.saveFile(fileName, bytes);
      final attachment = Attachment(
        fileName: fileName,
        mimeType: 'image/png',
        fileType: 'image',
        hash: AttachmentStorage.computeHash(bytes),
        storagePath: storagePath,
        fileSize: bytes.length,
        conversationId: 'conversation-1',
      )..base64Data = 'not-persisted';
      final saved = ChatMessage(
        role: 'assistant',
        content: 'Here is the image',
        attachments: [attachment],
      );

      final serialized = saved.toMap();
      final restored = ChatMessage.fromMap(serialized);

      expect(serialized.toString(), isNot(contains('not-persisted')));
      expect(restored.attachments.single.storagePath, storagePath);
      expect(restored.attachments.single.fileName, fileName);
      expect(await AttachmentStorage.readFile(storagePath), bytes);
    } finally {
      PathProviderPlatform.instance = priorPlatform;
      await directory.delete(recursive: true);
    }
  });

  test(
    'stream manager saves provider image events into assistant history',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'responses-stream-image-',
      );
      final priorPlatform = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _TestPathProvider(directory.path);
      final manager = ChatStreamManager();
      try {
        manager.adapter.forceService(
          ChatService(
            provider: OpenAICompatibleChatProvider(
              baseUrl: 'https://api.example.test/v1/responses',
              apiKey: 'test-key',
              endpointType: 'responses',
              sseStreamOverride: (
                url,
                headers,
                body, {
                cancelToken,
                locale,
                onResponseHeaders,
              }) =>
                  Stream.fromIterable([
                {
                  'type': 'response.output_item.done',
                  'output_index': 0,
                  'item': {
                    'type': 'image_generation_call',
                    'result': 'iVBORwECAw==',
                  },
                },
                {
                  'type': 'response.completed',
                  'response': {
                    'output': [
                      {
                        'type': 'image_generation_call',
                        'result': 'iVBORwECAw==',
                      },
                    ],
                  },
                },
              ].map((event) => 'data: ${jsonEncode(event)}')),
            ),
            modelConfig: ModelConfig(
              name: 'Test model',
              modelId: 'test-model',
              typeConfig: {'context': 4096, 'maxTokens': 1024},
            ),
            endpointType: 'responses',
          ),
        );
        final result = await manager.startStreaming(
          text: 'Draw a cat',
          convId: 'conversation-image',
          history: [],
        );

        final assistant = result.assistantMessage!;
        expect(assistant.attachments, hasLength(1));
        expect(assistant.attachments.single.fileType, 'image');
        expect(
          await AttachmentStorage.readFile(
            assistant.attachments.single.storagePath,
          ),
          Uint8List.fromList([137, 80, 78, 71, 1, 2, 3]),
        );
        expect(assistant.toMap().toString(), isNot(contains('iVBORw')));
        expect(
          ChatMessage.fromMap(assistant.toMap()).attachments.single.storagePath,
          assistant.attachments.single.storagePath,
        );
      } finally {
        manager.dispose();
        PathProviderPlatform.instance = priorPlatform;
        await directory.delete(recursive: true);
      }
    },
  );
}
