import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/ai_gateway/ai_gateway_protocol_bridges.dart';
import 'package:stroom/models/stroom_conversation.dart';
import 'package:stroom/services/chat_protocol.dart';

void main() {
  group('AI Gateway protocol bridges', () {
    test('OpenAI mixed media parts keep canonical types and order', () {
      final source = <String, dynamic>{
        'role': 'user',
        'content': [
          {'type': 'text', 'text': 'Listen and inspect.'},
          {
            'type': 'input_audio',
            'input_audio': {'data': 'AQID', 'format': 'wav'},
          },
          {
            'type': 'video_url',
            'video_url': {
              'url': 'data:video/mp4;base64,BAUG',
              'timestamp': '00:00:01.250',
            },
          },
          {
            'type': 'file',
            'file': {
              'filename': 'notes.txt',
              'file_data': 'data:text/plain;base64,bm90ZXM=',
            },
          },
          {
            'type': 'transcription',
            'text': 'Hello there.',
            'segments': [
              {'start': 0.0, 'end': 0.5, 'text': 'Hello'},
              {'start': 0.6, 'end': 1.0, 'text': 'there.'},
            ],
          },
        ],
      };

      final bridge = AiGatewayProtocolBridges.openAiChatCompletions;
      final neutral = bridge.toStroom(source);

      expect(neutral.content.map((part) => part.type), [
        'text',
        'audio',
        'video',
        'file',
        'transcription',
      ]);
      expect(neutral.content[2].data['timestamp'], '00:00:01.250');
      expect(neutral.content.map((part) => part.data['source']), [
        source['content'][0],
        source['content'][1],
        source['content'][2],
        source['content'][3],
        source['content'][4],
      ]);
      expect(bridge.fromStroom(neutral), source);
      expect(
        () => AiGatewayProtocolBridges.buildRequest(
          'google.gemini.generate_content',
          AiGatewayProtocolRequest(modelId: 'gemini', messages: [neutral]),
        ),
        throwsUnsupportedError,
      );
    });

    test('OpenAI input_file references serialize as Anthropic documents', () {
      final source = AiGatewayProtocolBridges.openAiResponses.toStroom({
        'type': 'message',
        'role': 'user',
        'content': [
          {
            'type': 'input_file',
            'filename': 'report.pdf',
            'file_url': 'https://files.example/report.pdf',
          },
        ],
      });

      final request = AiGatewayProtocolBridges.buildRequest(
        'anthropic.messages',
        AiGatewayProtocolRequest(modelId: 'claude', messages: [source]),
      );

      expect(request?.body['messages'], [
        {
          'role': 'user',
          'content': [
            {
              'type': 'document',
              'source': {
                'type': 'url',
                'url': 'https://files.example/report.pdf',
              },
              'title': 'report.pdf',
            },
          ],
        },
      ]);
    });

    test('Gemini preserves Anthropic PDF documents', () {
      final anthropic = AiGatewayProtocolBridges.anthropicMessages;
      final fromBase64 = anthropic.toStroom({
        'role': 'user',
        'content': [
          {
            'type': 'document',
            'title': 'report.pdf',
            'source': {
              'type': 'base64',
              'media_type': 'application/pdf',
              'data': 'cGRm',
            },
          },
        ],
      });
      final fromUrl = anthropic.toStroom({
        'role': 'user',
        'content': [
          {
            'type': 'document',
            'source': {
              'type': 'url',
              'url': 'https://files.example/report.pdf',
            },
          },
        ],
      });

      final inlineRequest = AiGatewayProtocolBridges.buildRequest(
        'google.gemini.generate_content',
        AiGatewayProtocolRequest(modelId: 'gemini', messages: [fromBase64]),
      );
      final urlRequest = AiGatewayProtocolBridges.buildRequest(
        'google.gemini.generate_content',
        AiGatewayProtocolRequest(modelId: 'gemini', messages: [fromUrl]),
      );

      expect(inlineRequest?.body['contents'], [
        {
          'role': 'user',
          'parts': [
            {
              'inlineData': {'mimeType': 'application/pdf', 'data': 'cGRm'},
            },
          ],
        },
      ]);
      expect(urlRequest?.body['contents'], [
        {
          'role': 'user',
          'parts': [
            {
              'fileData': {
                'fileUri': 'https://files.example/report.pdf',
                'mimeType': 'application/pdf',
              },
            },
          ],
        },
      ]);
    });

    test('Anthropic rejects non-PDF input_file documents clearly', () {
      final source = AiGatewayProtocolBridges.openAiResponses.toStroom({
        'type': 'message',
        'role': 'user',
        'content': [
          {
            'type': 'input_file',
            'filename': 'notes.txt',
            'file_data': 'data:text/plain;base64,bm90ZXM=',
          },
        ],
      });

      expect(
        () => AiGatewayProtocolBridges.buildRequest(
          'anthropic.messages',
          AiGatewayProtocolRequest(modelId: 'claude', messages: [source]),
        ),
        throwsUnsupportedError,
      );
    });

    test('Anthropic rejects invalid retained document source maps', () {
      for (final source in [
        {
          'type': 'base64',
          'media_type': 'text/plain',
          'data': 'bm90ZXM=',
        },
        {
          'type': 'base64',
          'media_type': 'application/pdf',
          'data': '',
        },
        {
          'type': 'base64',
          'media_type': 'application/pdf',
          'data': '%%%invalid-base64%%%',
        },
        {
          'type': 'url',
          'url': 'http://files.example/report.pdf',
        },
      ]) {
        final message = StroomMessage(
          id: 'invalid-retained-document',
          role: 'user',
          sequence: 0,
          createdAt: DateTime.utc(2026),
          content: [
            StroomContentPart(
              type: 'file',
              data: {
                'source': {'type': 'document', 'source': source},
              },
            ),
          ],
        );

        expect(
          () => AiGatewayProtocolBridges.buildRequest(
            'anthropic.messages',
            AiGatewayProtocolRequest(modelId: 'claude', messages: [message]),
          ),
          throwsUnsupportedError,
        );
      }
    });

    test('Anthropic rejects malformed PDF data URL payloads', () {
      final message = StroomMessage(
        id: 'invalid-pdf-data-url',
        role: 'user',
        sequence: 0,
        createdAt: DateTime.utc(2026),
        content: [
          StroomContentPart.file(
            reference: 'data:application/pdf;base64,%%%invalid-base64%%%',
            fileName: 'report.pdf',
            mimeType: 'application/pdf',
          ),
        ],
      );

      expect(
        () => AiGatewayProtocolBridges.buildRequest(
          'anthropic.messages',
          AiGatewayProtocolRequest(modelId: 'claude', messages: [message]),
        ),
        throwsUnsupportedError,
      );
    });

    test('Anthropic and Gemini reuse externalized PDF references', () {
      final message = StroomMessage(
        id: 'externalized-pdf-reference',
        role: 'user',
        sequence: 0,
        createdAt: DateTime.utc(2026),
        content: [
          StroomContentPart(
            type: 'file',
            data: {
              'source': {
                'type': 'document',
                'source': {
                  'type': 'base64',
                  'media_type': 'application/pdf',
                  'data': {'stroomMediaReference': true},
                },
              },
              'reference': 'data:application/pdf;base64,cGRm',
              'mimeType': 'application/pdf',
              'fileName': 'report.pdf',
            },
          ),
        ],
      );

      final anthropic = AiGatewayProtocolBridges.buildRequest(
        'anthropic.messages',
        AiGatewayProtocolRequest(modelId: 'claude', messages: [message]),
      );
      final gemini = AiGatewayProtocolBridges.buildRequest(
        'google.gemini.generate_content',
        AiGatewayProtocolRequest(modelId: 'gemini', messages: [message]),
      );

      expect(anthropic?.body['messages'], [
        {
          'role': 'user',
          'content': [
            {
              'type': 'document',
              'source': {
                'type': 'base64',
                'media_type': 'application/pdf',
                'data': 'cGRm',
              },
              'title': 'report.pdf',
            },
          ],
        },
      ]);
      expect(gemini?.body['contents'], [
        {
          'role': 'user',
          'parts': [
            {
              'inlineData': {'mimeType': 'application/pdf', 'data': 'cGRm'},
            },
          ],
        },
      ]);
    });

    test('Gemini ignores externalized inline-data markers', () {
      final message = StroomMessage(
        id: 'externalized-image-reference',
        role: 'user',
        sequence: 0,
        createdAt: DateTime.utc(2026),
        content: [
          StroomContentPart(
            type: 'image',
            data: {
              'inlineData': {
                'mimeType': 'image/png',
                'data': {'stroomMediaReference': true},
              },
              'source': {
                'inlineData': {
                  'mimeType': 'image/png',
                  'data': {'stroomMediaReference': true},
                },
              },
              'reference': 'data:image/png;base64,AQID',
              'mimeType': 'image/png',
            },
          ),
        ],
      );

      final result = AiGatewayProtocolBridges.buildRequest(
        'google.gemini.generate_content',
        AiGatewayProtocolRequest(modelId: 'gemini', messages: [message]),
      );

      expect(
        result?.body['contents'][0]['parts'][0]['inlineData'],
        {'mimeType': 'image/png', 'data': 'AQID'},
      );
    });

    test('Gemini infers MIME for OpenAI image URL source extensions', () {
      final message = AiGatewayProtocolBridges.openAiChatCompletions.toStroom({
        'role': 'user',
        'content': [
          {
            'type': 'image_url',
            'image_url': {'url': 'https://cdn.example/photo.png'},
          },
        ],
      });

      final request = AiGatewayProtocolBridges.buildRequest(
        'google.gemini.generate_content',
        AiGatewayProtocolRequest(modelId: 'gemini-flash', messages: [message]),
      );

      expect(request?.body['contents'], [
        {
          'role': 'user',
          'parts': [
            {
              'fileData': {
                'fileUri': 'https://cdn.example/photo.png',
                'mimeType': 'image/png',
              },
            },
          ],
        },
      ]);
    });

    test(
      'Gemini serializes ordered media references with their MIME types',
      () {
        final message = StroomMessage(
          id: 'mixed-media',
          role: 'user',
          sequence: 0,
          createdAt: DateTime.utc(2026),
          content: [
            StroomContentPart.text('Summarize these.'),
            StroomContentPart.image(
              reference: 'https://media.example/image.png',
              mimeType: 'image/png',
            ),
            StroomContentPart.audio(
              reference: 'https://media.example/audio.wav',
              mimeType: 'audio/wav',
            ),
            StroomContentPart.video(
              reference: 'https://media.example/clip.mp4',
              mimeType: 'video/mp4',
            ),
            StroomContentPart.file(
              reference: 'https://media.example/notes.pdf',
              fileName: 'notes.pdf',
              mimeType: 'application/pdf',
            ),
            StroomContentPart.transcription(text: 'Hello there.'),
          ],
        );

        final request = AiGatewayProtocolBridges.buildRequest(
          'google.gemini.generate_content',
          AiGatewayProtocolRequest(
            modelId: 'gemini-flash',
            messages: [message],
          ),
        );

        expect(request?.body['contents'], [
          {
            'role': 'user',
            'parts': [
              {'text': 'Summarize these.'},
              {
                'fileData': {
                  'fileUri': 'https://media.example/image.png',
                  'mimeType': 'image/png',
                },
              },
              {
                'fileData': {
                  'fileUri': 'https://media.example/audio.wav',
                  'mimeType': 'audio/wav',
                },
              },
              {
                'fileData': {
                  'fileUri': 'https://media.example/clip.mp4',
                  'mimeType': 'video/mp4',
                },
              },
              {
                'fileData': {
                  'fileUri': 'https://media.example/notes.pdf',
                  'mimeType': 'application/pdf',
                },
              },
              {'text': 'Hello there.'},
            ],
          },
        ]);

        final timestampedTranscript = StroomMessage(
          id: 'timestamped-transcript',
          role: 'user',
          sequence: 1,
          createdAt: DateTime.utc(2026),
          content: [
            StroomContentPart.transcription(
              text: 'Hello.',
              segments: [
                {'start': 0.0, 'end': 0.5, 'text': 'Hello.'},
              ],
            ),
          ],
        );
        expect(
          () => AiGatewayProtocolBridges.buildRequest(
            'google.gemini.generate_content',
            AiGatewayProtocolRequest(
              modelId: 'gemini-flash',
              messages: [timestampedTranscript],
            ),
          ),
          throwsUnsupportedError,
        );
      },
    );

    test(
        'Gemini converts OpenAI image data URL source extensions to inline data',
        () {
      final message = StroomMessage(
        id: 'openai-image-data-url',
        role: 'user',
        sequence: 0,
        createdAt: DateTime.utc(2026),
        content: [
          StroomContentPart(
            type: 'image',
            data: {
              'source': {
                'type': 'image_url',
                'image_url': {'url': 'data:image/png;base64,aGVsbG8='},
              },
            },
          ),
        ],
      );

      final request = AiGatewayProtocolBridges.buildRequest(
        'google.gemini.generate_content',
        AiGatewayProtocolRequest(modelId: 'gemini-flash', messages: [message]),
      );

      expect(request?.body['contents'], [
        {
          'role': 'user',
          'parts': [
            {
              'inlineData': {'mimeType': 'image/png', 'data': 'aGVsbG8='},
            },
          ],
        },
      ]);
    });

    test('Gemini rejects malformed base64 data URL references', () {
      final message = StroomMessage(
        id: 'openai-image-invalid-data-url',
        role: 'user',
        sequence: 0,
        createdAt: DateTime.utc(2026),
        content: [
          StroomContentPart(
            type: 'image',
            data: {
              'source': {
                'type': 'image_url',
                'image_url': {'url': 'data:image/png;base64,%%%invalid%%%'},
              },
            },
          ),
        ],
      );

      expect(
        () => AiGatewayProtocolBridges.buildRequest(
          'google.gemini.generate_content',
          AiGatewayProtocolRequest(
              modelId: 'gemini-flash', messages: [message]),
        ),
        throwsUnsupportedError,
      );
    });

    test('Gemini rejects data URL MIME mismatches for media parts', () {
      final message = StroomMessage(
        id: 'openai-image-pdf-data-url',
        role: 'user',
        sequence: 0,
        createdAt: DateTime.utc(2026),
        content: [
          StroomContentPart.image(
            reference: 'data:application/pdf;base64,cGRm',
            mimeType: 'image/png',
          ),
        ],
      );

      expect(
        () => AiGatewayProtocolBridges.buildRequest(
          'google.gemini.generate_content',
          AiGatewayProtocolRequest(modelId: 'gemini', messages: [message]),
        ),
        throwsUnsupportedError,
      );
    });

    test('Gemini preserves parameterized base64 image data URLs', () {
      final message = StroomMessage(
        id: 'parameterized-image-data-url',
        role: 'user',
        sequence: 0,
        createdAt: DateTime.utc(2026),
        content: [
          StroomContentPart.image(
            reference: 'data:image/png;charset=utf-8;base64,aGVsbG8=',
          ),
        ],
      );

      final request = AiGatewayProtocolBridges.buildRequest(
        'google.gemini.generate_content',
        AiGatewayProtocolRequest(modelId: 'gemini-flash', messages: [message]),
      );

      expect(request?.body['contents'], [
        {
          'role': 'user',
          'parts': [
            {
              'inlineData': {'mimeType': 'image/png', 'data': 'aGVsbG8='},
            },
          ],
        },
      ]);
    });

    test('Gemini response media parts use canonical modality types', () {
      final source = <String, dynamic>{
        'candidates': [
          {
            'content': {
              'role': 'model',
              'parts': [
                {'text': 'Here are the media.'},
                {
                  'inlineData': {'mimeType': 'image/png', 'data': 'AQ=='},
                },
                {
                  'inlineData': {'mimeType': 'audio/wav', 'data': 'Ag=='},
                },
                {
                  'fileData': {
                    'mimeType': 'video/mp4',
                    'fileUri': 'gs://bucket/clip.mp4',
                  },
                  'videoMetadata': {'startOffset': '1s'},
                },
                {
                  'fileData': {
                    'mimeType': 'application/pdf',
                    'fileUri': 'gs://bucket/report.pdf',
                  },
                },
              ],
            },
          },
        ],
      };
      final bridge = AiGatewayProtocolBridges.geminiGenerateContent;
      final neutral = bridge.toStroom(source);

      expect(neutral.content.map((part) => part.type), [
        'text',
        'image',
        'audio',
        'video',
        'file',
      ]);
      expect(neutral.content[3].data['videoMetadata'], {'startOffset': '1s'});
      expect(bridge.fromStroom(neutral), source);
    });

    test('rejects content parts with no target protocol representation', () {
      final unsupported = StroomMessage(
        id: 'unsupported-content',
        role: 'user',
        sequence: 0,
        createdAt: DateTime.utc(2026),
        content: [
          StroomContentPart(
            type: 'provider_custom_payload',
            data: {'value': 1},
          ),
        ],
      );

      for (final protocolId in [
        'openai.chat_completions',
        'openai.responses',
        'anthropic.messages',
        'google.gemini.generate_content',
        'google.gemini.interactions',
        'ollama.chat',
      ]) {
        expect(
          () => AiGatewayProtocolBridges.buildRequest(
            protocolId,
            AiGatewayProtocolRequest(modelId: 'model', messages: [unsupported]),
          ),
          throwsUnsupportedError,
          reason: protocolId,
        );
      }
    });

    test(
      'Chat Completions retains tool, reasoning, and unknown source fields',
      () {
        final source = <String, dynamic>{
          'role': 'assistant',
          'content': 'Let me check.',
          'reasoning_content': 'Need inspect the provided records.',
          'tool_calls': [
            {
              'id': 'call_1',
              'type': 'function',
              'function': {
                'name': 'lookup',
                'arguments': '{"q":"weather"}',
                'vendor_extension': 7,
              },
            },
          ],
          'refusal': null,
          'vendor_trace': {'region': 'west'},
        };

        final bridge = AiGatewayProtocolBridges.openAiChatCompletions;
        final neutral = bridge.toStroom(source);
        final roundTrip = bridge.fromStroom(neutral);

        expect(neutral.content.map((part) => part.type), [
          'text',
          'reasoning',
          'tool_call',
        ]);
        expect(neutral.extensions['openai.chat_completions']['vendor_trace'], {
          'region': 'west',
        });
        expect(roundTrip, source);

        final edited = StroomMessage(
          id: neutral.id,
          role: neutral.role,
          sequence: neutral.sequence,
          createdAt: neutral.createdAt,
          content: [StroomContentPart.text('Updated.')],
          extensions: neutral.extensions,
        );
        expect(bridge.fromStroom(edited), {...source, 'content': 'Updated.'});
      },
    );

    test('Responses function items retain IDs and unrecognized fields', () {
      final source = <String, dynamic>{
        'type': 'function_call',
        'id': 'fc_1',
        'call_id': 'call_1',
        'name': 'lookup',
        'arguments': '{"q":"weather"}',
        'status': 'completed',
        'custom_item': {'opaque': true},
      };

      final bridge = AiGatewayProtocolBridges.openAiResponses;
      final neutral = bridge.toStroom(source);

      expect(neutral.content.single.type, 'tool_call');
      expect(neutral.content.single.data['id'], 'call_1');
      expect(neutral.extensions['openai.responses']['id'], 'fc_1');
      expect(bridge.fromStroom(neutral), source);

      final message = bridge.toStroom({
        'type': 'message',
        'id': 'msg_1',
        'role': 'assistant',
        'content': [
          {'type': 'output_text', 'text': 'Visible answer', 'annotations': []},
        ],
      });
      expect(message.content.single.type, 'text');
      expect(message.content.single.data['text'], 'Visible answer');
    });

    test('Responses serializes images parsed from Chat Completions', () {
      final chatMessage =
          AiGatewayProtocolBridges.openAiChatCompletions.toStroom({
        'role': 'user',
        'content': [
          {'type': 'text', 'text': 'Describe this.'},
          {
            'type': 'image_url',
            'image_url': {
              'url': 'https://media.example/photo.png',
              'detail': 'high',
            },
          },
        ],
      });

      final request = AiGatewayProtocolBridges.buildRequest(
        'openai.responses',
        AiGatewayProtocolRequest(modelId: 'gpt-6', messages: [chatMessage]),
      );

      expect(request?.body['input'], [
        {
          'type': 'message',
          'role': 'user',
          'content': [
            {'type': 'input_text', 'text': 'Describe this.'},
            {
              'type': 'input_image',
              'image_url': 'https://media.example/photo.png',
              'detail': 'high',
            },
          ],
        },
      ]);
    });

    test('edited Responses function items retain unknown fields', () {
      final bridge = AiGatewayProtocolBridges.openAiResponses;
      final originalCall = bridge.toStroom({
        'type': 'function_call',
        'call_id': 'call-1',
        'name': 'lookup',
        'arguments': '{"q":"old"}',
        'custom_call_field': 'preserve-call',
      });
      final editedCall = StroomMessage(
        id: originalCall.id,
        role: originalCall.role,
        sequence: originalCall.sequence,
        createdAt: originalCall.createdAt,
        content: [
          StroomContentPart.toolCall(
            id: 'call-1',
            name: 'lookup',
            arguments: {'q': 'new'},
            extraFields: originalCall.content.single.extraFields,
          ),
        ],
        extensions: originalCall.extensions,
      );
      final originalResult = bridge.toStroom({
        'type': 'function_call_output',
        'call_id': 'call-1',
        'output': 'old result',
        'custom_result_field': 'preserve-result',
      });
      final editedResult = StroomMessage(
        id: originalResult.id,
        role: originalResult.role,
        sequence: originalResult.sequence,
        createdAt: originalResult.createdAt,
        content: [
          StroomContentPart.toolResult(
            toolCallId: 'call-1',
            result: 'new result',
            extraFields: originalResult.content.single.extraFields,
          ),
        ],
        extensions: originalResult.extensions,
      );

      final request = AiGatewayProtocolBridges.buildRequest(
        'openai.responses',
        AiGatewayProtocolRequest(
          modelId: 'gpt-6',
          messages: [editedCall, editedResult],
        ),
      );
      expect(request?.body['input'], [
        {
          'type': 'function_call',
          'call_id': 'call-1',
          'name': 'lookup',
          'arguments': '{"q":"new"}',
          'custom_call_field': 'preserve-call',
        },
        {
          'type': 'function_call_output',
          'call_id': 'call-1',
          'output': 'new result',
          'custom_result_field': 'preserve-result',
        },
      ]);
    });

    test('Responses expands edited messages with all tool calls and media', () {
      final bridge = AiGatewayProtocolBridges.openAiResponses;
      final original = bridge.toStroom({
        'type': 'message',
        'id': 'message-1',
        'role': 'assistant',
        'content': [
          {'type': 'output_text', 'text': 'Starting.'},
        ],
      });
      final edited = StroomMessage(
        id: original.id,
        role: original.role,
        sequence: original.sequence,
        createdAt: original.createdAt,
        content: [
          StroomContentPart.text('Starting.'),
          StroomContentPart.image(
            reference: 'data:image/png;base64,aGVsbG8=',
            mimeType: 'image/png',
          ),
          StroomContentPart.toolCall(
            id: 'call-1',
            name: 'first',
            arguments: {'x': 1},
          ),
          StroomContentPart.toolCall(
            id: 'call-2',
            name: 'second',
            arguments: {'y': 2},
          ),
        ],
        extensions: original.extensions,
      );

      final request = AiGatewayProtocolBridges.buildRequest(
        'openai.responses',
        AiGatewayProtocolRequest(modelId: 'gpt-6', messages: [edited]),
      );
      expect(request?.body['input'], [
        {
          'type': 'message',
          'role': 'assistant',
          'content': [
            {'type': 'output_text', 'text': 'Starting.'},
            {
              'type': 'output_image',
              'image_url': 'data:image/png;base64,aGVsbG8=',
            },
          ],
        },
        {
          'type': 'function_call',
          'call_id': 'call-1',
          'name': 'first',
          'arguments': '{"x":1}',
        },
        {
          'type': 'function_call',
          'call_id': 'call-2',
          'name': 'second',
          'arguments': '{"y":2}',
        },
      ]);
      expect(() => bridge.fromStroom(edited), throwsUnsupportedError);
    });

    test(
      'OpenAI bridges preserve image inputs in their native content shape',
      () {
        final source = {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': 'What is this?'},
            {
              'type': 'image_url',
              'image_url': {
                'url': 'data:image/png;base64,aGVsbG8=',
                'detail': 'high',
              },
            },
            {'type': 'text', 'text': 'And this?'},
          ],
        };
        final chat = AiGatewayProtocolBridges.openAiChatCompletions;
        final neutral = chat.toStroom(source);
        expect(neutral.content.map((part) => part.type), [
          'text',
          'image',
          'text',
        ]);
        expect(chat.fromStroom(neutral), source);

        final responses = AiGatewayProtocolBridges.buildRequest(
          'openai.responses',
          AiGatewayProtocolRequest(modelId: 'gpt-6', messages: [neutral]),
        );
        expect(responses?.body['input'], [
          {
            'type': 'message',
            'role': 'user',
            'content': [
              {'type': 'input_text', 'text': 'What is this?'},
              {
                'type': 'input_image',
                'image_url': 'data:image/png;base64,aGVsbG8=',
                'detail': 'high',
              },
              {'type': 'input_text', 'text': 'And this?'},
            ],
          },
        ]);

        final chatRequest = AiGatewayProtocolBridges.buildRequest(
          'openai.chat_completions',
          AiGatewayProtocolRequest(modelId: 'gpt-4.1', messages: [neutral]),
        );
        expect(chatRequest?.body['messages'], [
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': 'What is this?'},
              {
                'type': 'image_url',
                'image_url': {
                  'url': 'data:image/png;base64,aGVsbG8=',
                  'detail': 'high',
                },
              },
              {'type': 'text', 'text': 'And this?'},
            ],
          },
        ]);
      },
    );

    test('Chat Completions represents tool results with their call IDs', () {
      final request = AiGatewayProtocolBridges.buildRequest(
        'openai.chat_completions',
        AiGatewayProtocolRequest(
          modelId: 'gpt-4.1',
          messages: [
            StroomMessage(
              id: 'assistant-1',
              role: 'assistant',
              sequence: 0,
              createdAt: DateTime.utc(2026),
              content: [
                StroomContentPart.toolCall(
                  id: 'call-1',
                  name: 'lookup',
                  arguments: {'city': 'Paris'},
                ),
              ],
            ),
            StroomMessage(
              id: 'tool-1',
              role: 'tool',
              sequence: 1,
              createdAt: DateTime.utc(2026),
              content: [
                StroomContentPart.toolResult(
                  toolCallId: 'call-1',
                  result: {'temperature': 18},
                ),
              ],
            ),
          ],
        ),
      );
      expect(request?.body['messages'], [
        {
          'role': 'assistant',
          'content': '',
          'tool_calls': [
            {
              'id': 'call-1',
              'type': 'function',
              'function': {'name': 'lookup', 'arguments': '{"city":"Paris"}'},
            },
          ],
        },
        {
          'role': 'tool',
          'tool_call_id': 'call-1',
          'content': '{"temperature":18}',
        },
      ]);
    });

    test('OpenAI tool history converts to each target protocol shape', () {
      final source = AiGatewayProtocolBridges.openAiChatCompletions;
      final messages = [
        source.toStroom({
          'role': 'assistant',
          'content': null,
          'tool_calls': [
            {
              'id': 'call-1',
              'type': 'function',
              'function': {'name': 'lookup', 'arguments': '{"city":"Paris"}'},
            },
          ],
        }),
        source.toStroom({
          'role': 'tool',
          'tool_call_id': 'call-1',
          'content': '{"temperature":18}',
        }),
      ];

      final anthropic = AiGatewayProtocolBridges.buildRequest(
        'anthropic.messages',
        AiGatewayProtocolRequest(modelId: 'claude', messages: messages),
      );
      expect(anthropic?.body['messages'], [
        {
          'role': 'assistant',
          'content': [
            {
              'type': 'tool_use',
              'id': 'call-1',
              'name': 'lookup',
              'input': {'city': 'Paris'},
            },
          ],
        },
        {
          'role': 'user',
          'content': [
            {
              'type': 'tool_result',
              'tool_use_id': 'call-1',
              'content': '{"temperature":18}',
            },
          ],
        },
      ]);

      final responses = AiGatewayProtocolBridges.buildRequest(
        'openai.responses',
        AiGatewayProtocolRequest(modelId: 'gpt-4.1', messages: messages),
      );
      expect(responses?.body['input'], [
        {
          'type': 'function_call',
          'call_id': 'call-1',
          'name': 'lookup',
          'arguments': '{"city":"Paris"}',
        },
        {
          'type': 'function_call_output',
          'call_id': 'call-1',
          'output': '{"temperature":18}',
        },
      ]);

      final gemini = AiGatewayProtocolBridges.buildRequest(
        'google.gemini.generate_content',
        AiGatewayProtocolRequest(modelId: 'gemini', messages: messages),
      );
      final interactions = AiGatewayProtocolBridges.buildRequest(
        'google.gemini.interactions',
        AiGatewayProtocolRequest(modelId: 'gemini', messages: messages),
      );
      expect(gemini?.body['contents'], [
        {
          'role': 'model',
          'parts': [
            {
              'functionCall': {
                'id': 'call-1',
                'name': 'lookup',
                'args': {'city': 'Paris'},
              },
            },
          ],
        },
        {
          'role': 'user',
          'parts': [
            {
              'functionResponse': {
                'id': 'call-1',
                'name': 'lookup',
                'response': '{"temperature":18}',
              },
            },
          ],
        },
      ]);
      expect(interactions?.body['input'], [
        {
          'type': 'function_call',
          'id': 'call-1',
          'name': 'lookup',
          'arguments': {'city': 'Paris'},
        },
        {
          'type': 'function_result',
          'call_id': 'call-1',
          'result': '{"temperature":18}',
        },
      ]);
    });

    test(
      'Gemini model messages become assistant messages across protocols',
      () {
        final gemini = AiGatewayProtocolBridges.geminiGenerateContent;
        final neutral = gemini.toStroom({
          'role': 'model',
          'parts': [
            {'text': 'Hello.'},
          ],
        });

        expect(neutral.role, 'assistant');
        final openAi = AiGatewayProtocolBridges.buildRequest(
          'openai.chat_completions',
          AiGatewayProtocolRequest(modelId: 'gpt-4.1', messages: [neutral]),
        );
        expect(openAi?.body['messages'], [
          {'role': 'assistant', 'content': 'Hello.'},
        ]);
      },
    );

    test(
      'Gemini streamed tool thought signatures survive follow-up history',
      () {
        final streamed = AiGatewayProtocolStreamBridge.mapEvents(
          'google.gemini.generate_content',
          {
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'functionCall': {
                        'name': 'lookup',
                        'args': {'q': 'weather'},
                      },
                      'thoughtSignature': 'opaque-thought-signature',
                    },
                  ],
                },
              },
            ],
          },
        );
        expect(streamed.single.thoughtSignature, 'opaque-thought-signature');

        final toolCall = normalizeToolCall({
          'id': 'call-1',
          'thoughtSignature': streamed.single.thoughtSignature,
          'function': {'name': 'lookup', 'arguments': streamed.single.delta},
        });
        final assistantHistory = const OpenAIProtocol()
            .buildAssistantChainMessage(content: '', toolCalls: [toolCall]);
        final neutralHistory = AiGatewayProtocolBridges.openAiChatCompletions
            .toStroom(assistantHistory.single);
        final followUp = AiGatewayProtocolBridges.buildRequest(
          'google.gemini.generate_content',
          AiGatewayProtocolRequest(
            modelId: 'gemini-2.5-pro',
            messages: [neutralHistory],
          ),
        );
        expect(
          (followUp?.body['contents'] as List)
              .single['parts']
              .single['thoughtSignature'],
          'opaque-thought-signature',
        );
      },
    );

    test('edited Gemini Interactions history uses edited content', () {
      final bridge = AiGatewayProtocolBridges.geminiInteractions;
      final original = bridge.toStroom({
        'id': 'upstream-interaction-id',
        'steps': [
          {
            'type': 'model_output',
            'content': [
              {
                'type': 'text',
                'text': 'Original answer.',
                'provider_text_field': 'preserve-me',
              },
            ],
          },
        ],
      });
      final originalText = original.content.single;
      final edited = StroomMessage(
        id: original.id,
        role: original.role,
        sequence: original.sequence,
        createdAt: original.createdAt,
        content: [
          StroomContentPart(
            type: 'text',
            data: {...originalText.data, 'text': 'Edited answer.'},
          ),
        ],
        extensions: original.extensions,
      );

      final request = AiGatewayProtocolBridges.buildRequest(
        'google.gemini.interactions',
        AiGatewayProtocolRequest(modelId: 'gemini-3-flash', messages: [edited]),
      );
      expect(request?.body['input'], [
        {
          'type': 'model_output',
          'content': [
            {
              'type': 'text',
              'text': 'Edited answer.',
              'provider_text_field': 'preserve-me',
            },
          ],
        },
      ]);
    });

    test('OpenAI direct conversion represents a single tool result', () {
      final result = StroomMessage(
        id: 'tool-result',
        role: 'tool',
        sequence: 0,
        createdAt: DateTime.utc(2026),
        content: [
          StroomContentPart.toolResult(toolCallId: 'call-1', result: 'done'),
        ],
      );

      expect(
        AiGatewayProtocolBridges.openAiChatCompletions.fromStroom(result),
        {'role': 'tool', 'tool_call_id': 'call-1', 'content': 'done'},
      );
      final mixed = StroomMessage(
        id: 'mixed-tool-result',
        role: 'tool',
        sequence: 1,
        createdAt: DateTime.utc(2026),
        content: [
          StroomContentPart.text('result'),
          StroomContentPart.toolResult(toolCallId: 'call-1', result: 'done'),
        ],
      );
      expect(
        () => AiGatewayProtocolBridges.openAiChatCompletions.fromStroom(mixed),
        throwsUnsupportedError,
      );
    });

    test('Anthropic and Gemini move system-role messages to instructions', () {
      final source = AiGatewayProtocolBridges.openAiChatCompletions;
      final messages = [
        source.toStroom({'role': 'system', 'content': 'Be concise.'}),
        source.toStroom({'role': 'user', 'content': 'Hello.'}),
      ];

      final anthropic = AiGatewayProtocolBridges.buildRequest(
        'anthropic.messages',
        AiGatewayProtocolRequest(modelId: 'claude', messages: messages),
      );
      final gemini = AiGatewayProtocolBridges.buildRequest(
        'google.gemini.generate_content',
        AiGatewayProtocolRequest(modelId: 'gemini', messages: messages),
      );

      expect(anthropic?.body['system'], 'Be concise.');
      expect(anthropic?.body['messages'], [
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': 'Hello.'},
          ],
        },
      ]);
      expect(gemini?.body['systemInstruction'], {
        'parts': [
          {'text': 'Be concise.'},
        ],
      });
      expect(gemini?.body['contents'], [
        {
          'role': 'user',
          'parts': [
            {'text': 'Hello.'},
          ],
        },
      ]);
    });

    test('OpenAI and Ollama do not duplicate matching system prompts', () {
      final systemMessage = AiGatewayProtocolBridges.openAiChatCompletions
          .toStroom({'role': 'system', 'content': 'Be concise.'});
      final userMessage = AiGatewayProtocolBridges.openAiChatCompletions
          .toStroom({'role': 'user', 'content': 'Hello.'});

      for (final protocol in const ['openai.chat_completions', 'ollama.chat']) {
        final request = AiGatewayProtocolBridges.buildRequest(
          protocol,
          AiGatewayProtocolRequest(
            modelId: 'model',
            system: 'Be concise.',
            messages: [systemMessage, userMessage],
          ),
        );
        final messages = request?.body['messages'] as List;
        expect(messages.where((message) => message['role'] == 'system'), [
          {'role': 'system', 'content': 'Be concise.'},
        ]);
      }
    });

    test(
      'Responses deduplicates a matching system prompt into instructions',
      () {
        final bridge = AiGatewayProtocolBridges.openAiChatCompletions;
        final systemMessage = bridge.toStroom({
          'role': 'system',
          'content': 'Be concise.',
        });
        final userMessage = bridge.toStroom({
          'role': 'user',
          'content': 'Hello.',
        });

        final response = AiGatewayProtocolBridges.buildRequest(
          'openai.responses',
          AiGatewayProtocolRequest(
            modelId: 'gpt-4o',
            system: 'Be concise.',
            messages: [systemMessage, userMessage],
          ),
        );

        expect(response?.body['instructions'], 'Be concise.');
        expect(response?.body['input'], [
          {
            'type': 'message',
            'role': 'user',
            'content': [
              {'type': 'input_text', 'text': 'Hello.'},
            ],
          },
        ]);
      },
    );

    test('Anthropic and Gemini deduplicate matching system instructions', () {
      final bridge = AiGatewayProtocolBridges.openAiChatCompletions;
      final systemMessage = bridge.toStroom({
        'role': 'system',
        'content': 'Be concise.',
      });
      final userMessage = bridge.toStroom({
        'role': 'user',
        'content': 'Hello.',
      });

      final anthropic = AiGatewayProtocolBridges.buildRequest(
        'anthropic.messages',
        AiGatewayProtocolRequest(
          modelId: 'claude',
          system: 'Be concise.',
          messages: [systemMessage, userMessage],
        ),
      );
      final gemini = AiGatewayProtocolBridges.buildRequest(
        'google.gemini.generate_content',
        AiGatewayProtocolRequest(
          modelId: 'gemini',
          system: 'Be concise.',
          messages: [systemMessage, userMessage],
        ),
      );

      expect(anthropic?.body['system'], 'Be concise.');
      expect(gemini?.body['systemInstruction'], {
        'parts': [
          {'text': 'Be concise.'},
        ],
      });
    });

    test('Anthropic preserves redacted thinking when a message is edited', () {
      final bridge = AiGatewayProtocolBridges.anthropicMessages;
      final original = bridge.toStroom({
        'role': 'assistant',
        'content': [
          {'type': 'redacted_thinking', 'data': 'opaque-redacted-payload'},
        ],
      });
      final edited = StroomMessage(
        id: original.id,
        role: original.role,
        sequence: original.sequence,
        createdAt: original.createdAt,
        content: [
          ...original.content,
          StroomContentPart.text('Additional response text.'),
        ],
        extensions: original.extensions,
      );

      expect(bridge.fromStroom(edited)['content'], [
        {'type': 'redacted_thinking', 'data': 'opaque-redacted-payload'},
        {'type': 'text', 'text': 'Additional response text.'},
      ]);
    });

    test('object tool results encode as JSON for Responses and Anthropic', () {
      final toolResult =
          AiGatewayProtocolBridges.openAiChatCompletions.toStroom({
        'role': 'tool',
        'tool_call_id': 'call-object',
        'content': {'temperature': 18},
      });

      final responses = AiGatewayProtocolBridges.buildRequest(
        'openai.responses',
        AiGatewayProtocolRequest(modelId: 'gpt', messages: [toolResult]),
      );
      final anthropic = AiGatewayProtocolBridges.buildRequest(
        'anthropic.messages',
        AiGatewayProtocolRequest(modelId: 'claude', messages: [toolResult]),
      );

      expect(responses?.body['input'], [
        {
          'type': 'function_call_output',
          'call_id': 'call-object',
          'output': '{"temperature":18}',
        },
      ]);
      expect(anthropic?.body['messages'], [
        {
          'role': 'user',
          'content': [
            {
              'type': 'tool_result',
              'tool_use_id': 'call-object',
              'content': '{"temperature":18}',
            },
          ],
        },
      ]);
    });

    test('OpenAI image URLs convert to Anthropic image blocks', () {
      final neutral = AiGatewayProtocolBridges.openAiChatCompletions.toStroom({
        'role': 'user',
        'content': [
          {'type': 'text', 'text': 'Describe this.'},
          {
            'type': 'image_url',
            'image_url': {'url': 'data:image/png;base64,aGVsbG8='},
          },
        ],
      });

      final request = AiGatewayProtocolBridges.buildRequest(
        'anthropic.messages',
        AiGatewayProtocolRequest(modelId: 'claude', messages: [neutral]),
      );

      expect(request?.body['messages'], [
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': 'Describe this.'},
            {
              'type': 'image',
              'source': {
                'type': 'base64',
                'media_type': 'image/png',
                'data': 'aGVsbG8=',
              },
            },
          ],
        },
      ]);

      final httpsImage =
          AiGatewayProtocolBridges.openAiChatCompletions.toStroom({
        'role': 'user',
        'content': [
          {
            'type': 'image_url',
            'image_url': {'url': 'https://example.test/image.png'},
          },
        ],
      });
      final httpsRequest = AiGatewayProtocolBridges.buildRequest(
        'anthropic.messages',
        AiGatewayProtocolRequest(modelId: 'claude', messages: [httpsImage]),
      );
      expect(httpsRequest?.body['messages'], [
        {
          'role': 'user',
          'content': [
            {
              'type': 'image',
              'source': {
                'type': 'url',
                'url': 'https://example.test/image.png',
              },
            },
          ],
        },
      ]);
    });

    test('Ollama retains image data URLs and rejects remote image URLs', () {
      final openAi = AiGatewayProtocolBridges.openAiChatCompletions;
      final dataImage = openAi.toStroom({
        'role': 'user',
        'content': [
          {
            'type': 'image_url',
            'image_url': {'url': 'data:image/jpeg;base64,aGVsbG8='},
          },
        ],
      });
      final request = AiGatewayProtocolBridges.buildRequest(
        'ollama.chat',
        AiGatewayProtocolRequest(modelId: 'llava', messages: [dataImage]),
      );
      expect(request?.body['messages'], [
        {
          'role': 'user',
          'content': '',
          'images': ['aGVsbG8='],
        },
      ]);

      final remoteImage = openAi.toStroom({
        'role': 'user',
        'content': [
          {
            'type': 'image_url',
            'image_url': {'url': 'https://example.test/photo.png'},
          },
        ],
      });
      expect(
        () => AiGatewayProtocolBridges.buildRequest(
          'ollama.chat',
          AiGatewayProtocolRequest(modelId: 'llava', messages: [remoteImage]),
        ),
        throwsUnsupportedError,
      );
    });

    test('Ollama encodes neutral tool results as tool messages', () {
      final toolResult =
          AiGatewayProtocolBridges.openAiChatCompletions.toStroom({
        'role': 'tool',
        'tool_call_id': 'call-1',
        'content': '{"temperature":18}',
      });

      final request = AiGatewayProtocolBridges.buildRequest(
        'ollama.chat',
        AiGatewayProtocolRequest(modelId: 'llama3', messages: [toolResult]),
      );

      expect(request?.body['messages'], [
        {'role': 'tool', 'content': '{"temperature":18}'},
      ]);
    });

    test('Ollama maps thinking into neutral and outbound messages', () {
      final bridge = AiGatewayProtocolBridges.ollamaChat;
      final neutral = bridge.toStroom({
        'role': 'assistant',
        'content': 'Visible answer.',
        'thinking': 'Private reasoning.',
      });
      expect(neutral.content.map((part) => part.type), ['text', 'reasoning']);
      expect(neutral.content.last.data['text'], 'Private reasoning.');

      final request = AiGatewayProtocolBridges.buildRequest(
        'ollama.chat',
        AiGatewayProtocolRequest(
          modelId: 'llama3',
          messages: [
            StroomMessage(
              id: 'reasoning-message',
              role: 'assistant',
              sequence: 0,
              createdAt: DateTime.utc(2026),
              content: [
                StroomContentPart.text('Visible answer.'),
                StroomContentPart.reasoning('Private reasoning.'),
              ],
            ),
          ],
        ),
      );
      expect(request?.body['messages'], [
        {
          'role': 'assistant',
          'content': 'Visible answer.',
          'thinking': 'Private reasoning.',
        },
      ]);
    });

    test('Anthropic thinking signatures and tool result errors round-trip', () {
      final source = <String, dynamic>{
        'role': 'assistant',
        'content': [
          {'type': 'thinking', 'thinking': 'Plan', 'signature': 'sig_abc'},
          {
            'type': 'tool_use',
            'id': 'tool_1',
            'name': 'lookup',
            'input': {'q': 'weather'},
          },
          {
            'type': 'tool_result',
            'tool_use_id': 'tool_1',
            'content': 'not found',
            'is_error': true,
          },
        ],
        'stop_reason': 'tool_use',
        'provider_field': ['kept'],
      };

      final bridge = AiGatewayProtocolBridges.anthropicMessages;
      final neutral = bridge.toStroom(source);

      expect(neutral.content.map((part) => part.type), [
        'reasoning',
        'tool_call',
        'tool_result',
      ]);
      expect(neutral.content.first.data['signature'], 'sig_abc');
      expect(neutral.content.last.data['isError'], isTrue);
      expect(bridge.fromStroom(neutral), source);
    });

    test('Gemini and Interactions retain multimodal and continuation data', () {
      final generateContent = <String, dynamic>{
        'candidates': [
          {
            'finishReason': 'STOP',
            'content': {
              'role': 'model',
              'parts': [
                {'text': 'Inspecting image.'},
                {
                  'inlineData': {'mimeType': 'image/png', 'data': 'aGVsbG8='},
                },
                {
                  'functionCall': {
                    'id': 'call_2',
                    'name': 'lookup',
                    'args': {'q': 'weather'},
                  },
                },
                {'thought': true, 'text': 'private reasoning'},
              ],
            },
          },
        ],
        'usageMetadata': {'totalTokenCount': 14},
        'source_marker': 'kept',
      };
      final gemini = AiGatewayProtocolBridges.geminiGenerateContent;
      final geminiNeutral = gemini.toStroom(generateContent);
      expect(geminiNeutral.content.map((part) => part.type), [
        'text',
        'image',
        'tool_call',
        'reasoning',
      ]);
      expect(geminiNeutral.finishReason, 'STOP');
      expect(geminiNeutral.usage, {'totalTokenCount': 14});
      expect(gemini.fromStroom(geminiNeutral), generateContent);
      final geminiRequest = AiGatewayProtocolBridges.buildRequest(
        'google.gemini.generate_content',
        AiGatewayProtocolRequest(
          modelId: 'gemini-3-flash',
          messages: [geminiNeutral],
        ),
      );
      expect(geminiRequest?.body['contents'], [
        {
          'role': 'model',
          'parts': [
            {'text': 'Inspecting image.'},
            {
              'inlineData': {'mimeType': 'image/png', 'data': 'aGVsbG8='},
            },
            {
              'functionCall': {
                'id': 'call_2',
                'name': 'lookup',
                'args': {'q': 'weather'},
              },
            },
            {'text': 'private reasoning', 'thought': true},
          ],
        },
      ]);
      final imageReferenceRequest = AiGatewayProtocolBridges.buildRequest(
        'google.gemini.generate_content',
        AiGatewayProtocolRequest(
          modelId: 'gemini-3-flash',
          messages: [
            StroomMessage(
              id: 'image-reference',
              role: 'user',
              sequence: 0,
              createdAt: DateTime.utc(2026),
              content: [
                StroomContentPart.image(
                  reference: 'https://example.test/picture.png',
                  mimeType: 'image/png',
                ),
              ],
            ),
          ],
        ),
      );
      expect(imageReferenceRequest?.body['contents'], [
        {
          'role': 'user',
          'parts': [
            {
              'fileData': {
                'fileUri': 'https://example.test/picture.png',
                'mimeType': 'image/png',
              },
            },
          ],
        },
      ]);
      expect(
        () => AiGatewayProtocolBridges.buildRequest(
          'google.gemini.generate_content',
          AiGatewayProtocolRequest(
            modelId: 'gemini-3-flash',
            messages: [
              StroomMessage(
                id: 'local-image-reference',
                role: 'user',
                sequence: 0,
                createdAt: DateTime.utc(2026),
                content: [
                  StroomContentPart.image(reference: '/tmp/picture.png'),
                ],
              ),
            ],
          ),
        ),
        throwsUnsupportedError,
      );

      final interaction = <String, dynamic>{
        'id': 'interaction_upstream_1',
        'previous_interaction_id': 'interaction_upstream_0',
        'status': 'completed',
        'steps': [
          {
            'type': 'model_output',
            'content': [
              {'type': 'text', 'text': 'Done'},
            ],
          },
          {
            'type': 'function_call',
            'id': 'call_3',
            'name': 'lookup',
            'arguments': {'q': 'weather'},
          },
        ],
        'future_field': 19,
      };
      final interactions = AiGatewayProtocolBridges.geminiInteractions;
      final interactionNeutral = interactions.toStroom(interaction);
      expect(
        interactionNeutral.extensions['google.gemini.interactions']
            ['previous_interaction_id'],
        'interaction_upstream_0',
      );
      expect(interactionNeutral.id, isEmpty);
      expect(interactions.fromStroom(interactionNeutral), interaction);
    });

    test(
      'request builders keep provider routes and continuation fields explicit',
      () {
        final message = StroomMessage(
          id: 'message-1',
          role: 'user',
          sequence: 0,
          createdAt: DateTime.utc(2026),
          content: [StroomContentPart.text('Hello')],
        );
        final interaction = AiGatewayProtocolBridges.buildRequest(
          'google.gemini.interactions',
          AiGatewayProtocolRequest(
            modelId: 'gemini-3-flash',
            messages: [message],
            previousInteractionId: 'upstream-parent',
            stream: true,
            options: {'model': 'wrong-model', 'safetySettings': []},
          ),
        );
        expect(interaction?.path, '/v1beta/interactions?alt=sse');
        expect(interaction?.body['model'], 'gemini-3-flash');
        expect(interaction?.body['input'], [
          {'type': 'text', 'text': 'Hello'},
        ]);
        expect(interaction?.body['previous_interaction_id'], 'upstream-parent');
        expect(interaction?.body['stream'], isTrue);
        expect(interaction?.body['safetySettings'], isEmpty);

        final gemini = AiGatewayProtocolBridges.buildRequest(
          'google.gemini.generate_content',
          AiGatewayProtocolRequest(
            modelId: 'gemini-3-flash',
            messages: [
              StroomMessage(
                id: 'assistant-1',
                role: 'assistant',
                sequence: 1,
                createdAt: DateTime.utc(2026),
                content: [StroomContentPart.text('Hello')],
              ),
            ],
            stream: true,
            system: 'Be concise',
            maxOutputTokens: 128,
            options: {
              'generationConfig': {'topP': 0.9},
            },
          ),
        );
        expect(
          gemini?.path,
          '/v1beta/models/gemini-3-flash:streamGenerateContent?alt=sse',
        );
        expect(gemini?.body['contents'], [
          {
            'role': 'model',
            'parts': [
              {'text': 'Hello'},
            ],
          },
        ]);
        expect(gemini?.body['systemInstruction'], {
          'parts': [
            {'text': 'Be concise'},
          ],
        });
        expect(gemini?.body['generationConfig'], {
          'maxOutputTokens': 128,
          'topP': 0.9,
        });

        final responses = AiGatewayProtocolBridges.buildRequest(
          'openai.responses',
          AiGatewayProtocolRequest(
            modelId: 'gpt-6',
            messages: [
              StroomMessage(
                id: 'assistant-2',
                role: 'assistant',
                sequence: 2,
                createdAt: DateTime.utc(2026),
                content: [
                  StroomContentPart.text('I will look that up.'),
                  StroomContentPart.toolCall(
                    id: 'call-1',
                    name: 'lookup',
                    arguments: {'q': 'weather'},
                  ),
                ],
              ),
            ],
          ),
        );
        expect(responses?.body['input'], [
          {
            'type': 'message',
            'role': 'assistant',
            'content': [
              {'type': 'output_text', 'text': 'I will look that up.'},
            ],
          },
          {
            'type': 'function_call',
            'call_id': 'call-1',
            'name': 'lookup',
            'arguments': '{"q":"weather"}',
          },
        ]);
      },
    );

    test('Ollama maps maxOutputTokens to options.num_predict', () {
      final request = AiGatewayProtocolBridges.buildRequest(
        'ollama.chat',
        AiGatewayProtocolRequest(
          modelId: 'llama3',
          messages: const [],
          maxOutputTokens: 64,
          options: {'top_k': 20},
        ),
      );

      expect(request?.body['options'], {'top_k': 20, 'num_predict': 64});
    });

    test('Ollama keeps root request fields outside generation options', () {
      final request = AiGatewayProtocolBridges.buildRequest(
        'ollama.chat',
        AiGatewayProtocolRequest(
          modelId: 'llama3',
          messages: const [],
          options: const {
            'format': 'json',
            'keep_alive': '5m',
            'options': {'num_ctx': 8192},
          },
        ),
      );

      expect(request?.body['format'], 'json');
      expect(request?.body['keep_alive'], '5m');
      expect(request?.body['options'], {'num_ctx': 8192});
    });

    test(
      'Gemini preserves generationConfig options without standard fields',
      () {
        final request = AiGatewayProtocolBridges.buildRequest(
          'google.gemini.generate_content',
          AiGatewayProtocolRequest(
            modelId: 'gemini',
            messages: const [],
            options: const {
              'generationConfig': {'topK': 40},
            },
          ),
        );

        expect(request?.body['generationConfig'], {'topK': 40});
      },
    );

    test('Gemini Interactions maps inline image data', () {
      final neutral = AiGatewayProtocolBridges.openAiChatCompletions.toStroom({
        'role': 'user',
        'content': [
          {
            'type': 'image_url',
            'image_url': {'url': 'data:image/png;base64,aGVsbG8='},
          },
        ],
      });

      final request = AiGatewayProtocolBridges.buildRequest(
        'google.gemini.interactions',
        AiGatewayProtocolRequest(modelId: 'gemini', messages: [neutral]),
      );

      expect(request?.body['input'], [
        {
          'type': 'image',
          'data': 'aGVsbG8=',
          'mime_type': 'image/png',
        },
      ]);
    });

    test('Gemini Interactions re-encodes native inline image source', () {
      final message = StroomMessage(
        id: 'native-interactions-image',
        role: 'user',
        sequence: 0,
        createdAt: DateTime.utc(2026),
        content: [
          StroomContentPart(
            type: 'image',
            data: {
              'source': {
                'type': 'image',
                'data': 'aGVsbG8=',
                'mime_type': 'image/png',
              },
            },
          ),
        ],
      );

      final request = AiGatewayProtocolBridges.buildRequest(
        'google.gemini.interactions',
        AiGatewayProtocolRequest(modelId: 'gemini', messages: [message]),
      );

      expect(request?.body['input'], [
        {
          'type': 'image',
          'data': 'aGVsbG8=',
          'mime_type': 'image/png',
        },
      ]);
    });

    test(
      'Responses rejects unsupported generic audio instead of dropping it',
      () {
        final neutral = AiGatewayProtocolBridges.openAiChatCompletions.toStroom(
          {
            'role': 'user',
            'content': [
              {
                'type': 'input_audio',
                'input_audio': {'format': 'wav', 'data': 'YWJj'},
              },
            ],
          },
        );

        expect(
          () => AiGatewayProtocolBridges.buildRequest(
            'openai.responses',
            AiGatewayProtocolRequest(modelId: 'gpt', messages: [neutral]),
          ),
          throwsUnsupportedError,
        );
      },
    );

    test(
      'Gemini maps OpenAI audio and video inputs or rejects unsupported files',
      () {
        final neutral = AiGatewayProtocolBridges.openAiChatCompletions.toStroom(
          {
            'role': 'user',
            'content': [
              {
                'type': 'input_audio',
                'input_audio': {'format': 'wav', 'data': 'YWJj'},
              },
              {
                'type': 'video_url',
                'video_url': {'url': 'https://example.test/clip.mp4'},
              },
            ],
          },
        );
        final request = AiGatewayProtocolBridges.buildRequest(
          'google.gemini.generate_content',
          AiGatewayProtocolRequest(modelId: 'gemini', messages: [neutral]),
        );
        expect(request?.body['contents'], [
          {
            'role': 'user',
            'parts': [
              {
                'inlineData': {'mimeType': 'audio/wav', 'data': 'YWJj'},
              },
              {
                'fileData': {
                  'fileUri': 'https://example.test/clip.mp4',
                  'mimeType': 'video/mp4',
                },
              },
            ],
          },
        ]);

        final unsupportedFile =
            AiGatewayProtocolBridges.openAiChatCompletions.toStroom({
          'role': 'user',
          'content': [
            {
              'type': 'file',
              'file': {'file_id': 'file-1'},
            },
          ],
        });
        expect(
          () => AiGatewayProtocolBridges.buildRequest(
            'google.gemini.generate_content',
            AiGatewayProtocolRequest(
              modelId: 'gemini',
              messages: [unsupportedFile],
            ),
          ),
          throwsUnsupportedError,
        );
      },
    );

    test('Gemini preserves video metadata alongside inline video bytes', () {
      final message = StroomMessage(
        id: 'gemini-inline-video-metadata',
        role: 'user',
        sequence: 0,
        createdAt: DateTime.utc(2026),
        content: [
          StroomContentPart(
            type: 'video',
            data: {
              'inlineData': {'mimeType': 'video/mp4', 'data': 'AQID'},
              'videoMetadata': {'frameTimestamp': '1.25s', 'frameIndex': 3},
            },
          ),
        ],
      );

      final request = AiGatewayProtocolBridges.buildRequest(
        'google.gemini.generate_content',
        AiGatewayProtocolRequest(modelId: 'gemini', messages: [message]),
      );

      expect(request?.body['contents'], [
        {
          'role': 'user',
          'parts': [
            {
              'inlineData': {'mimeType': 'video/mp4', 'data': 'AQID'},
              'videoMetadata': {'frameTimestamp': '1.25s', 'frameIndex': 3},
            },
          ],
        },
      ]);
    });

    test('Gemini preserves video metadata alongside file references', () {
      final message = StroomMessage(
        id: 'gemini-video-reference-metadata',
        role: 'user',
        sequence: 0,
        createdAt: DateTime.utc(2026),
        content: [
          StroomContentPart(
            type: 'video',
            data: {
              'fileData': {
                'fileUri': 'gs://bucket/clip.mp4',
                'mimeType': 'video/mp4',
              },
              'videoMetadata': {'frameTimestamp': '2.5s', 'frameIndex': 5},
            },
          ),
        ],
      );

      final request = AiGatewayProtocolBridges.buildRequest(
        'google.gemini.generate_content',
        AiGatewayProtocolRequest(modelId: 'gemini', messages: [message]),
      );

      expect(request?.body['contents'], [
        {
          'role': 'user',
          'parts': [
            {
              'fileData': {
                'fileUri': 'gs://bucket/clip.mp4',
                'mimeType': 'video/mp4',
              },
              'videoMetadata': {'frameTimestamp': '2.5s', 'frameIndex': 5},
            },
          ],
        },
      ]);
    });

    test('Gemini maps OpenAI Responses input_file references and data', () {
      final source = AiGatewayProtocolBridges.openAiResponses.toStroom({
        'type': 'message',
        'role': 'user',
        'content': [
          {
            'type': 'input_file',
            'filename': 'report.pdf',
            'file_url': 'https://files.example/report.pdf',
          },
          {
            'type': 'input_file',
            'filename': 'inline.pdf',
            'file_data': 'data:application/pdf;base64,cGRm',
          },
        ],
      });

      final request = AiGatewayProtocolBridges.buildRequest(
        'google.gemini.generate_content',
        AiGatewayProtocolRequest(modelId: 'gemini-flash', messages: [source]),
      );

      expect(request?.body['contents'], [
        {
          'role': 'user',
          'parts': [
            {
              'fileData': {
                'fileUri': 'https://files.example/report.pdf',
                'mimeType': 'application/pdf',
              },
            },
            {
              'inlineData': {
                'mimeType': 'application/pdf',
                'data': 'cGRm',
              },
            },
          ],
        },
      ]);
    });

    test('Gemini maps Responses input_audio format-only MIME', () {
      final message = AiGatewayProtocolBridges.openAiResponses.toStroom({
        'type': 'message',
        'role': 'user',
        'content': [
          {
            'type': 'input_audio',
            'input_audio': {'format': 'wav', 'data': 'YWJj'},
          },
        ],
      });

      final request = AiGatewayProtocolBridges.buildRequest(
        'google.gemini.generate_content',
        AiGatewayProtocolRequest(modelId: 'gemini', messages: [message]),
      );

      expect(request?.body['contents'], [
        {
          'role': 'user',
          'parts': [
            {
              'inlineData': {'mimeType': 'audio/wav', 'data': 'YWJj'},
            },
          ],
        },
      ]);
    });

    test('Gemini rejects malformed plain input_audio base64', () {
      final message = AiGatewayProtocolBridges.openAiResponses.toStroom({
        'type': 'message',
        'role': 'user',
        'content': [
          {
            'type': 'input_audio',
            'input_audio': {'format': 'wav', 'data': '%%%invalid-base64%%%'},
          },
        ],
      });

      expect(
        () => AiGatewayProtocolBridges.buildRequest(
          'google.gemini.generate_content',
          AiGatewayProtocolRequest(modelId: 'gemini', messages: [message]),
        ),
        throwsUnsupportedError,
      );
    });

    test('Gemini maps audio and output_audio format-only MIME', () {
      final message = AiGatewayProtocolBridges.openAiResponses.toStroom({
        'type': 'message',
        'role': 'user',
        'content': [
          {
            'type': 'audio',
            'audio': {'format': 'wav', 'data': 'YWJj'},
          },
          {
            'type': 'output_audio',
            'output_audio': {'format': 'mp3', 'data': 'ZGVm'},
          },
        ],
      });

      final request = AiGatewayProtocolBridges.buildRequest(
        'google.gemini.generate_content',
        AiGatewayProtocolRequest(modelId: 'gemini', messages: [message]),
      );

      expect(request?.body['contents'], [
        {
          'role': 'user',
          'parts': [
            {
              'inlineData': {'mimeType': 'audio/wav', 'data': 'YWJj'},
            },
            {
              'inlineData': {'mimeType': 'audio/mpeg', 'data': 'ZGVm'},
            },
          ],
        },
      ]);
    });

    test('request builders translate function tools to native schemas', () {
      final function = {
        'name': 'lookup',
        'description': 'Look up a location.',
        'parameters': {
          'type': 'object',
          'properties': {
            'city': {'type': 'string'},
          },
        },
        'vendor_extension': 'preserved',
      };
      final openAiTool = {'type': 'function', 'function': function};
      AiGatewayProtocolRequest request() => AiGatewayProtocolRequest(
            modelId: 'model-1',
            messages: const [],
            tools: [openAiTool],
          );

      final responses = AiGatewayProtocolBridges.buildRequest(
        'openai.responses',
        request(),
      );
      expect(responses?.body['tools'], [
        {'type': 'function', ...function},
      ]);

      final anthropic = AiGatewayProtocolBridges.buildRequest(
        'anthropic.messages',
        request(),
      );
      expect(anthropic?.body['tools'], [
        {
          'name': 'lookup',
          'description': 'Look up a location.',
          'vendor_extension': 'preserved',
          'input_schema': function['parameters'],
        },
      ]);
      expect(
        anthropic?.body['tools']?.first.containsKey('parameters'),
        isFalse,
      );

      final gemini = AiGatewayProtocolBridges.buildRequest(
        'google.gemini.generate_content',
        request(),
      );
      expect(gemini?.body['tools'], [
        {
          'functionDeclarations': [
            {
              'name': 'lookup',
              'description': 'Look up a location.',
              'parameters': function['parameters'],
            },
          ],
        },
      ]);
    });

    test('Anthropic token counting uses its dedicated request endpoint', () {
      final request = AiGatewayProtocolBridges.buildRequest(
        'anthropic.messages',
        AiGatewayProtocolRequest(
          modelId: 'claude-sonnet-4',
          operation: 'count_tokens',
          messages: [
            StroomMessage(
              id: 'message-1',
              role: 'user',
              sequence: 0,
              createdAt: DateTime.utc(2026),
              content: [StroomContentPart.text('Hello')],
            ),
          ],
          system: 'Be concise',
          stream: true,
        ),
      );
      expect(request?.path, '/v1/messages/count_tokens');
      expect(request?.streams, isFalse);
      expect(request?.body, {
        'messages': [
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': 'Hello'},
            ],
          },
        ],
        'system': 'Be concise',
        'model': 'claude-sonnet-4',
      });
    });

    test('Responses refusal deltas become visible text events', () {
      final refusal =
          AiGatewayProtocolStreamBridge.mapEvent('openai.responses', {
        'type': 'response.refusal.delta',
        'delta': 'I cannot help with that request.',
      });

      expect(refusal.kind, AiGatewayProtocolStreamEventKind.textDelta);
      expect(refusal.delta, 'I cannot help with that request.');
    });

    test(
      'stream frames normalize text, reasoning, tool, usage, and errors',
      () {
        final openAi = AiGatewayProtocolStreamBridge.mapEvent(
          'openai.chat_completions',
          {
            'choices': [
              {
                'delta': {
                  'tool_calls': [
                    {
                      'id': 'call-1',
                      'function': {'name': 'lookup', 'arguments': '{"q":'},
                    },
                  ],
                },
              },
            ],
          },
        );
        final responses = AiGatewayProtocolStreamBridge.mapEvent(
          'openai.responses',
          {'type': 'response.output_text.delta', 'delta': 'hello'},
        );
        final responseFailed = AiGatewayProtocolStreamBridge.mapEvent(
          'openai.responses',
          {
            'type': 'response.failed',
            'response': {
              'error': {'code': 'server_error'},
            },
          },
        );
        final responseTool = AiGatewayProtocolStreamBridge.mapEvent(
          'openai.responses',
          {
            'type': 'response.output_item.added',
            'item': {
              'type': 'function_call',
              'call_id': 'call-r',
              'name': 'lookup',
            },
          },
        );
        final anthropic = AiGatewayProtocolStreamBridge.mapEvent(
          'anthropic.messages',
          {
            'type': 'content_block_delta',
            'delta': {'type': 'thinking_delta', 'thinking': 'considering'},
          },
        );
        final anthropicStream = AiGatewayProtocolStreamState();
        final anthropicStart = AiGatewayProtocolStreamBridge.mapEvent(
          'anthropic.messages',
          {
            'type': 'content_block_start',
            'index': 3,
            'content_block': {
              'type': 'tool_use',
              'id': 'tool-call-3',
              'name': 'lookup',
              'input': {},
            },
          },
          state: anthropicStream,
        );
        final anthropicArguments = AiGatewayProtocolStreamBridge.mapEvent(
          'anthropic.messages',
          {
            'type': 'content_block_delta',
            'index': 3,
            'delta': {'type': 'input_json_delta', 'partial_json': '{"q":'},
          },
          state: anthropicStream,
        );
        final gemini = AiGatewayProtocolStreamBridge.mapEvent(
          'google.gemini.generate_content',
          {
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'private thought', 'thought': true},
                  ],
                },
              },
            ],
          },
        );
        final usage = AiGatewayProtocolStreamBridge.mapEvent(
          'openai.responses',
          {
            'type': 'response.completed',
            'response': {
              'usage': {'input_tokens': 4, 'output_tokens': 2},
            },
          },
        );
        final error = AiGatewayProtocolStreamBridge.mapEvent(
          'google.gemini.interactions',
          {
            'type': 'error',
            'error': {'code': 'invalid_argument'},
          },
        );
        final interactionTool = AiGatewayProtocolStreamBridge.mapEvent(
          'google.gemini.interactions',
          {
            'type': 'interaction.step.completed',
            'output': {
              'type': 'function_call',
              'id': 'interaction-call-1',
              'name': 'lookup',
              'arguments': {'city': 'Paris'},
            },
          },
        );
        final interactionText = AiGatewayProtocolStreamBridge.mapEvent(
          'google.gemini.interactions',
          {
            'event_type': 'content.delta',
            'delta': {'type': 'text', 'text': 'interaction answer'},
          },
        );

        expect(openAi.kind, AiGatewayProtocolStreamEventKind.toolCallDelta);
        expect(openAi.toolCallId, 'call-1');
        expect(openAi.toolName, 'lookup');
        expect(openAi.delta, '{"q":');
        expect(responses.kind, AiGatewayProtocolStreamEventKind.textDelta);
        expect(responses.delta, 'hello');
        expect(responseFailed.kind, AiGatewayProtocolStreamEventKind.error);
        expect(
          responseTool.kind,
          AiGatewayProtocolStreamEventKind.toolCallDelta,
        );
        expect(responseTool.toolCallId, 'call-r');
        expect(responseTool.toolName, 'lookup');
        expect(anthropic.kind, AiGatewayProtocolStreamEventKind.reasoningDelta);
        expect(anthropicStart.delta, isNull);
        expect(anthropicArguments.toolCallId, 'tool-call-3');
        expect(anthropicArguments.toolCallIndex, 3);
        expect(anthropicArguments.delta, '{"q":');
        expect(gemini.kind, AiGatewayProtocolStreamEventKind.reasoningDelta);
        expect(usage.kind, AiGatewayProtocolStreamEventKind.usage);
        expect(usage.usage, {'input_tokens': 4, 'output_tokens': 2});
        expect(error.kind, AiGatewayProtocolStreamEventKind.error);
        expect(error.raw['error'], {'code': 'invalid_argument'});
        expect(
          interactionTool.kind,
          AiGatewayProtocolStreamEventKind.toolCallDelta,
        );
        expect(interactionTool.delta, '{"city":"Paris"}');
        expect(interactionText.type, 'content.delta');
        expect(
          interactionText.kind,
          AiGatewayProtocolStreamEventKind.textDelta,
        );
        expect(interactionText.delta, 'interaction answer');

        final streamState = AiGatewayProtocolStreamState();
        final multiToolDeltas = AiGatewayProtocolStreamBridge.mapEvents(
          'openai.chat_completions',
          {
            'choices': [
              {
                'delta': {
                  'tool_calls': [
                    {
                      'index': 0,
                      'id': 'call-a',
                      'function': {'name': 'first', 'arguments': '{'},
                    },
                    {
                      'index': 1,
                      'id': 'call-b',
                      'function': {'name': 'second', 'arguments': '{'},
                    },
                  ],
                },
              },
            ],
          },
          state: streamState,
        );
        final laterToolDelta = AiGatewayProtocolStreamBridge.mapEvents(
          'openai.chat_completions',
          {
            'choices': [
              {
                'delta': {
                  'tool_calls': [
                    {
                      'index': 1,
                      'function': {'arguments': '}'},
                    },
                  ],
                },
              },
            ],
          },
          state: streamState,
        );
        final geminiFrame = AiGatewayProtocolStreamBridge.mapEvents(
          'google.gemini.generate_content',
          {
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'answer'},
                    {
                      'functionCall': {
                        'name': 'lookup',
                        'args': {'q': 'x'},
                      },
                    },
                  ],
                },
              },
              {
                'content': {
                  'parts': [
                    {'text': 'reasoning', 'thought': true},
                  ],
                },
              },
            ],
          },
        );
        final geminiFrameWithUsage = AiGatewayProtocolStreamBridge.mapEvents(
          'google.gemini.generate_content',
          {
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'visible'},
                    {'text': 'thinking', 'thought': true},
                  ],
                },
              },
            ],
            'usageMetadata': {'totalTokenCount': 7},
          },
        );
        final ollamaFrame = AiGatewayProtocolStreamBridge.mapEvents(
          'ollama.chat',
          {
            'message': {
              'thinking': 'private thought',
              'tool_calls': [
                {
                  'function': {
                    'name': 'lookup',
                    'arguments': {'q': 'x'},
                  },
                },
              ],
            },
            'prompt_eval_count': 3,
            'eval_count': 2,
            'done': true,
          },
        );
        final responseState = AiGatewayProtocolStreamState();
        AiGatewayProtocolStreamBridge.mapEvents(
            'openai.responses',
            {
              'type': 'response.output_item.added',
              'item': {
                'type': 'function_call',
                'id': 'fc_item_1',
                'call_id': 'call_real_1',
                'name': 'lookup',
              },
            },
            state: responseState);
        final responseArguments = AiGatewayProtocolStreamBridge.mapEvents(
            'openai.responses',
            {
              'type': 'response.function_call_arguments.delta',
              'item_id': 'fc_item_1',
              'delta': '{"q":1}',
            },
            state: responseState);

        expect(multiToolDeltas.map((event) => event.toolCallId), [
          'call-a',
          'call-b',
        ]);
        expect(laterToolDelta.single.toolCallId, 'call-b');
        expect(laterToolDelta.single.toolCallIndex, 1);
        expect(geminiFrame.map((event) => event.kind), [
          AiGatewayProtocolStreamEventKind.textDelta,
          AiGatewayProtocolStreamEventKind.toolCallDelta,
          AiGatewayProtocolStreamEventKind.reasoningDelta,
        ]);
        expect(geminiFrameWithUsage.map((event) => event.kind), [
          AiGatewayProtocolStreamEventKind.textDelta,
          AiGatewayProtocolStreamEventKind.reasoningDelta,
          AiGatewayProtocolStreamEventKind.usage,
        ]);
        expect(ollamaFrame.map((event) => event.kind), [
          AiGatewayProtocolStreamEventKind.reasoningDelta,
          AiGatewayProtocolStreamEventKind.toolCallDelta,
          AiGatewayProtocolStreamEventKind.usage,
        ]);
        expect(ollamaFrame.first.delta, 'private thought');
        expect(ollamaFrame[1].toolName, 'lookup');
        expect(responseArguments.single.toolCallId, 'call_real_1');
        expect(responseArguments.single.toolItemId, 'fc_item_1');
      },
    );
  });
}
