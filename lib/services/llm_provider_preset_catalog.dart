/// Source-backed presets for ordinary API-key OpenAI Chat Completions APIs.
///
/// Provider identity is stored on an `openai-compatibility` account. This keeps
/// requests on the shared connector and leaves custom endpoint accounts intact.
class LlmProviderPresetModel {
  final String id;
  final String displayName;
  final Map<String, dynamic> capabilities;
  final String? apiProtocolOverride;

  const LlmProviderPresetModel(
    this.id, {
    String? displayName,
    this.capabilities = const {},
    this.apiProtocolOverride,
  }) : displayName = displayName ?? id;

  String accountEditorLine({String modelIdPrefix = ''}) => [
        '$modelIdPrefix$id',
        for (final entry
            in capabilities.entries.where((entry) => entry.value is bool))
          entry.value == true ? entry.key : '${entry.key}=false',
      ].join(',');
}

class LlmProviderPreset {
  final String id;
  final String displayName;
  final String baseUrl;
  final String? modelsUrl;
  final String modelIdPrefix;
  final String authType;
  final String authorizationHeader;
  final String authorizationScheme;
  final String defaultApiProtocol;
  final Map<String, String> headers;
  final List<LlmProviderPresetModel> fallbackModels;

  const LlmProviderPreset({
    required this.id,
    required this.displayName,
    required this.baseUrl,
    this.modelsUrl,
    this.modelIdPrefix = '',
    this.authType = 'api_key',
    this.authorizationHeader = 'Authorization',
    this.authorizationScheme = 'Bearer',
    this.defaultApiProtocol = 'openai.chat_completions',
    this.headers = const {},
    this.fallbackModels = const [],
  });

  /// Applies only preset-owned settings, retaining unrelated account settings.
  Map<String, dynamic> applyToEndpointConfig(Map<String, dynamic> existing) {
    final endpointConfig = {
      ...existing,
      'providerPresetId': id,
      'baseUrl': baseUrl,
      'apiProtocol': defaultApiProtocol,
    };
    _removePreviousPresetHeaders(endpointConfig, existing);
    endpointConfig['apiKeyHeader'] = authorizationHeader;
    endpointConfig['apiKeyScheme'] = authorizationScheme;
    _mergePresetHeaders(endpointConfig, headers);
    if (modelsUrl != null) {
      endpointConfig['modelsUrl'] = modelsUrl!;
    } else {
      final previousPresetId = existing['providerPresetId'];
      final previousPreset = findLlmOpenAiProviderPreset(
        previousPresetId is String ? previousPresetId : null,
      );
      if (previousPreset?.modelsUrl != null &&
          existing['modelsUrl'] == previousPreset!.modelsUrl) {
        endpointConfig.remove('modelsUrl');
      }
    }
    return endpointConfig;
  }

  /// Removes only settings owned by the current preset for a custom endpoint.
  static Map<String, dynamic> clearFromEndpointConfig(
    Map<String, dynamic> existing,
  ) {
    final endpointConfig = Map<String, dynamic>.from(existing);
    _removePreviousPresetHeaders(endpointConfig, existing);
    endpointConfig.remove('providerPresetId');
    return endpointConfig;
  }

  static void _removePreviousPresetHeaders(
    Map<String, dynamic> endpointConfig,
    Map<String, dynamic> existing,
  ) {
    final previousId = existing['providerPresetId'];
    final previous = findLlmOpenAiProviderPreset(
      previousId is String ? previousId : null,
    );
    if (previous == null) return;
    if (endpointConfig['apiKeyHeader'] == previous.authorizationHeader) {
      endpointConfig.remove('apiKeyHeader');
    }
    if (endpointConfig['apiKeyScheme'] == previous.authorizationScheme) {
      endpointConfig.remove('apiKeyScheme');
    }
    final configured = endpointConfig['headers'];
    if (configured is! Map) return;
    final remaining = Map<String, dynamic>.from(configured);
    for (final oldHeader in previous.headers.entries) {
      final matchingKey = remaining.keys
          .whereType<String>()
          .where((key) => key.toLowerCase() == oldHeader.key.toLowerCase())
          .firstOrNull;
      if (matchingKey != null && remaining[matchingKey] == oldHeader.value) {
        remaining.remove(matchingKey);
      }
    }
    if (remaining.isEmpty) {
      endpointConfig.remove('headers');
    } else {
      endpointConfig['headers'] = remaining;
    }
  }

  static void _mergePresetHeaders(
    Map<String, dynamic> endpointConfig,
    Map<String, String> presetHeaders,
  ) {
    if (presetHeaders.isEmpty) return;
    final configured = endpointConfig['headers'];
    final merged = configured is Map
        ? Map<String, dynamic>.from(configured)
        : <String, dynamic>{};
    for (final entry in presetHeaders.entries) {
      merged.removeWhere(
        (key, _) => key.toString().toLowerCase() == entry.key.toLowerCase(),
      );
      merged[entry.key] = entry.value;
    }
    endpointConfig['headers'] = merged;
  }
}

