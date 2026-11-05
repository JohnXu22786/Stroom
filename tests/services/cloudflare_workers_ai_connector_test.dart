import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/llm_account.dart';
import 'package:stroom/services/cloudflare_workers_ai_connector.dart';
import 'package:stroom/services/api_protocol_config.dart';
import 'package:stroom/services/llm_connector_service.dart';
import 'package:stroom/src/ai_gateway/ai_gateway_facade.dart';

void main() {
  group('Cloudflare Workers AI source catalog', () {
    test('contains the pinned models and context lengths only', () {
      expect(
        kCloudflareWorkersAiModelContextLengths,
        {
          '@cf/mistral/mistral-7b-instruct-v0.2-lora': 15000,
          '@cf/qwen/qwen2.5-coder-32b-instruct': 32768,
          '@cf/deepseek-ai/deepseek-r1-distill-qwen-32b': 80000,
          '@cf/meta/llama-3.3-70b-instruct-fp8-fast': 24000,
          '@cf/meta/llama-3.2-3b-instruct': 80000,
          '@cf/qwen/qwq-32b': 24000,
          '@cf/zai-org/glm-4.7-flash': 131072,
          '@cf/moonshotai/kimi-k2.6': 262144,
          '@cf/google/gemma-4-26b-a4b-it': 262144,
        },
      );
      expect(
        kCloudflareWorkersAiModelIds,
        kCloudflareWorkersAiModelContextLengths.keys.toList(),
      );
      final catalog = cloudflareWorkersAiModelCatalog('account-1');
      expect(
        catalog.map((model) => model.upstreamModelId).toList(),
        kCloudflareWorkersAiModelIds,
      );
      for (final model in catalog) {
        expect(model.capabilities.keys, {'contextLength'});
        expect(
          model.capabilities['contextLength'],
          kCloudflareWorkersAiModelContextLengths[model.upstreamModelId],
        );
      }
    });
  });

  group('Cloudflare Workers AI request contract', () {
    test('builds the account-scoped chat endpoint and bearer headers', () {
      expect(
        CloudflareWorkersAiConnector.buildChatCompletionsUri('account/123'),
        Uri.parse(
          'https://api.cloudflare.com/client/v4/accounts/account%2F123/ai/v1/chat/completions',
        ),
      );
      expect(
        CloudflareWorkersAiConnector.buildHeaders('api-token', stream: true),
        {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer api-token',
          'Accept': 'text/event-stream',
        },
      );
      expect(
        CloudflareWorkersAiConnector.buildHeaders('api-token'),
        {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer api-token',
        },
      );
    });

    test('normalizes text-only content and keeps non-text parts and tool data',
        () {
      final request = <String, dynamic>{
        'model': '@cf/qwen/qwen2.5-coder-32b-instruct',
        'messages': [
          {'role': 'user', 'content': 'plain'},
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': 'one'},
              {'type': 'text', 'text': 'two'},
            ],
          },
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': 'caption'},
              {
                'type': 'image_url',
                'image_url': {'url': 'data:image/png;base64,AA=='}
              }
            ],
          },
          {
            'role': 'assistant',
            'tool_calls': [
              {'id': 'call-1', 'type': 'function'},
            ],
          },
          {'role': 'tool', 'tool_call_id': 'call-1'},
          {'role': 'user', 'content': null},
          {'role': 'user', 'content': []},
          'unrecognized message shape',
        ],
      };

      final normalized = CloudflareWorkersAiConnector.normalizeRequestBody(
        request,
      ) as Map;
      final messages = normalized['messages'] as List;
      expect((messages[0] as Map)['content'], 'plain');
      expect((messages[1] as Map)['content'], 'onetwo');
      expect(
        (messages[2] as Map)['content'],
        (request['messages'] as List)[2]['content'],
      );
      expect((messages[3] as Map)['content'], '');
      expect((messages[3] as Map)['tool_calls'],
          (request['messages'] as List)[3]['tool_calls']);
      expect((messages[4] as Map)['content'], '');
      expect((messages[4] as Map)['tool_call_id'], 'call-1');
      expect((request['messages'] as List)[1]['content'], isA<List>());
      expect((messages[5] as Map)['content'], '');
      expect((messages[6] as Map)['content'], '');
      expect(messages[7], 'unrecognized message shape');
    });

    test('leaves bodies without a messages array unchanged', () {
      final body = {'input': 'hello'};
      expect(
          CloudflareWorkersAiConnector.normalizeRequestBody(body), same(body));
    });

    test(
        'native request builder uses the account URL and preserves multimodal data',
        () {
      const imagePart = {
        'type': 'image_url',
        'image_url': {'url': 'https://example.test/image.png'},
      };
      final request = LlmNativeRequestBuilder().build(
        account: LlmAccount(
          id: 'cloudflare-account',
          connectorType: 'cloudflare-ai',
          authType: 'api_key',
          displayName: 'Workers AI',
          endpointConfig: const {'cloudflareAccountId': 'cf-account-id'},
        ),
        credential: 'api-token',
        modelId: '@cf/meta/llama-3.2-3b-instruct',
        body: {
          'model': '@cf/meta/llama-3.2-3b-instruct',
          'messages': [
            {
              'role': 'user',
              'content': [
                {'type': 'text', 'text': 'describe'},
                imagePart,
              ],
            },
          ],
        },
        stream: true,
      );

      expect(
        request.uri.toString(),
        'https://api.cloudflare.com/client/v4/accounts/cf-account-id/ai/v1/chat/completions',
      );
      expect(request.headers['Authorization'], 'Bearer api-token');
      expect(request.headers['Accept'], 'text/event-stream');
      final content =
          ((request.body as Map)['messages'] as List).single['content'];
      expect(content, [
        {'type': 'text', 'text': 'describe'},
        imagePart,
      ]);
    });
  });

  test(
      'registers the same OpenAI Chat Completions route used by Chat/Task Flow',
      () {
    final connector = LlmConnectorRegistry.find('cloudflare-ai');
    final provider = LlmChatRoutingRuntime.defaultProviderCatalog
        .findProvider('cloudflare-ai');

    expect(connector?.authTypes, {'api_key'});
    expect(LlmConnectorRegistry.find('cf')?.id, 'cloudflare-ai');
    expect(LlmConnectorRegistry.canonicalId('cf'), 'cloudflare-ai');
    expect(connector?.protocol, LlmNativeProtocol.openAIChatCompletions);
    expect(connector?.modelCatalog, kCloudflareWorkersAiModelIds);
    expect(LlmConnectorRegistry.chatAdapterEndpointType('cloudflare-ai'),
        'openai');
    expect(
      LlmConnectorRegistry.isChatAdapterAuthTypeSupported(
        'cloudflare-ai',
        'api_key',
      ),
      isTrue,
    );
    expect(provider?.supportsChatAdapter, isTrue);
    expect(provider?.chatProtocolId, 'openai');
    expect(builtinDefaultApiProtocolForConnector('cloudflare-ai'),
        'openai.chat_completions');
  });
}
