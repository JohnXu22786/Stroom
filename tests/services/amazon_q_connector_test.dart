import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:stroom/ai_gateway/ai_gateway_contracts.dart';
import 'package:stroom/ai_gateway/ai_gateway_protocol_bridges.dart';
import 'package:stroom/models/stroom_conversation.dart';
import 'package:stroom/services/amazon_q_connector.dart';
import 'package:stroom/services/llm_connector_service.dart';
import 'package:stroom/services/llm_oauth_flow.dart';
import 'package:stroom/providers/llm_routed_chat_provider.dart';

void main() {
  group('Amazon Q Developer connector', () {
    test('registers Amazon Q OAuth separately from Bedrock and Kiro', () {
      final connector = LlmConnectorRegistry.find('amazon-q');

      expect(connector?.displayName, 'Amazon Q Developer');
      expect(connector?.authTypes, contains('oauth'));
      expect(connector?.protocol, LlmNativeProtocol.amazonQChat);
      expect(LlmConnectorRegistry.find('bedrock')?.id, 'bedrock');
      expect(LlmConnectorRegistry.find('kiro'), isNull);
      expect(LlmOAuthProviderPolicy.forProvider('amazon-q').supported, isTrue);
    });

    test('keeps tool call and result history and rejects non-text inputs', () {
      final request = AmazonQConnector.buildChatRequest(
        modelId: 'claude-sonnet-4',
        accountId: 'account-a',
        conversationId: 'conversation-tools',
        messages: const [
          {'role': 'user', 'content': 'Check the weather.'},
          {
            'role': 'assistant',
            'content': null,
            'tool_calls': [
              {
                'id': 'call-1',
                'type': 'function',
                'function': {
                  'name': 'weather',
                  'arguments': '{"city":"Paris"}',
                },
              },
            ],
          },
          {'role': 'tool', 'tool_call_id': 'call-1', 'content': 'Sunny.'},
          {'role': 'user', 'content': 'Summarize that.'},
        ],
        tools: const [
          {
            'type': 'function',
            'function': {
              'name': 'weather',
              'description': 'Get weather.',
              'parameters': {
                'type': 'object',
                'properties': {
                  'city': {'type': 'string'},
                },
              },
            },
          },
        ],
      );
      final state = request['conversationState'] as Map;
      expect(state['history'], [
        {
          'userInputMessage': {
            'content': 'Check the weather.',
            'modelId': 'claude-sonnet-4',
            'origin': 'AI_EDITOR',
          },
        },
        {
          'assistantResponseMessage': {
            'toolUses': [
              {
                'toolUseId': 'call-1',
                'name': 'weather',
                'input': {'city': 'Paris'},
              },
            ],
          },
        },
      ]);
      final current = state['currentMessage'] as Map;
      final user = current['userInputMessage'] as Map;
      expect(user['content'], 'Summarize that.');
      expect(user['userInputMessageContext'], {
        'tools': [
          {
            'toolSpecification': {
              'name': 'weather',
              'description': 'Get weather.',
              'inputSchema': {
                'json': {
                  'type': 'object',
                  'properties': {
                    'city': {'type': 'string'},
                  },
                },
              },
            },
          },
        ],
        'toolResults': [
          {
            'toolUseId': 'call-1',
            'status': 'success',
            'content': [
              {'text': 'Sunny.'},
            ],
          },
        ],
      });
      expect(
        () => AmazonQConnector.buildChatRequest(
          modelId: 'claude-sonnet-4',
          conversationId: 'conversation-image',
          messages: const [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'image_url',
                  'image_url': 'https://example.test/image.png',
                },
              ],
            },
          ],
        ),
        throwsFormatException,
      );
    });

    test(
      'builds chat and model URLs only for documented Q profile regions',
      () {
        expect(
          AmazonQConnector.chatUri('us-east-1'),
          Uri.https('q.us-east-1.amazonaws.com', '/generateAssistantResponse'),
        );
        expect(
          AmazonQConnector.chatUri('eu-central-1'),
          Uri.https(
            'q.eu-central-1.amazonaws.com',
            '/generateAssistantResponse',
          ),
        );
        expect(
          () => AmazonQConnector.chatUri('evil.com/path'),
          throwsArgumentError,
        );
        expect(AmazonQConnector.modelsUri('us-east-1').queryParameters, {
          'origin': 'AI_EDITOR',
        });
      },
    );

    test('parses only source-listed account models as text chat models', () {
      final models = AmazonQConnector.parseModels({
        'models': [
          {'modelId': 'claude-sonnet-4', 'modelName': 'Claude Sonnet 4'},
          {'id': 'q-chat-basic'},
          {'modelId': ''},
        ],
      });

      expect(models.map((model) => model.upstreamModelId), [
        'claude-sonnet-4',
        'q-chat-basic',
      ]);
      expect(models.first.displayName, 'Claude Sonnet 4');
      expect(models.first.capabilities, {
        'chat': true,
        'streaming': true,
        'tools': true,
      });
      expect(models.first.config['catalogSource'], 'account-entitlement');
    });

    test(
      'normalizes refresh-token imports and rejects malformed credentials',
      () {
        expect(
          AmazonQConnector.parseCredentialImport(
            '{"refreshToken":"refresh","accessToken":"access"}',
          ),
          containsPair('refresh_token', 'refresh'),
        );
        expect(
          () => AmazonQConnector.parseCredentialImport('{"access_token":"x"}'),
          throwsFormatException,
        );
        expect(
          () => AmazonQConnector.parseCredentialImport(
            '{"refresh_token":"r","clientId":"only-half"}',
          ),
          throwsFormatException,
        );
      },
    );

    test(
      'routes Amazon Q Chat and Task Flow through its plain-text chat bridge',
      () {
        expect(llmRoutedChatSupportedConnectorTypes('amazon-q.chat'), {
          'amazon-q',
        });
        expect(
          llmRoutedChatProtocolForAccountModel(
            account: AiGatewayAccount(
              id: 'q-account',
              connectorType: 'amazon-q',
              authType: 'oauth',
              displayName: 'Amazon Q',
              endpointConfig: const {},
            ),
            upstreamModelId: 'q-model',
            endpointType: 'openai.chat_completions',
          ),
          'amazon-q.chat',
        );
        final message = StroomMessage(
          id: 'task-input',
          role: 'user',
          sequence: 0,
          createdAt: DateTime.utc(2026),
          content: [StroomContentPart.text('Do this task.')],
        );
        final request = AiGatewayProtocolBridges.buildRequest(
          'amazon-q.chat',
          AiGatewayProtocolRequest(
            modelId: 'q-model',
            messages: [message],
            conversationId: 'task-123',
            accountId: 'q-account',
            stream: true,
          ),
        );
        expect(request?.path, '/generateAssistantResponse');
        expect(request?.streams, isTrue);
        final state = request!.body['conversationState'] as Map;
        final current = state['currentMessage'] as Map;
        expect(
          (current['userInputMessage'] as Map)['content'],
          'Do this task.',
        );
        expect(state['conversationId'], isNotEmpty);

        final failedTool = StroomMessage(
          id: 'failed-tool-result',
          role: 'tool',
          sequence: 1,
          createdAt: DateTime.utc(2026),
          content: [
            StroomContentPart.toolResult(
              toolCallId: 'call-failed',
              result: 'Tool failed.',
              isError: true,
            ),
          ],
        );
        final failedToolRequest = AiGatewayProtocolBridges.buildRequest(
          'amazon-q.chat',
          AiGatewayProtocolRequest(modelId: 'q-model', messages: [failedTool]),
        );
        final failedToolState =
            failedToolRequest!.body['conversationState'] as Map;
        final failedToolInput = (failedToolState['currentMessage']
            as Map)['userInputMessage'] as Map;
        expect(
          ((failedToolInput['userInputMessageContext'] as Map)['toolResults']
                  as List)
              .single,
          {
            'toolUseId': 'call-failed',
            'status': 'error',
            'content': [
              {'text': 'Tool failed.'},
            ],
          },
        );
      },
    );

    test('maps only source-supported reasoning effort into the Q request', () {
      AiGatewayEncodedProtocolRequest build({
        required String modelId,
        required Map<String, dynamic> options,
        double? temperature,
      }) =>
          AiGatewayProtocolBridges.buildRequest(
            'amazon-q.chat',
            AiGatewayProtocolRequest(
              modelId: modelId,
              messages: [
                StroomMessage(
                  id: 'reasoning-input',
                  role: 'user',
                  sequence: 0,
                  createdAt: DateTime.utc(2026),
                  content: [StroomContentPart.text('Solve this carefully.')],
                ),
              ],
              maxOutputTokens: 4096,
              temperature: temperature,
              options: options,
            ),
          )!;

      final adaptive = build(
        modelId: 'claude-sonnet-5',
        options: const {'reasoning_effort': 'high'},
        temperature: 0.2,
      );
      expect(adaptive.body['additionalModelRequestFields'], {
        'output_config': {'effort': 'high'},
        'thinking': {'type': 'adaptive', 'display': 'summarized'},
        'max_tokens': 4096,
      });
      expect(adaptive.body['inferenceConfig'], {'maxTokens': 4096});
      final adaptiveState = adaptive.body['conversationState'] as Map;
      final adaptiveCurrent = adaptiveState['currentMessage'] as Map;
      expect(
        ((adaptiveCurrent['userInputMessage'] as Map)['content'] as String),
        startsWith(
          '<thinking_mode>enabled</thinking_mode>'
          '<max_thinking_length>32000</max_thinking_length>',
        ),
      );

      final native = build(
        modelId: 'gpt-5.6-sol',
        options: const {
          'output_config': {'effort': 'xhigh'},
        },
      );
      expect(native.body['additionalModelRequestFields'], {
        'reasoning': {'effort': 'xhigh'},
      });

      final unsupported = build(
        modelId: 'claude-sonnet-4.5',
        options: const {'reasoning_effort': 'high'},
      );
      expect(unsupported.body, isNot(contains('additionalModelRequestFields')));
    });

    test('builds the Amazon Q request from the full chat transcript', () {
      final request = AmazonQConnector.buildChatRequest(
        modelId: 'claude-sonnet-4',
        accountId: 'account-a',
        conversationId: 'conversation-a',
        messages: const [
          {'role': 'system', 'content': 'Be concise.'},
          {'role': 'user', 'content': 'First question'},
          {'role': 'assistant', 'content': 'First answer'},
          {'role': 'user', 'content': 'Follow up'},
        ],
        maxOutputTokens: 300,
        temperature: 0.2,
      );

      final state = request['conversationState'] as Map;
      expect(state['chatTriggerType'], 'MANUAL');
      expect(state['conversationId'], isA<String>());
      expect(state['history'], [
        {
          'userInputMessage': {
            'content':
                '<system-reminder>\nBe concise.\n</system-reminder>\n\nFirst question',
            'modelId': 'claude-sonnet-4',
            'origin': 'AI_EDITOR',
          },
        },
        {
          'assistantResponseMessage': {'content': 'First answer'},
        },
      ]);
      expect(state['currentMessage'], {
        'userInputMessage': {
          'content': 'Follow up',
          'modelId': 'claude-sonnet-4',
          'origin': 'AI_EDITOR',
        },
      });
      expect(request['inferenceConfig'], {
        'maxTokens': 300,
        'temperature': 0.2,
      });
    });

    test('replays prior assistant reasoning in the Amazon Q transcript', () {
      final request = AmazonQConnector.buildChatRequest(
        modelId: 'claude-sonnet-5',
        conversationId: 'conversation-reasoning-history',
        messages: const [
          {'role': 'user', 'content': 'What is 6 times 7?'},
          {
            'role': 'assistant',
            'content': '42.',
            'reasoning_content': 'Multiply 6 by 7.',
          },
          {'role': 'user', 'content': 'Explain briefly.'},
        ],
      );
      final state = request['conversationState'] as Map;
      expect(state['history'], [
        {
          'userInputMessage': {
            'content': 'What is 6 times 7?',
            'modelId': 'claude-sonnet-5',
            'origin': 'AI_EDITOR',
          },
        },
        {
          'assistantResponseMessage': {
            'content': '<thinking>\nMultiply 6 by 7.\n</thinking>\n\n42.',
          },
        },
      ]);
      final current = state['currentMessage'] as Map;
      expect(
        (current['userInputMessage'] as Map)['content'],
        'Explain briefly.',
      );
    });

    test('preserves failed tool results in Amazon Q conversation history', () {
      final request = AmazonQConnector.buildChatRequest(
        modelId: 'claude-sonnet-4',
        conversationId: 'conversation-error',
        messages: const [
          {
            'role': 'tool',
            'tool_call_id': 'call-failed',
            'content': 'Tool failed.',
            'is_error': true,
          },
        ],
      );
      final state = request['conversationState'] as Map;
      final input = (state['currentMessage'] as Map)['userInputMessage'] as Map;
      expect(
        ((input['userInputMessageContext'] as Map)['toolResults'] as List)
            .single['status'],
        'error',
      );
    });

    test(
      'decodes split Amazon Q EventStream frames into text and reasoning',
      () async {
        final source = Stream<List<int>>.fromIterable([
          _eventFrame('assistantResponseEvent', {'content': 'Hello'}),
          _eventFrame('reasoningContentEvent', {'text': 'Because'}),
          _eventFrame('messageStopEvent', {}),
        ]).expand((frame) => [frame.sublist(0, 7), frame.sublist(7)]);
        final output = await AmazonQConnector.toOpenAiSse(
          source,
          modelId: 'claude-sonnet-4',
        ).fold<List<int>>(<int>[], (bytes, chunk) => bytes..addAll(chunk));
        final text = utf8.decode(output);

        expect(text, contains('"content":"Hello"'));
        expect(text, contains('"reasoning_content":"Because"'));
        expect(text, contains('data: [DONE]'));
      },
    );

    test('decodes tool use arrays into OpenAI function deltas', () async {
      final source = Stream<List<int>>.fromIterable([
        _eventFrame('toolUseEvent', [
          {
            'toolUseId': 'tool-1',
            'name': 'weather',
            'input': {'city': 'Paris'},
          },
          {
            'toolUseId': 'tool-2',
            'name': 'calendar',
            'input': {'day': 'tomorrow'},
          },
        ]),
        _eventFrame('messageStopEvent', {}),
      ]);
      final output = await AmazonQConnector.toOpenAiSse(
        source,
        modelId: 'claude-sonnet-4',
      ).fold<List<int>>(<int>[], (bytes, chunk) => bytes..addAll(chunk));
      final text = utf8.decode(output);

      expect(text, contains('"id":"tool-1"'));
      expect(text, contains('"name":"weather"'));
      expect(text, contains('"id":"tool-2"'));
      expect(text, contains('"name":"calendar"'));
      expect(text, contains('"arguments":"{\\"city\\":\\"Paris\\"}"'));
      expect(text, contains('"finish_reason":"tool_calls"'));
    });

    test('preserves reasoning signatures when a stream has no text delta', () {
      final events = AiGatewayProtocolStreamBridge.mapEvents('amazon-q.chat', {
        'choices': [
          {
            'delta': {'stroom.reasoningSignature': 'opaque-signature'},
          },
        ],
      });

      expect(events, hasLength(1));
      expect(
        events.single.kind,
        AiGatewayProtocolStreamEventKind.reasoningDelta,
      );
      expect(events.single.delta, isNull);
      expect(events.single.thoughtSignature, 'opaque-signature');
    });

    test('rejects corrupt and incomplete EventStream frames', () async {
      final corrupt = _eventFrame('messageStopEvent', {})..[8] ^= 0x01;
      await expectLater(
        AmazonQConnector.toOpenAiSse(Stream.value(corrupt), modelId: 'm'),
        emitsError(isA<FormatException>()),
      );
      await expectLater(
        AmazonQConnector.toOpenAiSse(
          Stream.value(_eventFrame('messageStopEvent', {}).sublist(0, 8)),
          modelId: 'm',
        ),
        emitsError(isA<FormatException>()),
      );
    });
  });
}

