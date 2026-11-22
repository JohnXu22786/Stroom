import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/stroom_conversation.dart';
import 'package:stroom/models/stroom_protocol_bridge.dart';
import 'package:stroom/services/conversation_media_storage.dart';

void main() {
  group('externalizeConversationMedia', () {
    test('externalizes Anthropic PDF document blocks before persistence',
        () async {
      final bytes = Uint8List.fromList([37, 80, 68, 70, 45, 49]);
      final encoded = base64Encode(bytes);
      final parsed = AnthropicMessagesBridge().parseMessage(
        {
          'role': 'user',
          'content': [
            {
              'type': 'document',
              'source': {
                'type': 'base64',
                'media_type': 'application/pdf',
                'data': encoded,
              },
            },
          ],
        },
        id: 'anthropic-pdf-persist',
        sequence: 0,
      );
      final saved = <Uint8List>[];

      final stored = await externalizeConversationMedia(
        parsed,
        saveFile: (fileName, payload, {stableId}) async {
          saved.add(payload);
          return 'attachments/$fileName';
        },
      );

      expect(parsed.content.single.type, 'file');
      expect(saved, hasLength(1));
      expect(saved.single, bytes);
      expect(
          stored.content.single.data['reference'], startsWith('attachments/'));
      expect(jsonEncode(stored.toMap()), isNot(contains(encoded)));

      final resolvedParts = await resolveConversationMediaReferences(
        [stored.content.single.toMap()],
        readFile: (path) async => path == 'attachments/file.pdf' ? bytes : null,
      );
      final restoredMessage = StroomMessage(
        id: stored.id,
        role: stored.role,
        sequence: stored.sequence,
        createdAt: stored.createdAt,
        content: [StroomContentPart.fromMap(resolvedParts.single)],
      );
      final serialized = AnthropicMessagesBridge()
          .serializeMessage(restoredMessage)
          .targetPayload!['content'] as List;
      expect(serialized.single['source']['data'], encoded);
    });

    test(
      'stores inline bytes and leaves ordered metadata plus a reference',
      () async {
        final bytes = Uint8List.fromList([1, 2, 3, 4]);
        final encoded = base64Encode(bytes);
        final saved = <Uint8List>[];
        final message = StroomMessage(
          id: 'message-1',
          role: 'user',
          sequence: 0,
          createdAt: DateTime.utc(2026),
          content: [
            StroomContentPart(type: 'text', data: {'text': 'look'}),
            StroomContentPart(
              type: 'image',
              data: {
                'mimeType': 'image/png',
                'imageUrl': 'data:image/png;base64,$encoded',
                'inlineData': {'mimeType': 'image/png', 'data': encoded},
                'source': {
                  'inlineData': {'mimeType': 'image/png', 'data': encoded},
                  'videoMetadata': {'timestamp': '00:00:02'},
                },
                'timestamp': '00:00:02',
              },
            ),
          ],
        );

        final stored = await externalizeConversationMedia(
          message,
          saveFile: (fileName, payload, {stableId}) async {
            expect(fileName, 'image.png');
            expect(stableId, 'message-1_0');
            saved.add(payload);
            return 'attachments/image.png';
          },
        );

        expect(saved, [bytes]);
        expect(stored.content.map((part) => part.type), ['text', 'image']);
        expect(stored.content[1].data['timestamp'], '00:00:02');
        expect(stored.content[1].data['reference'], 'attachments/image.png');
        expect(stored.content[1].data['storagePath'], 'attachments/image.png');
        expect(
          stored.content[1].data['source']['videoMetadata']['timestamp'],
          '00:00:02',
        );
        expect(jsonEncode(stored.toMap()), isNot(contains(encoded)));
        expect(jsonEncode(stored.toMap()), contains('stroomMediaReference'));
      },
    );

    test('leaves external references unchanged', () async {
      final message = StroomMessage(
        id: 'message-2',
        role: 'user',
        sequence: 0,
        createdAt: DateTime.utc(2026),
        content: [
          StroomContentPart(
            type: 'image',
            data: {'reference': 'https://example.test/image.png'},
          ),
        ],
      );
      var wrote = false;

      final stored = await externalizeConversationMedia(
        message,
        saveFile: (fileName, payload, {stableId}) async {
          wrote = true;
          return 'unused';
        },
      );

      expect(wrote, isFalse);
      expect(stored.content.single.data, message.content.single.data);
    });

    test('does not externalize empty inline media payloads', () async {
      final parts = [
        StroomContentPart(
          type: 'image',
          data: {
            'inlineData': {'mimeType': 'image/png', 'data': ''},
          },
        ),
        StroomContentPart.image(reference: 'data:image/png;base64,'),
        StroomContentPart(
          type: 'audio',
          data: {
            'source': {
              'input_audio': {
                'data': '',
                'format': 'wav',
              },
            },
          },
        ),
        StroomContentPart(
          type: 'audio',
          data: {
            'source': {
              'input_audio': {
                'data': 'data:audio/wav;base64,',
                'format': 'wav',
              },
            },
          },
        ),
      ];
      var writes = 0;

      for (final part in parts) {
        final message = StroomMessage(
          id: 'empty-inline-media',
          role: 'user',
          sequence: 0,
          createdAt: DateTime.utc(2026),
          content: [part],
        );
        final stored = await externalizeConversationMedia(
          message,
          saveFile: (fileName, payload, {stableId}) async {
            writes++;
            return 'attachments/$fileName';
          },
        );

        expect(stored.content.single.data.containsKey('storagePath'), isFalse);
        expect(stored.content.single.data['reference'],
            isNot(startsWith('attachments/')));
      }

      expect(writes, 0);
    });

    test('externalizes nested Anthropic and OpenAI file payloads', () async {
      final bytes = Uint8List.fromList([8, 9, 10]);
      final encoded = base64Encode(bytes);
      final message = StroomMessage(
        id: 'message-3',
        role: 'user',
        sequence: 0,
        createdAt: DateTime.utc(2026),
        content: [
          StroomContentPart(
            type: 'image',
            data: {
              'source': {
                'type': 'image',
                'source': {
                  'type': 'base64',
                  'media_type': 'image/png',
                  'data': encoded,
                },
              },
            },
          ),
          StroomContentPart(
            type: 'file',
            data: {
              'source': {
                'type': 'file',
                'file': {
                  'filename': 'report.pdf',
                  'file_data': 'data:application/pdf;base64,$encoded',
                },
              },
            },
          ),
        ],
      );

      final stored = await externalizeConversationMedia(
        message,
        saveFile: (fileName, payload, {stableId}) async =>
            'attachments/$stableId',
      );

      final json = jsonEncode(stored.toMap());
      expect(json, isNot(contains(encoded)));
      expect(json, isNot(contains('data:application/pdf;base64')));
      expect(stored.content[0].data['storagePath'], 'attachments/message-3_0');
      expect(stored.content[1].data['storagePath'], 'attachments/message-3_1');
    });

    test('externalizes data URLs with MIME parameters', () async {
      final bytes = Uint8List.fromList([11, 12, 13]);
      final encoded = base64Encode(bytes);
      final message = StroomMessage(
        id: 'message-parameterized-data-url',
        role: 'user',
        sequence: 0,
        createdAt: DateTime.utc(2026),
        content: [
          StroomContentPart(
            type: 'image',
            data: {
              'reference': 'data:image/svg+xml;charset=utf-8;base64,$encoded',
            },
          ),
        ],
      );

      final stored = await externalizeConversationMedia(
        message,
        saveFile: (fileName, payload, {stableId}) async {
          expect(fileName, 'image.bin');
          expect(payload, bytes);
          return 'attachments/$fileName';
        },
      );

      expect(stored.content.single.data['mimeType'], 'image/svg+xml');
      expect(stored.content.single.data['reference'], 'attachments/image.bin');
      expect(jsonEncode(stored.toMap()), isNot(contains(encoded)));
    });

    test('derives persisted audio MIME type from OpenAI audio format',
        () async {
      final bytes = Uint8List.fromList([11, 12, 13]);
      final message = StroomMessage(
        id: 'message-audio',
        role: 'user',
        sequence: 0,
        createdAt: DateTime.utc(2026),
        content: [
          StroomContentPart(
            type: 'audio',
            data: {
              'source': {
                'input_audio': {
                  'data': base64Encode(bytes),
                  'format': 'wav',
                },
              },
            },
          ),
        ],
      );

      final stored = await externalizeConversationMedia(
        message,
        saveFile: (fileName, payload, {stableId}) async {
          expect(fileName, 'audio.wav');
          expect(payload, bytes);
          return 'attachments/$fileName';
        },
      );

      expect(stored.content.single.data['mimeType'], 'audio/wav');
    });
  });

  test(
    'resolves local media references to provider payloads asynchronously',
    () async {
      final bytes = Uint8List.fromList([5, 6, 7]);
      final messages = [
        {
          'role': 'user',
          'content': [
            {
              'type': 'image_url',
              'image_url': {'url': 'attachments/photo.png'},
            },
            {
              'type': 'input_audio',
              'input_audio': {'data': 'attachments/voice.mp3', 'format': 'mp3'},
            },
            {
              'fileData': {
                'fileUri': 'attachments/clip.mp4',
                'mimeType': 'video/mp4',
              },
            },
            {
              'type': 'input_file',
              'file_url': 'attachments/report.pdf',
              'mime_type': 'application/pdf',
            },
            {
              'type': 'input_file',
              'file_uri': 'attachments/scan.pdf',
              'mime_type': 'application/pdf',
            },
          ],
        },
      ];

      final resolved = await resolveConversationMediaReferences(
        messages,
        readFile: (path) async => switch (path) {
          'attachments/photo.png' => bytes,
          'attachments/voice.mp3' => bytes,
          'attachments/clip.mp4' => bytes,
          'attachments/report.pdf' => bytes,
          'attachments/scan.pdf' => bytes,
          _ => null,
        },
      );

      final content = resolved.single['content'] as List;
      expect(
        (content[0]['image_url'] as Map)['url'],
        'data:image/png;base64,${base64Encode(bytes)}',
      );
      expect((content[1]['input_audio'] as Map)['data'], base64Encode(bytes));
      expect(content[2].containsKey('fileData'), isFalse);
      expect(content[2]['inlineData']['mimeType'], 'video/mp4');
      expect(content[2]['inlineData']['data'], base64Encode(bytes));
      expect(
        content[3]['file_url'],
        'data:application/pdf;base64,${base64Encode(bytes)}',
      );
      expect(
        content[4]['file_uri'],
        'data:application/pdf;base64,${base64Encode(bytes)}',
      );
    },
  );

  test('sanitizes captured diagnostics for provider media payloads', () {
    final encoded = base64Encode(Uint8List.fromList([1, 2, 3]));
    final sanitized = sanitizeConversationMediaJson({
      'body': {
        'content': [
          {
            'type': 'image',
            'source': {
              'type': 'base64',
              'media_type': 'image/png',
              'data': encoded,
            },
          },
          {
            'type': 'image_generation_call',
            'result': encoded,
          },
          {
            'inlineData': {'mimeType': 'audio/wav', 'data': encoded},
          },
        ],
      },
    });

    expect(jsonEncode(sanitized), isNot(contains(encoded)));
    expect(jsonEncode(sanitized), contains('stroomMediaReference'));
  });

  test('sanitizes generated image bytes inside images arrays', () {
    final encoded = base64Encode(Uint8List.fromList([8, 9, 10]));
    final dataUrl = 'data:image/png;base64,$encoded';
    final sanitized = sanitizeConversationMediaJson({
      'images': [encoded, dataUrl, 'https://example.test/reference.png'],
    });

    expect(jsonEncode(sanitized), isNot(contains(encoded)));
    expect(sanitized['images'], [
      {'stroomMediaReference': true},
      {'stroomMediaReference': true},
      'https://example.test/reference.png',
    ]);
  });

  test('externalization sanitizes list-valued source extensions', () async {
    final encoded = base64Encode(Uint8List.fromList([21, 22, 23]));
    final message = StroomMessage(
      id: 'message-list-extension',
      role: 'assistant',
      sequence: 0,
      createdAt: DateTime.utc(2026),
      content: [
        StroomContentPart(
          type: 'image',
          data: {
            'inlineData': {'mimeType': 'image/png', 'data': encoded},
          },
        ),
      ],
      extensions: {
        'provider.responses': [
          {'type': 'image_generation_call', 'result': encoded},
        ],
      },
    );

    final stored = await externalizeConversationMedia(
      message,
      saveFile: (fileName, payload, {stableId}) async =>
          'attachments/$fileName',
    );

    final json = jsonEncode(stored.toMap());
    expect(json, isNot(contains(encoded)));
    expect(json, contains('stroomMediaReference'));
  });

  test('externalization sanitizes source payloads on text-only messages',
      () async {
    final encoded = base64Encode(Uint8List.fromList([18, 19, 20]));
    final partialImageEvent = {
      'type': 'response.image_generation_call.partial_image',
      'partial_image_b64': encoded,
    };
    final message = StroomMessage(
      id: 'text-with-media-diagnostics',
      role: 'assistant',
      sequence: 0,
      createdAt: DateTime.utc(2026),
      content: [
        StroomContentPart(
          type: 'text',
          data: {'text': 'Partial result'},
          extraFields: {'providerEvent': partialImageEvent},
        ),
      ],
      extensions: {'provider.responses': partialImageEvent},
      extraFields: {'futureResponse': partialImageEvent},
      diagnostics: StroomMessageDiagnostics.fromMap({
        'rawResponse': partialImageEvent,
      }),
    );

    final stored = await externalizeConversationMedia(
      message,
      saveFile: (fileName, payload, {stableId}) async =>
          'attachments/$fileName',
    );

    final json = jsonEncode(stored.toMap());
    expect(json, isNot(contains(encoded)));
    expect(json, contains('stroomMediaReference'));
    expect(stored.content.single.extraFields['providerEvent'],
        containsPair('stroomMediaReference', true));
  });

  test('sanitizes Responses audio delta bytes in captured diagnostics', () {
    final encoded = base64Encode(Uint8List.fromList([14, 15, 16]));
    final sanitized = sanitizeConversationMediaJson({
      'type': 'response.output_audio.delta',
      'delta': encoded,
    });

    expect(jsonEncode(sanitized), isNot(contains(encoded)));
    expect(sanitized['stroomMediaReference'], isTrue);
  });

  test('sanitizes Responses partial image bytes in captured diagnostics', () {
    final encoded = base64Encode(Uint8List.fromList([31, 32, 33]));
    final sanitized = sanitizeConversationMediaJson({
      'type': 'response.image_generation_call.partial_image',
      'item_id': 'image-call-1',
      'partial_image_index': 0,
      'partial_image_b64': encoded,
    });

    expect(jsonEncode(sanitized), isNot(contains(encoded)));
    expect(sanitized['partial_image_b64'], isNull);
    expect(sanitized['stroomMediaReference'], isTrue);
  });

  test('sanitizes formatless Chat Completions audio deltas', () {
    final encoded = base64Encode(Uint8List.fromList([34, 35, 36]));
    final sanitized = sanitizeConversationMediaJson({
      'choices': [
        {
          'delta': {
            'audio': {'data': encoded},
          },
        },
      ],
    });

    expect(jsonEncode(sanitized), isNot(contains(encoded)));
    final choices = sanitized['choices'] as List;
    final delta = (choices.single as Map)['delta'] as Map;
    final audio = delta['audio'] as Map;
    expect(audio['stroomMediaReference'], isTrue);
  });
}