const llmOpenAiProviderPresets = <LlmProviderPreset>[
  LlmProviderPreset(
    id: 'api-airforce',
    displayName: 'Api.airforce',
    baseUrl: 'https://api.airforce/v1/chat/completions',
    modelsUrl: 'https://api.airforce/v1/models',
    headers: {
      'HTTP-Referer': 'https://endpoint-proxy.local',
      'X-Title': 'Endpoint Proxy',
    },
  ),
  LlmProviderPreset(
    id: 'navy',
    displayName: 'NavyAI',
    baseUrl: 'https://api.navy/v1/chat/completions',
    modelsUrl: 'https://api.navy/v1/models',
    headers: {'User-Agent': 'OmniRoute/1.0'},
  ),
  LlmProviderPreset(
    id: 'pioneer',
    displayName: 'Pioneer AI',
    baseUrl: 'https://api.pioneer.ai/v1/chat/completions',
    authorizationHeader: 'X-API-Key',
    authorizationScheme: '',
  ),
  LlmProviderPreset(
    id: 'uc-direct',
    displayName: 'UC Direct',
    baseUrl: 'https://api.uncensored.com/api/v1',
    authorizationHeader: 'X-API-Key',
    authorizationScheme: '',
  ),
  LlmProviderPreset(
    id: 'agnes-cn',
    displayName: 'Agnes AI (China)',
    baseUrl: 'https://api.agnes-ai.cn/v1/chat/completions',
    modelsUrl: 'https://api.agnes-ai.cn/v1/models',
    fallbackModels: [
      LlmProviderPresetModel(
        'agnes-2.0-flash',
        displayName: 'Agnes 2.0 Flash',
        capabilities: {
          'contextLength': 262144,
          'maxOutputTokens': 65536,
          'reasoning': true,
          'supportedThinkingEfforts': ['none', 'low', 'medium', 'high', 'max'],
          'vision': true,
          'toolCalling': true,
        },
      ),
      LlmProviderPresetModel(
        'agnes-2.5-flash',
        displayName: 'Agnes 2.5 Flash',
        capabilities: {
          'contextLength': 524288,
          'maxOutputTokens': 65536,
          'reasoning': true,
          'supportedThinkingEfforts': ['none', 'low', 'medium', 'high', 'max'],
          'vision': true,
          'toolCalling': true,
        },
      ),
      LlmProviderPresetModel(
        'agnes-3.0-flash',
        displayName: 'Agnes 3.0 Flash',
        capabilities: {
          'contextLength': 524288,
          'maxOutputTokens': 65536,
          'reasoning': true,
          'supportedThinkingEfforts': [
            'none',
            'minimal',
            'low',
            'medium',
            'high',
            'xhigh',
            'max',
          ],
          'vision': true,
          'toolCalling': true,
        },
      ),
    ],
  ),
  LlmProviderPreset(
    id: 'ai21',
    displayName: 'AI21 Labs',
    baseUrl: 'https://api.ai21.com/studio/v1/chat/completions',
    fallbackModels: [
      LlmProviderPresetModel('jamba-large-1.7'),
      LlmProviderPresetModel('jamba-mini-2'),
    ],
  ),
  LlmProviderPreset(
    id: 'aimlapi',
    displayName: 'AI/ML API',
    baseUrl: 'https://api.aimlapi.com/v1/chat/completions',
    fallbackModels: [
      LlmProviderPresetModel('gpt-5', displayName: 'GPT-5 (via AI/ML API)'),
      LlmProviderPresetModel(
        'claude-sonnet-4.6',
        displayName: 'Claude 4.6 Sonnet (via AI/ML API)',
      ),
      LlmProviderPresetModel(
        'gemini-2.5-pro',
        displayName: 'Gemini 2.5 Pro (via AI/ML API)',
      ),
      LlmProviderPresetModel('glm-5', displayName: 'GLM-5 (via AI/ML API)'),
      LlmProviderPresetModel(
        'deepseek-chat',
        displayName: 'DeepSeek V3 (via AI/ML API)',
      ),
      LlmProviderPresetModel(
        'mistral-large',
        displayName: 'Mistral Large (via AI/ML API)',
      ),
    ],
  ),
  LlmProviderPreset(
    id: 'ainative',
    displayName: 'AINative Studio',
    baseUrl: 'https://api.ainative.studio/api/v1/chat/completions',
    modelsUrl: 'https://api.ainative.studio/api/v1/models',
    fallbackModels: [
      LlmProviderPresetModel('qwen3-235b-cerebras',
          displayName: 'Qwen3 235B (Cerebras)',
          capabilities: {'contextLength': 131072, 'toolCalling': true}),
      LlmProviderPresetModel('qwen3-32b',
          displayName: 'Qwen3 32B',
          capabilities: {'contextLength': 131072, 'toolCalling': true}),
      LlmProviderPresetModel('qwen3-14b',
          displayName: 'Qwen3 14B',
          capabilities: {'contextLength': 131072, 'toolCalling': true}),
      LlmProviderPresetModel('qwen3-8b',
          displayName: 'Qwen3 8B',
          capabilities: {'contextLength': 131072, 'toolCalling': true}),
      LlmProviderPresetModel('llama-4-maverick',
          displayName: 'Llama 4 Maverick',
          capabilities: {'contextLength': 131072, 'toolCalling': true}),
      LlmProviderPresetModel('llama3.1-8b-cerebras',
          displayName: 'Llama 3.1 8B (Cerebras)',
          capabilities: {'contextLength': 131072, 'toolCalling': true}),
      LlmProviderPresetModel('deepseek-r1',
          displayName: 'DeepSeek R1',
          capabilities: {'contextLength': 65536, 'reasoning': true}),
      LlmProviderPresetModel('nous-coder',
          displayName: 'Nous Coder',
          capabilities: {'contextLength': 131072, 'toolCalling': true}),
      LlmProviderPresetModel('gemini-flash',
          displayName: 'Gemini Flash',
          capabilities: {'contextLength': 131072, 'toolCalling': true}),
    ],
  ),
  LlmProviderPreset(
    id: 'ainetcafe',
    displayName: 'ainetcafe',
    baseUrl: 'https://microquickjs.com/v1/chat/completions',
    modelsUrl: 'https://microquickjs.com/v1/models',
  ),
  LlmProviderPreset(
    id: 'aion',
    displayName: 'Aion Labs',
    baseUrl: 'https://api.aionlabs.ai/v1/chat/completions',
    modelsUrl: 'https://api.aionlabs.ai/v1/models',
    fallbackModels: [
      LlmProviderPresetModel('aion-labs/aion-3.0',
          displayName: 'Aion 3.0', capabilities: {'contextLength': 131072}),
      LlmProviderPresetModel('aion-labs/aion-3.0-mini',
          displayName: 'Aion 3.0 Mini',
          capabilities: {'contextLength': 131072}),
      LlmProviderPresetModel('aion-labs/aion-2.5',
          displayName: 'Aion 2.5', capabilities: {'contextLength': 131072}),
      LlmProviderPresetModel('aion-labs/aion-2.0',
          displayName: 'Aion 2.0', capabilities: {'contextLength': 131072}),
      LlmProviderPresetModel('aion-labs/aion-rp-llama-3.1-8b',
          displayName: 'Aion RP Llama 3.1 8B',
          capabilities: {'contextLength': 32768}),
    ],
  ),
  LlmProviderPreset(
    id: 'alibaba',
    displayName: 'Alibaba Cloud Model Studio',
    baseUrl:
        'https://dashscope-intl.aliyuncs.com/compatible-mode/v1/chat/completions',
    modelsUrl: 'https://dashscope-intl.aliyuncs.com/compatible-mode/v1/models',
    fallbackModels: [
      LlmProviderPresetModel('qwen3.8-max', displayName: 'Qwen3.8 Max'),
      LlmProviderPresetModel('qwen3.7-max', displayName: 'Qwen3.7 Max'),
      LlmProviderPresetModel('qwen3.7-plus', displayName: 'Qwen3.7 Plus'),
      LlmProviderPresetModel('qwen3.6-plus', displayName: 'Qwen3.6 Plus'),
      LlmProviderPresetModel('qwen3.6-27b', displayName: 'Qwen3.6 27B'),
      LlmProviderPresetModel('qwen3.6-35b-a3b', displayName: 'Qwen3.6 35B A3B'),
      LlmProviderPresetModel('qwen3.5-plus', displayName: 'Qwen3.5 Plus'),
      LlmProviderPresetModel('qwen3.5-122b-a10b',
          displayName: 'Qwen3.5 122B A10B'),
      LlmProviderPresetModel('qwen3.5-397b-a17b',
          displayName: 'Qwen3.5 397B A17B'),
      LlmProviderPresetModel('glm-5.2', displayName: 'GLM 5.2'),
      LlmProviderPresetModel('glm-5.2-fast-preview',
          displayName: 'GLM 5.2 Fast Preview'),
      LlmProviderPresetModel('deepseek-v4-pro', displayName: 'DeepSeek V4 Pro'),
      LlmProviderPresetModel('deepseek-v4-flash',
          displayName: 'DeepSeek V4 Flash'),
      LlmProviderPresetModel('kimi-k2.7-code', displayName: 'Kimi K2.7 Code'),
    ],
  ),
  LlmProviderPreset(
    id: 'alibaba-cn',
    displayName: 'Alibaba (China)',
    baseUrl:
        'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions',
    modelsUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1/models',
    fallbackModels: [
      LlmProviderPresetModel('qwen3.8-max', displayName: 'Qwen3.8 Max'),
      LlmProviderPresetModel('qwen3.7-max', displayName: 'Qwen3.7 Max'),
      LlmProviderPresetModel('qwen3.7-plus', displayName: 'Qwen3.7 Plus'),
      LlmProviderPresetModel('qwen3.6-plus', displayName: 'Qwen3.6 Plus'),
      LlmProviderPresetModel('qwen3.6-27b', displayName: 'Qwen3.6 27B'),
      LlmProviderPresetModel('qwen3.6-35b-a3b', displayName: 'Qwen3.6 35B A3B'),
      LlmProviderPresetModel('qwen3.5-plus', displayName: 'Qwen3.5 Plus'),
      LlmProviderPresetModel('qwen3.5-122b-a10b',
          displayName: 'Qwen3.5 122B A10B'),
      LlmProviderPresetModel('qwen3.5-397b-a17b',
          displayName: 'Qwen3.5 397B A17B'),
      LlmProviderPresetModel('glm-5.2', displayName: 'GLM 5.2'),
      LlmProviderPresetModel('glm-5.2-fast-preview',
          displayName: 'GLM 5.2 Fast Preview'),
      LlmProviderPresetModel('deepseek-v4-pro', displayName: 'DeepSeek V4 Pro'),
      LlmProviderPresetModel('deepseek-v4-flash',
          displayName: 'DeepSeek V4 Flash'),
      LlmProviderPresetModel('kimi-k2.7-code', displayName: 'Kimi K2.7 Code'),
    ],
  ),
  LlmProviderPreset(
    id: 'ant-ling',
    displayName: 'Ant Ling / Ring (inclusionAI)',
    baseUrl: 'https://api.ant-ling.com/v1/chat/completions',
    fallbackModels: [
      LlmProviderPresetModel('Ling-2.6-1T', displayName: 'Ling 2.6 1T'),
      LlmProviderPresetModel('Ring-2.6-1T', displayName: 'Ring 2.6 1T'),
      LlmProviderPresetModel('Ling-2.6-flash', displayName: 'Ling 2.6 Flash'),
    ],
  ),
  LlmProviderPreset(
    id: 'anyapi',
    displayName: 'AnyAPI AI',
    baseUrl: 'https://api.anyapi.ai/v1/chat/completions',
    modelsUrl: 'https://api.anyapi.ai/v1/models',
  ),
  LlmProviderPreset(
    id: 'apmix',
    displayName: 'Apmix',
    baseUrl: 'https://api.apmix.ai/v1/chat/completions',
    modelsUrl: 'https://api.apmix.ai/v1/models',
    fallbackModels: [
      LlmProviderPresetModel('claude-haiku-4-5'),
      LlmProviderPresetModel('claude-sonnet-5'),
      LlmProviderPresetModel('claude-opus-5'),
      LlmProviderPresetModel('claude-opus-4-8'),
      LlmProviderPresetModel('claude-opus-4-7'),
      LlmProviderPresetModel('claude-opus-4-6'),
      LlmProviderPresetModel('claude-fable-5'),
      LlmProviderPresetModel('claude-sonnet-4-6'),
      LlmProviderPresetModel('gpt-5.6-terra'),
      LlmProviderPresetModel('gpt-5.6-sol'),
      LlmProviderPresetModel('gpt-5.6-luna'),
      LlmProviderPresetModel('gpt-5.5'),
      LlmProviderPresetModel('gpt-6-astra'),
      LlmProviderPresetModel('gpt-6-sol'),
      LlmProviderPresetModel('gpt-6-luna'),
      LlmProviderPresetModel('gpt-6-luna-free'),
      LlmProviderPresetModel('gemini-3.8-flash'),
      LlmProviderPresetModel('gemini-3.7-flash'),
      LlmProviderPresetModel('gemini-3.6-flash'),
      LlmProviderPresetModel('gemini-3.1-pro'),
      LlmProviderPresetModel('grok-4.5'),
      LlmProviderPresetModel('grok-4.6'),
      LlmProviderPresetModel('grok-4.7'),
      LlmProviderPresetModel('deepseek-v4-pro'),
      LlmProviderPresetModel('deepseek-v4-flash'),
      LlmProviderPresetModel('deepseek-v4.1-flash'),
      LlmProviderPresetModel('deepseek-v4-flash-free'),
      LlmProviderPresetModel('qwen3.8-flash'),
      LlmProviderPresetModel('qwen3.8-max'),
      LlmProviderPresetModel('glm-5.3-flash'),
      LlmProviderPresetModel('glm-5.3'),
      LlmProviderPresetModel('glm-5.2'),
      LlmProviderPresetModel('glm-5-turbo'),
      LlmProviderPresetModel('kimi-k2.7-code'),
      LlmProviderPresetModel('kimi-k3'),
      LlmProviderPresetModel('mimo-v2.5-pro'),
      LlmProviderPresetModel('mimo-v2.5'),
      LlmProviderPresetModel('hy4-preview'),
      LlmProviderPresetModel('composer-2.5-fast'),
      LlmProviderPresetModel(
        'minimax-m3',
        displayName: 'MiniMax M3',
        capabilities: {'contextLength': 1048576, 'vision': true},
      ),
      LlmProviderPresetModel('muse-spark-1.3'),
    ],
  ),
  LlmProviderPreset(
    id: 'arcee-ai',
    displayName: 'Arcee AI',
    baseUrl: 'https://api.arcee.ai/api/v1/chat/completions',
  ),
  LlmProviderPreset(
    id: 'auriko',
    displayName: 'Auriko',
    baseUrl: 'https://api.auriko.ai/v1/chat/completions',
    modelsUrl: 'https://api.auriko.ai/v1/models',
  ),
  LlmProviderPreset(
    id: 'bai',
    displayName: 'b.ai',
    baseUrl: 'https://api.b.ai/v1/chat/completions',
    modelsUrl: 'https://api.b.ai/v1/models',
    // The pinned registry names only DeepSeek Reasoner as b.ai's thinking
    // model; other discovered models remain untouched by reasoning echo.
    fallbackModels: [
      LlmProviderPresetModel(
        'deepseek-reasoner',
        displayName: 'DeepSeek Reasoner',
        capabilities: {'reasoning': true},
      ),
    ],
  ),
  LlmProviderPreset(
    id: 'baichuan',
    displayName: 'Baichuan',
    baseUrl: 'https://api.baichuan-ai.com/v1/chat/completions',
    fallbackModels: [
      LlmProviderPresetModel(
        'Baichuan4-Turbo',
        displayName: 'Baichuan 4 Turbo',
        capabilities: {'contextLength': 32768},
      ),
      LlmProviderPresetModel(
        'Baichuan4-Air',
        displayName: 'Baichuan 4 Air',
        capabilities: {'contextLength': 32768},
      ),
      LlmProviderPresetModel('Baichuan4', displayName: 'Baichuan 4'),
      LlmProviderPresetModel(
        'Baichuan3-Turbo',
        displayName: 'Baichuan 3 Turbo',
        capabilities: {'contextLength': 32768},
      ),
      LlmProviderPresetModel(
        'Baichuan3-Turbo-128k',
        displayName: 'Baichuan 3 Turbo 128k',
        capabilities: {'contextLength': 131072},
      ),
    ],
  ),
  // The pinned registry also registers `qianfan` at
  // open-sse/config/providers/registry/qianfan/index.ts:8 with this same chat
  // URL and a separate /models URL. This cohort exposes the audited `baidu`
  // entry and its static catalog once as “Baidu ERNIE (Qianfan)”.
  LlmProviderPreset(
    id: 'baidu',
    displayName: 'Baidu ERNIE (Qianfan)',
    baseUrl: 'https://qianfan.baidubce.com/v2/chat/completions',
    fallbackModels: [
      LlmProviderPresetModel('ernie-5.1',
          displayName: 'ERNIE 5.1', capabilities: {'contextLength': 131072}),
      LlmProviderPresetModel('ernie-5.0',
          displayName: 'ERNIE 5.0', capabilities: {'contextLength': 131072}),
      LlmProviderPresetModel('ernie-x1.1',
          displayName: 'ERNIE X1.1', capabilities: {'contextLength': 32768}),
      LlmProviderPresetModel('ernie-4.5-turbo-128k',
          displayName: 'ERNIE 4.5 Turbo 128K',
          capabilities: {'contextLength': 131072}),
      LlmProviderPresetModel('ernie-4.5-turbo-32k',
          displayName: 'ERNIE 4.5 Turbo 32K',
          capabilities: {'contextLength': 32768}),
      LlmProviderPresetModel('ernie-4.5-turbo-vl',
          displayName: 'ERNIE 4.5 Turbo VL',
          capabilities: {'contextLength': 131072}),
      LlmProviderPresetModel('ernie-4.5-21b-a3b',
          displayName: 'ERNIE 4.5 21B A3B',
          capabilities: {'contextLength': 131072}),
      LlmProviderPresetModel('ernie-4.5-0.3b',
          displayName: 'ERNIE 4.5 0.3B',
          capabilities: {'contextLength': 131072}),
      LlmProviderPresetModel('ernie-4.0-8k', displayName: 'ERNIE 4.0 8K'),
      LlmProviderPresetModel('ernie-4.0-turbo-128k',
          displayName: 'ERNIE 4.0 Turbo 128K',
          capabilities: {'contextLength': 131072}),
      LlmProviderPresetModel('ernie-4.0-turbo-8k',
          displayName: 'ERNIE 4.0 Turbo 8K',
          capabilities: {'contextLength': 8192}),
      LlmProviderPresetModel('ernie-3.5-8k',
          displayName: 'ERNIE 3.5 8K', capabilities: {'contextLength': 8192}),
      LlmProviderPresetModel('ernie-speed-128k',
          displayName: 'ERNIE Speed 128K',
          capabilities: {'contextLength': 131072}),
      LlmProviderPresetModel('ernie-speed-8k',
          displayName: 'ERNIE Speed 8K', capabilities: {'contextLength': 8192}),
      LlmProviderPresetModel('ernie-lite-8k',
          displayName: 'ERNIE Lite 8K', capabilities: {'contextLength': 8192}),
      LlmProviderPresetModel('ernie-tiny-8k',
          displayName: 'ERNIE Tiny 8K', capabilities: {'contextLength': 8192}),
    ],
  ),
  LlmProviderPreset(
    id: 'bluesminds',
    displayName: 'BluesMinds',
    baseUrl: 'https://api.bluesminds.com/v1/chat/completions',
    modelsUrl: 'https://api.bluesminds.com/v1/models',
    fallbackModels: [
      LlmProviderPresetModel('gpt-4o',
          displayName: 'GPT-4o', capabilities: {'contextLength': 128000}),
      LlmProviderPresetModel('gpt-4o-mini',
          displayName: 'GPT-4o Mini', capabilities: {'contextLength': 128000}),
      LlmProviderPresetModel('gpt-4.1',
          displayName: 'GPT-4.1', capabilities: {'contextLength': 128000}),
      LlmProviderPresetModel('gpt-4.1-mini',
          displayName: 'GPT-4.1 Mini', capabilities: {'contextLength': 128000}),
      LlmProviderPresetModel('gpt-4.1-nano',
          displayName: 'GPT-4.1 Nano', capabilities: {'contextLength': 128000}),
      LlmProviderPresetModel('claude-sonnet-4-5',
          displayName: 'Claude Sonnet 4.5',
          capabilities: {'contextLength': 128000}),
      LlmProviderPresetModel('claude-haiku-4-5',
          displayName: 'Claude Haiku 4.5',
          capabilities: {'contextLength': 128000}),
      LlmProviderPresetModel('gemini-2.0-flash',
          displayName: 'Gemini 2.0 Flash',
          capabilities: {'contextLength': 128000}),
      LlmProviderPresetModel('gemini-2.0-flash-exp',
          displayName: 'Gemini 2.0 Flash (Exp)',
          capabilities: {'contextLength': 128000}),
      LlmProviderPresetModel('deepseek-reasoner',
          displayName: 'DeepSeek Reasoner',
          capabilities: {'contextLength': 128000, 'reasoning': true}),
      LlmProviderPresetModel('deepseek-chat',
          displayName: 'DeepSeek Chat',
          capabilities: {'contextLength': 128000}),
      LlmProviderPresetModel('qwen-plus',
          displayName: 'Qwen Plus', capabilities: {'contextLength': 128000}),
      LlmProviderPresetModel('qwen-turbo',
          displayName: 'Qwen Turbo', capabilities: {'contextLength': 128000}),
      LlmProviderPresetModel('kimi-k2',
          displayName: 'Kimi K2', capabilities: {'contextLength': 128000}),
      LlmProviderPresetModel('kimi-k2-thinking',
          displayName: 'Kimi K2 Thinking',
          capabilities: {'contextLength': 128000}),
      LlmProviderPresetModel('glm-4.7',
          displayName: 'GLM 4.7', capabilities: {'contextLength': 128000}),
      LlmProviderPresetModel('glm-4-flash',
          displayName: 'GLM 4 Flash', capabilities: {'contextLength': 128000}),
      LlmProviderPresetModel('minimax-m2.5',
          displayName: 'MiniMax M2.5', capabilities: {'contextLength': 128000}),
      LlmProviderPresetModel('claude-opus-4-5',
          displayName: 'Claude Opus 4.5 (VIP)',
          capabilities: {'contextLength': 200000}),
      LlmProviderPresetModel('gemini-2.5-pro',
          displayName: 'Gemini 2.5 Pro (VIP)',
          capabilities: {'contextLength': 1048576}),
      LlmProviderPresetModel('grok-3',
          displayName: 'Grok-3 (VIP)', capabilities: {'contextLength': 131072}),
      LlmProviderPresetModel('qwen-max',
          displayName: 'Qwen Max (VIP)',
          capabilities: {'contextLength': 128000}),
    ],
  ),
  LlmProviderPreset(
    id: 'baseten',
    displayName: 'Baseten',
    baseUrl: 'https://inference.baseten.co/v1/chat/completions',
    fallbackModels: [
      LlmProviderPresetModel(
        'zai-org/GLM-5.3',
        displayName: 'GLM 5.3',
        capabilities: {'contextLength': 1048576},
      ),
      LlmProviderPresetModel(
        'zai-org/GLM-5.3-Fast',
        displayName: 'GLM 5.3 Fast',
        capabilities: {'contextLength': 1048576},
      ),
      LlmProviderPresetModel(
        'zai-org/GLM-5.3-Flash',
        displayName: 'GLM 5.3 Flash',
        capabilities: {'contextLength': 1048576},
      ),
      LlmProviderPresetModel(
        'zai-org/GLM-5.2',
        displayName: 'GLM 5.2',
        capabilities: {'contextLength': 1048576},
      ),
      LlmProviderPresetModel(
        'zai-org/GLM-5.2-Fast',
        displayName: 'GLM 5.2 Fast',
        capabilities: {'contextLength': 1048576},
      ),
      LlmProviderPresetModel(
        'zai-org/GLM-4.7',
        displayName: 'GLM 4.7',
        capabilities: {'contextLength': 200000},
      ),
      LlmProviderPresetModel(
        'deepseek-ai/DeepSeek-V4-Pro',
        displayName: 'DeepSeek V4 Pro',
        capabilities: {'contextLength': 1048576},
      ),
      LlmProviderPresetModel(
        'deepseek-ai/DeepSeek-V4-Pro-0813',
        displayName: 'DeepSeek V4 Pro 0813',
        capabilities: {'contextLength': 1048576},
      ),
      LlmProviderPresetModel(
        'deepseek-ai/DeepSeek-V4-Flash-0731',
        displayName: 'DeepSeek V4 Flash 0731',
        capabilities: {'contextLength': 1048576},
      ),
      LlmProviderPresetModel(
        'moonshotai/Kimi-K3',
        displayName: 'Kimi K3',
        capabilities: {'contextLength': 1048576},
      ),
      LlmProviderPresetModel(
        'moonshotai/Kimi-K2.6',
        displayName: 'Kimi K2.6',
        capabilities: {'contextLength': 262144},
      ),
      LlmProviderPresetModel(
        'moonshotai/Kimi-K2.7-Code',
        displayName: 'Kimi K2.7 Code',
        capabilities: {'contextLength': 262144},
      ),
      LlmProviderPresetModel(
        'openai/gpt-oss-120b',
        displayName: 'GPT OSS 120B',
        capabilities: {'contextLength': 131072},
      ),
      LlmProviderPresetModel(
        'nvidia/NVIDIA-Nemotron-3-Ultra-550B-A55B',
        displayName: 'Nemotron 3 Ultra',
        capabilities: {'contextLength': 202000},
      ),
      LlmProviderPresetModel(
        'thinkingmachines/inkling',
        displayName: 'Inkling',
        capabilities: {'contextLength': 1048576},
      ),
      LlmProviderPresetModel(
        'thinkingmachines/inkling-small',
        displayName: 'Inkling Small',
        capabilities: {'contextLength': 1048576},
      ),
    ],
  ),
  LlmProviderPreset(
    id: 'bazaarlink',
    displayName: 'BazaarLink',
    baseUrl: 'https://bazaarlink.ai/api/v1/chat/completions',
    modelsUrl: 'https://bazaarlink.ai/api/v1/models',
    fallbackModels: [
      LlmProviderPresetModel('auto:free', displayName: 'Auto Free (Zero Cost)'),
      LlmProviderPresetModel('claude-opus-4.7', displayName: 'Claude Opus 4.7'),
      LlmProviderPresetModel('claude-sonnet-4.6',
          displayName: 'Claude Sonnet 4.6'),
      LlmProviderPresetModel('claude-haiku-4.5',
          displayName: 'Claude Haiku 4.5'),
      LlmProviderPresetModel('gpt-5.5', displayName: 'GPT-5.5'),
      LlmProviderPresetModel('gpt-5.4', displayName: 'GPT-5.4'),
      LlmProviderPresetModel('gpt-5.4-mini', displayName: 'GPT-5.4 Mini'),
      LlmProviderPresetModel('gpt-5.4-nano', displayName: 'GPT-5.4 Nano'),
      LlmProviderPresetModel('grok-4.3', displayName: 'Grok 4.3'),
      LlmProviderPresetModel('grok-4.20', displayName: 'Grok 4.20'),
      LlmProviderPresetModel('gemini-3.1-pro-preview',
          displayName: 'Gemini 3.1 Pro'),
      LlmProviderPresetModel('gemini-3-flash-preview',
          displayName: 'Gemini 3 Flash'),
      LlmProviderPresetModel('gemini-3.1-flash-lite-preview',
          displayName: 'Gemini 3.1 Flash Lite'),
      LlmProviderPresetModel('gemma-4-31b-it',
          displayName: 'Gemma 4 31B',
          capabilities: {
            'reasoning': true,
            'supportedThinkingEfforts': ['none', 'low', 'medium', 'high', 'max']
          }),
      LlmProviderPresetModel('gemma-4-26b-a4b-it',
          displayName: 'Gemma 4 26B A4B'),
      LlmProviderPresetModel('deepseek-v3.2', displayName: 'DeepSeek V3.2'),
      LlmProviderPresetModel('kimi-k2.6', displayName: 'Kimi K2.6'),
      LlmProviderPresetModel('kimi-k2.5', displayName: 'Kimi K2.5'),
      LlmProviderPresetModel('glm-5.1', displayName: 'GLM 5.1'),
      LlmProviderPresetModel('glm-5', displayName: 'GLM 5'),
      LlmProviderPresetModel('mimo-v2.5-pro', displayName: 'MiMo-V2.5-Pro'),
      LlmProviderPresetModel('mimo-v2.5', displayName: 'MiMo-V2.5'),
      LlmProviderPresetModel('minimax-m3',
          displayName: 'MiniMax M3',
          capabilities: {'contextLength': 1048576, 'vision': true}),
      LlmProviderPresetModel('minimax-m2.7', displayName: 'MiniMax M2.7'),
      LlmProviderPresetModel('minimax-m2.5', displayName: 'MiniMax M2.5'),
      LlmProviderPresetModel('llama-4-maverick',
          displayName: 'Llama 4 Maverick'),
      LlmProviderPresetModel('llama-4-scout', displayName: 'Llama 4 Scout'),
      LlmProviderPresetModel('llama-3.3-70b-instruct',
          displayName: 'Llama 3.3 70B'),
      LlmProviderPresetModel('qwen3.6-plus', displayName: 'Qwen 3.6 Plus'),
      LlmProviderPresetModel('mistral-large-2512',
          displayName: 'Mistral Large 3'),
      LlmProviderPresetModel('mistral-medium-3.1',
          displayName: 'Mistral Medium 3.1'),
      LlmProviderPresetModel('mistral-small-2603',
          displayName: 'Mistral Small 4'),
      LlmProviderPresetModel('nemotron-3-super-120b-a12b',
          displayName: 'Nemotron 3 Super'),
    ],
  ),
  LlmProviderPreset(
    id: 'beatapi',
    displayName: 'BeatAPI',
    baseUrl: 'https://api.beatapi.io/v1/chat/completions',
    modelsUrl: 'https://api.beatapi.io/v1/models',
  ),
  LlmProviderPreset(
    id: 'bigmodel',
    displayName: 'BigModel.cn (Zhipu)',
    baseUrl: 'https://open.bigmodel.cn/api/paas/v4/chat/completions',
    fallbackModels: [
      LlmProviderPresetModel('glm-5.3', displayName: 'GLM 5.3'),
      LlmProviderPresetModel('glm-5.3-flash', displayName: 'GLM 5.3 Flash'),
      LlmProviderPresetModel('glm-5.2', displayName: 'GLM 5.2'),
      LlmProviderPresetModel('glm-5.1', displayName: 'GLM 5.1'),
      LlmProviderPresetModel('glm-5-turbo', displayName: 'GLM 5 Turbo'),
      LlmProviderPresetModel('glm-5', displayName: 'GLM 5'),
      LlmProviderPresetModel('glm-4.7', displayName: 'GLM 4.7'),
      LlmProviderPresetModel('glm-4.7-flash', displayName: 'GLM 4.7 Flash'),
      LlmProviderPresetModel('glm-4.7-flashx', displayName: 'GLM 4.7 FlashX'),
      LlmProviderPresetModel('glm-4.6', displayName: 'GLM 4.6'),
      LlmProviderPresetModel('glm-4.5-air', displayName: 'GLM 4.5 Air'),
      LlmProviderPresetModel('glm-4.5-airx', displayName: 'GLM 4.5 AirX'),
      LlmProviderPresetModel('glm-4.5-flash', displayName: 'GLM 4.5 Flash'),
      LlmProviderPresetModel('glm-4-flash-250414',
          displayName: 'GLM 4 Flash 250414'),
      LlmProviderPresetModel('glm-4-flashx-250414',
          displayName: 'GLM 4 FlashX 250414'),
    ],
  ),
  LlmProviderPreset(
    id: 'byteplus',
    displayName: 'BytePlus ModelArk (AP Southeast)',
    baseUrl: 'https://ark.ap-southeast.bytepluses.com/api/v3/chat/completions',
    modelsUrl: 'https://ark.ap-southeast.bytepluses.com/api/v3/models',
    fallbackModels: [
      LlmProviderPresetModel(
        'seed-2.0',
        displayName: 'Seed 2.0',
        capabilities: {'contextLength': 128000},
      ),
      LlmProviderPresetModel(
        'kimi-k2-thinking',
        displayName: 'Kimi K2 Thinking',
        capabilities: {'reasoning': true, 'contextLength': 128000},
      ),
      LlmProviderPresetModel(
        'glm-4.7',
        displayName: 'GLM 4.7',
        capabilities: {'contextLength': 128000},
      ),
      LlmProviderPresetModel(
        'gpt-oss-120b',
        displayName: 'GPT-OSS-120B',
        capabilities: {'contextLength': 128000},
      ),
    ],
  ),
  LlmProviderPreset(
    id: 'bytez',
    displayName: 'Bytez',
    baseUrl: 'https://api.bytez.com/models/v2/openai/v1/chat/completions',
    fallbackModels: [
      LlmProviderPresetModel('meta-llama/Llama-3.3-70B-Instruct'),
      LlmProviderPresetModel('mistralai/Mistral-7B-Instruct-v0.3'),
      LlmProviderPresetModel('Qwen/Qwen2.5-72B-Instruct'),
    ],
  ),
  LlmProviderPreset(
    id: 'cerebras',
    displayName: 'Cerebras',
    baseUrl: 'https://api.cerebras.ai/v1/chat/completions',
    fallbackModels: [
      LlmProviderPresetModel('zai-glm-4.7', displayName: 'GLM 4.7'),
      LlmProviderPresetModel('gemma-4-31b', displayName: 'Gemma 4 31B'),
      LlmProviderPresetModel('gpt-oss-120b', displayName: 'GPT OSS 120B'),
    ],
  ),
  LlmProviderPreset(
    id: 'charm-hyper',
    displayName: 'Charm Hyper',
    baseUrl: 'https://hyper.charm.land/v1/chat/completions',
    modelsUrl: 'https://hyper.charm.land/v1/models',
    fallbackModels: [
      LlmProviderPresetModel('hyper/auto', displayName: 'Charm Hyper Auto')
    ],
  ),
  LlmProviderPreset(
    id: 'chat-oripe',
    displayName: 'Chat Oripe',
    baseUrl: 'https://api.oriper.com/v1/chat/completions',
    modelsUrl: 'https://api.oriper.com/v1/models',
  ),
  LlmProviderPreset(
    id: 'chatanywhere',
    displayName: 'ChatAnywhere',
    baseUrl: 'https://api.chatanywhere.org/v1/chat/completions',
    modelsUrl: 'https://api.chatanywhere.org/v1/models',
  ),
  // Evidence: OmniRoute open-sse/config/providers/registry/chenzk/index.ts.
  // Its runtime default context length is not representable for discovered
  // models in this preset contract, so no per-model context is asserted here.
  LlmProviderPreset(
    id: 'chenzk',
    displayName: 'Chenzk',
    baseUrl: 'https://chenzk.top/v1/chat/completions',
    modelsUrl: 'https://chenzk.top/v1/models',
  ),
  LlmProviderPreset(
    id: 'cheaperinference',
    displayName: 'CheaperInference',
    baseUrl: 'https://api.cheaperinference.com/v1/chat/completions',
    modelsUrl: 'https://api.cheaperinference.com/v1/models',
    fallbackModels: [
      LlmProviderPresetModel(
        'gpt-5.4',
        displayName: 'GPT-5.4',
        capabilities: {
          'chat': true,
          'streaming': true,
          'vision': true,
          'reasoning': true,
          'tools': true,
        },
        apiProtocolOverride: 'openai.responses',
      ),
      LlmProviderPresetModel(
        'gpt-5.4-mini',
        displayName: 'GPT-5.4 Mini',
        capabilities: {
          'chat': true,
          'streaming': true,
          'vision': true,
          'reasoning': true,
          'tools': true,
        },
        apiProtocolOverride: 'openai.responses',
      ),
      LlmProviderPresetModel(
        'gpt-5.5',
        displayName: 'GPT-5.5',
        capabilities: {
          'chat': true,
          'streaming': true,
          'vision': true,
          'reasoning': true,
          'tools': true,
        },
        apiProtocolOverride: 'openai.responses',
      ),
      LlmProviderPresetModel(
        'gpt-5.6-luna',
        displayName: 'GPT-5.6 Luna',
        capabilities: {
          'chat': true,
          'streaming': true,
          'vision': true,
          'reasoning': true,
          'tools': true,
        },
        apiProtocolOverride: 'openai.responses',
      ),
      LlmProviderPresetModel(
        'gpt-5.6-sol',
        displayName: 'GPT-5.6 Sol',
        capabilities: {
          'chat': true,
          'streaming': true,
          'vision': true,
          'reasoning': true,
          'tools': true,
        },
        apiProtocolOverride: 'openai.responses',
      ),
      LlmProviderPresetModel(
        'gpt-5.6-terra',
        displayName: 'GPT-5.6 Terra',
        capabilities: {
          'chat': true,
          'streaming': true,
          'vision': true,
          'reasoning': true,
          'tools': true,
        },
        apiProtocolOverride: 'openai.responses',
      ),
    ],
  ),
  LlmProviderPreset(
    id: 'chutes',
    displayName: 'Chutes.ai',
    baseUrl: 'https://llm.chutes.ai/v1/chat/completions',
    fallbackModels: [
      LlmProviderPresetModel('Qwen2.5-72B-Instruct',
          displayName: 'Qwen2.5 72B'),
    ],
  ),
  LlmProviderPreset(
    id: 'cloudcode-one',
    displayName: 'CloudCode.ONE',
    baseUrl: 'https://api.cloudcode.one/v1/chat/completions',
    modelsUrl: 'https://api.cloudcode.one/v1/models',
    fallbackModels: [
      LlmProviderPresetModel('glm-4.7-flash', displayName: 'GLM 4.7 Flash'),
      LlmProviderPresetModel('glm-4.6v-flash', displayName: 'GLM 4.6V Flash'),
    ],
  ),
  LlmProviderPreset(
    id: 'codestral',
    displayName: 'Codestral',
    baseUrl: 'https://codestral.mistral.ai/v1/chat/completions',
    fallbackModels: [
      LlmProviderPresetModel('codestral-2508'),
      LlmProviderPresetModel('codestral-latest'),
    ],
  ),
  LlmProviderPreset(
    id: 'cohere',
    displayName: 'Cohere',
    baseUrl: 'https://api.cohere.com/compatibility/v1/chat/completions',
    modelsUrl: 'https://api.cohere.com/compatibility/v1/models',
    fallbackModels: [
      LlmProviderPresetModel('command-a-reasoning-08-2025',
          displayName: 'Command A Reasoning (Aug 2025)'),
      LlmProviderPresetModel('command-a-vision-07-2025',
          displayName: 'Command A Vision (Jul 2025)'),
      LlmProviderPresetModel('command-a-03-2025',
          displayName: 'Command A (Mar 2025)'),
      LlmProviderPresetModel('command-r7b-12-2024',
          displayName: 'Command R7B (Dec 2024)'),
      LlmProviderPresetModel('command-r-plus-08-2024',
          displayName: 'Command R Plus (Aug 2024)'),
      LlmProviderPresetModel('command-r-08-2024',
          displayName: 'Command R (Aug 2024)'),
    ],
  ),
  LlmProviderPreset(
    id: 'coze',
    displayName: 'Coze',
    baseUrl: 'https://api.coze.com/v1/chat/completions',
    fallbackModels: [
      LlmProviderPresetModel('claude-3-7-sonnet-20250514',
          displayName: 'Claude 3.7 Sonnet'),
    ],
  ),
  LlmProviderPreset(
    id: 'crof',
    displayName: 'CrofAI',
    baseUrl: 'https://crof.ai/v1/chat/completions',
    fallbackModels: [
      LlmProviderPresetModel('deepseek-v4-pro',
          displayName: 'DeepSeek V4 Pro',
          capabilities: {
            'reasoning': true,
            'supportedThinkingEfforts': ['none', 'low', 'medium', 'high', 'max']
          }),
      LlmProviderPresetModel('deepseek-v4-flash',
          displayName: 'DeepSeek V4 Flash',
          capabilities: {
            'reasoning': true,
            'supportedThinkingEfforts': ['none', 'low', 'medium', 'high', 'max']
          }),
      LlmProviderPresetModel('deepseek-v4-flash-0731',
          displayName: 'DeepSeek V4 Flash 0731',
          capabilities: {
            'reasoning': true,
            'supportedThinkingEfforts': ['none', 'low', 'medium', 'high', 'max']
          }),
      LlmProviderPresetModel('deepseek-v3.2', displayName: 'DeepSeek V3.2'),
      LlmProviderPresetModel('kimi-k2.6',
          displayName: 'Kimi K2.6',
          capabilities: {
            'reasoning': true,
            'supportedThinkingEfforts': ['none', 'low', 'medium', 'high', 'max']
          }),
      LlmProviderPresetModel('kimi-k2.7-code',
          displayName: 'Kimi K2.7 Code',
          capabilities: {
            'reasoning': true,
            'supportedThinkingEfforts': ['none', 'low', 'medium', 'high', 'max']
          }),
      LlmProviderPresetModel('kimi-k3', displayName: 'Kimi K3', capabilities: {
        'reasoning': true,
        'supportedThinkingEfforts': ['none', 'low', 'medium', 'high', 'max']
      }),
      LlmProviderPresetModel('kimi-k3-eco',
          displayName: 'Kimi K3 Eco',
          capabilities: {
            'reasoning': true,
            'supportedThinkingEfforts': ['none', 'low', 'medium', 'high', 'max']
          }),
      LlmProviderPresetModel('glm-5.1', displayName: 'GLM 5.1', capabilities: {
        'reasoning': true,
        'supportedThinkingEfforts': ['none', 'low', 'medium', 'high', 'max']
      }),
      LlmProviderPresetModel('glm-5.2', displayName: 'GLM 5.2', capabilities: {
        'reasoning': true,
        'supportedThinkingEfforts': ['none', 'low', 'medium', 'high', 'max']
      }),
      LlmProviderPresetModel('mimo-v2.5-pro',
          displayName: 'Mimo 2.5 Pro',
          capabilities: {
            'reasoning': true,
            'supportedThinkingEfforts': ['none', 'low', 'medium', 'high', 'max']
          }),
      LlmProviderPresetModel('gemma-4-31b-it',
          displayName: 'Gemma 4 31B',
          capabilities: {
            'reasoning': true,
            'supportedThinkingEfforts': ['none', 'low', 'medium', 'high', 'max']
          }),
      LlmProviderPresetModel('qwen3.6-27b',
          displayName: 'Qwen3.6 27B',
          capabilities: {
            'reasoning': true,
            'supportedThinkingEfforts': ['none', 'low', 'medium', 'high', 'max']
          }),
      LlmProviderPresetModel('qwen3.5-397b-a17b',
          displayName: 'Qwen3.5 397B A17B',
          capabilities: {
            'reasoning': true,
            'supportedThinkingEfforts': ['none', 'low', 'medium', 'high', 'max']
          }),
      LlmProviderPresetModel('qwen3.5-9b',
          displayName: 'Qwen3.5 9B',
          capabilities: {
            'reasoning': true,
            'supportedThinkingEfforts': ['none', 'low', 'medium', 'high', 'max']
          }),
    ],
  ),
  // Registry audit pinned at OmniRoute d1ba822: Dahl uses the shared OpenAI
  // Chat Completions executor, bearer API key, and two static models.
  LlmProviderPreset(
    id: 'dahl',
    displayName: 'Dahl',
    baseUrl: 'https://inference.dahl.global/v1/chat/completions',
    fallbackModels: [
      LlmProviderPresetModel(
        'MiniMaxAI/MiniMax-M2.7',
        displayName: 'MiniMax M2.7',
        capabilities: {'contextLength': 200000},
      ),
      LlmProviderPresetModel(
        'moonshotai/Kimi-K2.6',
        displayName: 'Kimi K2.6',
        capabilities: {'contextLength': 200000},
      ),
    ],
  ),
  LlmProviderPreset(
    id: 'daoxe',
    displayName: 'DaoXE',
    baseUrl: 'https://api.daoxe.com/v1/chat/completions',
    modelsUrl: 'https://api.daoxe.com/v1/models',
    fallbackModels: [
      LlmProviderPresetModel('claude-sonnet-4-6',
          displayName: 'Claude Sonnet 4.6'),
      LlmProviderPresetModel('claude-opus-4-8', displayName: 'Claude Opus 4.8'),
      LlmProviderPresetModel('claude-haiku-4-5-20251001',
          displayName: 'Claude Haiku 4.5'),
      LlmProviderPresetModel('gpt-5.5', displayName: 'GPT-5.5'),
      LlmProviderPresetModel('gpt-5.4', displayName: 'GPT-5.4'),
      LlmProviderPresetModel('gemini-3.1-pro-preview',
          displayName: 'Gemini 3.1 Pro Preview'),
      LlmProviderPresetModel('grok-4.5', displayName: 'Grok 4.5'),
      LlmProviderPresetModel('grok-4.3', displayName: 'Grok 4.3'),
      LlmProviderPresetModel('kimi-k2.5', displayName: 'Kimi K2.5'),
    ],
  ),
  LlmProviderPreset(
    id: 'demonroute',
    displayName: 'Demon Route',
    baseUrl: 'https://api.demonroute.com/v1/chat/completions',
    modelsUrl: 'https://api.demonroute.com/v1/models',
    fallbackModels: [
      LlmProviderPresetModel('dphn/Dolphin3.0-Llama3.1-8B',
          displayName: 'Dolphin 3.0 Llama 3.1 8B'),
      LlmProviderPresetModel('dphn/Dolphin-Mistral-24B-Venice-Edition',
          displayName: 'Dolphin Mistral 24B Venice'),
      LlmProviderPresetModel('TheDrummer/Artemis-31B-v1.2',
          displayName: 'Artemis 31B v1.2'),
      LlmProviderPresetModel('TheDrummer/Cydonia-24B-v4.3',
          displayName: 'Cydonia 24B v4.3'),
      LlmProviderPresetModel('huihui-ai/Huihui-Qwen3.6-35B-A3B-abliterated',
          displayName: 'Huihui Qwen 3.6 35B A3B Abliterated'),
      LlmProviderPresetModel('huihui-ai/Huihui-gemma-4-31B-it-abliterated-v2',
          displayName: 'Huihui Gemma 4 31B Abliterated v2'),
      LlmProviderPresetModel('dphn/dolphin-2.9.3-mistral-nemo-12b',
          displayName: 'Dolphin 2.9.3 Mistral Nemo 12B'),
    ],
  ),
  LlmProviderPreset(
    id: 'dgrid',
    displayName: 'DGrid',
    baseUrl: 'https://api.dgrid.ai/v1/chat/completions',
    modelsUrl: 'https://api.dgrid.ai/v1/models',
    fallbackModels: [
      LlmProviderPresetModel('dgridai/free',
          displayName: 'DGrid Free Models Router',
          capabilities: {'contextLength': 128000}),
    ],
  ),
  LlmProviderPreset(
    id: 'digitalocean',
    displayName: 'DigitalOcean',
    baseUrl: 'https://inference.do-ai.run/v1/chat/completions',
    modelsUrl: 'https://inference.do-ai.run/v1/models',
  ),
  LlmProviderPreset(
    id: 'dit',
    displayName: 'DIT.ai',
    baseUrl: 'https://api.dit.ai/v1/chat/completions',
    modelsUrl: 'https://api.dit.ai/v1/models',
    fallbackModels: [
      LlmProviderPresetModel('gpt-5.4',
          displayName: 'GPT-5.4 (DIT.ai)',
          capabilities: {
            'contextLength': 400000,
            'toolCalling': true,
            'reasoning': true,
            'vision': true
          }),
      LlmProviderPresetModel('claude-sonnet-4-6',
          displayName: 'Claude Sonnet 4.6 (DIT.ai)',
          capabilities: {
            'contextLength': 200000,
            'toolCalling': true,
            'reasoning': true,
            'vision': true,
            'supportedThinkingEfforts': ['low', 'medium', 'high', 'max']
          }),
    ],
  ),
  LlmProviderPreset(
    id: 'dxnt',
    displayName: 'DXNT / DX Token',
    baseUrl: 'https://www.dxnt.com/v1/chat/completions',
    modelsUrl: 'https://www.dxnt.com/v1/models',
  ),
  LlmProviderPreset(
    id: 'electronhub',
    displayName: 'Electron Hub',
    baseUrl: 'https://api.electronhub.ai/v1/chat/completions',
    modelsUrl: 'https://api.electronhub.ai/v1/models',
  ),
  LlmProviderPreset(
    id: 'eurouter',
    displayName: 'EURouter',
    baseUrl: 'https://api.eurouter.ai/v1/chat/completions',
    modelsUrl: 'https://api.eurouter.ai/v1/models',
  ),
  LlmProviderPreset(
    id: 'factory',
    displayName: 'Factory',
    baseUrl: 'https://api.factory.ai/v1/chat/completions',
    fallbackModels: [
      LlmProviderPresetModel('auto', displayName: 'Factory Auto (best model)'),
    ],
  ),
  LlmProviderPreset(
    id: 'fastrouter',
    displayName: 'FastRouter',
    baseUrl: 'https://api.fastrouter.ai/api/v1/chat/completions',
    modelsUrl: 'https://api.fastrouter.ai/api/v1/models',
  ),
  LlmProviderPreset(
    id: 'featherless-ai',
    displayName: 'Featherless AI',
    baseUrl: 'https://api.featherless.ai/v1/chat/completions',
    fallbackModels: [
      LlmProviderPresetModel('featherless-ai/Qwerky-72B'),
      LlmProviderPresetModel('featherless-ai/Qwerky-QwQ-32B'),
    ],
  ),
  LlmProviderPreset(
    id: 'deepinfra',
    displayName: 'DeepInfra',
    baseUrl: 'https://api.deepinfra.com/v1/openai/chat/completions',
    fallbackModels: [
      LlmProviderPresetModel('anthropic/claude-4-opus'),
      LlmProviderPresetModel('anthropic/claude-4-sonnet'),
      LlmProviderPresetModel('openai/gpt-oss-120b'),
      LlmProviderPresetModel('openai/gpt-oss-20b'),
      LlmProviderPresetModel('google/gemma-4-31B-it'),
      LlmProviderPresetModel('google/gemma-4-26B-A4B-it'),
      LlmProviderPresetModel('nvidia/NVIDIA-Nemotron-3-Super-120B-A12B'),
      LlmProviderPresetModel('nvidia/Nemotron-3-Nano-Omni-30B-A3B-Reasoning'),
      LlmProviderPresetModel(
          'meta-llama/Llama-4-Maverick-17B-128E-Instruct-FP8'),
      LlmProviderPresetModel('meta-llama/Llama-4-Scout-17B-16E-Instruct'),
      LlmProviderPresetModel('meta-llama/Llama-3.3-70B-Instruct-Turbo'),
      LlmProviderPresetModel('NousResearch/Hermes-3-Llama-3.1-405B'),
      LlmProviderPresetModel('deepseek-ai/DeepSeek-V4-Pro'),
      LlmProviderPresetModel('deepseek-ai/DeepSeek-V4-Flash'),
      LlmProviderPresetModel('zai-org/GLM-5.1'),
      LlmProviderPresetModel('moonshotai/Kimi-K2.6'),
      LlmProviderPresetModel('MiniMaxAI/MiniMax-M2.5'),
      LlmProviderPresetModel('Qwen/Qwen3.6-35B-A3B'),
      LlmProviderPresetModel('Qwen/Qwen3.5-397B-A17B'),
      LlmProviderPresetModel('Qwen/Qwen3.5-122B-A10B'),
      LlmProviderPresetModel('XiaomiMiMo/MiMo-V2.5-Pro'),
      LlmProviderPresetModel('XiaomiMiMo/MiMo-V2.5'),
    ],
  ),
  LlmProviderPreset(
    id: 'doubao',
    displayName: 'Doubao',
    baseUrl: 'https://ark.cn-beijing.volces.com/api/v3/chat/completions',
    fallbackModels: [
      LlmProviderPresetModel(
        'doubao-seed-2-0-pro-260215',
        displayName: 'Doubao Seed 2.0 Pro',
        capabilities: {'contextLength': 262144},
      ),
      LlmProviderPresetModel(
        'doubao-seed-2-0-lite-260215',
        displayName: 'Doubao Seed 2.0 Lite',
        capabilities: {'contextLength': 262144},
      ),
      LlmProviderPresetModel(
        'doubao-seed-2-0-mini-260215',
        displayName: 'Doubao Seed 2.0 Mini',
        capabilities: {'contextLength': 262144},
      ),
      LlmProviderPresetModel(
        'doubao-seed-2-0-code-preview-260215',
        displayName: 'Doubao Seed 2.0 Code',
        capabilities: {'contextLength': 262144},
      ),
      LlmProviderPresetModel(
        'doubao-seed-1-8-251228',
        displayName: 'Doubao Seed 1.8',
        capabilities: {'contextLength': 262144},
      ),
      LlmProviderPresetModel(
        'doubao-seed-1-6-251015',
        displayName: 'Doubao Seed 1.6',
        capabilities: {'contextLength': 262144},
      ),
      LlmProviderPresetModel(
        'doubao-seed-1-6-flash-250828',
        displayName: 'Doubao Seed 1.6 Flash',
        capabilities: {'contextLength': 262144},
      ),
      LlmProviderPresetModel(
        'doubao-1-5-pro-32k-250115',
        displayName: 'Doubao 1.5 Pro 32K',
        capabilities: {'contextLength': 32768},
      ),
      LlmProviderPresetModel('doubao-pro-32k', displayName: 'Doubao Pro 32K'),
    ],
  ),
  LlmProviderPreset(
    id: 'fireworks',
    displayName: 'Fireworks AI',
    baseUrl: 'https://api.fireworks.ai/inference/v1/chat/completions',
    modelsUrl:
        'https://api.fireworks.ai/v1/accounts/fireworks/models?filter=supports_serverless=true',
    modelIdPrefix: 'accounts/fireworks/models/',
    fallbackModels: [
      LlmProviderPresetModel(
        'deepseek-v4-flash',
        displayName: 'DeepSeek V4 Flash',
        capabilities: {'reasoning': true},
      ),
      LlmProviderPresetModel(
        'deepseek-v4-pro',
        displayName: 'DeepSeek V4 Pro',
        capabilities: {'reasoning': true},
      ),
      LlmProviderPresetModel('glm-5p1', displayName: 'GLM 5.1'),
      LlmProviderPresetModel(
        'gpt-oss-120b',
        displayName: 'OpenAI gpt-oss-120b',
      ),
      LlmProviderPresetModel('gpt-oss-20b', displayName: 'OpenAI gpt-oss-20b'),
      LlmProviderPresetModel('kimi-k2p5', displayName: 'Kimi K2.5'),
      LlmProviderPresetModel('kimi-k2p6', displayName: 'Kimi K2.6'),
      LlmProviderPresetModel('minimax-m2p5', displayName: 'MiniMax M2.5'),
      LlmProviderPresetModel('minimax-m2p7', displayName: 'MiniMax M2.7'),
      LlmProviderPresetModel('qwen3p6-plus', displayName: 'Qwen3.6 Plus'),
    ],
  ),
  LlmProviderPreset(
    id: 'groq',
    displayName: 'Groq',
    baseUrl: 'https://api.groq.com/openai/v1/chat/completions',
    fallbackModels: [
      LlmProviderPresetModel(
        'groq/compound',
        displayName: 'Groq Compound',
        capabilities: {'reasoning': false},
      ),
      LlmProviderPresetModel(
        'allam-2-7b',
        displayName: 'ALLaM 2 7B',
        capabilities: {'reasoning': false},
      ),
      LlmProviderPresetModel(
        'openai/gpt-oss-120b',
        displayName: 'GPT-OSS 120B',
      ),
      LlmProviderPresetModel('openai/gpt-oss-20b', displayName: 'GPT-OSS 20B'),
      LlmProviderPresetModel('qwen/qwen3.6-27b', displayName: 'Qwen3.6 27B'),
      LlmProviderPresetModel('qwen/qwen3.8-27b', displayName: 'Qwen3.8 27B'),
      LlmProviderPresetModel(
        'openai/gpt-oss-safeguard-20b',
        displayName: 'GPT-OSS Safeguard 20B',
      ),
    ],
  ),
  LlmProviderPreset(
    id: 'huggingface',
    displayName: 'HuggingFace',
    baseUrl: 'https://router.huggingface.co/v1/chat/completions',
    modelsUrl: 'https://router.huggingface.co/v1/models',
    fallbackModels: [
      LlmProviderPresetModel(
        'meta-llama/llama-3.1-8b-instruct',
        displayName: 'Llama 3.1 8B',
      ),
      LlmProviderPresetModel(
        'meta-llama/llama-3.2-11b-instruct',
        displayName: 'Llama 3.2 11B',
      ),
      LlmProviderPresetModel(
        'mistralai/mistral-7b-instruct',
        displayName: 'Mistral 7B',
      ),
      LlmProviderPresetModel('google/gemma-2-9b-it', displayName: 'Gemma 2 9B'),
      LlmProviderPresetModel(
        'Qwen/Qwen2.5-7B-Instruct',
        displayName: 'Qwen 2.5 7B',
      ),
      LlmProviderPresetModel(
        'deepseek-ai/DeepSeek-V3',
        displayName: 'DeepSeek V3',
      ),
    ],
  ),
  LlmProviderPreset(
    id: 'iflytek',
    displayName: 'iFlytek Spark',
    baseUrl: 'https://spark-api-open.xf-yun.com/v1/chat/completions',
    fallbackModels: [
      LlmProviderPresetModel(
        '4.0Ultra',
        displayName: 'Spark 4.0 Ultra',
        capabilities: {'contextLength': 32768},
      ),
      LlmProviderPresetModel('generalv3.5', displayName: 'Spark Max (V3.5)'),
      LlmProviderPresetModel(
        'max-32k',
        displayName: 'Spark Max 32K',
        capabilities: {'contextLength': 32768},
      ),
      LlmProviderPresetModel(
        'generalv3',
        displayName: 'Spark Pro',
        capabilities: {'contextLength': 8192},
      ),
      LlmProviderPresetModel(
        'pro-128k',
        displayName: 'Spark Pro 128K',
        capabilities: {'contextLength': 131072},
      ),
      LlmProviderPresetModel(
        'lite',
        displayName: 'Spark Lite',
        capabilities: {'contextLength': 4096},
      ),
    ],
  ),
  LlmProviderPreset(
    id: 'internlm',
    displayName: 'InternLM (Intern-S1)',
    baseUrl: 'https://chat.intern-ai.org.cn/api/v1/chat/completions',
    fallbackModels: [
      LlmProviderPresetModel('intern-s1-pro', displayName: 'Intern-S1 Pro'),
      LlmProviderPresetModel('intern-s1', displayName: 'Intern-S1'),
      LlmProviderPresetModel('intern-s1-mini', displayName: 'Intern-S1 Mini'),
      LlmProviderPresetModel('internvl3.5-latest',
          displayName: 'InternVL3.5 Latest'),
      LlmProviderPresetModel('intern-latest', displayName: 'Intern Latest'),
    ],
  ),
  LlmProviderPreset(
    id: 'mistral',
    displayName: 'Mistral',
    baseUrl: 'https://api.mistral.ai/v1/chat/completions',
    fallbackModels: [
      LlmProviderPresetModel(
        'mistral-large-latest',
        displayName: 'Mistral Large 3',
      ),
      LlmProviderPresetModel(
        'mistral-medium-3-5',
        displayName: 'Mistral Medium 3.5',
      ),
      LlmProviderPresetModel(
        'mistral-small-latest',
        displayName: 'Mistral Small 4',
      ),
      LlmProviderPresetModel('devstral-latest', displayName: 'Devstral 2'),
      LlmProviderPresetModel('codestral-latest', displayName: 'Codestral'),
    ],
  ),
  LlmProviderPreset(
    id: 'novita',
    displayName: 'Novita AI',
    baseUrl: 'https://api.novita.ai/openai/v1/chat/completions',
    modelsUrl: 'https://api.novita.ai/openai/v1/models',
    fallbackModels: [
      LlmProviderPresetModel(
        'deepseek/deepseek-v4-pro',
        displayName: 'DeepSeek V4 Pro',
        capabilities: {
          'reasoning': true,
          'contextLength': 1048576,
          'maxOutputTokens': 393216,
        },
      ),
      LlmProviderPresetModel(
        'deepseek/deepseek-v4-flash',
        displayName: 'DeepSeek V4 Flash',
        capabilities: {
          'reasoning': true,
          'contextLength': 1048576,
          'maxOutputTokens': 393216,
        },
      ),
      LlmProviderPresetModel(
        'deepseek/deepseek-v3.2',
        displayName: 'DeepSeek V3.2',
        capabilities: {
          'reasoning': true,
          'contextLength': 163840,
          'maxOutputTokens': 65536,
        },
      ),
      LlmProviderPresetModel(
        'moonshotai/kimi-k3',
        displayName: 'Kimi K3',
        capabilities: {
          'reasoning': true,
          'vision': true,
          'contextLength': 1048576,
          'maxOutputTokens': 1048576,
        },
      ),
      LlmProviderPresetModel(
        'moonshotai/kimi-k2.7-code',
        displayName: 'Kimi K2.7 Code',
        capabilities: {
          'reasoning': true,
          'vision': true,
          'contextLength': 262144,
          'maxOutputTokens': 262144,
        },
      ),
      LlmProviderPresetModel(
        'moonshotai/kimi-k2.6',
        displayName: 'Kimi K2.6',
        capabilities: {
          'reasoning': true,
          'vision': true,
          'contextLength': 262144,
          'maxOutputTokens': 262144,
        },
      ),
      LlmProviderPresetModel(
        'zai-org/glm-5.2',
        displayName: 'GLM 5.2',
        capabilities: {
          'reasoning': true,
          'contextLength': 1048576,
          'maxOutputTokens': 131072,
        },
      ),
      LlmProviderPresetModel(
        'zai-org/glm-5.1',
        displayName: 'GLM 5.1',
        capabilities: {
          'reasoning': true,
          'contextLength': 204800,
          'maxOutputTokens': 131072,
        },
      ),
      LlmProviderPresetModel(
        'zai-org/glm-4.7',
        displayName: 'GLM 4.7',
        capabilities: {
          'reasoning': true,
          'contextLength': 204800,
          'maxOutputTokens': 131072,
        },
      ),
      LlmProviderPresetModel(
        'minimax/minimax-m3',
        displayName: 'MiniMax M3',
        capabilities: {
          'reasoning': true,
          'vision': true,
          'contextLength': 1000000,
          'maxOutputTokens': 131072,
        },
      ),
      LlmProviderPresetModel(
        'minimax/minimax-m2.7',
        displayName: 'MiniMax M2.7',
        capabilities: {
          'reasoning': true,
          'contextLength': 204800,
          'maxOutputTokens': 131072,
        },
      ),
      LlmProviderPresetModel(
        'qwen/qwen3.7-max',
        displayName: 'Qwen3.7 Max',
        capabilities: {
          'reasoning': true,
          'contextLength': 1000000,
          'maxOutputTokens': 65536,
        },
      ),
      LlmProviderPresetModel(
        'qwen/qwen3.6-plus',
        displayName: 'Qwen3.6 Plus',
        capabilities: {
          'reasoning': true,
          'vision': true,
          'contextLength': 1000000,
          'maxOutputTokens': 65536,
        },
      ),
      LlmProviderPresetModel(
        'qwen/qwen3.5-397b-a17b',
        displayName: 'Qwen3.5 397B A17B',
        capabilities: {
          'reasoning': true,
          'vision': true,
          'contextLength': 262144,
          'maxOutputTokens': 65536,
        },
      ),
      LlmProviderPresetModel(
        'qwen/qwen3-coder-480b-a35b-instruct',
        displayName: 'Qwen3 Coder 480B',
        capabilities: {'contextLength': 262144, 'maxOutputTokens': 65536},
      ),
      LlmProviderPresetModel(
        'xiaomimimo/mimo-v2.5-pro',
        displayName: 'MiMo V2.5 Pro',
        capabilities: {
          'reasoning': true,
          'contextLength': 1048576,
          'maxOutputTokens': 131072,
        },
      ),
      LlmProviderPresetModel(
        'openai/gpt-oss-120b',
        displayName: 'OpenAI gpt-oss-120b',
        capabilities: {
          'reasoning': true,
          'contextLength': 131072,
          'maxOutputTokens': 32768,
        },
      ),
      LlmProviderPresetModel(
        'google/gemma-4-31b-it',
        displayName: 'Gemma 4 31B',
        capabilities: {
          'reasoning': true,
          'vision': true,
          'contextLength': 262144,
          'maxOutputTokens': 131072,
        },
      ),
      LlmProviderPresetModel(
        'meta-llama/llama-3.1-8b-instruct',
        displayName: 'Llama 3.1 8B Instruct',
        capabilities: {'contextLength': 16384, 'maxOutputTokens': 16384},
      ),
    ],
  ),
  LlmProviderPreset(
    id: 'nvidia',
    displayName: 'NVIDIA NIM',
    baseUrl: 'https://integrate.api.nvidia.com/v1/chat/completions',
    fallbackModels: [
      LlmProviderPresetModel('moonshotai/kimi-k3', displayName: 'Kimi K3'),
      LlmProviderPresetModel(
        'deepseek-ai/deepseek-v4-pro-0813',
        displayName: 'DeepSeek V4 Pro 0813',
        capabilities: {'reasoning': true},
      ),
      LlmProviderPresetModel(
        'deepseek-ai/deepseek-v4-flash-0731',
        displayName: 'DeepSeek V4 Flash 0731',
        capabilities: {'reasoning': true},
      ),
      LlmProviderPresetModel(
        'meta/muse-glimmer-30b',
        displayName: 'Muse Glimmer 30B',
      ),
      LlmProviderPresetModel(
        'poolside/laguna-xs-2.1',
        displayName: 'Laguna XS 2.1',
      ),
      LlmProviderPresetModel(
        'google/gemma-4-31b-it',
        displayName: 'Gemma 4 31B',
      ),
      LlmProviderPresetModel(
        'google/diffusiongemma-26b-a4b-it',
        displayName: 'DiffusionGemma 26B A4B IT',
      ),
      LlmProviderPresetModel(
        'nvidia/nemotron-3-ultra-550b-a55b',
        displayName: 'Nemotron 3 Ultra 550B A55B',
        capabilities: {'reasoning': true},
      ),
      LlmProviderPresetModel(
        'nvidia/nemotron-3.5-super-vl-120b-a12b',
        displayName: 'Nemotron 3.5 Super VL 120B A12B',
        capabilities: {'vision': true},
      ),
      LlmProviderPresetModel(
        'nvidia/nemotron-3.5-lightning-30b-a3b',
        displayName: 'Nemotron 3 Lightning 30B A3B',
      ),
      LlmProviderPresetModel(
        'nvidia/nemotron-3-nano-omni-30b-a3b-reasoning',
        displayName: 'Nemotron 3 Nano Omni 30B A3B Reasoning',
        capabilities: {'reasoning': true, 'vision': true},
      ),
      LlmProviderPresetModel(
        'openai/gpt-oss-120b',
        displayName: 'GPT OSS 120B',
      ),
    ],
  ),
  LlmProviderPreset(
    id: 'siliconflow',
    displayName: 'SiliconFlow',
    baseUrl: 'https://api.siliconflow.com/v1/chat/completions',
    fallbackModels: [
      LlmProviderPresetModel('deepseek-ai/DeepSeek-V3.2',
          displayName: 'DeepSeek V3.2'),
      LlmProviderPresetModel('deepseek-ai/DeepSeek-V3.2-Exp',
          displayName: 'DeepSeek V3.2 Exp'),
      LlmProviderPresetModel('deepseek-ai/DeepSeek-V3.1',
          displayName: 'DeepSeek V3.1'),
      LlmProviderPresetModel('deepseek-ai/DeepSeek-V3.1-Terminus',
          displayName: 'DeepSeek V3.1 Terminus'),
      LlmProviderPresetModel('deepseek-ai/DeepSeek-V3',
          displayName: 'DeepSeek V3'),
      LlmProviderPresetModel('deepseek-ai/DeepSeek-R1',
          displayName: 'DeepSeek R1'),
      LlmProviderPresetModel('deepseek-ai/deepseek-vl2',
          displayName: 'DeepSeek VL2'),
      LlmProviderPresetModel('nex-agi/DeepSeek-V3.1-Nex-N1',
          displayName: 'DeepSeek V3.1 Nex N1'),
      LlmProviderPresetModel('Qwen/Qwen3.6-35B-A3B',
          displayName: 'Qwen 3.6 35B A3B'),
      LlmProviderPresetModel('Qwen/Qwen3.6-27B', displayName: 'Qwen 3.6 27B'),
      LlmProviderPresetModel('Qwen/Qwen3.5-397B-A17B',
          displayName: 'Qwen 3.5 397B A17B'),
      LlmProviderPresetModel('Qwen/Qwen3.5-122B-A10B',
          displayName: 'Qwen 3.5 122B A10B'),
      LlmProviderPresetModel('Qwen/Qwen3.5-35B-A3B',
          displayName: 'Qwen 3.5 35B A3B'),
      LlmProviderPresetModel('Qwen/Qwen3.5-27B', displayName: 'Qwen 3.5 27B'),
      LlmProviderPresetModel('Qwen/Qwen3.5-9B', displayName: 'Qwen 3.5 9B'),
      LlmProviderPresetModel('Qwen/Qwen3-Next-80B-A3B-Instruct',
          displayName: 'Qwen3 Next 80B Instruct'),
      LlmProviderPresetModel('Qwen/Qwen3-Next-80B-A3B-Thinking',
          displayName: 'Qwen3 Next 80B Thinking'),
      LlmProviderPresetModel('Qwen/Qwen3-235B-A22B',
          displayName: 'Qwen3 235B A22B'),
      LlmProviderPresetModel('Qwen/Qwen3-235B-A22B-Instruct-2507',
          displayName: 'Qwen3 235B A22B Instruct'),
      LlmProviderPresetModel('Qwen/Qwen3-235B-A22B-Thinking-2507',
          displayName: 'Qwen3 235B A22B Thinking'),
      LlmProviderPresetModel('Qwen/Qwen3-32B', displayName: 'Qwen3 32B'),
      LlmProviderPresetModel('Qwen/Qwen3-30B-A3B-Instruct-2507',
          displayName: 'Qwen3 30B A3B Instruct'),
      LlmProviderPresetModel('Qwen/Qwen3-30B-A3B-Thinking-2507',
          displayName: 'Qwen3 30B A3B Thinking'),
      LlmProviderPresetModel('Qwen/Qwen3-14B', displayName: 'Qwen3 14B'),
      LlmProviderPresetModel('Qwen/Qwen3-8B', displayName: 'Qwen3 8B'),
      LlmProviderPresetModel('Qwen/Qwen3-Coder-480B-A35B-Instruct',
          displayName: 'Qwen3 Coder 480B'),
      LlmProviderPresetModel('Qwen/Qwen3-Coder-30B-A3B-Instruct',
          displayName: 'Qwen3 Coder 30B'),
      LlmProviderPresetModel('Qwen/Qwen3-Omni-30B-A3B-Instruct',
          displayName: 'Qwen3 Omni 30B Instruct'),
      LlmProviderPresetModel('Qwen/Qwen3-Omni-30B-A3B-Thinking',
          displayName: 'Qwen3 Omni 30B Thinking'),
      LlmProviderPresetModel('Qwen/Qwen3-Omni-30B-A3B-Captioner',
          displayName: 'Qwen3 Omni 30B Captioner'),
      LlmProviderPresetModel('Qwen/Qwen2.5-72B-Instruct',
          displayName: 'Qwen 2.5 72B'),
      LlmProviderPresetModel('Qwen/Qwen2.5-72B-Instruct-128K',
          displayName: 'Qwen 2.5 72B 128K'),
      LlmProviderPresetModel('Qwen/Qwen2.5-32B-Instruct',
          displayName: 'Qwen 2.5 32B'),
      LlmProviderPresetModel('Qwen/Qwen2.5-14B-Instruct',
          displayName: 'Qwen 2.5 14B'),
      LlmProviderPresetModel('Qwen/Qwen2.5-7B-Instruct',
          displayName: 'Qwen 2.5 7B'),
      LlmProviderPresetModel('Qwen/Qwen2.5-VL-7B-Instruct',
          displayName: 'Qwen 2.5 VL 7B'),
      LlmProviderPresetModel('zai-org/GLM-5.1', displayName: 'GLM 5.1'),
      LlmProviderPresetModel('zai-org/GLM-5', displayName: 'GLM 5'),
      LlmProviderPresetModel('zai-org/GLM-5V-Turbo',
          displayName: 'GLM 5V Turbo'),
      LlmProviderPresetModel('zai-org/GLM-4.7', displayName: 'GLM 4.7'),
      LlmProviderPresetModel('zai-org/GLM-4.6', displayName: 'GLM 4.6'),
      LlmProviderPresetModel('zai-org/GLM-4.6V', displayName: 'GLM 4.6V'),
      LlmProviderPresetModel('zai-org/GLM-4.5', displayName: 'GLM 4.5'),
      LlmProviderPresetModel('zai-org/GLM-4.5-Air', displayName: 'GLM 4.5 Air'),
      LlmProviderPresetModel('zai-org/GLM-4.5V', displayName: 'GLM 4.5V'),
      LlmProviderPresetModel('THUDM/GLM-4-32B-0414', displayName: 'GLM 4 32B'),
      LlmProviderPresetModel('THUDM/GLM-4-9B-0414', displayName: 'GLM 4 9B'),
      LlmProviderPresetModel('THUDM/GLM-Z1-32B-0414',
          displayName: 'GLM Z1 32B'),
      LlmProviderPresetModel('THUDM/GLM-Z1-9B-0414', displayName: 'GLM Z1 9B'),
      LlmProviderPresetModel('moonshotai/Kimi-K2.6', displayName: 'Kimi K2.6'),
      LlmProviderPresetModel('moonshotai/Kimi-K2.5', displayName: 'Kimi K2.5'),
      LlmProviderPresetModel('moonshotai/Kimi-K2-Instruct',
          displayName: 'Kimi K2 Instruct'),
      LlmProviderPresetModel('moonshotai/Kimi-K2-Instruct-0905',
          displayName: 'Kimi K2 Instruct 0905'),
      LlmProviderPresetModel('moonshotai/Kimi-K2-Thinking',
          displayName: 'Kimi K2 Thinking'),
      LlmProviderPresetModel('openai/gpt-oss-120b',
          displayName: 'GPT OSS 120B'),
      LlmProviderPresetModel('openai/gpt-oss-20b', displayName: 'GPT OSS 20B'),
      LlmProviderPresetModel('baidu/ERNIE-4.5-300B-A47B',
          displayName: 'ERNIE 4.5 300B'),
      LlmProviderPresetModel('tencent/Hunyuan-A13B-Instruct',
          displayName: 'Hunyuan A13B'),
      LlmProviderPresetModel('tencent/Hunyuan-MT-7B',
          displayName: 'Hunyuan MT 7B'),
      LlmProviderPresetModel('tencent/Hy3-preview',
          displayName: 'Hunyuan Hy3 Preview'),
      LlmProviderPresetModel('meta-llama/Meta-Llama-3.1-8B-Instruct',
          displayName: 'Llama 3.1 8B'),
      LlmProviderPresetModel('MiniMaxAI/MiniMax-M2.5',
          displayName: 'MiniMax M2.5'),
      LlmProviderPresetModel('MiniMaxAI/MiniMax-M2.1',
          displayName: 'MiniMax M2.1'),
      LlmProviderPresetModel('inclusionAI/Ling-flash-2.0',
          displayName: 'Ling Flash 2.0'),
      LlmProviderPresetModel('inclusionAI/Ling-mini-2.0',
          displayName: 'Ling Mini 2.0'),
      LlmProviderPresetModel('inclusionAI/Ring-flash-2.0',
          displayName: 'Ring Flash 2.0'),
      LlmProviderPresetModel('google/gemma-4-31B-it',
          displayName: 'Gemma 4 31B'),
      LlmProviderPresetModel('google/gemma-4-26B-A4B-it',
          displayName: 'Gemma 4 26B'),
      LlmProviderPresetModel('ByteDance-Seed/Seed-OSS-36B-Instruct',
          displayName: 'Seed OSS 36B'),
    ],
  ),
  LlmProviderPreset(
    id: 'stepfun-cn',
    displayName: 'StepFun China (.com)',
    baseUrl: 'https://api.stepfun.com/v1/chat/completions',
    modelsUrl: 'https://api.stepfun.com/v1/models',
    fallbackModels: _stepfunFallbackModels,
  ),
  LlmProviderPreset(
    id: 'stepfun-international',
    displayName: 'StepFun International (.ai)',
    baseUrl: 'https://api.stepfun.ai/v1/chat/completions',
    fallbackModels: _stepfunFallbackModels,
  ),
  LlmProviderPreset(
    id: 'together',
    displayName: 'Together AI',
    baseUrl: 'https://api.together.xyz/v1/chat/completions',
    fallbackModels: [
      LlmProviderPresetModel(
        'meta-llama/Llama-3.3-70B-Instruct-Turbo-Free',
        displayName: 'Llama 3.3 70B Turbo (Free)',
      ),
      LlmProviderPresetModel(
        'meta-llama/Llama-Vision-Free',
        displayName: 'Llama Vision (Free)',
      ),
      LlmProviderPresetModel(
        'deepseek-ai/DeepSeek-R1-Distill-Llama-70B-Free',
        displayName: 'DeepSeek R1 Distill Llama 70B (Free)',
      ),
      LlmProviderPresetModel(
        'meta-llama/Llama-3.3-70B-Instruct-Turbo',
        displayName: 'Llama 3.3 70B Turbo',
      ),
      LlmProviderPresetModel(
        'deepseek-ai/DeepSeek-R1',
        displayName: 'DeepSeek R1',
      ),
      LlmProviderPresetModel('Qwen/Qwen3-235B-A22B', displayName: 'Qwen3 235B'),
      LlmProviderPresetModel(
        'meta-llama/Llama-4-Maverick-17B-128E-Instruct-FP8',
        displayName: 'Llama 4 Maverick',
      ),
    ],
  ),
  LlmProviderPreset(
    id: 'yi',
    displayName: 'Yi (01.AI)',
    baseUrl: 'https://api.lingyiwanwu.com/v1/chat/completions',
    fallbackModels: [
      LlmProviderPresetModel('yi-large', displayName: 'Yi Large'),
    ],
  ),
  LlmProviderPreset(
    id: 'freeaiapikey',
    displayName: 'FreeAIAPIKey',
    baseUrl: 'https://api.freeaiapikey.com/v1/chat/completions',
    modelsUrl: 'https://api.freeaiapikey.com/v1/models',
    fallbackModels: [
      LlmProviderPresetModel('openai/gpt-4o',
          displayName: 'GPT-4o (via FreeAIAPIKey)',
          capabilities: {'contextLength': 128000}),
      LlmProviderPresetModel('openai/gpt-5.4',
          displayName: 'GPT-5.4 (via FreeAIAPIKey)',
          capabilities: {'contextLength': 128000}),
      LlmProviderPresetModel('openai/gpt-5.5',
          displayName: 'GPT-5.5 (via FreeAIAPIKey)',
          capabilities: {'contextLength': 128000}),
      LlmProviderPresetModel('openai/gpt-5.6-sol',
          displayName: 'GPT-5.6 Sol (via FreeAIAPIKey)',
          capabilities: {'contextLength': 128000}),
      LlmProviderPresetModel('anthropic/claude-opus-4.6',
          displayName: 'Claude Opus 4.6 (via FreeAIAPIKey)',
          capabilities: {
            'contextLength': 1000000,
            'reasoning': true,
            'supportedThinkingEfforts': ['low', 'medium', 'high', 'max'],
          }),
      LlmProviderPresetModel('anthropic/claude-opus-4.7',
          displayName: 'Claude Opus 4.7 (via FreeAIAPIKey)',
          capabilities: {'contextLength': 128000}),
      LlmProviderPresetModel('anthropic/claude-opus-4.8',
          displayName: 'Claude Opus 4.8 (via FreeAIAPIKey)',
          capabilities: {'contextLength': 128000}),
      LlmProviderPresetModel('anthropic/claude-opus-5',
          displayName: 'Claude Opus 5 (via FreeAIAPIKey)',
          capabilities: {'contextLength': 128000}),
      LlmProviderPresetModel('anthropic/claude-sonnet-4.6',
          displayName: 'Claude Sonnet 4.6 (via FreeAIAPIKey)',
          capabilities: {
            'contextLength': 1000000,
            'reasoning': true,
            'supportedThinkingEfforts': ['low', 'medium', 'high', 'max'],
          }),
      LlmProviderPresetModel('anthropic/claude-sonnet-5',
          displayName: 'Claude Sonnet 5 (via FreeAIAPIKey)',
          capabilities: {'contextLength': 128000}),
    ],
  ),
  LlmProviderPreset(
    id: 'freeinference',
    displayName: 'FreeInference',
    baseUrl: 'https://freeinference.org/v1/chat/completions',
    modelsUrl: 'https://freeinference.org/v1/models',
  ),
  LlmProviderPreset(
    id: 'freemodel-dev',
    displayName: 'FreeModel.dev',
    baseUrl: 'https://api.freemodel.dev/v1/chat/completions',
    modelsUrl: 'https://api.freemodel.dev/v1/models',
    fallbackModels: [
      LlmProviderPresetModel('gpt-5.5',
          displayName: 'GPT-5.5', capabilities: {'contextLength': 400000}),
      LlmProviderPresetModel('gpt-5.4',
          displayName: 'GPT-5.4', capabilities: {'contextLength': 400000}),
      LlmProviderPresetModel('gpt-5.4-mini',
          displayName: 'GPT-5.4 Mini', capabilities: {'contextLength': 128000}),
      LlmProviderPresetModel('gpt-5.3-codex',
          displayName: 'GPT-5.3 Codex',
          capabilities: {'contextLength': 128000}),
    ],
  ),
  LlmProviderPreset(
    id: 'freetheai',
    displayName: 'FreeTheAi',
    baseUrl: 'https://api.freetheai.org/v1/chat/completions',
    modelsUrl: 'https://api.freetheai.org/v1/models',
    fallbackModels: [
      LlmProviderPresetModel('fta/zai/glm-5.3',
          displayName: 'GLM 5.3 (zai)',
          capabilities: {'contextLength': 128000}),
      LlmProviderPresetModel('fta/kimi/k3',
          displayName: 'Kimi K3', capabilities: {'contextLength': 128000}),
    ],
  ),
  LlmProviderPreset(
    id: 'friendliai',
    displayName: 'FriendliAI',
    baseUrl: 'https://api.friendli.ai/serverless/v1/chat/completions',
    modelsUrl: 'https://api.friendli.ai/serverless/v1/models',
    fallbackModels: [
      LlmProviderPresetModel('meta-llama-3.1-70b-instruct'),
      LlmProviderPresetModel('meta-llama-3.1-8b-instruct'),
    ],
  ),
  LlmProviderPreset(
    id: 'galadriel',
    displayName: 'Galadriel',
    baseUrl: 'https://api.galadriel.ai/v1/chat/completions',
    fallbackModels: [
      LlmProviderPresetModel('galadriel-latest'),
    ],
  ),
  LlmProviderPreset(
    id: 'greenpt',
    displayName: 'GreenPT',
    baseUrl: 'https://api.greenpt.ai/v1/chat/completions',
    modelsUrl: 'https://api.greenpt.ai/v1/models',
  ),
  LlmProviderPreset(
    id: 'hcnsec',
    displayName: 'Huancheng Public API',
    baseUrl: 'https://api.hcnsec.cn/v1/chat/completions',
    modelsUrl: 'https://api.hcnsec.cn/v1/models',
  ),
  LlmProviderPreset(
    id: 'helixmind',
    displayName: 'HelixMind',
    baseUrl: 'https://helixmind.online/v1/chat/completions',
    modelsUrl: 'https://helixmind.online/v1/models',
  ),
  LlmProviderPreset(
    id: 'helyxai',
    displayName: 'Helyx AI',
    baseUrl: 'https://helyxai.space/v1/chat/completions',
    modelsUrl: 'https://helyxai.space/v1/models',
  ),
  LlmProviderPreset(
    id: 'heroku',
    displayName: 'Heroku AI',
    baseUrl: 'https://us.inference.heroku.com/v1/chat/completions',
    fallbackModels: [
      LlmProviderPresetModel('claude-opus-4-7'),
      LlmProviderPresetModel('claude-4-6-sonnet'),
      LlmProviderPresetModel('claude-4-5-haiku'),
      LlmProviderPresetModel('glm-4-7'),
      LlmProviderPresetModel('kimi-k2-5'),
      LlmProviderPresetModel('minimax-m2-1'),
      LlmProviderPresetModel('deepseek-v3-2'),
      LlmProviderPresetModel('qwen3-coder-480b'),
      LlmProviderPresetModel('qwen3-235b'),
      LlmProviderPresetModel('gpt-oss-120b'),
      LlmProviderPresetModel('nova-pro'),
      LlmProviderPresetModel('nova-2-lite'),
    ],
  ),
  LlmProviderPreset(
    id: 'hyperbolic',
    displayName: 'Hyperbolic',
    baseUrl: 'https://api.hyperbolic.xyz/v1/chat/completions',
    fallbackModels: [
      LlmProviderPresetModel('Qwen/QwQ-32B', displayName: 'QwQ 32B'),
      LlmProviderPresetModel('deepseek-ai/DeepSeek-R1',
          displayName: 'DeepSeek R1'),
      LlmProviderPresetModel('deepseek-ai/DeepSeek-V3',
          displayName: 'DeepSeek V3'),
      LlmProviderPresetModel('meta-llama/Llama-3.3-70B-Instruct',
          displayName: 'Llama 3.3 70B'),
      LlmProviderPresetModel('meta-llama/Llama-3.2-3B-Instruct',
          displayName: 'Llama 3.2 3B'),
      LlmProviderPresetModel('Qwen/Qwen2.5-72B-Instruct',
          displayName: 'Qwen 2.5 72B'),
      LlmProviderPresetModel('Qwen/Qwen2.5-Coder-32B-Instruct',
          displayName: 'Qwen 2.5 Coder 32B'),
      LlmProviderPresetModel('NousResearch/Hermes-3-Llama-3.1-70B',
          displayName: 'Hermes 3 70B'),
    ],
  ),
  // Registry audit pinned at OmniRoute d1ba822: open-sse/config/providers/
  // registry/inception/index.ts:4-22 uses the default OpenAI executor.
  LlmProviderPreset(
    id: 'inception',
    displayName: 'Inception',
    baseUrl: 'https://api.inceptionlabs.ai/v1/chat/completions',
    fallbackModels: [
      LlmProviderPresetModel(
        'mercury-2',
        displayName: 'Mercury 2',
        capabilities: {'contextLength': 128000, 'maxOutputTokens': 50000},
      ),
      LlmProviderPresetModel(
        'mercury-2.5',
        displayName: 'Mercury 2.5',
        capabilities: {'contextLength': 260000, 'maxOutputTokens': 65536},
      ),
    ],
  ),
  // Registry audit pinned at OmniRoute d1ba822: open-sse/config/providers/
  // registry/inference-net/index.ts:5-12 uses the default OpenAI executor.
  LlmProviderPreset(
    id: 'inference-net',
    displayName: 'Inference.net',
    baseUrl: 'https://api.inference.net/v1/chat/completions',
    fallbackModels: [
      LlmProviderPresetModel('meta-llama/Llama-3.3-70B-Instruct'),
      LlmProviderPresetModel('deepseek-ai/DeepSeek-R1'),
      LlmProviderPresetModel('Qwen/Qwen2.5-72B-Instruct'),
    ],
  ),
  // Registry audit pinned at OmniRoute d1ba822: open-sse/config/providers/
  // registry/kenari/index.ts:4-13 declares direct /models discovery.
  LlmProviderPreset(
    id: 'kenari',
    displayName: 'Kenari',
    baseUrl: 'https://kenari.id/v1/chat/completions',
    modelsUrl: 'https://kenari.id/v1/models',
  ),
  // Registry audit pinned at OmniRoute d1ba822: open-sse/config/providers/
  // registry/kilo-gateway/index.ts:9-25 uses bearer auth and direct discovery.
  LlmProviderPreset(
    id: 'kilo-gateway',
    displayName: 'Kilo Gateway',
    baseUrl: 'https://api.kilo.ai/api/gateway/chat/completions',
    modelsUrl: 'https://api.kilo.ai/api/gateway/models',
    fallbackModels: [
      LlmProviderPresetModel('kilo-auto/frontier',
          displayName: 'Kilo Auto Frontier'),
      LlmProviderPresetModel('kilo-auto/balanced',
          displayName: 'Kilo Auto Balanced'),
      LlmProviderPresetModel('kilo-auto/free', displayName: 'Kilo Auto Free'),
      LlmProviderPresetModel('nvidia/nemotron-3-super-120b-a12b:free',
          displayName: 'Nemotron 3 Super 120B (Free)'),
      LlmProviderPresetModel('minimax/minimax-m2.5:free',
          displayName: 'MiniMax M2.5 (Free)'),
      LlmProviderPresetModel('arcee-ai/trinity-large-preview:free',
          displayName: 'Trinity Large Preview (Free)'),
    ],
  ),
  // Registry audit pinned at OmniRoute d1ba822: open-sse/config/providers/
  // registry/lambda-ai/index.ts:5-12 uses the default OpenAI executor.
  LlmProviderPreset(
    id: 'lambda-ai',
    displayName: 'Lambda AI',
    baseUrl: 'https://api.lambda.ai/v1/chat/completions',
    fallbackModels: [
      LlmProviderPresetModel('deepseek-r1-671b'),
      LlmProviderPresetModel('llama3.3-70b-instruct-fp8'),
      LlmProviderPresetModel('qwen25-coder-32b-instruct'),
    ],
  ),
  // Registry audit pinned at OmniRoute d1ba822: open-sse/config/providers/
  // registry/liquid/index.ts:13-21 declares the current inference host.
  LlmProviderPreset(
    id: 'liquid',
    displayName: 'Liquid AI',
    baseUrl: 'https://inference.liquid.ai/v1/chat/completions',
    modelsUrl: 'https://inference.liquid.ai/v1/models',
    fallbackModels: [
      LlmProviderPresetModel('liquid-lfm-40b', displayName: 'Liquid LFM 40B'),
    ],
  ),
  // Registry audit pinned at OmniRoute d1ba822: open-sse/config/providers/
  // registry/literouter/index.ts:5-10 uses the shared OpenAI-compatible builder.
  LlmProviderPreset(
    id: 'literouter',
    displayName: 'LiteRouter',
    baseUrl: 'https://api.literouter.com/v1/chat/completions',
    modelsUrl: 'https://api.literouter.com/v1/models',
  ),
  // Registry audit pinned at OmniRoute d1ba822: open-sse/config/providers/
  // registry/llamagate/index.ts:5-12 uses the default OpenAI executor.
  LlmProviderPreset(
    id: 'llamagate',
    displayName: 'LlamaGate',
    baseUrl: 'https://llamagate.ai/v1/chat/completions',
    fallbackModels: [
      LlmProviderPresetModel('qwen2.5-coder-7b'),
      LlmProviderPresetModel('deepseek-coder-6.7b'),
      LlmProviderPresetModel('qwen3-vl-8b'),
    ],
  ),
  // Registry audit pinned at OmniRoute d1ba822: open-sse/config/providers/
  // registry/llm-kiwi/index.ts:5-13 exposes discovery and a small fallback.
  LlmProviderPreset(
    id: 'llm-kiwi',
    displayName: 'LLM.Kiwi',
    baseUrl: 'https://api.llm.kiwi/v1/chat/completions',
    modelsUrl: 'https://api.llm.kiwi/v1/models',
    fallbackModels: [
      LlmProviderPresetModel('auto', displayName: 'Auto'),
      LlmProviderPresetModel('hrLLM'),
    ],
  ),
  // Registry audit pinned at OmniRoute d1ba822: open-sse/config/providers/
  // registry/llm7/index.ts:4-21 uses the default OpenAI executor and discovery.
  LlmProviderPreset(
    id: 'llm7',
    displayName: 'LLM7.io',
    baseUrl: 'https://api.llm7.io/v1/chat/completions',
    modelsUrl: 'https://api.llm7.io/v1/models',
    fallbackModels: [
      LlmProviderPresetModel('gpt-4o-mini-2024-07-18',
          displayName: 'GPT-4o mini (LLM7)'),
      LlmProviderPresetModel('gpt-4.1-nano-2025-04-14',
          displayName: 'GPT-4.1 nano (LLM7)'),
      LlmProviderPresetModel('deepseek-r1-0528',
          displayName: 'DeepSeek R1 (LLM7)'),
      LlmProviderPresetModel('qwen2.5-coder-32b-instruct',
          displayName: 'Qwen2.5 Coder 32B (LLM7)'),
    ],
  ),
  // Registry audit pinned at OmniRoute d1ba822: open-sse/config/providers/
  // registry/llmgateway/index.ts:5-10 uses the shared OpenAI-compatible builder.
  LlmProviderPreset(
    id: 'llmgateway',
    displayName: 'LLM Gateway',
    baseUrl: 'https://api.llmgateway.io/v1/chat/completions',
    modelsUrl: 'https://api.llmgateway.io/v1/models',
  ),
  // Registry audit pinned at OmniRoute d1ba822: the generic OpenAI executor
  // builds this endpoint and /models route from the provider base.
  LlmProviderPreset(
    id: 'logfare',
    displayName: 'Logfare',
    baseUrl: 'https://logfare.ai/v1/chat/completions',
    modelsUrl: 'https://logfare.ai/v1/models',
  ),
  // Registry audit pinned at OmniRoute d1ba822: OpenAI Chat Completions with
  // bearer auth and a static LongCat-2.0 fallback model.
  LlmProviderPreset(
    id: 'longcat',
    displayName: 'LongCat AI',
    baseUrl: 'https://api.longcat.chat/openai/v1/chat/completions',
    fallbackModels: [
      LlmProviderPresetModel(
        'LongCat-2.0',
        displayName: 'LongCat 2.0 (10M tok free 🆓)',
        capabilities: {'contextLength': 1048576},
      ),
    ],
  ),
  // Registry audit pinned at OmniRoute d1ba822: the generic OpenAI executor
  // builds this endpoint and /models route from the provider base.
  LlmProviderPreset(
    id: 'lyceum',
    displayName: 'Lyceum',
    baseUrl: 'https://api.lyceum.technology/openai/v1/chat/completions',
    modelsUrl: 'https://api.lyceum.technology/openai/v1/models',
  ),
  // Registry audit pinned at OmniRoute d1ba822: the generic OpenAI executor
  // builds this endpoint and /models route from the provider base.
  LlmProviderPreset(
    id: 'meganova-ai',
    displayName: 'MegaNova AI',
    baseUrl: 'https://api.meganova.ai/v1/chat/completions',
    modelsUrl: 'https://api.meganova.ai/v1/models',
  ),
  // Registry audit pinned at OmniRoute d1ba822: the generic OpenAI executor
  // builds this endpoint and /models route from the provider base.
  LlmProviderPreset(
    id: 'mixlayer',
    displayName: 'Mixlayer',
    baseUrl: 'https://models.mixlayer.ai/v1/chat/completions',
    modelsUrl: 'https://models.mixlayer.ai/v1/models',
  ),
  // Registry audit pinned at OmniRoute d1ba822: the generic OpenAI executor
  // builds this endpoint and /models route from the provider base.
  LlmProviderPreset(
    id: 'mnn-ai',
    displayName: 'MNN AI',
    baseUrl: 'https://api.mnnai.ru/v1/chat/completions',
    modelsUrl: 'https://api.mnnai.ru/v1/models',
  ),
  // Registry audit pinned at OmniRoute d1ba822: Naga.ai requires an API key;
  // the separate Naga.ac entry accepts optional authentication despite sharing
  // this chat and model endpoint.
  LlmProviderPreset(
    id: 'naga-ai',
    displayName: 'Naga AI',
    baseUrl: 'https://api.naga.ac/v1/chat/completions',
    modelsUrl: 'https://api.naga.ac/v1/models',
  ),
  // Registry audit pinned at OmniRoute d1ba822: key-gated discovery and these
  // eight models are declared by the NaN.Builders OpenAI-compatible registry.
  LlmProviderPreset(
    id: 'nan',
    displayName: 'NaN.Builders',
    baseUrl: 'https://api.nan.builders/v1/chat/completions',
    modelsUrl: 'https://api.nan.builders/v1/models',
    fallbackModels: [
      LlmProviderPresetModel(
        'deepseek-v4-flash',
        displayName: 'DeepSeek V4 Flash',
      ),
      LlmProviderPresetModel('mimo-v2.5', displayName: 'MiMo V2.5'),
      LlmProviderPresetModel('mimo-v2.6-flash', displayName: 'MiMo V2.6 Flash'),
      LlmProviderPresetModel('qwen3.8-flash', displayName: 'Qwen3.8 Flash'),
      LlmProviderPresetModel('qwen3.6', displayName: 'Qwen3.6'),
      LlmProviderPresetModel('glm5.3', displayName: 'GLM 5.3'),
      LlmProviderPresetModel('glm5.3-flash', displayName: 'GLM 5.3 Flash'),
      LlmProviderPresetModel('gemma4', displayName: 'Gemma 4'),
    ],
  ),
  // Registry audit pinned at OmniRoute d1ba822: NanoGPT has an API-key bearer
  // mode, live /models discovery, and this small offline seed catalog.
  LlmProviderPreset(
    id: 'nanogpt',
    displayName: 'NanoGPT',
    baseUrl: 'https://nano-gpt.com/api/v1/chat/completions',
    modelsUrl: 'https://nano-gpt.com/api/v1/models',
    fallbackModels: [
      LlmProviderPresetModel('chatgpt-4o-latest'),
      LlmProviderPresetModel('claude-3.5-sonnet'),
      LlmProviderPresetModel('gpt-4o-mini'),
    ],
  ),
  // Registry audit pinned at OmniRoute d1ba822: NaraRouter uses API-key
  // bearer auth and these registry-declared fallback models, with no /models
  // discovery endpoint.
  LlmProviderPreset(
    id: 'nara',
    displayName: 'NaraRouter',
    baseUrl: 'https://router.bynara.id/v1/chat/completions',
    fallbackModels: [
      LlmProviderPresetModel(
        'agnes-2.0-flash',
        displayName: 'Agnes 2.0 Flash',
        capabilities: {
          'contextLength': 262144,
          'toolCalling': true,
          'vision': true,
          'reasoning': true,
        },
      ),
      LlmProviderPresetModel(
        'agnes-2.5-flash',
        displayName: 'Agnes 2.5 Flash',
        capabilities: {
          'contextLength': 524288,
          'toolCalling': true,
          'vision': true,
          'reasoning': true,
        },
      ),
      LlmProviderPresetModel(
        'laguna-s-2.1',
        displayName: 'Laguna S 2.1',
        capabilities: {
          'contextLength': 262144,
          'toolCalling': true,
          'reasoning': true,
        },
      ),
      LlmProviderPresetModel(
        'minimax-m3-free',
        displayName: 'MiniMax M3 (free)',
        capabilities: {
          'contextLength': 1000000,
          'vision': true,
          'reasoning': true,
        },
      ),
      LlmProviderPresetModel(
        'mistral-large',
        displayName: 'Mistral Large',
        capabilities: {'contextLength': 252000, 'toolCalling': true},
      ),
      LlmProviderPresetModel(
        'mistral-medium-3-5',
        displayName: 'Mistral Medium 3.5',
        capabilities: {
          'contextLength': 256000,
          'toolCalling': true,
          'vision': true,
        },
      ),
      LlmProviderPresetModel(
        'qwen3.8-27b',
        displayName: 'Qwen3.8 27B',
        capabilities: {'toolCalling': true},
      ),
      LlmProviderPresetModel(
        'stepfun-3.7-flash',
        displayName: 'StepFun 3.7 Flash',
        capabilities: {'contextLength': 262144, 'toolCalling': true},
      ),
    ],
  ),
  // Registry audit pinned at OmniRoute d1ba822: Nebius API-key bearer mode
  // declares one offline fallback and no model-list endpoint.
  LlmProviderPreset(
    id: 'nebius',
    displayName: 'Nebius AI',
    baseUrl: 'https://api.tokenfactory.nebius.com/v1/chat/completions',
    fallbackModels: [
      LlmProviderPresetModel(
        'meta-llama/Llama-3.3-70B-Instruct',
        displayName: 'Llama 3.3 70B Instruct',
      ),
    ],
  ),
  // Deferred from M43: NLP Cloud's audited executor sends to /v1/gpu, while
  // this shared connector appends /chat/completions to the configured path.
  // The resulting /v1/gpu/chat/completions URL is not the audited endpoint.
  // Registry evidence: OmniRoute d1ba822 open-sse/config/providers/registry/
  // nlpcloud/index.ts:4-12.
  //
  // Registry audit pinned at OmniRoute d1ba822: Nous Research declares two
  // API-key bearer fallback models and no model-list endpoint.
  LlmProviderPreset(
    id: 'nous-research',
    displayName: 'Nous Research',
    baseUrl: 'https://inference-api.nousresearch.com/v1/chat/completions',
    fallbackModels: [
      LlmProviderPresetModel(
        'Hermes-4-405B',
        displayName: 'Hermes 4 405B (Nous Research)',
      ),
      LlmProviderPresetModel(
        'Hermes-4-70B',
        displayName: 'Hermes 4 70B (Nous Research)',
      ),
    ],
  ),
  // Registry audit pinned at OmniRoute d1ba822: nScale declares these static
  // models with API-key bearer auth and no /models discovery endpoint.
  LlmProviderPreset(
    id: 'nscale',
    displayName: 'nScale',
    baseUrl: 'https://inference.api.nscale.com/v1/chat/completions',
    fallbackModels: [
      LlmProviderPresetModel('moonshotai/Kimi-K2.5'),
      LlmProviderPresetModel('Qwen/Qwen3-235B-A22B-Instruct-2507'),
      LlmProviderPresetModel('openai/gpt-oss-120b'),
      LlmProviderPresetModel('openai/gpt-oss-20b'),
      LlmProviderPresetModel('meta-llama/Llama-4-Scout-17B-16E-Instruct'),
      LlmProviderPresetModel('meta-llama/Llama-3.3-70B-Instruct'),
    ],
  ),
  // Registry audit pinned at OmniRoute d1ba822: Nube's key-gated /models
  // endpoint is authoritative; passthrough is enabled and no fallback list is
  // declared.
  LlmProviderPreset(
    id: 'nube',
    displayName: 'Nube.sh',
    baseUrl: 'https://ai.nube.sh/api/v1/chat/completions',
    modelsUrl: 'https://ai.nube.sh/api/v1/models',
  ),
  // The OCI API-key account path is a standard bearer key for Chat Completions.
  // These exact default-region routes come from the OCI URL builders at
  // OmniRoute d1ba822 open-sse/config/oci.ts:3-40; the optional project header
  // is documented for Responses and agentic use, outside this chat preset.
  LlmProviderPreset(
    id: 'oci',
    displayName: 'OCI Generative AI',
    baseUrl:
        'https://inference.generativeai.us-chicago-1.oci.oraclecloud.com/openai/v1/chat/completions',
    modelsUrl:
        'https://inference.generativeai.us-chicago-1.oci.oraclecloud.com/openai/v1/models',
  ),
  // Registry audit pinned at OmniRoute d1ba822: OfoxAI is bearer-authenticated
  // and exposes live /models discovery with no fallback list.
  LlmProviderPreset(
    id: 'ofoxai',
    displayName: 'OfoxAI',
    baseUrl: 'https://api.ofox.ai/v1/chat/completions',
    modelsUrl: 'https://api.ofox.ai/v1/models',
  ),
  // Registry audit pinned at OmniRoute d1ba822: Ollama Cloud uses bearer auth,
  // /api/tags discovery, passthrough models, and these reasoning-aware seeds.
  LlmProviderPreset(
    id: 'ollama-cloud',
    displayName: 'Ollama Cloud',
    baseUrl: 'https://ollama.com/v1/chat/completions',
    modelsUrl: 'https://ollama.com/api/tags',
    fallbackModels: [
      LlmProviderPresetModel(
        'gpt-oss:20b',
        displayName: 'GPT-OSS 20B',
        capabilities: {
          'reasoning': true,
          'supportedThinkingEfforts': ['low', 'medium', 'high'],
        },
      ),
      LlmProviderPresetModel(
        'gpt-oss:120b',
        displayName: 'GPT-OSS 120B',
        capabilities: {
          'reasoning': true,
          'supportedThinkingEfforts': ['low', 'medium', 'high'],
        },
      ),
      LlmProviderPresetModel(
        'deepseek-v4-pro',
        displayName: 'DeepSeek V4 Pro',
        capabilities: {
          'reasoning': true,
          'supportedThinkingEfforts': ['none', 'low', 'medium', 'high', 'max'],
        },
      ),
      LlmProviderPresetModel(
        'deepseek-v4-flash',
        displayName: 'DeepSeek V4 Flash',
        capabilities: {
          'reasoning': true,
          'supportedThinkingEfforts': ['none', 'low', 'medium', 'high', 'max'],
        },
      ),
      LlmProviderPresetModel('kimi-k2.6', displayName: 'Kimi K2.6'),
      LlmProviderPresetModel(
        'glm-5.1',
        displayName: 'GLM 5.1',
        capabilities: {
          'reasoning': true,
          'supportsXHighEffort': false,
          'supportedThinkingEfforts': ['none', 'low', 'medium', 'high', 'max'],
        },
      ),
      LlmProviderPresetModel(
        'glm-5.2',
        displayName: 'GLM 5.2',
        capabilities: {
          'reasoning': true,
          'supportsXHighEffort': false,
          'supportedThinkingEfforts': ['none', 'low', 'medium', 'high', 'max'],
        },
      ),
      LlmProviderPresetModel(
        'minimax-m3',
        displayName: 'MiniMax M3',
        capabilities: {'contextLength': 1048576, 'vision': true},
      ),
      LlmProviderPresetModel('minimax-m2.7', displayName: 'MiniMax M2.7'),
      LlmProviderPresetModel('gemma4:31b', displayName: 'Gemma 4 31B'),
      LlmProviderPresetModel(
        'nemotron-3-super',
        displayName: 'NVIDIA Nemotron 3 Super',
      ),
      LlmProviderPresetModel('qwen3.5:397b', displayName: 'Qwen 3.5 397B'),
    ],
  ),
  // Registry audit pinned at OmniRoute d1ba822: onomeo uses the standard
  // bearer API-key executor, explicit Chat Completions and models endpoints,
  // and passthrough model IDs without an offline seed list.
  LlmProviderPreset(
    id: 'onomeo',
    displayName: 'onomeo',
    baseUrl: 'https://onomeo.com/v1/chat/completions',
    modelsUrl: 'https://onomeo.com/v1/models',
  ),
  // Registry audit pinned at OmniRoute d1ba822: OpenAdapter uses bearer auth,
  // live /v1/models discovery and one fallback model with its declared tool
  // calling and context capabilities.
  LlmProviderPreset(
    id: 'openadapter',
    displayName: 'OpenAdapter',
    baseUrl: 'https://api.openadapter.in/v1/chat/completions',
    modelsUrl: 'https://api.openadapter.in/v1/models',
    fallbackModels: [
      LlmProviderPresetModel(
        'glm-4.7',
        displayName: 'GLM 4.7 (OpenAdapter)',
        capabilities: {'contextLength': 128000, 'toolCalling': true},
      ),
    ],
  ),
  // Registry audit pinned at OmniRoute d1ba822: OpenVecta uses bearer auth
  // and these nine source-declared offline model seeds. Its registry leaves
  // modelsUrl undefined, so the shared connector derives /v1/models from baseUrl.
  LlmProviderPreset(
    id: 'openvecta',
    displayName: 'OpenVecta',
    baseUrl: 'https://api.openvecta.com/v1/chat/completions',
    fallbackModels: [
      LlmProviderPresetModel('glm-4.7-flash',
          displayName: 'GLM 4.7 Flash',
          capabilities: {'contextLength': 131072}),
      LlmProviderPresetModel('claude-sonnet-4.6',
          displayName: 'Claude Sonnet 4.6',
          capabilities: {'contextLength': 1000000}),
      LlmProviderPresetModel('deepseek-v4-flash',
          displayName: 'DeepSeek V4 Flash',
          capabilities: {'contextLength': 131072}),
      LlmProviderPresetModel('gpt-oss-120b',
          displayName: 'GPT OSS 120B', capabilities: {'contextLength': 131072}),
      LlmProviderPresetModel('gemma-4-31b',
          displayName: 'Gemma 4 31B', capabilities: {'contextLength': 262144}),
      LlmProviderPresetModel('kimi-k2.6',
          displayName: 'Kimi K2.6', capabilities: {'contextLength': 200000}),
      LlmProviderPresetModel('llama-3.3-70b-instruct',
          displayName: 'Llama 3.3 70B Instruct',
          capabilities: {'contextLength': 131072}),
      LlmProviderPresetModel('llama-4-maverick',
          displayName: 'Llama 4 Maverick',
          capabilities: {'contextLength': 1048576}),
      LlmProviderPresetModel('nemotron-3-super-120b',
          displayName: 'Nemotron 3 Super 120B',
          capabilities: {'contextLength': 262144}),
    ],
  ),
  // Registry audit pinned at OmniRoute d1ba822: Opper uses bearer auth,
  // live model discovery, and passthrough model IDs with no static seeds.
  LlmProviderPreset(
    id: 'opper',
    displayName: 'Opper',
    baseUrl: 'https://api.opper.ai/v3/compat/chat/completions',
    modelsUrl: 'https://api.opper.ai/v3/compat/models',
  ),
  // Registry audit pinned at OmniRoute d1ba822: PLaMo uses bearer auth and
  // declares one offline model with context and output-token limits.
  LlmProviderPreset(
    id: 'plamo',
    displayName: 'PLaMo',
    baseUrl: 'https://api.platform.preferredai.jp/v1/chat/completions',
    fallbackModels: [
      LlmProviderPresetModel('plamo-3.0-prime',
          displayName: 'PLaMo 3.0 Prime',
          capabilities: {'contextLength': 262144, 'maxOutputTokens': 20000}),
    ],
  ),
  // Registry audit pinned at OmniRoute d1ba822: Poe's API-key mode defaults
  // to Chat Completions with bearer auth. This preset includes only models
  // whose registry target is Chat Completions; Poe's Responses and Claude-only
  // Anthropic Messages routing remains deferred to protocol-aware catalog work.
  LlmProviderPreset(
    id: 'poe',
    displayName: 'Poe',
    baseUrl: 'https://api.poe.com/v1/chat/completions',
    fallbackModels: [
      LlmProviderPresetModel('gpt-5.2', displayName: 'GPT-5.2'),
      LlmProviderPresetModel('gemini-3.0-pro', displayName: 'Gemini 3.0 Pro'),
    ],
  ),
  // Registry audit pinned at OmniRoute d1ba822: Poixe AI uses bearer auth,
  // live /v1/models discovery and passthrough model IDs without static seeds.
  LlmProviderPreset(
    id: 'poixe-ai',
    displayName: 'Poixe AI',
    baseUrl: 'https://api.poixe.com/v1/chat/completions',
    modelsUrl: 'https://api.poixe.com/v1/models',
  ),
  // Registry audit pinned at OmniRoute d1ba822: Poolside uses bearer auth,
  // authenticated /v1/models discovery, and two static Preview models.
  // Evidence: registry/poolside/index.ts:22-45.
  LlmProviderPreset(
    id: 'poolside',
    displayName: 'Poolside',
    baseUrl: 'https://inference.poolside.ai/v1/chat/completions',
    modelsUrl: 'https://inference.poolside.ai/v1/models',
    fallbackModels: [
      LlmProviderPresetModel(
        'poolside/laguna-xs-2.1',
        displayName: 'Laguna XS 2.1',
        capabilities: {
          'toolCalling': true,
          'reasoning': true,
          'contextLength': 262144,
          'maxOutputTokens': 32768,
        },
      ),
      LlmProviderPresetModel(
        'poolside/laguna-s-2.1',
        displayName: 'Laguna S 2.1',
        capabilities: {
          'toolCalling': true,
          'reasoning': true,
          'contextLength': 262144,
          'maxOutputTokens': 32768,
        },
      ),
    ],
  ),
  // PublicAI's pinned runtime uses the default Bearer Chat Completions
  // executor and the provider's static OpenAI-compatible model list.
  // Evidence: registry/publicai/index.ts:4-12; shared.ts:490-498.
  LlmProviderPreset(
    id: 'publicai',
    displayName: 'PublicAI',
    baseUrl: 'https://api.publicai.co/v1/chat/completions',
    fallbackModels: [
      LlmProviderPresetModel('swiss-ai/apertus-70b-instruct'),
      LlmProviderPresetModel('swiss-ai/Apertus-8B-Instruct-2509'),
      LlmProviderPresetModel('aisingapore/Qwen-SEA-LION-v4-32B-IT'),
      LlmProviderPresetModel('aisingapore/Gemma-SEA-LION-v4-27B-IT'),
      LlmProviderPresetModel('allenai/Olmo-3-32B-Think'),
      LlmProviderPresetModel('allenai/Olmo-3-7B-Instruct'),
      LlmProviderPresetModel('utter-project/EuroLLM-22B-Instruct-2512'),
    ],
  ),
  // Regolo declares live /v1/models discovery and no static model seeds.
  // Evidence: registry/regolo/index.ts:4-16.
  LlmProviderPreset(
    id: 'regolo',
    displayName: 'Regolo AI',
    baseUrl: 'https://api.regolo.ai/v1/chat/completions',
    modelsUrl: 'https://api.regolo.ai/v1/models',
  ),
  // Reka's pinned static catalog includes the model-specific reasoning and
  // output-token metadata declared by its default Chat Completions registry.
  // Evidence: registry/reka/index.ts:3-18.
  LlmProviderPreset(
    id: 'reka',
    displayName: 'Reka',
    baseUrl: 'https://api.reka.ai/v1/chat/completions',
    fallbackModels: [
      LlmProviderPresetModel(
        'reka-flash-3',
        displayName: 'Reka Flash 3',
        capabilities: {
          'reasoning': true,
          'alwaysReasons': true,
          'maxOutputTokens': 8192,
        },
      ),
      LlmProviderPresetModel('reka-flash', displayName: 'Reka Flash'),
      LlmProviderPresetModel('reka-edge-2603', displayName: 'Reka Edge 2603'),
    ],
  ),
  // Requesty uses the default Bearer Chat Completions executor and a live
  // /v1/models catalog with passthrough model IDs and no static seeds.
  // Evidence: registry/requesty/index.ts:4-11.
  LlmProviderPreset(
    id: 'requesty',
    displayName: 'Requesty',
    baseUrl: 'https://router.requesty.ai/v1/chat/completions',
    modelsUrl: 'https://router.requesty.ai/v1/models',
  ),
  // SambaNova's pinned runtime uses the default Bearer Chat Completions
  // executor and a source-declared static catalog.
  // Evidence: registry/sambanova/index.ts:4-12; shared.ts:437-445.
  LlmProviderPreset(
    id: 'sambanova',
    displayName: 'SambaNova',
    baseUrl: 'https://api.sambanova.ai/v1/chat/completions',
    fallbackModels: [
      LlmProviderPresetModel('MiniMax-M2.7'),
      LlmProviderPresetModel('DeepSeek-V3.2'),
      LlmProviderPresetModel('Llama-4-Maverick-17B-128E-Instruct'),
      LlmProviderPresetModel('Meta-Llama-3.3-70B-Instruct'),
      LlmProviderPresetModel('gpt-oss-120b'),
      LlmProviderPresetModel('DeepSeek-V3.1'),
      LlmProviderPresetModel('gemma-4-31B-it'),
    ],
  ),
  // Sarvam's pinned runtime uses Bearer Chat Completions and two static models.
  // Evidence: registry/sarvam/index.ts:3-15.
  LlmProviderPreset(
    id: 'sarvam',
    displayName: 'Sarvam AI',
    baseUrl: 'https://api.sarvam.ai/v1/chat/completions',
    fallbackModels: [
      LlmProviderPresetModel(
        'sarvam-105b',
        displayName: 'Sarvam 105B',
        capabilities: {'contextLength': 131072},
      ),
      LlmProviderPresetModel(
        'sarvam-30b',
        displayName: 'Sarvam 30B',
        capabilities: {'contextLength': 65536},
      ),
    ],
  ),
  // Scaleway's pinned runtime uses Bearer Chat Completions and a static list;
  // it declares no discovery URL or additional model capabilities.
  // Evidence: registry/scaleway/index.ts:3-20.
  LlmProviderPreset(
    id: 'scaleway',
    displayName: 'Scaleway AI',
    baseUrl: 'https://api.scaleway.ai/v1/chat/completions',
    fallbackModels: [
      LlmProviderPresetModel(
        'qwen3-235b-a22b-instruct-2507',
        displayName: 'Qwen3 235B A22B (1M free tok 🆓)',
      ),
      LlmProviderPresetModel(
        'llama-3.1-70b-instruct',
        displayName: 'Llama 3.1 70B (🆓 EU)',
      ),
      LlmProviderPresetModel(
        'llama-3.1-8b-instruct',
        displayName: 'Llama 3.1 8B (🆓 EU)',
      ),
      LlmProviderPresetModel(
        'mistral-small-3.2-24b-instruct-2506',
        displayName: 'Mistral Small 3.2 (🆓 EU)',
      ),
      LlmProviderPresetModel(
        'deepseek-v3-0324',
        displayName: 'DeepSeek V3 (🆓 EU)',
      ),
      LlmProviderPresetModel(
        'gpt-oss-120b',
        displayName: 'GPT-OSS 120B (🆓 EU)',
      ),
    ],
  ),
  // M46 entries use the pinned OmniRoute d1ba822 OpenAI-compatible helper or
  // default executor: API-key authentication uses Bearer Authorization.
  // Evidence for each entry is recorded next to its provider ID.
  // Evidence: registry/sealion/index.ts, shared.ts.
  LlmProviderPreset(
    id: 'sealion',
    displayName: 'SEA-LION',
    baseUrl: 'https://api.sea-lion.ai/v1/chat/completions',
    fallbackModels: [
      LlmProviderPresetModel('aisingapore/Llama-SEA-LION-v3.5-70B-R',
          displayName: 'Llama SEA-LION v3.5 70B R',
          capabilities: {'contextLength': 131072}),
      LlmProviderPresetModel('aisingapore/Llama-SEA-LION-v3-70B-IT',
          displayName: 'Llama SEA-LION v3 70B IT',
          capabilities: {'contextLength': 131072}),
      LlmProviderPresetModel('aisingapore/Gemma-SEA-LION-v4-27B-IT',
          displayName: 'Gemma SEA-LION v4 27B IT',
          capabilities: {'contextLength': 131072}),
      LlmProviderPresetModel('aisingapore/Qwen-SEA-LION-v4.5-27B-IT',
          displayName: 'Qwen SEA-LION v4.5 27B IT',
          capabilities: {'contextLength': 32768}),
      LlmProviderPresetModel('aisingapore/Qwen-SEA-LION-v4-32B-IT',
          displayName: 'Qwen SEA-LION v4 32B IT',
          capabilities: {'contextLength': 32768}),
    ],
  ),
  // Evidence: registry/seekai/index.ts, shared.ts.
  LlmProviderPreset(
    id: 'seekai',
    displayName: 'SeekAi',
    baseUrl: 'https://seekai.cc/v1/chat/completions',
    modelsUrl: 'https://seekai.cc/v1/models',
  ),
  // Evidence: registry/sensenova/index.ts.
  LlmProviderPreset(
    id: 'sensenova',
    displayName: 'SenseNova',
    baseUrl: 'https://token.sensenova.cn/v1/chat/completions',
    fallbackModels: [
      LlmProviderPresetModel('sensenova-6.7-flash-lite',
          displayName: 'SenseNova 6.7 Flash-Lite',
          capabilities: {
            'contextLength': 262144,
            'maxOutputTokens': 65536,
            'vision': true,
            'toolCalling': true,
          }),
      LlmProviderPresetModel('deepseek-v4-flash',
          displayName: 'DeepSeek V4 Flash',
          capabilities: {
            'contextLength': 1048576,
            'maxOutputTokens': 65536,
            'reasoning': true,
            'supportedThinkingEfforts': ['none', 'low', 'medium', 'high'],
            'supportsXHighEffort': false,
            'interleavedField': 'reasoning_content',
          }),
      LlmProviderPresetModel('glm-5.2', displayName: 'GLM 5.2', capabilities: {
        'contextLength': 1048576,
        'maxOutputTokens': 65536,
        'reasoning': true,
        'interleavedField': 'reasoning_content',
      }),
    ],
  ),
  // Evidence: registry/sparkdesk/index.ts.
  LlmProviderPreset(
    id: 'sparkdesk',
    displayName: 'SparkDesk',
    baseUrl: 'https://spark-api-open.xf-yun.com/v1/chat/completions',
    fallbackModels: [
      LlmProviderPresetModel('4.0Ultra',
          displayName: 'Spark 4.0 Ultra',
          capabilities: {'contextLength': 32768}),
      LlmProviderPresetModel('generalv3',
          displayName: 'Spark Pro', capabilities: {'contextLength': 8192}),
      LlmProviderPresetModel('pro-128k',
          displayName: 'Spark Pro 128K',
          capabilities: {'contextLength': 131072}),
      LlmProviderPresetModel('lite',
          displayName: 'Spark Lite', capabilities: {'contextLength': 4096}),
    ],
  ),
  // Evidence: registry/speka/index.ts, shared.ts.
  LlmProviderPreset(
    id: 'speka',
    displayName: 'Speka AI',
    baseUrl: 'https://speka.me/v1/chat/completions',
    modelsUrl: 'https://speka.me/v1/models',
  ),
  // Evidence: registry/synthetic/index.ts.
  LlmProviderPreset(
    id: 'synthetic',
    displayName: 'Synthetic',
    baseUrl: 'https://api.synthetic.new/openai/v1/chat/completions',
    modelsUrl: 'https://api.synthetic.new/openai/v1/models',
    fallbackModels: [
      LlmProviderPresetModel('hf:openai/gpt-oss-120b',
          displayName: 'openai/gpt-oss-120b',
          capabilities: {
            'contextLength': 131072,
            'maxOutputTokens': 65536,
            'toolCalling': true,
            'reasoning': true,
          }),
      LlmProviderPresetModel('hf:zai-org/GLM-5.2',
          displayName: 'zai-org/GLM-5.2',
          capabilities: {
            'contextLength': 524288,
            'maxOutputTokens': 65536,
            'toolCalling': true,
            'reasoning': true,
          }),
      LlmProviderPresetModel('hf:moonshotai/Kimi-K2.7-Code',
          displayName: 'moonshotai/Kimi-K2.7-Code',
          capabilities: {
            'contextLength': 262144,
            'maxOutputTokens': 65536,
            'toolCalling': true,
            'reasoning': true,
            'vision': true,
          }),
      LlmProviderPresetModel('hf:Qwen/Qwen3.6-27B',
          displayName: 'Qwen/Qwen3.6-27B',
          capabilities: {
            'contextLength': 262144,
            'maxOutputTokens': 65536,
            'toolCalling': true,
            'reasoning': true,
            'vision': true,
          }),
      LlmProviderPresetModel('hf:MiniMaxAI/MiniMax-M3',
          displayName: 'MiniMaxAI/MiniMax-M3',
          capabilities: {
            'contextLength': 262144,
            'maxOutputTokens': 65536,
            'toolCalling': true,
            'reasoning': true,
            'vision': true,
          }),
      LlmProviderPresetModel('hf:zai-org/GLM-4.7-Flash',
          displayName: 'zai-org/GLM-4.7-Flash',
          capabilities: {
            'contextLength': 196608,
            'maxOutputTokens': 65536,
            'toolCalling': true,
            'reasoning': true,
          }),
      LlmProviderPresetModel(
          'hf:nvidia/NVIDIA-Nemotron-3-Super-120B-A12B-NVFP4',
          displayName: 'nvidia/NVIDIA-Nemotron-3-Super-120B-A12B-NVFP4',
          capabilities: {
            'contextLength': 262144,
            'maxOutputTokens': 65536,
            'toolCalling': true,
            'reasoning': true,
          }),
    ],
  ),
  // Evidence: registry/tokenmarket/index.ts, shared.ts.
  LlmProviderPreset(
    id: 'tokenmarket',
    displayName: 'Token Market',
    baseUrl: 'https://api.tokensmarket.ai/v1/chat/completions',
    modelsUrl: 'https://api.tokensmarket.ai/v1/models',
  ),
  // Evidence: registry/tokenreply/index.ts, shared.ts.
  LlmProviderPreset(
    id: 'tokenreply',
    displayName: 'TokenReply',
    baseUrl: 'https://api.tokenreply.com/v1/chat/completions',
    modelsUrl: 'https://api.tokenreply.com/v1/models',
  ),
  // M46 deferred: the pinned Tencent registry warns that its legacy Hunyuan
  // platform discontinues 46 model lines (including TurboS/T1) on 2026-06-22
  // and requests a recheck by 2026-09-30. That date has passed; this cohort
  // audit has no post-deadline source verifying current endpoint/model support,
  // so Tencent remains excluded pending verification. This does not assert
  // that the entire provider is discontinued. SumoPod, Token Kiosk and
  // TokenRouter declare defaultContextLength=128000 with dynamic /models, which
  // the existing preset contract cannot attach to remotely discovered models.
  // TheB.AI has no per-ID registry entry/executable adapter at M33 pin d1ba822.
  // M45 deferred: Pollinations is dispatched to a dedicated executor and uses
  // optional API-key auth (registry/pollinations/index.ts:8-22;
  // executors/index.ts:70); Predibase's pinned endpoint is recorded as
  // unresolved/discontinued by the M33 2026-06-19 DNS audit despite its static
  // registry declaration (registry/predibase/index.ts:4-12); Qiniu declares
  // defaultContextLength 128000, which the current preset cannot attach to
  // discovered models (registry/qiniu/index.ts:3-14); Routeway requires a fixed
  // User-Agent header (registry/routeway/index.ts:12-18); SAP has no per-ID
  // provider registry entry or verified runtime adapter at this pin (M33 audit).
  // Deferred from M44: the pinned 1min.ai executor translates OpenAI messages
  // to its promptObject/SSE API and authenticates with `API-KEY`; see registry
  // oneminai/index.ts:3-28 and executors/index.ts:68-69.
  // OpenRouter, OrcaRouter and Perplexity declare fixed provider request
  // headers not represented by a preset: registry openrouter/index.ts:17-20,
  // orcarouter/index.ts:18-21 and perplexity/index.ts:13-15. OpenRouter and
  // Perplexity also need distinct authenticated key-check URLs.
  // OVHcloud's registry uses optional/no-auth semantics beyond this preset's
  // required API-key account mode: registry ovhcloud/index.ts:7-23.
  // Pioneer uses `X-API-Key` and filtered `/base-models` discovery; current
  // shared connector auth is Bearer: registry pioneer/index.ts:13-27.
  // Deferred from M43: the audited Navy registry adds User-Agent: OmniRoute/1.0
  // because its upstream rejects requests without that header. This preset
  // contract only emits standard bearer auth and cannot express that header.
  // Registry evidence: OmniRoute d1ba822 open-sse/config/providers/registry/
  // navy/index.ts:17-20,22.
  // M47 adds the source-backed Chat Completions routes below. UC Direct is
  // deferred: its pinned API requires X-API-Key, while the shared connector
  // injects API keys as Bearer Authorization and cannot bind the secret to a
  // provider-specific header (registry/uc-direct/index.ts:25-35).
  // Typhoon's pin declares one static model and no discovery URL.
  LlmProviderPreset(
    id: 'typhoon',
    displayName: 'Typhoon',
    baseUrl: 'https://api.opentyphoon.ai/v1/chat/completions',
    fallbackModels: [
      LlmProviderPresetModel(
        'typhoon-v2.5-30b-a3b-instruct',
        displayName: 'Typhoon v2.5 30B A3B Instruct',
        capabilities: {'contextLength': 131072},
      ),
    ],
  ),
  // The pinned registries use live OpenAI-compatible model discovery and
  // bearer auth; their model IDs come from the provider-owned /models lists.
  LlmProviderPreset(
    id: 'unifically',
    displayName: 'Unifically',
    baseUrl: 'https://api.unifically.com/v1/chat/completions',
    modelsUrl: 'https://api.unifically.com/v1/models?category=llm',
  ),
  LlmProviderPreset(
    id: 'unorouter',
    displayName: 'UnoRouter',
    baseUrl: 'https://api.unorouter.com/v1/chat/completions',
    modelsUrl: 'https://api.unorouter.com/v1/models',
  ),
  LlmProviderPreset(
    id: 'upstage',
    displayName: 'Upstage',
    baseUrl: 'https://api.upstage.ai/v1/chat/completions',
    fallbackModels: [
      LlmProviderPresetModel('solar-pro3'),
      LlmProviderPresetModel('solar-mini'),
    ],
  ),
  LlmProviderPreset(
    id: 'v0-vercel',
    displayName: 'v0 (Vercel)',
    baseUrl: 'https://api.v0.dev/v1/chat/completions',
    fallbackModels: [
      LlmProviderPresetModel('v0-1.0-md'),
      LlmProviderPresetModel('v0-1.5-lg'),
      LlmProviderPresetModel('v0-1.5-md'),
    ],
  ),
  LlmProviderPreset(
    id: 'venice',
    displayName: 'Venice.ai',
    baseUrl: 'https://api.venice.ai/api/v1/chat/completions',
    fallbackModels: [LlmProviderPresetModel('venice-latest')],
  ),
  LlmProviderPreset(
    id: 'vercel-ai-gateway',
    displayName: 'Vercel AI Gateway',
    baseUrl: 'https://ai-gateway.vercel.sh/v1/chat/completions',
    fallbackModels: [
      LlmProviderPresetModel('openai/gpt-4.1'),
      LlmProviderPresetModel('anthropic/claude-4-sonnet'),
      LlmProviderPresetModel('google/gemini-2.5-pro'),
      LlmProviderPresetModel('moonshotai/kimi-k2'),
      LlmProviderPresetModel('vercel/v0-1.5-md'),
    ],
  ),
  LlmProviderPreset(
    id: 'void-ai',
    displayName: 'Void AI',
    baseUrl: 'https://api.voidai.app/v1/chat/completions',
    modelsUrl: 'https://api.voidai.app/v1/models',
  ),
  LlmProviderPreset(
    id: 'volcengine',
    displayName: 'Volcengine',
    baseUrl: 'https://ark.cn-beijing.volces.com/api/v3/chat/completions',
    fallbackModels: [
      LlmProviderPresetModel('deepseek-v3-2-251201'),
      LlmProviderPresetModel('doubao-seed-2-0-pro-260215'),
      LlmProviderPresetModel('doubao-seed-2-0-code-preview-260215'),
      LlmProviderPresetModel('kimi-k2-5-260127'),
      LlmProviderPresetModel('glm-4-7-251222'),
      LlmProviderPresetModel('DeepSeek-V4-Flash'),
      LlmProviderPresetModel('DeepSeek-V4-Pro'),
    ],
  ),
  // Agent Plan and Coding Plan are separate products with distinct chat
  // endpoints and model catalogs. Agent Plan has no /models endpoint; Coding
  // Plan exposes its catalog under the /api/coding/v3 API root.
  LlmProviderPreset(
    id: 'volcengine-agent-plan',
    displayName: 'Volcengine Ark Agent Plan',
    baseUrl: 'https://ark.cn-beijing.volces.com/api/plan/v3/chat/completions',
    fallbackModels: [
      LlmProviderPresetModel('doubao-seed-evolving',
          displayName: 'Doubao Seed Evolving (Agent Plan)',
          capabilities: {
            'contextLength': 1048576,
            'toolCalling': true,
            'vision': true,
            'reasoning': true
          }),
      LlmProviderPresetModel('doubao-seed-2-1-turbo-260628',
          displayName: 'Doubao Seed 2.1 Turbo (Agent Plan)',
          capabilities: {
            'contextLength': 262144,
            'toolCalling': true,
            'vision': true,
            'reasoning': true
          }),
      LlmProviderPresetModel('doubao-seed-2-0-lite-260215',
          displayName: 'Doubao Seed 2.0 Lite (Agent Plan)',
          capabilities: {
            'contextLength': 262144,
            'toolCalling': true,
            'vision': true,
            'reasoning': true
          }),
      LlmProviderPresetModel('doubao-seed-2-0-mini-260215',
          displayName: 'Doubao Seed 2.0 Mini (Agent Plan)',
          capabilities: {
            'contextLength': 262144,
            'toolCalling': true,
            'vision': true,
            'reasoning': true
          }),
      LlmProviderPresetModel('deepseek-v4-flash-ga-260731',
          displayName: 'DeepSeek V4 Flash GA (Agent Plan)',
          capabilities: {
            'contextLength': 1048576,
            'toolCalling': true,
            'reasoning': true
          }),
      LlmProviderPresetModel('kimi-k3',
          displayName: 'Kimi K3 (Agent Plan)',
          capabilities: {
            'contextLength': 1048576,
            'toolCalling': true,
            'vision': true,
            'reasoning': true
          }),
      LlmProviderPresetModel('glm-5-2-260617',
          displayName: 'GLM 5.2 (Agent Plan)',
          capabilities: {
            'contextLength': 1048576,
            'toolCalling': true,
            'reasoning': true
          }),
      LlmProviderPresetModel('kimi-k2.7-code',
          displayName: 'Kimi K2.7 Code (Agent Plan)',
          capabilities: {
            'contextLength': 1048576,
            'toolCalling': true,
            'vision': true,
            'reasoning': true
          }),
      LlmProviderPresetModel('minimax-m3',
          displayName: 'MiniMax M3 (Agent Plan)',
          capabilities: {
            'contextLength': 1048576,
            'toolCalling': true,
            'vision': true,
            'reasoning': true
          }),
      LlmProviderPresetModel('deepseek-v4-pro-260425',
          displayName: 'DeepSeek V4 Pro (Agent Plan)',
          capabilities: {
            'contextLength': 1048576,
            'toolCalling': true,
            'reasoning': true
          }),
      LlmProviderPresetModel('minimax-m2.7',
          displayName: 'MiniMax M2.7 (Agent Plan)',
          capabilities: {
            'contextLength': 1048576,
            'toolCalling': true,
            'reasoning': true
          }),
      LlmProviderPresetModel('kimi-k2.6',
          displayName: 'Kimi K2.6 (Agent Plan)',
          capabilities: {
            'contextLength': 1048576,
            'toolCalling': true,
            'reasoning': true
          }),
    ],
  ),
  LlmProviderPreset(
    id: 'volcengine-coding-plan',
    displayName: 'Volcengine Ark Coding Plan',
    baseUrl: 'https://ark.cn-beijing.volces.com/api/coding/v3/chat/completions',
    modelsUrl: 'https://ark.cn-beijing.volces.com/api/coding/v3/models',
    fallbackModels: [
      LlmProviderPresetModel('doubao-seed-2-1-turbo',
          displayName: 'Doubao Seed 2.1 Turbo (Coding Plan)',
          capabilities: {
            'contextLength': 262144,
            'toolCalling': true,
            'vision': true,
            'reasoning': true
          }),
      LlmProviderPresetModel('doubao-seed-2.0-lite',
          displayName: 'Doubao Seed 2.0 Lite (Coding Plan)',
          capabilities: {
            'contextLength': 262144,
            'toolCalling': true,
            'vision': true,
            'reasoning': true
          }),
      LlmProviderPresetModel('deepseek-v4-flash',
          displayName: 'DeepSeek V4 Flash (Coding Plan)',
          capabilities: {
            'contextLength': 1048576,
            'toolCalling': true,
            'reasoning': true
          }),
      LlmProviderPresetModel('glm-5.2',
          displayName: 'GLM 5.2 (Coding Plan)',
          capabilities: {
            'contextLength': 1048576,
            'toolCalling': true,
            'reasoning': true
          }),
      LlmProviderPresetModel('kimi-k2.7-code',
          displayName: 'Kimi K2.7 Code (Coding Plan)',
          capabilities: {
            'contextLength': 1048576,
            'toolCalling': true,
            'vision': true,
            'reasoning': true
          }),
      LlmProviderPresetModel('minimax-m3',
          displayName: 'MiniMax M3 (Coding Plan)',
          capabilities: {
            'contextLength': 1048576,
            'toolCalling': true,
            'vision': true,
            'reasoning': true
          }),
      LlmProviderPresetModel('deepseek-v4-pro',
          displayName: 'DeepSeek V4 Pro (Coding Plan)',
          capabilities: {
            'contextLength': 1048576,
            'toolCalling': true,
            'reasoning': true
          }),
      LlmProviderPresetModel('minimax-m2.7',
          displayName: 'MiniMax M2.7 (Coding Plan)',
          capabilities: {
            'contextLength': 1048576,
            'toolCalling': true,
            'reasoning': true
          }),
      LlmProviderPresetModel('kimi-k2.6',
          displayName: 'Kimi K2.6 (Coding Plan)',
          capabilities: {
            'contextLength': 1048576,
            'toolCalling': true,
            'reasoning': true
          }),
    ],
  ),
  LlmProviderPreset(
    id: 'wandb',
    displayName: 'Weights & Biases Inference',
    baseUrl: 'https://api.inference.wandb.ai/v1/chat/completions',
    fallbackModels: [
      LlmProviderPresetModel('openai/gpt-oss-120b'),
      LlmProviderPresetModel('Qwen/Qwen3-Coder-480B-A35B-Instruct'),
      LlmProviderPresetModel('deepseek-ai/DeepSeek-V3.1'),
    ],
  ),
  // M48 audit: the pinned OmniRoute d1ba822 runtime has no per-ID watsonx
  // executor/registry entry, so its matrix card alone cannot supply a preset.
  // x5lab and ZenMux declare defaultContextLength: 128000 for dynamic models,
  // which this catalog cannot preserve on discovered models (registry/x5lab/
  // index.ts:10; registry/zenmux/index.ts:12). Both remain deferred.
  // Xiaomi MiMo Token Plan is also deferred: its keys are cluster-bound across
  // CN/SGP/AMS and the shared account flow cannot select/persist a region
  // (shared/constants/xiaomiTokenPlanRegions.ts:4-22).
  // The remaining entries use the pinned OpenAI Chat Completions default
  // executor, API-key/Bearer auth, and provider-declared static or /models
  // catalogs. M33 audit rows 294-306 provide the source cross-check.
  LlmProviderPreset(
    id: 'writer',
    displayName: 'Writer',
    baseUrl: 'https://api.writer.com/v1/chat/completions',
    fallbackModels: [
      LlmProviderPresetModel(
        'palmyra-x5',
        displayName: 'Palmyra X5',
        capabilities: {'contextLength': 1048576},
      ),
      LlmProviderPresetModel(
        'palmyra-x4',
        displayName: 'Palmyra X4',
        capabilities: {'contextLength': 131072},
      ),
    ],
  ),
  LlmProviderPreset(
    id: 'xiaomi-mimo',
    displayName: 'Xiaomi MiMo',
    baseUrl: 'https://api.xiaomimimo.com/v1/chat/completions',
    fallbackModels: [
      LlmProviderPresetModel(
        'mimo-v2.5-pro',
        displayName: 'MiMo-V2.5-Pro',
        capabilities: {'contextLength': 1048576, 'maxOutputTokens': 131072},
      ),
      LlmProviderPresetModel(
        'mimo-v2.5',
        displayName: 'MiMo-V2.5',
        capabilities: {'contextLength': 1048576, 'maxOutputTokens': 131072},
      ),
    ],
  ),
  LlmProviderPreset(
    id: 'xkiro',
    displayName: 'xKiro',
    baseUrl: 'https://api.xkiro.com/v1/chat/completions',
    fallbackModels: [
      LlmProviderPresetModel(
        'qwen/qwen3-vl-plus:free',
        displayName: 'Qwen3 VL Plus',
        capabilities: {
          'contextLength': 262144,
          'toolCalling': true,
          'vision': true,
        },
      ),
      LlmProviderPresetModel(
        'sensenova/sensenova-6.8-flash-lite',
        displayName: 'SenseNova 6.8 Flash-Lite',
        capabilities: {
          'contextLength': 262144,
          'toolCalling': true,
          'vision': true,
        },
      ),
      LlmProviderPresetModel(
        'minimax/minimax-m2.7:free',
        displayName: 'MiniMax M2.7',
        capabilities: {'contextLength': 204800, 'toolCalling': true},
      ),
      LlmProviderPresetModel(
        'minimax/minimax-m2.7-highspeed:free',
        displayName: 'MiniMax M2.7 Highspeed',
        capabilities: {'contextLength': 204800, 'toolCalling': true},
      ),
      LlmProviderPresetModel(
        'minimax/minimax-m2.5:free',
        displayName: 'MiniMax M2.5',
        capabilities: {'contextLength': 204800, 'toolCalling': true},
      ),
      LlmProviderPresetModel(
        'minimax/minimax-m3:free',
        displayName: 'MiniMax M3',
        capabilities: {
          'contextLength': 1000000,
          'toolCalling': true,
          'vision': true,
        },
      ),
      LlmProviderPresetModel(
        'minimax/minimax-m2.1-highspeed:free',
        displayName: 'MiniMax M2.1 Highspeed',
        capabilities: {'contextLength': 204800, 'toolCalling': true},
      ),
      LlmProviderPresetModel(
        'minimax/minimax-m2.5-highspeed:free',
        displayName: 'MiniMax M2.5 Highspeed',
        capabilities: {'contextLength': 204800, 'toolCalling': true},
      ),
      LlmProviderPresetModel(
        'minimax/minimax-m2.1:free',
        displayName: 'MiniMax M2.1',
        capabilities: {'contextLength': 204800, 'toolCalling': true},
      ),
      LlmProviderPresetModel(
        'minimax/minimax-m2:free',
        displayName: 'MiniMax M2',
        capabilities: {'contextLength': 204800, 'toolCalling': true},
      ),
      LlmProviderPresetModel(
        'qwen/qwen3.5-flash:free',
        displayName: 'Qwen3.5 Flash',
        capabilities: {
          'contextLength': 1000000,
          'toolCalling': true,
          'vision': true,
        },
      ),
      LlmProviderPresetModel(
        'qwen/qwen3.6-plus:free',
        displayName: 'Qwen3.6 Plus',
        capabilities: {
          'contextLength': 1000000,
          'toolCalling': true,
          'vision': true,
        },
      ),
      LlmProviderPresetModel(
        'qwen/qwen3.5-397b-a17b:free',
        displayName: 'Qwen3.5 397B A17B',
        capabilities: {
          'contextLength': 262144,
          'toolCalling': true,
          'vision': true,
        },
      ),
      LlmProviderPresetModel(
        'qwen/qwen3.5-omni-flash:free',
        displayName: 'Qwen3.5 Omni Flash',
        capabilities: {
          'contextLength': 262144,
          'toolCalling': true,
          'vision': true,
        },
      ),
      LlmProviderPresetModel(
        'mistralai/mistral-large-2512',
        displayName: 'Mistral Large 3',
        capabilities: {
          'contextLength': 256000,
          'toolCalling': true,
          'vision': true,
          'reasoning': false,
        },
      ),
      LlmProviderPresetModel(
        'mistralai/mistral-medium-3.5',
        displayName: 'Mistral Medium 3.5',
        capabilities: {
          'contextLength': 256000,
          'toolCalling': true,
          'vision': true,
        },
      ),
      LlmProviderPresetModel(
        'mistralai/mistral-small-2603',
        displayName: 'Mistral Small 4',
        capabilities: {
          'contextLength': 256000,
          'toolCalling': true,
          'vision': true,
        },
      ),
      LlmProviderPresetModel(
        'mistralai/codestral-2508',
        displayName: 'Codestral',
        capabilities: {
          'contextLength': 256000,
          'toolCalling': true,
          'reasoning': false,
        },
      ),
      LlmProviderPresetModel(
        'mistralai/devstral-medium',
        displayName: 'Devstral 2',
        capabilities: {
          'contextLength': 256000,
          'toolCalling': true,
          'reasoning': false,
        },
      ),
      LlmProviderPresetModel(
        'mistralai/ministral-8b',
        displayName: 'Ministral 3 8B',
        capabilities: {
          'contextLength': 256000,
          'toolCalling': true,
          'vision': true,
          'reasoning': false,
        },
      ),
      LlmProviderPresetModel(
        'mistralai/ministral-3b',
        displayName: 'Ministral 3 3B',
        capabilities: {
          'contextLength': 128000,
          'toolCalling': true,
          'vision': true,
          'reasoning': false,
        },
      ),
      LlmProviderPresetModel(
        'deepseek/deepseek-v4-pro',
        displayName: 'DeepSeek V4 Pro',
        capabilities: {'contextLength': 1048576, 'toolCalling': true},
      ),
      LlmProviderPresetModel(
        'deepseek/deepseek-v3.2',
        displayName: 'DeepSeek V3.2',
        capabilities: {'contextLength': 131072, 'toolCalling': true},
      ),
      LlmProviderPresetModel(
        'deepseek/deepseek-chat-v3.1',
        displayName: 'DeepSeek V3.1',
        capabilities: {'contextLength': 163840, 'toolCalling': true},
      ),
      LlmProviderPresetModel(
        'qwen/qwen3.7-plus:free',
        displayName: 'Qwen3.7 Plus',
        capabilities: {
          'contextLength': 1000000,
          'toolCalling': true,
          'vision': true,
        },
      ),
      LlmProviderPresetModel(
        'mistralai/ministral-14b',
        displayName: 'Ministral 3 14B',
        capabilities: {
          'contextLength': 256000,
          'toolCalling': true,
          'vision': true,
          'reasoning': false,
        },
      ),
      LlmProviderPresetModel(
        'qwen/qwen3.6-max-preview:free',
        displayName: 'Qwen3.6 Max Preview',
        capabilities: {'contextLength': 262144, 'toolCalling': true},
      ),
      LlmProviderPresetModel(
        'qwen/qwen3.5-plus:free',
        displayName: 'Qwen3.5 Plus',
        capabilities: {
          'contextLength': 1000000,
          'toolCalling': true,
          'vision': true,
        },
      ),
      LlmProviderPresetModel(
        'qwen/qwen3.5-omni-plus:free',
        displayName: 'Qwen3.5 Omni Plus',
        capabilities: {
          'contextLength': 262144,
          'toolCalling': true,
          'vision': true,
        },
      ),
      LlmProviderPresetModel(
        'deepseek/deepseek-v4-flash',
        displayName: 'DeepSeek V4 Flash',
        capabilities: {'contextLength': 1048576, 'toolCalling': true},
      ),
      LlmProviderPresetModel(
        'sensenova/sensenova-6.7-flash-lite',
        displayName: 'SenseNova 6.7 Flash-Lite',
        capabilities: {
          'contextLength': 262144,
          'toolCalling': true,
          'vision': true,
        },
      ),
      LlmProviderPresetModel(
        'qwen/qwen3.8-max:free',
        displayName: 'Qwen3.8 Max',
        capabilities: {
          'contextLength': 1000000,
          'toolCalling': true,
          'vision': true,
        },
      ),
      LlmProviderPresetModel(
        'qwen/qwen3.7-max:free',
        displayName: 'Qwen3.7 Max',
        capabilities: {'contextLength': 1000000, 'toolCalling': true},
      ),
      LlmProviderPresetModel(
        'qwen/qwen3.6-27b:free',
        displayName: 'Qwen3.6 27B',
        capabilities: {
          'contextLength': 262144,
          'toolCalling': true,
          'vision': true,
        },
      ),
      LlmProviderPresetModel(
        'qwen/qwen3.6-35b-a3b:free',
        displayName: 'Qwen3.6 35B A3B',
        capabilities: {
          'contextLength': 262144,
          'toolCalling': true,
          'vision': true,
        },
      ),
      LlmProviderPresetModel(
        'qwen/qwen3-max:free',
        displayName: 'Qwen3 Max',
        capabilities: {
          'contextLength': 262144,
          'toolCalling': true,
          'vision': true,
        },
      ),
      LlmProviderPresetModel(
        'qwen/qwen3-coder-plus:free',
        displayName: 'Qwen3 Coder Plus',
        capabilities: {
          'contextLength': 1048576,
          'toolCalling': true,
          'vision': true,
        },
      ),
      LlmProviderPresetModel(
        'qwen/qwen-plus-2025-07-28:free',
        displayName: 'Qwen Plus 0728',
        capabilities: {
          'contextLength': 131072,
          'toolCalling': true,
          'vision': true,
        },
      ),
      LlmProviderPresetModel(
        'qwen/qwen3-omni-flash:free',
        displayName: 'Qwen3 Omni Flash',
        capabilities: {
          'contextLength': 262144,
          'toolCalling': true,
          'vision': true,
        },
      ),
    ],
  ),
  LlmProviderPreset(
    id: 'y-api',
    displayName: 'Y-API',
    baseUrl: 'https://api.y-api.bestvirtualgoods.com/v1/chat/completions',
    modelsUrl: 'https://api.y-api.bestvirtualgoods.com/v1/models',
  ),
  LlmProviderPreset(
    id: 'yolo-auto',
    displayName: 'Yolo-Auto',
    baseUrl: 'https://yolo-auto.com/v1/chat/completions',
    modelsUrl: 'https://yolo-auto.com/v1/models',
    fallbackModels: [
      LlmProviderPresetModel(
        'qwen3.6-35b-a3b',
        displayName: 'Qwen 3.6 35B A3B',
      ),
    ],
  ),
  LlmProviderPreset(
    id: 'zerolimitai',
    displayName: 'ZeroLimitAI',
    baseUrl: 'https://www.zerolimitai.com/api/v1/chat/completions',
    modelsUrl: 'https://www.zerolimitai.com/api/v1/models',
  ),
  LlmProviderPreset(
    id: 'zylo-api',
    displayName: 'Zylo API',
    baseUrl: 'https://api.zyloai.net/v1/chat/completions',
    modelsUrl: 'https://api.zyloai.net/v1/models',
  ),
];