Uint8List _eventFrame(String eventType, Object? payload) {
  final name = utf8.encode(':event-type');
  final value = utf8.encode(eventType);
  final header = <int>[
    name.length,
    ...name,
    7,
    (value.length >> 8) & 0xff,
    value.length & 0xff,
    ...value,
  ];
  final content = utf8.encode(jsonEncode(payload));
  final total = 12 + header.length + content.length + 4;
  final bytes = Uint8List(total);
  final view = ByteData.sublistView(bytes);
  view.setUint32(0, total, Endian.big);
  view.setUint32(4, header.length, Endian.big);
  view.setUint32(8, _crc32(bytes.sublist(0, 8)), Endian.big);
  bytes.setRange(12, 12 + header.length, header);
  bytes.setRange(12 + header.length, total - 4, content);
  view.setUint32(total - 4, _crc32(bytes.sublist(0, total - 4)), Endian.big);
  return bytes;
}

int _crc32(List<int> bytes) {
  var crc = 0xffffffff;
  for (final byte in bytes) {
    crc ^= byte;
    for (var bit = 0; bit < 8; bit++) {
      crc = (crc & 1) == 1 ? (crc >> 1) ^ 0xedb88320 : crc >> 1;
    }
  }
  return (crc ^ 0xffffffff) & 0xffffffff;
}
