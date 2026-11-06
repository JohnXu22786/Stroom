import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/ai_gateway/ai_gateway_contracts.dart';
import 'package:stroom/ai_gateway/ai_gateway_protocol_bridges.dart';
import 'package:stroom/models/stroom_conversation.dart';
import 'package:stroom/providers/llm_routed_chat_provider.dart';
import 'package:stroom/services/oneminai_protocol.dart';

void main() {
  group('1min.AI native chat protocol', () {
    test('builds the source-backed URL, API key header, and body', () {
      expect(OneMinAiProtocol.requestUri(stream: false).toString(),
          'https://api.1min.ai/api/chat-with-ai');
      expect(OneMinAiProtocol.requestUri(stream: true).toString(),
          'https://api.1min.ai/api/chat-with-ai?isStreaming=true');
      expect(OneMinAiProtocol.buildHeaders('secret'), {
        'Content-Type': 'application/json',
        'API-KEY': 'secret',
      });
      expect(
        OneMinAiProtocol.buildRequest('account-model/with:punctuation', {
          'messages': [
            {'role': 'user', 'content': 'hello'},
          ],
        }),
        {
          'type': 'UNIFY_CHAT_WITH_AI',
          'model': 'account-model/with:punctuation',
          'promptObject': {'prompt': 'hello'},
        },
      );
    });

    test('flattens all supported message roles and preserves a lone user text',
        () {
      expect(
        OneMinAiProtocol.buildPrompt([
          {'role': 'system', 'content': 'rules'},
          {'role': 'developer', 'content': 'extra rules'},
          {'role': 'user', 'content': 'question'},
          {'role': 'assistant', 'content': 'answer'},
        ]),
        'System: rules\n\nSystem: extra rules\n\nUser: question\n\nAssistant: answer',
      );
      expect(
        OneMinAiProtocol.buildPrompt([
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': 'hello'},
            ],
          },
        ]),
        'hello',
      );
    });

    test('Gateway bridge sends full text history to the provider-native body',
        () {
      final messages = [
        for (final (index, entry) in [
          ('system', 'rules'),
          ('developer', 'more rules'),
          ('user', 'question'),
          ('assistant', 'answer'),
        ].indexed)
          StroomMessage(
            id: 'm$index',
            role: entry.$1,
            sequence: index,
            createdAt: DateTime.utc(2026),
            content: [StroomContentPart.text(entry.$2)],
          ),
      ];
      final request = AiGatewayProtocolBridges.buildRequest(
        'oneminai.chat',
        AiGatewayProtocolRequest(
          modelId: 'account-model-id',
          messages: messages,
          stream: true,
        ),
      );
      expect(request!.path, '/api/chat-with-ai');
      expect(request.streams, isTrue);
      expect(request.body, {
        'type': 'UNIFY_CHAT_WITH_AI',
        'model': 'account-model-id',
        'promptObject': {
          'prompt':
              'System: rules\n\nSystem: more rules\n\nUser: question\n\nAssistant: answer',
        },
      });
    });

    test('Chat routing selects 1min.AI protocol and rejects protocol overrides',
        () {
      final account = AiGatewayAccount(
        id: 'one-min-ai',
        connectorType: 'oneminai',
        authType: 'api_key',
        displayName: '1min.AI',
        endpointConfig: const {'apiProtocol': 'oneminai.chat'},
        models: [
          AiGatewayUpstreamModel(
            id: 'one-min-model',
            upstreamModelId: 'account-owned-model',
            displayName: 'Account model',
          ),
        ],
      );
      expect(llmRoutedChatSupportedConnectorTypes('oneminai.chat'), {
        'oneminai',
      });
      expect(
        llmRoutedChatProtocolForAccountModel(
          account: account,
          upstreamModelId: 'account-owned-model',
          endpointType: 'openai.chat_completions',
        ),
        'oneminai.chat',
      );
      final unsupported = AiGatewayAccount(
        id: 'one-min-ai-unsupported',
        connectorType: 'oneminai',
        authType: 'api_key',
        displayName: '1min.AI',
        models: [
          AiGatewayUpstreamModel(
            id: 'one-min-model',
            upstreamModelId: 'account-owned-model',
            displayName: 'Account model',
            config: {'apiProtocolOverride': 'openai.chat_completions'},
          ),
        ],
      );
      expect(
        () => llmRoutedChatProtocolForAccountModel(
          account: unsupported,
          upstreamModelId: 'account-owned-model',
          endpointType: 'oneminai.chat',
        ),
        throwsStateError,
      );
    });

    test('joins nonstream resultObject string fragments', () {
      expect(
        OneMinAiProtocol.parseCompletion({
          'aiRecord': {
            'aiRecordDetail': {
              'resultObject': [
                'hello ',
                'world',
                4,
                {'ignored': true}
              ],
            },
          },
        }),
        'hello world',
      );
    });

    test('parses event framed SSE across arbitrary byte chunk boundaries', () {
      final parser = OneMinAiSseAccumulator();
      final first = parser.addChunk('event: content\ndata: {"con');
      expect(first, isEmpty);
      final second = parser.addChunk('tent":"hel');
      expect(second, isEmpty);
      final third = parser.addChunk(
        'lo"}\n\nevent: content\ndata: {"content":" world"}\n\n'
        'event: result\ndata: {}\n\n'
        'event: done\ndata: {}\n\n',
      );
      expect(third.map((event) => event.textDelta).whereType<String>(),
          ['hello', ' world']);
      expect(third.last.done, isTrue);
      expect(parser.done, isTrue);
      expect(parser.addChunk('event: content\ndata: {"content":"late"}\n\n'),
          isEmpty);

      final crlfParser = OneMinAiSseAccumulator();
      expect(crlfParser.addChunk('event: content\r'), isEmpty);
      expect(crlfParser.addChunk('\ndata: {"content":"crlf"}\r'), isEmpty);
      final crlf = crlfParser.addChunk('\n\r\nevent: done\r\ndata: {}\r\n\r\n');
      expect(crlf.first.textDelta, 'crlf');
      expect(crlf.last.done, isTrue);
    });

    test('surfaces upstream error as a fixed safe connector error', () {
      final parser = OneMinAiSseAccumulator();
      final events = parser.addChunk(
        'event: error\ndata: {"message":"private upstream detail"}\n\n',
      );
      expect(events.single.errorMessage, '1min.AI request failed.');
      expect(events.single.errorMessage, isNot(contains('private upstream')));
      expect(parser.done, isTrue);
    });

    test('translated stream keeps ordered deltas and cancels its source',
        () async {
      final source = StreamController<List<int>>();
      var sourceCancelled = false;
      source.onCancel = () {
        sourceCancelled = true;
      };
      final subscription = OneMinAiProtocol.translateSse(
        source.stream,
        modelId: 'gpt-4o-mini',
      ).listen((_) {});
      source.add(utf8.encode(
        'event: content\ndata: {"content":"one"}\n\n'
        'event: content\ndata: {"content":"two"}\n\n',
      ));
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();
      expect(sourceCancelled, isTrue);
    });

    test('rejects unsupported tools, output formats, and non-text content', () {
      for (final body in [
        {
          'messages': [
            {'role': 'user', 'content': 'hello'},
          ],
          'tools': [
            {
              'type': 'function',
              'function': {'name': 'lookup'}
            },
          ],
        },
        {
          'messages': [
            {'role': 'user', 'content': 'hello'},
          ],
          'functions': [
            {'name': 'lookup'},
          ],
        },
        {
          'messages': [
            {'role': 'assistant', 'content': null, 'tool_calls': []},
          ],
        },
        {
          'messages': [
            {'role': 'user', 'content': 'hello'},
          ],
          'response_format': {'type': 'json_object'},
        },
        {
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'image_url',
                  'image_url': {'url': 'data:image/png;base64,AA=='}
                }
              ],
            },
          ],
        },
        for (final contentType in ['input_audio', 'video_url', 'file'])
          {
            'messages': [
              {
                'role': 'user',
                'content': [
                  {'type': contentType, 'data': 'unsupported'},
                ],
              },
            ],
          },
      ]) {
        expect(
          () => OneMinAiProtocol.buildRequest('gpt-4o-mini', body),
          throwsUnsupportedError,
        );
      }
    });
  });
}
