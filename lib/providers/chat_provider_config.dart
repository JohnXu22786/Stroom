// ============================================================================
// Chat 模型配置 & 供应商注册表
// 遵循与 tts_config.dart 相同的注册表模式
// ============================================================================

/// Chat 模型配置
class ChatModelConfig {
  final String modelId; // 模型 ID，如 'gpt-4o'
  final int maxTokens; // 最大 Token 数，默认 4096
  final double temperature; // 温度，默认 0.7
  final String systemPrompt; // 系统提示词，默认 '你是一个有帮助的助手。'
  final bool supportStream; // 是否支持流式，默认 true

  const ChatModelConfig({
    required this.modelId,
    this.maxTokens = 4096,
    this.temperature = 0.7,
    this.systemPrompt = '你是一个有帮助的助手。',
    this.supportStream = true,
  });

  Map<String, dynamic> toMap() => {
        'modelId': modelId,
        'maxTokens': maxTokens,
        'temperature': temperature,
        'systemPrompt': systemPrompt,
        'supportStream': supportStream,
      };

  factory ChatModelConfig.fromMap(Map<String, dynamic> map) => ChatModelConfig(
        modelId: map['modelId'] as String,
        maxTokens: (map['maxTokens'] as num?)?.toInt() ?? 4096,
        temperature: (map['temperature'] as num?)?.toDouble() ?? 0.7,
        systemPrompt: map['systemPrompt'] as String? ?? '你是一个有帮助的助手。',
        supportStream: map['supportStream'] as bool? ?? true,
      );

  ChatModelConfig copy() => ChatModelConfig(
        modelId: modelId,
        maxTokens: maxTokens,
        temperature: temperature,
        systemPrompt: systemPrompt,
        supportStream: supportStream,
      );
}

/// 聊天供应商定义
class ChatProviderDefinition {
  final String id; // 唯一标识，如 'openai_compatible'
  final String label; // 显示名称，如 'OpenAI Compatible'
  final String? defaultBaseUrl; // 默认 API 地址
  final List<ChatModelConfig> defaultModels; // 默认模型列表
  final Map<String, dynamic> defaultConfig; // 供应商专属默认配置

  const ChatProviderDefinition({
    required this.id,
    required this.label,
    this.defaultBaseUrl,
    this.defaultModels = const [],
    this.defaultConfig = const {},
  });

  /// 转 Map（用于持久化）
  Map<String, dynamic> toMap() => {
        'id': id,
        'label': label,
        'defaultBaseUrl': defaultBaseUrl,
        'defaultModels': defaultModels.map((m) => m.toMap()).toList(),
        'defaultConfig': defaultConfig,
      };

  /// 从 Map 构造
  factory ChatProviderDefinition.fromMap(Map<String, dynamic> map) {
    return ChatProviderDefinition(
      id: map['id'] as String,
      label: map['label'] as String,
      defaultBaseUrl: map['defaultBaseUrl'] as String?,
      defaultModels: map['defaultModels'] is List
          ? (map['defaultModels'] as List)
              .map((m) =>
                  ChatModelConfig.fromMap(Map<String, dynamic>.from(m as Map)))
              .toList()
          : [],
      defaultConfig:
          Map<String, dynamic>.from(map['defaultConfig'] as Map? ?? {}),
    );
  }
}

/// 聊天供应商注册表
class ChatProviderRegistry {
  static final Map<String, ChatProviderDefinition> _registry = {};

  /// 注册一个供应商
  static void register(ChatProviderDefinition def) {
    _registry[def.id] = def;
  }

  /// 通过 id 获取定义
  static ChatProviderDefinition? get(String id) => _registry[id];

  /// 获取所有已注册的供应商
  static List<ChatProviderDefinition> getAll() =>
      _registry.values.toList(growable: false);

  /// 是否已注册
  static bool isRegistered(String id) => _registry.containsKey(id);

  /// 注销（用于测试）
  static void unregister(String id) => _registry.remove(id);
}

// ============================================================================
// 内置聊天供应商注册
// ============================================================================

/// 注册所有内置聊天供应商
void registerBuiltinChatProviders() {
  ChatProviderRegistry.register(ChatProviderDefinition(
    id: 'openai_compatible',
    label: 'OpenAI Compatible',
    defaultBaseUrl: 'https://api.openai.com/v1',
    defaultModels: [
      ChatModelConfig(
        modelId: 'gpt-4o',
        systemPrompt: '你是一个有帮助的助手。',
      ),
      ChatModelConfig(
        modelId: 'gpt-4o-mini',
        systemPrompt: '你是一个有帮助的助手。',
      ),
      ChatModelConfig(
        modelId: 'gpt-4-turbo',
        systemPrompt: '你是一个有帮助的助手。',
      ),
    ],
  ));
}

// ============================================================================
// 全局配置工具函数（基于注册表）
// ============================================================================

/// 获取指定供应商的模型列表
List<ChatModelConfig> getChatProviderModels(String providerId) {
  final def = ChatProviderRegistry.get(providerId);
  return def != null ? List.from(def.defaultModels) : [];
}

/// 检查供应商是否受支持
bool isChatProviderSupported(String providerId) {
  return ChatProviderRegistry.isRegistered(providerId);
}
