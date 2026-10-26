import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/models/message_block.dart';
import 'package:stroom/models/stroom_conversation.dart';
import 'package:stroom/models/stroom_protocol_bridge.dart';
import 'package:stroom/models/tool_call.dart';
import 'package:stroom/providers/conversation_provider.dart';

void main() {
  group('protocol-neutral conversation schema', () {
    test('legacy conversation JSON and unknown blocks remain lossless', () {
      final legacy = <String, dynamic>{
        'id': 'legacy-conversation',
        'title': 'Legacy',
        'createdAt': '2024-01-01T00:00:00.000Z',
        'updatedAt': '2024-01-02T00:00:00.000Z',
        'messages': [
          {
            'id': 'legacy-message',
            'role': 'assistant',
            'content': 'hello',
            'createdAt': '2024-01-01T01:00:00.000Z',
            'attachments': [
              {
                'id': 'att-1',
                'fileName': 'photo.png',
                'storagePath': 'm/1',
                'futureAnnotation': {'source': 'newer-version'},
              },
            ],
            'toolCalls': [
              {
                'id': 'tool-1',
                'name': 'lookup',
                'arguments': {'key': 'value'},
                'status': 'completed',
                'futureToolField': {'retain': true},
              },
            ],
            'blocks': [
              {
                'type': 'vendor_future',
                'opaque': {
                  'version': 9,
                  'tags': ['a'],
                },
              },
            ],
            'customOldField': {'keep': true},
          },
        ],
        'contextSummary': 'compressed',
        'futureConversationField': {'future': 'keep'},
      };

      final restored = Conversation.fromMap(legacy);
      final serialized = restored.toMap();
      final second = Conversation.fromMap(serialized).toMap();

      expect(second['id'], 'legacy-conversation');
      expect(second['schemaVersion'], 1);
      expect(second['contextSummary'], 'compressed');
      expect(second['futureConversationField'], {'future': 'keep'});
      final message = (second['messages'] as List).single as Map;
      expect(message['id'], 'legacy-message');
      expect(message['schemaVersion'], 1);
      expect((message['attachments'] as List).single['storagePath'], 'm/1');
      expect(
        (message['attachments'] as List).single['futureAnnotation'],
        {'source': 'newer-version'},
      );
      expect((message['blocks'] as List).single, {
        'type': 'vendor_future',
        'opaque': {
          'version': 9,
          'tags': ['a'],
        },
      });
      expect(message['customOldField'], {'keep': true});
      expect(
        (message['toolCalls'] as List).single['futureToolField'],
        {'retain': true},
      );
    });

    test('legacy tool calls and reasoning become canonical content parts', () {
      final legacy = ChatMessage(
        id: 'legacy-agent-message',
        role: 'assistant',
        content: 'spoken answer',
        createdAt: DateTime.utc(2025),
        reasoningSections: ['thought'],
        textSections: ['spoken answer'],
        toolCalls: [
          ToolCallData(
            id: 'call_1',
            name: 'lookup',
            arguments: {'query': 'one'},
          ),
        ],
      );

      final neutral = StroomMessage.fromLegacy(legacy, sequence: 0);
      final translated = OpenAiResponsesBridge().serializeMessage(neutral);
      final output = translated.targetPayload!['output'] as List;

      expect(neutral.content.map((part) => part.type), [
        'reasoning',
        'text',
        'tool_call',
      ]);
      expect(output.map((item) => item['type']), [
        'reasoning',
        'message',
        'function_call',
      ]);
      expect(output.last['name'], 'lookup');
    });

    test('legacy tool block results become protocol tool-result items', () {
      final legacy = ChatMessage(
        id: 'legacy-block-tool-result',
        role: 'assistant',
        content: '',
        createdAt: DateTime.utc(2025),
        blocks: [
          ToolCallBlock(
            id: 'call_1',
            name: 'lookup',
            arguments: {'query': 'one'},
            status: ToolCallStatus.completed,
            result: 'one match',
          ),
        ],
      );

      final neutral = StroomMessage.fromLegacy(legacy, sequence: 0);
      final translated = OpenAiResponsesBridge().serializeMessage(neutral);
      final output = translated.targetPayload!['output'] as List;

      expect(neutral.content.map((part) => part.type), [
        'tool_call',
        'tool_result',
      ]);
      expect(output.map((item) => item['type']), [
        'function_call',
        'function_call_output',
      ]);
      expect(output.last['output'], 'one match');
    });

    test(
      'legacy extension loss is partial and returned with mapping result',
      () {
        final neutral = StroomMessage.fromLegacy(
          ChatMessage(
            id: 'legacy-extension-message',
            role: 'assistant',
            content: 'hello',
            createdAt: DateTime.utc(2025),
            legacyFields: {'future_legacy_value': 'keep'},
          ),
          sequence: 0,
        );

        final result = OpenAiResponsesBridge().serializeMessage(neutral);
        final restored = ProtocolMappingResult.fromJson(result.toJson());

        expect(result.fidelity, MappingFidelity.partial);
        expect(result.details, contains(contains('stroom.legacy')));
        expect(restored.sourceExtensionData, neutral.extensions);
      },
    );

    test(
      'legacy raw request and response move to bounded redacted diagnostics',
      () {
        final legacy = ChatMessage(
          id: 'diagnostic-message',
          role: 'assistant',
          content: 'done',
          rawRequest: {
            'prompt': 'hello',
            'headers': {
              'Authorization': 'Bearer private-token',
              'content-type': 'application/json',
            },
            'api_key': 'private-key',
          },
          rawResponse: {'finish_reason': 'stop'},
        );

        final neutral = StroomMessage.fromLegacy(legacy, sequence: 0);
        final restored = StroomMessage.fromMap(neutral.toMap());

        expect(restored.diagnostics?.rawRequest?['prompt'], 'hello');
        expect(restored.diagnostics?.rawRequest?['headers'], {
          'content-type': 'application/json',
        });
        expect(restored.diagnostics?.rawRequest, isNot(contains('api_key')));
        expect(restored.diagnostics?.rawResponse, {'finish_reason': 'stop'});
        expect(
          restored.extensions['stroom.legacy'],
          isNot(contains('rawRequest')),
        );
        expect(
          restored.diagnostics!.toMap().toString().length,
          lessThanOrEqualTo(StroomMessageDiagnostics.maxSerializedBytes),
        );
        expect(
          utf8.encode(jsonEncode(restored.diagnostics!.toMap())).length,
          lessThanOrEqualTo(StroomMessageDiagnostics.maxSerializedBytes),
        );
      },
    );

    test('oversized diagnostic payloads are omitted', () {
      final legacy = ChatMessage(
        id: 'large-diagnostic-message',
        role: 'assistant',
        content: 'done',
        rawRequest: {
          'request': List<String>.filled(
            StroomMessageDiagnostics.maxSerializedBytes,
            'x',
          ).join(),
        },
      );

      final neutral = StroomMessage.fromLegacy(legacy, sequence: 0);
      expect(neutral.diagnostics?.rawRequest, isNull);
    });

    test('canonical message round trips ordered modalities and extensions', () {
      final conversation = StroomConversation(
        id: 'neutral-c',
        title: 'Mixed media',
        messages: [
          StroomMessage(
            id: 'neutral-m',
            role: 'assistant',
            sequence: 4,
            createdAt: DateTime.utc(2025, 1, 1),
            extraFields: {
              'futureMessageKey': {'keep': 'yes'},
            },
            content: [
              StroomContentPart(type: 'text', data: {'text': 'look'}),
              StroomContentPart(type: 'image', data: {'ref': 'media:image-1'}),
              StroomContentPart(type: 'audio', data: {'ref': 'media:audio-2'}),
              StroomContentPart(type: 'video', data: {'ref': 'media:video-3'}),
              StroomContentPart(
                type: 'file',
                data: {'ref': 'media:file-4'},
                extraFields: {'vendor': 'file-annotation'},
              ),
              StroomContentPart(type: 'citation', data: {'uri': 'opaque:ref'}),
            ],
            extensions: {
              'openai.responses': {
                'version': '2025-03-01',
                'items': [
                  {
                    'type': 'reasoning',
                    'id': 'rs_1',
                    'summary': ['private'],
                  },
                ],
              },
              'future.extension': {
                'unknown': [1, 2, 3],
              },
            },
          ),
        ],
      );

      final json = conversation.toJson();
      final restored = StroomConversation.fromJson(json);
      expect(restored.schemaVersion, 1);
      expect(restored.messages.single.sequence, 4);
      expect(restored.messages.single.extraFields, {
        'futureMessageKey': {'keep': 'yes'},
      });
      expect(restored.messages.single.content.map((part) => part.type), [
        'text',
        'image',
        'audio',
        'video',
        'file',
        'citation',
      ]);
      expect(restored.messages.single.extensions['future.extension'], {
        'unknown': [1, 2, 3],
      });
      expect(restored.messages.single.content[4].extraFields, {
        'vendor': 'file-annotation',
      });
      expect(restored.toJson(), json);
    });

    test(
      'four independent bridge formats round trip payloads and stream events',
      () {
        final fixtures = <ProtocolBridge>[
          OpenAiChatCompletionsBridge(),
          OpenAiResponsesBridge(),
          AnthropicMessagesBridge(),
          GeminiBridge(),
        ];
        final payload = <String, dynamic>{
          'provider_unknown': {
            'keep': ['all', 'values'],
          },
          'messages': [
            {
              'role': 'assistant',
              'content': [
                {'type': 'refusal', 'text': 'no'},
              ],
            },
          ],
        };
        final events = [
          ProtocolStreamEvent(
            type: 'content.delta',
            sequence: 0,
            payload: {'text': 'hello'},
          ),
          ProtocolStreamEvent(
            type: 'terminal',
            sequence: 1,
            payload: {
              'finishReason': 'stop',
              'usage': {'output': 1},
            },
            extraFields: {
              'futureEventField': {'keep': true},
            },
          ),
        ];

        for (final bridge in fixtures) {
          final encoded = bridge.encode(
            ProtocolBridgeExchange(
              payload: payload,
              events: events,
              extensions: [
                ProtocolExtension(
                  protocolId: bridge.protocolId,
                  version: bridge.contractVersion,
                  type: 'future.block',
                  data: {
                    'opaque': {'keep': true},
                  },
                  extraFields: {'futureEnvelopeKey': 'keep'},
                ),
              ],
            ),
          );
          encoded['futureTopLevelField'] = {'keep': 'all'};
          final decoded = bridge.decode(encoded);
          expect(decoded.payload, payload, reason: bridge.protocolId);
          expect(
            decoded.events.map((event) => event.toJson()).toList(),
            events.map((event) => event.toJson()).toList(),
            reason: bridge.protocolId,
          );
          expect(decoded.events.last.extraFields, {
            'futureEventField': {'keep': true},
          });
          expect(decoded.extensions.single.data, {
            'opaque': {'keep': true},
          });
          expect(decoded.extensions.single.extraFields, {
            'futureEnvelopeKey': 'keep',
          });
          expect(bridge.encode(decoded)['futureTopLevelField'], {
            'keep': 'all',
          }, reason: bridge.protocolId);
        }
      },
    );

    test('bridge envelopes preserve future schema and contract versions', () {
      final bridge = OpenAiChatCompletionsBridge();
      final envelope = bridge.encode(
        ProtocolBridgeExchange(payload: {'messages': []}),
      )
        ..['bridgeSchemaVersion'] = 2
        ..['contractVersion'] = '2';

      final roundTripped = bridge.encode(bridge.decode(envelope));

      expect(roundTripped['bridgeSchemaVersion'], 2);
      expect(roundTripped['contractVersion'], '2');
    });

    test('each protocol parser round trips its own wire message exactly', () {
      final messages = <ProtocolBridge, Map<String, dynamic>>{
        OpenAiChatCompletionsBridge(): {
          'role': 'assistant',
          'content': 'Hello',
          'provider_field': {'keep': true},
        },
        OpenAiResponsesBridge(): {
          'id': 'resp_1',
          'status': 'completed',
          'output': [
            {
              'type': 'message',
              'role': 'assistant',
              'content': [
                {'type': 'output_text', 'text': 'Hello'},
              ],
            },
          ],
        },
        AnthropicMessagesBridge(): {
          'role': 'assistant',
          'content': [
            {'type': 'text', 'text': 'Hello'},
          ],
          'stop_reason': 'end_turn',
        },
        GeminiBridge(): {
          'candidates': [
            {
              'content': {
                'role': 'model',
                'parts': [
                  {'text': 'Hello'},
                ],
              },
              'finishReason': 'STOP',
            },
          ],
        },
      };

      for (final entry in messages.entries) {
        final parsed = entry.key.parseMessage(
          entry.value,
          id: 'message-${entry.key.protocolId}',
          sequence: 2,
          createdAt: DateTime.utc(2025, 1, 1),
        );
        final result = entry.key.serializeMessage(parsed);
        expect(
          result.fidelity,
          MappingFidelity.exact,
          reason: entry.key.protocolId,
        );
        expect(result.targetPayload, entry.value, reason: entry.key.protocolId);
      }
    });

    test('same-protocol serialization uses edited neutral content', () {
      final bridge = OpenAiResponsesBridge();
      final parsed = bridge.parseMessage(
        {
          'status': 'completed',
          'output': [
            {
              'type': 'message',
              'role': 'assistant',
              'content': [
                {'type': 'output_text', 'text': 'before'},
              ],
            },
          ],
        },
        id: 'edited-response',
        sequence: 0,
        createdAt: DateTime.utc(2025),
      );
      final edited = StroomMessage(
        id: parsed.id,
        role: parsed.role,
        sequence: parsed.sequence,
        createdAt: parsed.createdAt,
        content: [StroomContentPart.text('after')],
        status: parsed.status,
        finishReason: parsed.finishReason,
        usage: parsed.usage,
        extensions: parsed.extensions,
      );

      final result = bridge.serializeMessage(edited);
      final output = result.targetPayload!['output'] as List;

      expect(output.single['content'].single['text'], 'after');
      expect(result.fidelity, MappingFidelity.partial);
      expect(result.details, contains(contains('message changed')));
      expect(result.sourceExtension?.data['wireMessage'], isNotNull);
    });

    test('Chat Completions serializes tool arguments as JSON strings', () {
      final bridge = OpenAiChatCompletionsBridge();
      final message = StroomMessage(
        id: 'chat-tool-call',
        role: 'assistant',
        sequence: 0,
        createdAt: DateTime.utc(2025),
        content: [
          StroomContentPart.toolCall(
            id: 'call_1',
            name: 'lookup',
            arguments: {'query': 'one'},
          ),
        ],
      );

      final result = bridge.serializeMessage(message);

      expect(
        ((result.targetPayload!['tool_calls'] as List).single
            as Map)['function']['arguments'],
        '{"query":"one"}',
      );
    });

    test('Responses serializes new tool arguments as JSON strings', () {
      final message = StroomMessage(
        id: 'responses-tool-call',
        role: 'assistant',
        sequence: 0,
        createdAt: DateTime.utc(2025),
        content: [
          StroomContentPart.toolCall(
            id: 'call_1',
            name: 'lookup',
            arguments: {'query': 'one'},
          ),
        ],
      );

      final result = OpenAiResponsesBridge().serializeMessage(message);

      expect(
        (result.targetPayload!['output'] as List).single['arguments'],
        '{"query":"one"}',
      );
    });

    test('Responses output maps non-assistant roles and reports partial', () {
      final message = StroomMessage(
        id: 'responses-user-output',
        role: 'user',
        sequence: 0,
        createdAt: DateTime.utc(2025),
        content: [StroomContentPart.text('input')],
      );

      final result = OpenAiResponsesBridge().serializeMessage(message);
      final output = result.targetPayload!['output'] as List;

      expect(output.single['role'], 'assistant');
      expect(result.fidelity, MappingFidelity.partial);
      expect(result.details, contains(contains('role')));
    });

    test('Responses reports lost tool-result error state', () {
      final message = StroomMessage(
        id: 'responses-tool-error',
        role: 'assistant',
        sequence: 0,
        createdAt: DateTime.utc(2025),
        content: [
          StroomContentPart.toolResult(
            toolCallId: 'call_1',
            result: 'tool failed',
            isError: true,
          ),
        ],
      );

      final result = OpenAiResponsesBridge().serializeMessage(message);

      expect(result.fidelity, MappingFidelity.partial);
      expect(result.details, contains(contains('error')));
      expect(
        (result.targetPayload!['output'] as List).single['output'],
        'tool failed',
      );
    });

    test('Chat Completions preserves neutral refusal parts', () {
      final bridge = OpenAiChatCompletionsBridge();
      final message = StroomMessage(
        id: 'chat-refusal',
        role: 'assistant',
        sequence: 0,
        createdAt: DateTime.utc(2025),
        content: [StroomContentPart.refusal('I cannot help with that.')],
      );

      final result = bridge.serializeMessage(message);

      expect(result.fidelity, MappingFidelity.exact);
      expect(result.targetPayload?['refusal'], 'I cannot help with that.');
    });

    test('Chat Completions preserves ordered neutral image references', () {
      final message = StroomMessage(
        id: 'chat-image-content',
        role: 'user',
        sequence: 0,
        createdAt: DateTime.utc(2025),
        content: [
          StroomContentPart.text('before'),
          StroomContentPart.image(
            reference: 'https://cdn.example/photo.png',
            detail: 'high',
          ),
          StroomContentPart.text('after'),
        ],
      );

      final result = OpenAiChatCompletionsBridge().serializeMessage(message);

      expect(result.targetPayload!['content'], [
        {'type': 'text', 'text': 'before'},
        {
          'type': 'image_url',
          'image_url': {
            'url': 'https://cdn.example/photo.png',
            'detail': 'high',
          },
        },
        {'type': 'text', 'text': 'after'},
      ]);
      expect(result.fidelity, MappingFidelity.exact);
    });

    test('Chat image_url parts normalize and survive edited serialization', () {
      final source = OpenAiChatCompletionsBridge();
      final original = {
        'role': 'user',
        'content': [
          {'type': 'text', 'text': 'before'},
          {
            'type': 'image_url',
            'image_url': {
              'url': 'https://cdn.example/photo.png',
              'detail': 'high',
              'future_image_config': {'keep': true},
            },
          },
          {'type': 'text', 'text': 'after'},
        ],
      };
      final parsed = source.parseMessage(
        original,
        id: 'chat-image-url-source',
        sequence: 0,
      );
      final edited = StroomMessage(
        id: parsed.id,
        role: parsed.role,
        sequence: parsed.sequence,
        createdAt: parsed.createdAt,
        content: [
          StroomContentPart.text('edited'),
          parsed.content[1],
          parsed.content[2],
        ],
        extensions: parsed.extensions,
      );

      expect(parsed.content[1].type, 'image');
      expect(
        parsed.content[1].extraFields['openai.chat_completions.image_url'],
        {'future_image_config': {'keep': true}},
      );
      final translated = source.serializeMessage(edited);

      expect(translated.targetPayload!['content'], [
        {'type': 'text', 'text': 'edited'},
        {
          'type': 'image_url',
          'image_url': {
            'url': 'https://cdn.example/photo.png',
            'detail': 'high',
            'future_image_config': {'keep': true},
          },
        },
        {'type': 'text', 'text': 'after'},
      ]);
      expect(translated.fidelity, MappingFidelity.partial);
      expect(
        translated.details,
        isNot(contains(contains('image_url'))),
      );
      expect(translated.sourceExtension?.data['wireMessage'], original);
    });

    test('Chat text part annotations survive as partial source extensions', () {
      final source = OpenAiChatCompletionsBridge();
      final original = {
        'role': 'user',
        'content': [
          {'type': 'text', 'text': 'hello', 'future_annotation': 'keep'},
        ],
      };
      final parsed = source.parseMessage(
        original,
        id: 'chat-text-part-extra',
        sequence: 0,
      );

      expect(parsed.content.single.type, 'text');
      expect(parsed.content.single.data['text'], 'hello');
      expect(parsed.content.single.extraFields['future_annotation'], 'keep');
      final translated = GeminiBridge().serializeMessage(parsed);

      expect(translated.fidelity, MappingFidelity.partial);
      expect(translated.details, contains(contains('future_annotation')));
      expect(translated.sourceExtension?.data['wireMessage'], original);
    });

    test('Gemini multi-candidate source reports partial fidelity', () {
      final source = GeminiBridge();
      final target = OpenAiChatCompletionsBridge();
      final original = {
        'candidates': [
          {
            'content': {
              'role': 'model',
              'parts': [
                {'text': 'first'},
              ],
            },
            'finishReason': 'STOP',
          },
          {
            'content': {
              'role': 'model',
              'parts': [
                {'text': 'second'},
              ],
            },
            'finishReason': 'STOP',
          },
        ],
      };
      final parsed = source.parseMessage(
        original,
        id: 'gemini-candidates',
        sequence: 0,
      );

      final translated = target.serializeMessage(parsed);

      expect(translated.fidelity, MappingFidelity.partial);
      expect(translated.details, contains(contains('candidate')));
      expect(translated.sourceExtension?.data['wireMessage'], original);
    });

    test('Gemini function-call extras report partial fidelity', () {
      final source = GeminiBridge();
      final target = OpenAiChatCompletionsBridge();
      final original = {
        'candidates': [
          {
            'content': {
              'role': 'model',
              'parts': [
                {
                  'functionCall': {
                    'id': 'call_1',
                    'name': 'lookup',
                    'args': {'query': 'one'},
                    'future_call_field': {'keep': true},
                  },
                },
              ],
            },
          },
        ],
      };
      final parsed = source.parseMessage(
        original,
        id: 'gemini-function-extra',
        sequence: 0,
      );

      final translated = target.serializeMessage(parsed);

      expect(translated.fidelity, MappingFidelity.partial);
      expect(translated.details, contains(contains('future_call_field')));
      expect(translated.sourceExtension?.data['wireMessage'], original);
    });

    test(
      'Responses text annotations report partial cross-protocol fidelity',
      () {
        final source = OpenAiResponsesBridge();
        final target = OpenAiChatCompletionsBridge();
        final original = {
          'status': 'completed',
          'output': [
            {
              'type': 'message',
              'role': 'assistant',
              'content': [
                {
                  'type': 'output_text',
                  'text': 'answer',
                  'annotations': [
                    {'type': 'url_citation', 'url': 'https://example.com'},
                  ],
                },
              ],
            },
          ],
        };
        final parsed = source.parseMessage(
          original,
          id: 'responses-annotations',
          sequence: 0,
        );

        final translated = target.serializeMessage(parsed);

        expect(translated.fidelity, MappingFidelity.partial);
        expect(translated.details, contains(contains('annotations')));
        expect(translated.sourceExtension?.data['wireMessage'], original);
      },
    );

    test('Responses message item extras report partial fidelity', () {
      final source = OpenAiResponsesBridge();
      final original = {
        'output': [
          {
            'type': 'message',
            'role': 'assistant',
            'content': [
              {'type': 'output_text', 'text': 'answer'},
            ],
            'future_item_field': {'keep': true},
          },
        ],
      };
      final parsed = source.parseMessage(
        original,
        id: 'responses-message-item-extra',
        sequence: 0,
      );

      final translated = OpenAiChatCompletionsBridge().serializeMessage(parsed);

      expect(translated.fidelity, MappingFidelity.partial);
      expect(translated.details, contains(contains('future_item_field')));
      expect(translated.sourceExtension?.data['wireMessage'], original);
    });

    test('Responses reasoning metadata reports partial Anthropic fidelity', () {
      final source = OpenAiResponsesBridge();
      final target = AnthropicMessagesBridge();
      final original = {
        'status': 'completed',
        'output': [
          {
            'type': 'reasoning',
            'id': 'rs_1',
            'status': 'completed',
            'encrypted_content': 'opaque-reasoning',
            'summary': [
              {'type': 'summary_text', 'text': 'private thought'},
            ],
          },
        ],
      };
      final parsed = source.parseMessage(
        original,
        id: 'responses-reasoning-metadata',
        sequence: 0,
      );

      final translated = target.serializeMessage(parsed);

      expect(translated.targetPayload!['content'], [
        {'type': 'thinking', 'thinking': 'private thought'},
      ]);
      expect(translated.fidelity, MappingFidelity.partial);
      expect(translated.details, contains(contains('encrypted_content')));
      expect(translated.details, contains(contains('id')));
      expect(translated.sourceExtension?.data['wireMessage'], original);
    });

    test('Responses reasoning summary extras report partial fidelity', () {
      final source = OpenAiResponsesBridge();
      final original = {
        'status': 'completed',
        'output': [
          {
            'type': 'reasoning',
            'summary': [
              {
                'type': 'summary_text',
                'text': 'private thought',
                'future_annotation': {'source': 'new-api'},
              },
            ],
          },
        ],
      };
      final parsed = source.parseMessage(
        original,
        id: 'responses-reasoning-summary-extra',
        sequence: 0,
      );

      final translated = AnthropicMessagesBridge().serializeMessage(parsed);

      expect(translated.targetPayload!['content'], [
        {'type': 'thinking', 'thinking': 'private thought'},
      ]);
      expect(translated.fidelity, MappingFidelity.partial);
      expect(translated.details, contains(contains('future_annotation')));
      expect(translated.sourceExtension?.data['wireMessage'], original);
    });

    test('Anthropic tool-result extras report partial mapping fidelity', () {
      final source = AnthropicMessagesBridge();
      final original = {
        'role': 'user',
        'content': [
          {
            'type': 'tool_result',
            'tool_use_id': 'call_1',
            'content': {'ok': true},
            'cache_control': {'type': 'ephemeral'},
          },
        ],
      };
      final parsed = source.parseMessage(
        original,
        id: 'anthropic-tool-result-extra',
        sequence: 0,
      );

      final translated = GeminiBridge().serializeMessage(parsed);

      expect(translated.fidelity, MappingFidelity.partial);
      expect(translated.details, contains(contains('cache_control')));
      expect(translated.sourceExtension?.data['wireMessage'], original);
    });

    test(
      'Anthropic thinking extras report partial cross-protocol fidelity',
      () {
        final source = AnthropicMessagesBridge();
        final original = {
          'role': 'assistant',
          'content': [
            {
              'type': 'thinking',
              'thinking': 'private thought',
              'cache_control': {'type': 'ephemeral'},
            },
          ],
        };
        final parsed = source.parseMessage(
          original,
          id: 'anthropic-thinking-extra',
          sequence: 0,
        );

        final translated = OpenAiResponsesBridge().serializeMessage(parsed);

        expect(translated.fidelity, MappingFidelity.partial);
        expect(translated.details, contains(contains('cache_control')));
        expect(translated.sourceExtension?.data['wireMessage'], original);
      },
    );

    test(
      'Responses function-output extras report partial mapping fidelity',
      () {
        final source = OpenAiResponsesBridge();
        final original = {
          'status': 'completed',
          'output': [
            {
              'type': 'function_call_output',
              'call_id': 'call_1',
              'output': {'ok': true},
              'future_output_field': {'keep': true},
            },
          ],
        };
        final parsed = source.parseMessage(
          original,
          id: 'responses-function-output-extra',
          sequence: 0,
        );

        final translated = GeminiBridge().serializeMessage(parsed);

        expect(translated.fidelity, MappingFidelity.partial);
        expect(translated.details, contains(contains('future_output_field')));
        expect(translated.sourceExtension?.data['wireMessage'], original);
      },
    );

    test('Responses function-call extras report partial mapping fidelity', () {
      final source = OpenAiResponsesBridge();
      final original = {
        'status': 'completed',
        'output': [
          {
            'type': 'function_call',
            'call_id': 'call_1',
            'name': 'lookup',
            'arguments': '{"query":"one"}',
            'future_call_field': {'keep': true},
          },
        ],
      };
      final parsed = source.parseMessage(
        original,
        id: 'responses-function-call-extra',
        sequence: 0,
      );

      final translated = GeminiBridge().serializeMessage(parsed);

      expect(translated.fidelity, MappingFidelity.partial);
      expect(translated.details, contains(contains('future_call_field')));
      expect(translated.sourceExtension?.data['wireMessage'], original);
    });

    test('Gemini function-response extras report partial mapping fidelity', () {
      final source = GeminiBridge();
      final original = {
        'candidates': [
          {
            'content': {
              'role': 'tool',
              'parts': [
                {
                  'functionResponse': {
                    'id': 'call_1',
                    'response': {'ok': true},
                    'future_response_field': 'keep',
                  },
                },
              ],
            },
          },
        ],
      };
      final parsed = source.parseMessage(
        original,
        id: 'gemini-function-response-extra',
        sequence: 0,
      );

      final translated = OpenAiChatCompletionsBridge().serializeMessage(parsed);

      expect(translated.fidelity, MappingFidelity.partial);
      expect(translated.details, contains(contains('future_response_field')));
      expect(translated.sourceExtension?.data['wireMessage'], original);
    });

    test('Gemini function-response name survives when an id is present', () {
      final source = GeminiBridge();
      final original = {
        'candidates': [
          {
            'content': {
              'role': 'model',
              'parts': [
                {
                  'functionResponse': {
                    'id': 'call_1',
                    'name': 'lookup',
                    'response': {'ok': true},
                  },
                },
              ],
            },
          },
        ],
      };
      final parsed = source.parseMessage(
        original,
        id: 'gemini-function-response-name',
        sequence: 0,
        createdAt: DateTime.utc(2025),
      );

      final translated = OpenAiResponsesBridge().serializeMessage(parsed);

      expect(translated.fidelity, MappingFidelity.partial);
      expect(translated.details, contains(contains('name')));
      expect(translated.sourceExtension?.data['wireMessage'], original);
    });

    test('Gemini function responses serialize their tool name', () {
      final message = StroomMessage(
        id: 'named-gemini-result',
        role: 'assistant',
        sequence: 0,
        createdAt: DateTime.utc(2025),
        content: [
          StroomContentPart.toolResult(
            toolCallId: 'call_1',
            name: 'lookup',
            result: {'ok': true},
          ),
        ],
      );

      final result = GeminiBridge().serializeMessage(message);
      final parts =
          (result.targetPayload!['contents'] as List).single['parts'] as List;

      expect((parts.single as Map)['functionResponse'], {
        'id': 'call_1',
        'name': 'lookup',
        'response': {'ok': true},
      });
    });

    test('Gemini serializes neutral media references as fileData parts', () {
      final message = StroomMessage(
        id: 'gemini-media-reference',
        role: 'user',
        sequence: 0,
        createdAt: DateTime.utc(2026),
        content: [
          StroomContentPart.image(
            reference: 'gs://bucket/photo.png',
            mimeType: 'image/png',
          ),
          StroomContentPart.video(
            reference: 'gs://bucket/clip.mp4',
            mimeType: 'video/mp4',
          ),
          StroomContentPart.file(
            reference: 'gs://bucket/report.pdf',
            mimeType: 'application/pdf',
          ),
        ],
      );

      final translated = GeminiBridge().serializeMessage(message);

      expect(translated.targetPayload!['contents'], [
        {
          'role': 'user',
          'parts': [
            {
              'fileData': {
                'fileUri': 'gs://bucket/photo.png',
                'mimeType': 'image/png',
              },
            },
            {
              'fileData': {
                'fileUri': 'gs://bucket/clip.mp4',
                'mimeType': 'video/mp4',
              },
            },
            {
              'fileData': {
                'fileUri': 'gs://bucket/report.pdf',
                'mimeType': 'application/pdf',
              },
            },
          ],
        },
      ]);
      expect(translated.fidelity, MappingFidelity.exact);
    });

    test('Gemini omits unsupported canonical part shapes', () {
      final message = StroomMessage(
        id: 'gemini-unsupported-structured-output',
        role: 'assistant',
        sequence: 0,
        createdAt: DateTime.utc(2025),
        content: [
          StroomContentPart.structuredOutput(
            format: 'json',
            value: {'ok': true},
          ),
        ],
      );

      final result = GeminiBridge().serializeMessage(message);
      final parts =
          (result.targetPayload!['contents'] as List).single['parts'] as List;

      expect(result.fidelity, MappingFidelity.partial);
      expect(result.details, contains(contains('structured_output')));
      expect(parts, isEmpty);
    });

    test('Gemini reports malformed inline media as partial', () {
      final message = StroomMessage(
        id: 'gemini-malformed-inline-media',
        role: 'user',
        sequence: 0,
        createdAt: DateTime.utc(2025),
        content: [
          StroomContentPart(
            type: 'inline_media',
            data: {'futureShape': {'opaque': true}},
          ),
        ],
      );

      final result = GeminiBridge().serializeMessage(message);
      final parts =
          (result.targetPayload!['contents'] as List).single['parts'] as List;

      expect(result.fidelity, MappingFidelity.partial);
      expect(result.details, contains(contains('inline_media')));
      expect(parts, isEmpty);
    });

    test('Gemini candidate content extras report partial mapping fidelity', () {
      final source = GeminiBridge();
      final original = {
        'candidates': [
          {
            'content': {
              'role': 'model',
              'parts': [
                {'text': 'answer'},
              ],
              'future_config': {'keep': true},
            },
            'finishReason': 'STOP',
          },
        ],
      };
      final parsed = source.parseMessage(
        original,
        id: 'gemini-content-extra',
        sequence: 0,
      );

      final translated = OpenAiChatCompletionsBridge().serializeMessage(parsed);

      expect(translated.fidelity, MappingFidelity.partial);
      expect(translated.details, contains(contains('future_config')));
      expect(translated.sourceExtension?.data['wireMessage'], original);
    });

    test('constrained target roles map safely and report fidelity loss', () {
      final bridges = <ProtocolBridge>[
        AnthropicMessagesBridge(),
        GeminiBridge(),
      ];
      for (final role in ['system', 'developer']) {
        final message = StroomMessage(
          id: 'role-$role',
          role: role,
          sequence: 0,
          createdAt: DateTime.utc(2025),
          content: [StroomContentPart.text('instructions')],
        );

        for (final bridge in bridges) {
          final result = bridge.serializeMessage(message);
          final targetRole = bridge is GeminiBridge
              ? ((result.targetPayload!['contents'] as List).single
                    as Map)['role']
              : result.targetPayload!['role'];
          expect(targetRole, 'user', reason: '${bridge.protocolId}:$role');
          expect(
            result.fidelity,
            MappingFidelity.partial,
            reason: '${bridge.protocolId}:$role',
          );
          expect(result.details, contains(contains(role)));
        }
      }
    });

    test('Gemini text thought signature reports partial fidelity', () {
      final source = GeminiBridge();
      final target = OpenAiChatCompletionsBridge();
      final original = {
        'candidates': [
          {
            'content': {
              'role': 'model',
              'parts': [
                {'text': 'answer', 'thoughtSignature': 'opaque-signature'},
              ],
            },
            'finishReason': 'STOP',
          },
        ],
      };
      final parsed = source.parseMessage(
        original,
        id: 'gemini-thought-signature',
        sequence: 0,
      );

      final translated = target.serializeMessage(parsed);

      expect(translated.fidelity, MappingFidelity.partial);
      expect(translated.details, contains(contains('thoughtSignature')));
      expect(translated.sourceExtension?.data['wireMessage'], original);
    });

    test('Chat tool results report multiple and error result loss', () {
      final bridge = OpenAiChatCompletionsBridge();
      final message = StroomMessage(
        id: 'tool-result-loss',
        role: 'tool',
        sequence: 0,
        createdAt: DateTime.utc(2025),
        content: [
          StroomContentPart.toolResult(
            toolCallId: 'call_1',
            result: 'first error',
            isError: true,
          ),
          StroomContentPart.toolResult(
            toolCallId: 'call_2',
            result: 'second result',
          ),
        ],
      );

      final result = bridge.serializeMessage(message);

      expect(result.fidelity, MappingFidelity.partial);
      expect(result.details, contains(contains('multiple')));
      expect(result.details, contains(contains('error')));
      expect(result.targetPayload?['tool_call_id'], 'call_1');
    });

    test('Chat tool messages stringify structured results and report partial', () {
      final message = StroomMessage(
        id: 'chat-structured-tool-result',
        role: 'tool',
        sequence: 0,
        createdAt: DateTime.utc(2025),
        content: [
          StroomContentPart.toolResult(
            toolCallId: 'call_1',
            result: {'matches': 1},
          ),
        ],
      );

      final result = OpenAiChatCompletionsBridge().serializeMessage(message);

      expect(result.targetPayload!['content'], '{"matches":1}');
      expect(result.fidelity, MappingFidelity.partial);
      expect(result.details, contains(contains('structured')));
    });

    test('Chat Completions reports interleaved content order loss', () {
      final source = GeminiBridge();
      final original = {
        'candidates': [
          {
            'content': {
              'role': 'model',
              'parts': [
                {'text': 'before'},
                {
                  'functionCall': {
                    'id': 'call_1',
                    'name': 'lookup',
                    'args': {'query': 'one'},
                  },
                },
                {'text': 'after'},
              ],
            },
          },
        ],
      };
      final parsed = source.parseMessage(
        original,
        id: 'chat-order-loss',
        sequence: 0,
      );

      final translated = OpenAiChatCompletionsBridge().serializeMessage(parsed);

      expect(translated.fidelity, MappingFidelity.partial);
      expect(translated.details, contains(contains('order')));
      expect(translated.sourceExtension?.data['wireMessage'], original);
    });

    test('Chat Completions reports text-before-tool ordering loss', () {
      final message = StroomMessage(
        id: 'text-before-tool-call',
        role: 'assistant',
        sequence: 0,
        createdAt: DateTime.utc(2025),
        content: [
          StroomContentPart.text('first'),
          StroomContentPart.toolCall(
            id: 'call_1',
            name: 'lookup',
            arguments: const {},
          ),
        ],
      );

      final result = OpenAiChatCompletionsBridge().serializeMessage(message);

      expect(result.fidelity, MappingFidelity.partial);
      expect(result.details, contains(contains('order')));
    });

    test('Chat tool-role serialization reports dropped co-occurring parts', () {
      final message = StroomMessage(
        id: 'tool-result-with-text',
        role: 'tool',
        sequence: 0,
        createdAt: DateTime.utc(2025),
        content: [
          StroomContentPart.toolResult(toolCallId: 'call_1', result: 'result'),
          StroomContentPart.text('extra text'),
        ],
      );

      final result = OpenAiChatCompletionsBridge().serializeMessage(message);

      expect(result.fidelity, MappingFidelity.partial);
      expect(result.details, contains(contains('text')));
    });

    test('Anthropic and Gemini serialize tool results with valid roles', () {
      final bridges = <ProtocolBridge>[
        AnthropicMessagesBridge(),
        GeminiBridge(),
      ];
      final message = StroomMessage(
        id: 'tool-role-cross-protocol',
        role: 'tool',
        sequence: 0,
        createdAt: DateTime.utc(2025),
        content: [
          StroomContentPart.toolResult(
            toolCallId: 'call_1',
            result: {'ok': true},
          ),
        ],
      );

      for (final bridge in bridges) {
        final result = bridge.serializeMessage(message);
        final role = bridge is GeminiBridge
            ? ((result.targetPayload!['contents'] as List).single
                  as Map)['role']
            : result.targetPayload!['role'];
        expect(role, 'user', reason: bridge.protocolId);
        expect(
          result.fidelity,
          MappingFidelity.partial,
          reason: bridge.protocolId,
        );
        expect(result.details, contains(contains('role')));
      }
    });

    test('Gemini reports tool-result error loss', () {
      final bridge = GeminiBridge();
      final message = StroomMessage(
        id: 'gemini-tool-error',
        role: 'tool',
        sequence: 0,
        createdAt: DateTime.utc(2025),
        content: [
          StroomContentPart.toolResult(
            toolCallId: 'call_1',
            result: {'message': 'failed'},
            isError: true,
          ),
        ],
      );

      final result = bridge.serializeMessage(message);

      expect(result.fidelity, MappingFidelity.partial);
      expect(result.details, contains(contains('error')));
    });

    test('Responses serialization preserves interleaved content order', () {
      final bridge = OpenAiResponsesBridge();
      final message = StroomMessage(
        id: 'ordered-responses',
        role: 'assistant',
        sequence: 0,
        createdAt: DateTime.utc(2025),
        content: [
          StroomContentPart.reasoning('first thought'),
          StroomContentPart.text('answer'),
          StroomContentPart.reasoning('last thought'),
        ],
      );

      final result = bridge.serializeMessage(message);

      expect(result.fidelity, MappingFidelity.exact);
      expect(
        (result.targetPayload!['output'] as List)
            .map((item) => (item as Map)['type'])
            .toList(),
        ['reasoning', 'message', 'reasoning'],
      );
    });

    test('Anthropic serialization maps reasoning to thinking blocks', () {
      final bridge = AnthropicMessagesBridge();
      final message = StroomMessage(
        id: 'anthropic-thinking',
        role: 'assistant',
        sequence: 0,
        createdAt: DateTime.utc(2025),
        content: [
          StroomContentPart(
            type: 'reasoning',
            data: {'text': 'private thought', 'signature': 'opaque-sig'},
          ),
        ],
      );

      final result = bridge.serializeMessage(message);

      expect(result.fidelity, MappingFidelity.exact);
      expect(result.targetPayload!['content'], [
        {
          'type': 'thinking',
          'thinking': 'private thought',
          'signature': 'opaque-sig',
        },
      ]);
    });

    test('Anthropic omits unsupported canonical block types', () {
      final message = StroomMessage(
        id: 'anthropic-unsupported-structured-output',
        role: 'assistant',
        sequence: 0,
        createdAt: DateTime.utc(2025),
        content: [
          StroomContentPart.structuredOutput(
            format: 'json',
            value: {'ok': true},
          ),
        ],
      );

      final result = AnthropicMessagesBridge().serializeMessage(message);

      expect(result.fidelity, MappingFidelity.partial);
      expect(result.details, contains(contains('structured_output')));
      expect(result.targetPayload!['content'], isEmpty);
    });

    test('cross-protocol loss is partial and retains source extension', () {
      final source = OpenAiChatCompletionsBridge();
      final target = AnthropicMessagesBridge();
      final parsed = source.parseMessage(
        {
          'role': 'assistant',
          'content': 'I cannot help with that request.',
          'refusal': 'policy',
          'provider_field': {'keep': true},
        },
        id: 'cross-message',
        sequence: 0,
      );

      final translated = target.serializeMessage(parsed);
      expect(translated.fidelity, MappingFidelity.partial);
      expect(translated.details, isNotEmpty);
      expect(translated.sourceProtocolId, source.protocolId);
      expect(translated.sourceExtension?.data['wireMessage'], {
        'role': 'assistant',
        'content': 'I cannot help with that request.',
        'refusal': 'policy',
        'provider_field': {'keep': true},
      });
      expect(translated.targetPayload?['content'], isA<List>());
    });

    test('same-protocol mapping selects its extension among multiple formats', () {
      final anthropic = AnthropicMessagesBridge().parseMessage(
        {
          'role': 'assistant',
          'content': [
            {'type': 'text', 'text': 'hello'},
          ],
        },
        id: 'multi-protocol-extension',
        sequence: 0,
      );
      final responses = OpenAiResponsesBridge().parseMessage(
        {
          'type': 'message',
          'role': 'assistant',
          'content': [
            {'type': 'output_text', 'text': 'hello'},
          ],
        },
        id: 'multi-protocol-extension',
        sequence: 0,
      );
      final restored = StroomMessage.fromMap(
        responses.toMap()
          ..['extensions'] = {
            'anthropic.messages': anthropic.extensions['anthropic.messages'],
            'openai.responses': responses.extensions['openai.responses'],
          },
      );

      final result = OpenAiResponsesBridge().serializeMessage(restored);

      expect(result.fidelity, MappingFidelity.exact);
      expect(result.sourceProtocolId, 'openai.responses');
      expect(result.targetPayload, {
        'type': 'message',
        'role': 'assistant',
        'content': [
          {'type': 'output_text', 'text': 'hello'},
        ],
      });
    });

    test(
      'Anthropic thinking maps to Responses with signature loss reported',
      () {
        final source = AnthropicMessagesBridge();
        final target = OpenAiResponsesBridge();
        final original = {
          'role': 'assistant',
          'content': [
            {
              'type': 'thinking',
              'thinking': 'private thought',
              'signature': 'opaque-signature',
            },
          ],
        };
        final parsed = source.parseMessage(
          original,
          id: 'thinking-cross-protocol',
          sequence: 0,
        );

        final translated = target.serializeMessage(parsed);

        expect(translated.targetPayload!['output'], [
          {
            'type': 'reasoning',
            'summary': ['private thought'],
          },
        ]);
        expect(translated.fidelity, MappingFidelity.partial);
        expect(translated.details, contains(contains('signature')));
        expect(translated.sourceExtension?.data['wireMessage'], original);
      },
    );

    test('known unmapped Anthropic fields report partial fidelity', () {
      final source = AnthropicMessagesBridge();
      final target = OpenAiResponsesBridge();
      final original = {
        'role': 'assistant',
        'content': [
          {'type': 'text', 'text': 'done'},
        ],
        'stop_sequence': 'CUSTOM_STOP',
      };
      final parsed = source.parseMessage(
        original,
        id: 'stop-sequence',
        sequence: 0,
      );

      final translated = target.serializeMessage(parsed);

      expect(translated.fidelity, MappingFidelity.partial);
      expect(translated.details, contains(contains('stop_sequence')));
      expect(translated.sourceExtension?.data['wireMessage'], original);
    });

    test('Anthropic string content survives cross-protocol mapping', () {
      final source = AnthropicMessagesBridge();
      final original = {'role': 'assistant', 'content': 'hello'};
      final parsed = source.parseMessage(
        original,
        id: 'anthropic-string-content',
        sequence: 0,
        createdAt: DateTime.utc(2025),
      );

      final translated = OpenAiResponsesBridge().serializeMessage(parsed);

      expect(parsed.content.single.data['text'], 'hello');
      expect(translated.fidelity, MappingFidelity.exact);
      expect(translated.targetPayload!['output'], [
        {
          'type': 'message',
          'role': 'assistant',
          'content': [
            {'type': 'output_text', 'text': 'hello'},
          ],
        },
      ]);
    });

    test('unmapped nested tool call fields report partial fidelity', () {
      final source = OpenAiChatCompletionsBridge();
      final target = GeminiBridge();
      final original = {
        'role': 'assistant',
        'content': null,
        'tool_calls': [
          {
            'id': 'call_1',
            'type': 'function',
            'future_call_field': {'keep': true},
            'function': {
              'name': 'lookup',
              'arguments': {'query': 'one'},
            },
          },
        ],
      };
      final parsed = source.parseMessage(
        original,
        id: 'nested-call-fields',
        sequence: 0,
      );

      final translated = target.serializeMessage(parsed);

      expect(translated.fidelity, MappingFidelity.partial);
      expect(translated.details, contains(contains('future_call_field')));
      expect(translated.sourceExtension?.data['wireMessage'], original);
    });

    test(
      'Anthropic text block extras report partial cross-protocol fidelity',
      () {
        final source = AnthropicMessagesBridge();
        final target = OpenAiResponsesBridge();
        final original = {
          'role': 'assistant',
          'content': [
            {
              'type': 'text',
              'text': 'cached answer',
              'cache_control': {'type': 'ephemeral'},
            },
          ],
        };
        final parsed = source.parseMessage(
          original,
          id: 'text-block-extra',
          sequence: 0,
        );

        final translated = target.serializeMessage(parsed);

        expect(translated.fidelity, MappingFidelity.partial);
        expect(translated.details, contains(contains('cache_control')));
        expect(translated.sourceExtension?.data['wireMessage'], original);
      },
    );

    test(
      'Anthropic tool-use extras report partial cross-protocol fidelity',
      () {
        final source = AnthropicMessagesBridge();
        final target = GeminiBridge();
        final original = {
          'role': 'assistant',
          'content': [
            {
              'type': 'tool_use',
              'id': 'tool_1',
              'name': 'lookup',
              'input': {'query': 'one'},
              'cache_control': {'type': 'ephemeral'},
            },
          ],
        };
        final parsed = source.parseMessage(
          original,
          id: 'tool-use-extra',
          sequence: 0,
        );

        final translated = target.serializeMessage(parsed);

        expect(translated.fidelity, MappingFidelity.partial);
        expect(translated.details, contains(contains('cache_control')));
        expect(translated.sourceExtension?.data['wireMessage'], original);
      },
    );

    test('opaque tool arguments report partial cross-protocol fidelity', () {
      final source = OpenAiChatCompletionsBridge();
      final target = GeminiBridge();
      final original = {
        'role': 'assistant',
        'content': null,
        'tool_calls': [
          {
            'id': 'call_opaque',
            'type': 'function',
            'function': {'name': 'lookup', 'arguments': '{malformed-json'},
          },
        ],
      };
      final parsed = source.parseMessage(
        original,
        id: 'opaque-tool-arguments',
        sequence: 0,
      );

      final translated = target.serializeMessage(parsed);

      expect(translated.fidelity, MappingFidelity.partial);
      expect(translated.details, contains(contains('arguments')));
      expect(translated.sourceExtension?.data['wireMessage'], original);
    });

    test('cross-protocol metadata loss cannot be reported as exact', () {
      final source = OpenAiChatCompletionsBridge();
      final target = GeminiBridge();
      final parsed = source.parseMessage(
        {
          'role': 'assistant',
          'content': 'Hello',
          'finish_reason': 'stop',
          'usage': {'completion_tokens': 1},
        },
        id: 'metadata-message',
        sequence: 0,
      );

      final translated = target.serializeMessage(parsed);
      expect(translated.fidelity, MappingFidelity.partial);
      expect(translated.details, contains(contains('finish reason')));
      expect(translated.details, contains(contains('usage')));
      expect(translated.sourceProtocolId, source.protocolId);
      expect(translated.sourceExtension?.data['wireMessage'], {
        'role': 'assistant',
        'content': 'Hello',
        'finish_reason': 'stop',
        'usage': {'completion_tokens': 1},
      });
    });

    test(
      'Responses does not map generic finish reason to incomplete status',
      () {
        final source = OpenAiChatCompletionsBridge();
        final parsed = source.parseMessage(
          {'role': 'assistant', 'content': 'done', 'finish_reason': 'stop'},
          id: 'completed-finish-reason',
          sequence: 0,
          createdAt: DateTime.utc(2025),
        );

        final translated = OpenAiResponsesBridge().serializeMessage(parsed);

        expect(translated.fidelity, MappingFidelity.partial);
        expect(translated.details, contains(contains('finish reason')));
        expect(translated.targetPayload, isNot(contains('incomplete_details')));
        expect(translated.sourceExtension?.data['wireMessage'], isNotNull);
      },
    );

    test(
      'unknown source wire fields report partial cross-protocol fidelity',
      () {
        final source = OpenAiChatCompletionsBridge();
        final target = GeminiBridge();
        final parsed = source.parseMessage(
          {
            'role': 'assistant',
            'content': 'Hello',
            'provider_field': {
              'future': [1, 2],
            },
          },
          id: 'unknown-field-message',
          sequence: 0,
        );

        final translated = target.serializeMessage(parsed);
        expect(translated.fidelity, MappingFidelity.partial);
        expect(translated.details, contains(contains('provider_field')));
        expect(
          translated.sourceExtension?.data['wireMessage'],
          containsPair('provider_field', {
            'future': [1, 2],
          }),
        );
      },
    );

    test(
      'unknown Responses output items remain visible to mapping fidelity',
      () {
        final source = OpenAiResponsesBridge();
        final target = AnthropicMessagesBridge();
        final parsed = source.parseMessage(
          {
            'output': [
              {
                'type': 'message',
                'role': 'assistant',
                'content': [
                  {'type': 'output_text', 'text': 'Hello'},
                ],
              },
              {
                'type': 'future_item',
                'id': 'item_future',
                'custom': {'keep': true},
              },
            ],
          },
          id: 'unknown-response-item',
          sequence: 0,
        );

        final translated = target.serializeMessage(parsed);
        expect(translated.fidelity, MappingFidelity.partial);
        expect(translated.details, contains(contains('unknown')));
        expect(parsed.content.map((part) => part.type), ['text', 'unknown']);
        expect(
          translated.sourceExtension?.data['wireMessage'],
          containsPair('output', isA<List>()),
        );
      },
    );

    test('same-protocol unknown Responses items remain exact', () {
      final bridge = OpenAiResponsesBridge();
      final original = {
        'output': [
          {
            'type': 'future_item',
            'id': 'future_1',
            'custom': {'keep': true},
          },
        ],
      };
      final parsed = bridge.parseMessage(
        original,
        id: 'same-protocol-future-item',
        sequence: 0,
        createdAt: DateTime.utc(2025),
      );

      final result = bridge.serializeMessage(parsed);

      expect(result.fidelity, MappingFidelity.exact);
      expect(result.targetPayload, original);
    });

    test(
      'partial mapping keeps source protocol extension and explains losses',
      () {
        final result = ProtocolMappingResult(
          fidelity: MappingFidelity.partial,
          details: ['target cannot represent the source signature field'],
          direction: 'anthropic.messages->openai.responses',
          sourceProtocolId: 'anthropic.messages',
          targetProtocolId: 'openai.responses',
          sourceExtension: ProtocolExtension(
            protocolId: 'anthropic.messages',
            version: '2025-01-01',
            type: 'thinking.signature',
            data: {'signature': 'opaque-signature'},
          ),
        );
        final restored = ProtocolMappingResult.fromJson(result.toJson());
        expect(restored.fidelity, MappingFidelity.partial);
        expect(
          restored.details.single,
          'target cannot represent the source signature field',
        );
        expect(restored.sourceProtocolId, 'anthropic.messages');
        expect(restored.targetProtocolId, 'openai.responses');
        expect(restored.sourceExtension?.data, {
          'signature': 'opaque-signature',
        });
      },
    );
  });
}
