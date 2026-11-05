import '../models/llm_account.dart';

/// Cloudflare Workers AI's manually maintained conversational model catalog.
///
/// These IDs and context windows come from the pinned OmniRoute provider
/// registry. Workers AI does not expose a compatible model-list endpoint.
const kCloudflareWorkersAiModelContextLengths = <String, int>{
  '@cf/mistral/mistral-7b-instruct-v0.2-lora': 15000,
  '@cf/qwen/qwen2.5-coder-32b-instruct': 32768,
  '@cf/deepseek-ai/deepseek-r1-distill-qwen-32b': 80000,
  '@cf/meta/llama-3.3-70b-instruct-fp8-fast': 24000,
  '@cf/meta/llama-3.2-3b-instruct': 80000,
  '@cf/qwen/qwq-32b': 24000,
  '@cf/zai-org/glm-4.7-flash': 131072,
  '@cf/moonshotai/kimi-k2.6': 262144,
  '@cf/google/gemma-4-26b-a4b-it': 262144,
};

const kCloudflareWorkersAiModelIds = <String>[
  '@cf/mistral/mistral-7b-instruct-v0.2-lora',
  '@cf/qwen/qwen2.5-coder-32b-instruct',
  '@cf/deepseek-ai/deepseek-r1-distill-qwen-32b',
  '@cf/meta/llama-3.3-70b-instruct-fp8-fast',
  '@cf/meta/llama-3.2-3b-instruct',
  '@cf/qwen/qwq-32b',
  '@cf/zai-org/glm-4.7-flash',
  '@cf/moonshotai/kimi-k2.6',
  '@cf/google/gemma-4-26b-a4b-it',
];

List<LlmUpstreamModel> cloudflareWorkersAiModelCatalog(String accountId) => [
      for (final (index, entry)
          in kCloudflareWorkersAiModelContextLengths.entries.indexed)
        LlmUpstreamModel(
          id: '$accountId:catalog:$index',
          upstreamModelId: entry.key,
          displayName: entry.key,
          capabilities: {'contextLength': entry.value},
          config: const {
            'catalogSource':
                'omniroute@d1ba82234c260e2cf6b0f3ac307a75240d5bbdc5',
          },
        ),
    ];

/// Source-backed URL, authentication and message handling for the provider.
abstract final class CloudflareWorkersAiConnector {
  static Uri buildChatCompletionsUri(String accountId) {
    final normalized = accountId.trim();
    if (normalized.isEmpty || RegExp(r'[\x00-\x20\x7F]').hasMatch(normalized)) {
      throw ArgumentError.value(accountId, 'accountId');
    }
    return Uri(
      scheme: 'https',
      host: 'api.cloudflare.com',
      pathSegments: [
        'client',
        'v4',
        'accounts',
        normalized,
        'ai',
        'v1',
        'chat',
        'completions',
      ],
    );
  }

  static Map<String, String> buildHeaders(
    String apiToken, {
    bool stream = false,
  }) {
    final token = apiToken.trim();
    if (token.isEmpty || RegExp(r'[\x00-\x1F\x7F]').hasMatch(token)) {
      throw ArgumentError.value(apiToken, 'apiToken');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      if (stream) 'Accept': 'text/event-stream',
    };
  }

  /// Matches OmniRoute's Workers AI request normalization without discarding
  /// non-text content parts or tool data. Images remain available to models
  /// whose endpoint schemas accept them.
  static Object? normalizeRequestBody(Object? body) {
    if (body is! Map || body['messages'] is! List) return body;
    final normalizedMessages = <dynamic>[];
    for (final rawMessage in body['messages'] as List) {
      if (rawMessage is! Map) {
        normalizedMessages.add(rawMessage);
        continue;
      }
      final message = Map<String, dynamic>.from(rawMessage);
      final content = message['content'];
      if (content == null) {
        message['content'] = '';
      } else if (content is List && content.every(_isTextPart)) {
        message['content'] =
            content.map((part) => (part as Map)['text'] as String).join();
      }
      normalizedMessages.add(message);
    }
    return {...Map<String, dynamic>.from(body), 'messages': normalizedMessages};
  }

  static bool _isTextPart(Object? part) =>
      part is Map && part['type'] == 'text' && part['text'] is String;
}
