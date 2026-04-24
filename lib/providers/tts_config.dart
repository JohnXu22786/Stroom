import 'dart:convert';

/// TTS供应商枚举
enum TTSProvider {
  glmTts('glm_tts'),
  aihubmixTts('aihubmix_tts');

  const TTSProvider(this.value);
  final String value;

  /// 从字符串值创建枚举
  static TTSProvider? fromValue(String value) {
    for (final provider in TTSProvider.values) {
      if (provider.value == value) {
        return provider;
      }
    }
    return null;
  }
}

// ============================================================================
// GLM-TTS 特有配置
// ============================================================================

/// GLM-TTS支持的音色列表
const List<String> glmSupportedVoices = [
  'female', // 默认，对应彤彤
  'tongtong', // 彤彤
  'xiaochen', // 小陈
  'chuichui', // 锤锤
  'jam', // jam
  'kazi', // kazi
  'douji', // douji
  'luodo', // luodo
];

/// GLM-TTS支持的音频格式
const List<String> glmSupportedFormats = ['wav', 'mp3', 'pcm', 'flac'];

/// GLM-TTS语速范围
const Map<String, double> glmSpeedRange = {'min': 0.5, 'max': 2.0};

/// GLM-TTS音量范围
const Map<String, double> glmVolumeRange = {'min': 0.0, 'max': 2.0};

/// GLM-TTS默认采样率
const int glmDefaultSampleRate = 24000;

/// GLM-TTS默认API基础URL
const String glmDefaultBaseUrl = 'https://open.bigmodel.cn/api/paas/v4';

/// GLM-TTS凭证和设置
class GlmConfig {
  final String? apiKey;
  final String? baseUrl;
  final bool forceTrim;

  const GlmConfig({
    this.apiKey,
    this.baseUrl,
    this.forceTrim = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'apiKey': apiKey,
      'baseUrl': baseUrl,
      'forceTrim': forceTrim,
    };
  }

  factory GlmConfig.fromMap(Map<String, dynamic> map) {
    return GlmConfig(
      apiKey: map['apiKey'] as String?,
      baseUrl: map['baseUrl'] as String?,
      forceTrim: map['forceTrim'] as bool? ?? true,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory GlmConfig.fromJson(String json) =>
      GlmConfig.fromMap(jsonDecode(json) as Map<String, dynamic>);

  GlmConfig copyWith({
    String? apiKey,
    String? baseUrl,
    bool? forceTrim,
  }) {
    return GlmConfig(
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      forceTrim: forceTrim ?? this.forceTrim,
    );
  }

  bool get isConfigured => apiKey?.isNotEmpty == true;

  @override
  String toString() =>
      'GlmConfig(apiKey: ${apiKey != null ? "***" : null}, baseUrl: $baseUrl, forceTrim: $forceTrim)';
}

// ============================================================================
// AIHUBMIX-TTS 特有配置
// ============================================================================

/// AIHUBMIX-TTS支持的音色列表
const List<String> aihubmixSupportedVoices = [
  'alloy', // 默认音色
  'echo', // 回声
  'fable', // 寓言
  'onyx', // 玛瑙
  'nova', // 新星
  'shimmer', // 闪烁
];

/// AIHUBMIX-TTS支持的音频格式
const List<String> aihubmixSupportedFormats = ['mp3', 'wav', 'pcm', 'flac'];

/// AIHUBMIX-TTS语速范围
const Map<String, double> aihubmixSpeedRange = {'min': 0.25, 'max': 4.0};

/// AIHUBMIX-TTS音量范围
const Map<String, double> aihubmixVolumeRange = {'min': 0.0, 'max': 2.0};

/// AIHUBMIX-TTS默认采样率
const int aihubmixDefaultSampleRate = 24000;

/// AIHUBMIX-TTS默认API基础URL
const String aihubmixDefaultBaseUrl = 'https://aihubmix.com/v1';

/// AIHUBMIX-TTS默认API密钥（内置默认）
const String aihubmixDefaultApiKey =
    'sk-jju5w22vNQHN0wy21f8eB0244f5047909bF4A3B387C37dB6';

/// AIHUBMIX-TTS凭证和设置
class AihubmixConfig {
  final String? apiKey;
  final String? baseUrl;
  final String? model;
  final String? voice;

  const AihubmixConfig({
    this.apiKey,
    this.baseUrl,
    this.model,
    this.voice,
  });

  Map<String, dynamic> toMap() {
    return {
      'apiKey': apiKey,
      'baseUrl': baseUrl,
      'model': model,
      'voice': voice,
    };
  }

  factory AihubmixConfig.fromMap(Map<String, dynamic> map) {
    return AihubmixConfig(
      apiKey: map['apiKey'] as String?,
      baseUrl: map['baseUrl'] as String?,
      model: map['model'] as String?,
      voice: map['voice'] as String?,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory AihubmixConfig.fromJson(String json) =>
      AihubmixConfig.fromMap(jsonDecode(json) as Map<String, dynamic>);

  AihubmixConfig copyWith({
    String? apiKey,
    String? baseUrl,
    String? model,
    String? voice,
  }) {
    return AihubmixConfig(
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
      voice: voice ?? this.voice,
    );
  }

  /// 默认音色（从支持的列表中取第一个）
  String get defaultVoice => aihubmixSupportedVoices.isNotEmpty
      ? aihubmixSupportedVoices.first
      : 'alloy';

  /// 默认模型
  String get defaultModel => 'gpt-4o-mini-tts';

  bool get isConfigured => apiKey?.isNotEmpty == true;

  @override
  String toString() =>
      'AihubmixConfig(apiKey: ${apiKey != null ? "***" : null}, baseUrl: $baseUrl, model: $model, voice: $voice)';
}

// ============================================================================
// 全局配置工具函数
// ============================================================================

/// 获取指定供应商支持的音色列表
List<String> getSupportedVoices(TTSProvider provider) {
  switch (provider) {
    case TTSProvider.glmTts:
      return List.from(glmSupportedVoices);
    case TTSProvider.aihubmixTts:
      return List.from(aihubmixSupportedVoices);
  }
}

/// 获取指定供应商支持的格式列表
List<String> getSupportedFormats(TTSProvider provider) {
  switch (provider) {
    case TTSProvider.glmTts:
      return List.from(glmSupportedFormats);
    case TTSProvider.aihubmixTts:
      return List.from(aihubmixSupportedFormats);
  }
}

/// 获取指定供应商的语速范围
Map<String, double> getSpeedRange(TTSProvider provider) {
  switch (provider) {
    case TTSProvider.glmTts:
      return Map.from(glmSpeedRange);
    case TTSProvider.aihubmixTts:
      return Map.from(aihubmixSpeedRange);
  }
}

/// 获取指定供应商的音量范围
Map<String, double> getVolumeRange(TTSProvider provider) {
  switch (provider) {
    case TTSProvider.glmTts:
      return Map.from(glmVolumeRange);
    case TTSProvider.aihubmixTts:
      return Map.from(aihubmixVolumeRange);
  }
}

/// 验证指定供应商的语速是否在有效范围内
bool validateSpeed(TTSProvider provider, double speed) {
  final range = getSpeedRange(provider);
  return speed >= range['min']! && speed <= range['max']!;
}

/// 验证指定供应商的音量是否在有效范围内
bool validateVolume(TTSProvider provider, double volume) {
  final range = getVolumeRange(provider);
  return volume >= range['min']! && volume <= range['max']!;
}

/// 检查供应商名称是否受支持
bool isProviderSupported(String providerName) {
  return TTSProvider.fromValue(providerName) != null;
}
