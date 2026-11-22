import 'package:flutter_test/flutter_test.dart';

import 'package:dio/dio.dart';

import 'dart:convert';
import 'dart:typed_data';

import 'package:stroom/models/ai_stream_event.dart';
import 'package:stroom/providers/chat_api_provider.dart';
import 'package:stroom/providers/responses_stream_parser.dart';

void main() {
  group('Responses request and output', () {
    test(
      'non-streaming chat preserves generated image items and response text',
      () async {
        final adapter = _JsonAdapter({
          'usage': {
            'input_tokens': 3,
            'output_tokens': 5,
            'input_tokens_details': {'cached_tokens': 1},
            'output_tokens_details': {'reasoning_tokens': 2},
            'total_cost': '0.01',
          },
          'output': [
            {
              'type': 'reasoning',
              'summary': [
                {'type': 'summary_text', 'text': 'Create a picture'},
              ],
            },
            {
              'type': 'message',
              'content': [
                {'type': 'output_text', 'text': 'Generated'},
              ],
            },
            {
              'type': 'image_generation_call',
              'result': 'aW1hZ2U=',
              'output_format': 'jpeg',
            },
          ],
        });
        final provider = OpenAICompatibleChatProvider(
          baseUrl: 'https://api.example.test/v1/responses',
          apiKey: 'test-key',
          endpointType: 'responses',
          dio: Dio()..httpClientAdapter = adapter,
        );

        expect(
          await provider.chat(const [], system: 'Be helpful'),
          'Generated',
        );
        expect(
          adapter.requestOptions?.path,
          'https://api.example.test/v1/responses',
        );
        expect(adapter.requestBody, containsPair('instructions', 'Be helpful'));
        expect(provider.lastNonStreamingEvents!.first.text, 'Generated');
        expect(
          provider.lastNonStreamingEvents!.any(
            (event) => event.isReasoning && event.text == 'Create a picture',
          ),
          isTrue,
        );
        expect(
          provider.lastNonStreamingEvents!.any(
            (event) => event.images?.single.base64Data == 'aW1hZ2U=',
          ),
          isTrue,
        );
        expect(
          provider.lastNonStreamingEvents!
              .firstWhere((event) => event.images?.isNotEmpty == true)
              .images!
              .single
              .mimeType,
          'image/jpeg',
        );
        expect(provider.lastUsage, {
          'inputTokens': 3,
          'outputTokens': 5,
          'cachedInputTokens': 1,
          'reasoningTokens': 2,
          'cost': 0.01,
        });
        expect(
            provider.lastResponseData.toString(), isNot(contains('aW1hZ2U=')));
        expect(
          provider.lastResponseData.toString(),
          contains('[image data stored as attachment]'),
        );
      },
    );

    test(
      'chatWithEvents exposes non-streaming images and tool calls',
      () async {
        final adapter = _JsonAdapter({
          'output': [
            {
              'type': 'message',
              'content': [
                {'type': 'output_text', 'text': 'Working on it'},
              ],
            },
            {
              'type': 'image_generation_call',
              'result': 'aGVsbG8=',
              'output_format': 'png',
            },
            {
              'type': 'function_call',
              'call_id': 'call-1',
              'name': 'lookup',
              'arguments': '{}',
            },
          ],
        });
        final provider = OpenAICompatibleChatProvider(
          baseUrl: 'https://api.example.test/v1/responses',
          apiKey: 'test-key',
          endpointType: 'responses',
          dio: Dio()..httpClientAdapter = adapter,
        );

        final events = await provider.chatWithEvents(const []);

        expect(events.any((event) => event.text == 'Working on it'), isTrue);
        expect(events.any((event) => event.images?.isNotEmpty == true), isTrue);
        expect(events.any((event) => event.isToolCallEvent), isTrue);
      },
    );

    test('non-streaming unknown output items return visible placeholders',
        () async {
      final provider = OpenAICompatibleChatProvider(
        baseUrl: 'https://api.example.test/v1/responses',
        apiKey: 'test-key',
        endpointType: 'responses',
        dio: Dio()
          ..httpClientAdapter = _JsonAdapter({
            'output': [
              {'type': 'computer_call'},
            ],
          }),
      );

      final events = await provider.chatWithEvents(const []);

      expect(
        events.map((event) => event.text),
        contains('[Responses 输出类型暂不支持: computer_call]'),
      );
    });

    test(
        'chat stream sends to the selected URL and emits image, tool, text, and usage events',
        () async {
      final fixtures = [
        {'type': 'response.output_text.delta', 'delta': 'Created'},
        {
          'type': 'response.output_item.done',
          'output_index': 0,
          'item': {'type': 'image_generation_call', 'result': 'aW1hZ2U='},
        },
        {
          'type': 'response.output_item.done',
          'output_index': 1,
          'item': {
            'type': 'function_call',
            'call_id': 'call_1',
            'name': 'lookup',
            'arguments': '{}',
          },
        },
        {
          'type': 'response.completed',
          'response': {
            'usage': {
              'input_tokens': 2,
              'output_tokens': 4,
              'total_cost': '0.025',
            },
            'output': [
              {'type': 'image_generation_call', 'result': 'aW1hZ2U='},
              {
                'type': 'function_call',
                'call_id': 'call_1',
                'name': 'lookup',
                'arguments': '{}',
              },
            ],
          },
        },
      ];
      String? requestedUrl;
      Map<String, dynamic>? requestBody;
      final provider = OpenAICompatibleChatProvider(
        baseUrl: 'https://api.example.test/v1/responses',
        apiKey: 'test-key',
        endpointType: 'responses',
        sseStreamOverride: (url, headers, body,
            {cancelToken, locale, onResponseHeaders}) {
          requestedUrl = url;
          requestBody = jsonDecode(body) as Map<String, dynamic>;
          return Stream<String>.fromIterable(
            fixtures.map((event) => 'data: ${jsonEncode(event)}'),
          );
        },
      );

      final events = await provider
          .chatStream(
            const [
              {'type': 'message', 'role': 'user', 'content': 'draw'},
            ],
            model: 'gpt-5',
            system: 'Be helpful',
            maxTokens: 99,
            tools: const [
              {'type': 'function', 'name': 'lookup'},
            ],
          )
          .toList();

      expect(requestedUrl, 'https://api.example.test/v1/responses');
      expect(requestBody, containsPair('input', isA<List>()));
      expect(requestBody, containsPair('instructions', 'Be helpful'));
      expect(events.any((event) => event.text == 'Created'), isTrue);
      expect(events.any((event) => event.images?.isNotEmpty == true), isTrue);
      expect(events.any((event) => event.isToolCallEvent), isTrue);
      expect(events.any((event) => event.usage?['inputTokens'] == 2), isTrue);
      expect(events.any((event) => event.usage?['cost'] == 0.025), isTrue);
      expect(provider.lastRequestUrl, 'https://api.example.test/v1/responses');
    });

    test(
      'stream failures preserve the Responses error frame in diagnostics',
      () async {
        final failure = {
          'type': 'response.failed',
          'response': {
            'error': {'message': 'model unavailable'},
          },
        };
        final provider = OpenAICompatibleChatProvider(
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
              Stream.value('data: ${jsonEncode(failure)}'),
        );

        await expectLater(
          provider.chatStream(const []).toList(),
          throwsA(
            isA<Exception>().having(
              (error) => error.toString(),
              'message',
              contains('model unavailable'),
            ),
          ),
        );
        expect(provider.lastResponseData, failure);
        expect(provider.lastResponseStatusCode, 200);
      },
    );

    test('stream error events retain diagnostic frame and response metadata',
        () async {
      const failure = {
        'type': 'error',
        'code': 'rate_limit_exceeded',
        'message': 'Too many requests',
      };
      final provider = OpenAICompatibleChatProvider(
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
        }) {
          onResponseHeaders?.call({
            'x-request-id': ['req-123']
          });
          return Stream.value('data: ${jsonEncode(failure)}');
        },
      );

      await expectLater(
        provider.chatStream(const []).toList(),
        throwsA(isA<Exception>()),
      );

      expect(provider.lastResponseData, failure);
      expect(provider.lastResponseStatusCode, 200);
      expect(provider.lastResponseHeaders, {
        'x-request-id': ['req-123']
      });
    });

    test('builds Responses body without changing the configured endpoint', () {
      final provider = OpenAICompatibleChatProvider(
        baseUrl: 'https://api.example.test/v1/responses',
        apiKey: 'key',
        endpointType: 'responses',
      );
      final body = provider.buildBody(
        const [
          {'type': 'message', 'role': 'user', 'content': 'hi'},
        ],
        model: 'gpt-5',
        system: 'Be concise',
        maxTokens: 100,
        reasoning: true,
        reasoningEffort: 'high',
        tools: const [
          {'type': 'function', 'name': 'lookup'},
        ],
        stream: true,
      );

      expect(provider.lastRequestUrl, isNull);
      expect(body, {
        'model': 'gpt-5',
        'input': [
          {'type': 'message', 'role': 'user', 'content': 'hi'},
        ],
        'instructions': 'Be concise',
        'max_output_tokens': 100,
        'stream': true,
        'tools': [
          {'type': 'function', 'name': 'lookup'},
        ],
        'reasoning': {'effort': 'high', 'summary': 'auto'},
      });
      expect(provider.endpointType, 'responses');
      final configured = createChatProviderFromConfig(
        providerName: 'OpenAI',
        baseUrl: 'https://api.example.test/v1/responses',
        apiKey: 'key',
        endpointType: 'responses',
      );
      expect(configured, isA<OpenAICompatibleChatProvider>());
      expect(
        (configured as OpenAICompatibleChatProvider).endpointType,
        'responses',
      );
    });

    test('stream parser keeps a generated image with sibling tool calls', () {
      final acc = ResponsesStreamAccumulator();
      final events = <AIStreamEvent>[];
      events.addAll(
        processResponsesStreamData({
          'type': 'response.output_item.done',
          'output_index': 0,
          'item': {'type': 'image_generation_call', 'result': 'aW1hZ2U='},
        }, acc),
      );
      events.addAll(
        processResponsesStreamData({
          'type': 'response.output_item.done',
          'output_index': 1,
          'item': {
            'type': 'function_call',
            'call_id': 'call_1',
            'name': 'lookup',
            'arguments': '{"q":"x"}',
          },
        }, acc),
      );

      expect(events.single.images, hasLength(1));
      expect(events.single.images!.single.base64Data, 'aW1hZ2U=');
      expect(events.single.images!.single.mimeType, 'image/png');
      expect(buildResponsesToolCallEvent(acc)!.toolCalls, [
        {
          'id': 'call_1',
          'type': 'function',
          'function': {'name': 'lookup', 'arguments': '{"q":"x"}'},
        },
      ]);
    });

    test(
      'parses streamed reasoning, usage, non-streaming images and errors',
      () {
        final acc = ResponsesStreamAccumulator();
        expect(
          processResponsesStreamData({
            'type': 'response.reasoning_summary_text.delta',
            'delta': 'plan',
          }, acc)
              .single,
          isA<AIStreamEvent>()
              .having((event) => event.text, 'text', 'plan')
              .having((event) => event.isReasoning, 'reasoning', true),
        );

        final response = <String, dynamic>{
          'usage': {
            'input_tokens': 7,
            'output_tokens': 3,
            'input_tokens_details': {'cached_tokens': 2},
            'output_tokens_details': {'reasoning_tokens': 1},
            'cost': '0.015',
          },
          'output': [
            {
              'type': 'message',
              'content': [
                {'type': 'output_text', 'text': 'Done'},
              ],
            },
            {'type': 'image_generation_call', 'result': 'aW1hZ2U='},
            {
              'type': 'function_call',
              'call_id': 'call_2',
              'name': 'lookup',
              'arguments': '{}',
            },
          ],
        };
        final parsed = parseResponsesOutput(response);
        expect(responsesText(response), 'Done');
        expect(parsed.first.usage, {
          'inputTokens': 7,
          'outputTokens': 3,
          'cachedInputTokens': 2,
          'reasoningTokens': 1,
          'cost': 0.015,
        });
        expect(parsed.any((event) => event.images?.isNotEmpty == true), isTrue);
        expect(parsed.any((event) => event.isToolCallEvent), isTrue);
        expect(
          parseResponsesOutput({
            'output': [
              {'type': 'computer_call'},
            ],
          }).map((event) => event.text),
          contains('[Responses 输出类型暂不支持: computer_call]'),
        );
        expect(
          () => processResponsesStreamData({
            'type': 'response.failed',
            'response': {
              'error': {'message': 'bad response'},
            },
          }, acc),
          throwsA(
            isA<Exception>().having(
              (error) => error.toString(),
              'message',
              contains('bad response'),
            ),
          ),
        );
      },
    );

    test('streamed reasoning output items are not marked unsupported', () {
      final acc = ResponsesStreamAccumulator();
      final events = <AIStreamEvent>[];
      events.addAll(
        processResponsesStreamData({
          'type': 'response.reasoning_summary_text.delta',
          'delta': 'plan',
        }, acc),
      );
      events.addAll(
        processResponsesStreamData({
          'type': 'response.output_item.done',
          'output_index': 0,
          'item': {
            'type': 'reasoning',
            'summary': [
              {'type': 'summary_text', 'text': 'plan'},
            ],
          },
        }, acc),
      );
      events.addAll(
        processResponsesStreamData({
          'type': 'response.completed',
          'response': {
            'output': [
              {
                'type': 'reasoning',
                'summary': [
                  {'type': 'summary_text', 'text': 'plan'},
                ],
              },
            ],
          },
        }, acc),
      );

      expect(
        events.map((event) => event.text).where((text) => text.isNotEmpty),
        ['plan'],
      );
      expect(events.any((event) => event.text.contains('不支持')), isFalse);
    });

    test('unsupported message parts and audio stream events stay visible', () {
      final parsed = parseResponsesOutput({
        'output': [
          {
            'type': 'message',
            'content': [
              {'type': 'output_audio', 'audio': 'base64-audio'},
            ],
          },
        ],
      });
      expect(
        parsed.map((event) => event.text),
        contains('[Responses 输出类型暂不支持: output_audio]'),
      );

      final streamed = processResponsesStreamData({
        'type': 'response.audio.delta',
        'delta': 'base64-audio',
      }, ResponsesStreamAccumulator());
      expect(
        streamed.map((event) => event.text),
        contains('[Responses 输出类型暂不支持: response.audio.delta]'),
      );
      expect(streamed.toString(), isNot(contains('base64-audio')));
    });

    test('legacy OpenAI endpoint still builds Chat Completions requests', () {
      final provider = OpenAICompatibleChatProvider(
        baseUrl: 'https://api.example.test/v1/chat/completions',
        apiKey: 'key',
      );
      expect(provider.buildBody(const []), containsPair('messages', const []));
      expect(provider.buildBody(const []), isNot(contains('input')));
      expect(provider.endpointType, 'openai');
    });
  });
}

class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this.responseData);

  final Map<String, dynamic> responseData;
  RequestOptions? requestOptions;
  Map<String, dynamic>? requestBody;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    requestOptions = options;
    final requestBytes = <int>[];
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        requestBytes.addAll(chunk);
      }
    }
    requestBody = jsonDecode(utf8.decode(requestBytes)) as Map<String, dynamic>;
    return ResponseBody.fromString(
      jsonEncode(responseData),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
