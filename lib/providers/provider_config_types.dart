import '../models/tts_models.dart';

// ============================================================================
// 供应商类型注册表 — 每种类型可注册默认值，新增类型只需注册一次
// ============================================================================

/// 模型配置页面的样式
enum ModelConfigStyle {
  /// TTS 样式：音色、音量、语速、裁切、流式输出、instruction 等
  tts,

  /// LLM 样式：模型ID、上下文长度、自定义参数
  llm,

  /// 简洁样式：模型ID、自定义参数（无上下文长度要求），用于 ASR
  simple,

  /// OCR 样式：模型ID、可选用户指令、OCR 参数（temperature 等）、自定义参数
  ocr,

  /// ASR 样式：模型ID、自定义参数、ASR 专有参数（language、response_format 等）
  asr,
}

class ProviderTypeDefinition {
  final String type;
  final String? defaultHost;
  final String? hostHint;
  final List<ModelConfig> defaultModels;
  final ModelConfigStyle modelConfigStyle;

  bool get useLlmModelConfig => modelConfigStyle == ModelConfigStyle.llm;

  const ProviderTypeDefinition({
    required this.type,
    this.defaultHost,
    this.hostHint,
    this.defaultModels = const [],
    this.modelConfigStyle = ModelConfigStyle.tts,
  });
}

class ProviderTypeRegistry {
  static final Map<String, ProviderTypeDefinition> _registry = {};

  static void register(ProviderTypeDefinition def) {
    _registry[def.type] = def;
  }

  static ProviderTypeDefinition? get(String type) => _registry[type];

  static bool isRegistered(String type) => _registry.containsKey(type);
}

void registerBuiltinProviderTypes() {
  ProviderTypeRegistry.register(
    const ProviderTypeDefinition(
      type: 'llm',
      hostHint: '例如: https://api.openai.com/v1/chat/completions',
      modelConfigStyle: ModelConfigStyle.llm,
    ),
  );
  ProviderTypeRegistry.register(
    const ProviderTypeDefinition(
      type: 'tts',
      hostHint: '例如: https://api.openai.com/v1/audio/speech',
      modelConfigStyle: ModelConfigStyle.tts,
    ),
  );
  ProviderTypeRegistry.register(
    const ProviderTypeDefinition(
      type: 'ocr',
      hostHint: '例如: https://api.openai.com/v1/chat/completions',
      modelConfigStyle: ModelConfigStyle.ocr,
    ),
  );
  ProviderTypeRegistry.register(
    const ProviderTypeDefinition(
      type: 'asr',
      hostHint: '例如: https://api.openai.com/v1/audio/transcriptions',
      modelConfigStyle: ModelConfigStyle.asr,
    ),
  );
  ProviderTypeRegistry.register(
    const ProviderTypeDefinition(
      type: 'mcp',
      hostHint: '例如: http://localhost:3001/sse',
    ),
  );
}