const _stepfunFallbackModels = <LlmProviderPresetModel>[
  LlmProviderPresetModel(
    'step-5-preview',
    displayName: 'Step 5 Preview',
    capabilities: {
      'contextLength': 1024000,
      'reasoning': true,
      'supportedThinkingEfforts': ['low', 'medium', 'high'],
      'vision': true,
      'toolCalling': true,
    },
  ),
  LlmProviderPresetModel('step-3.7-flash',
      displayName: 'Step 3.7 Flash', capabilities: {'contextLength': 262144}),
  LlmProviderPresetModel('step-3.5-flash',
      displayName: 'Step 3.5 Flash', capabilities: {'contextLength': 262144}),
  LlmProviderPresetModel('step-3.5-flash-2603',
      displayName: 'Step 3.5 Flash 2603',
      capabilities: {'contextLength': 262144}),
  LlmProviderPresetModel('step-1o-turbo-vision',
      displayName: 'Step 1o Turbo Vision',
      capabilities: {'contextLength': 32768}),
  LlmProviderPresetModel('step-1v', displayName: 'Step 1V'),
];

LlmProviderPreset? findLlmOpenAiProviderPreset(String? id) {
  if (id == null) return null;
  for (final preset in llmOpenAiProviderPresets) {
    if (preset.id == id) return preset;
  }
  return null;
}
