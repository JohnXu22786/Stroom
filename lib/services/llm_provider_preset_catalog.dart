/// Source-backed presets for ordinary API-key OpenAI Chat Completions APIs.
///
/// Provider identity is stored on an `openai-compatibility` account. This keeps
/// requests on the shared connector and leaves custom endpoint accounts intact.
class LlmProviderPresetModel {
  final String id;
  final String displayName;
  final Map<String, dynamic> capabilities;

  const LlmProviderPresetModel(
    this.id, {
    String? displayName,
    this.capabilities = const {},
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
    this.fallbackModels = const [],
  });

  /// Applies only preset-owned settings, retaining unrelated account settings.
  Map<String, dynamic> applyToEndpointConfig(Map<String, dynamic> existing) => {
        ...existing,
        'providerPresetId': id,
        'baseUrl': baseUrl,
        if (modelsUrl != null) 'modelsUrl': modelsUrl,
        'apiProtocol': defaultApiProtocol,
      };
}

const llmOpenAiProviderPresets = <LlmProviderPreset>[
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
    id: 'arcee-ai',
    displayName: 'Arcee AI',
    baseUrl: 'https://api.arcee.ai/api/v1/chat/completions',
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
    id: 'chutes',
    displayName: 'Chutes.ai',
    baseUrl: 'https://llm.chutes.ai/v1/chat/completions',
    fallbackModels: [
      LlmProviderPresetModel('Qwen2.5-72B-Instruct',
          displayName: 'Qwen2.5 72B'),
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
];

LlmProviderPreset? findLlmOpenAiProviderPreset(String? id) {
  if (id == null) return null;
  for (final preset in llmOpenAiProviderPresets) {
    if (preset.id == id) return preset;
  }
  return null;
}
