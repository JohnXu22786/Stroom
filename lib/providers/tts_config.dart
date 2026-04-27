// ============================================================================
// 供应商注册表 — 支持动态注册，替换旧的 TTSProvider 枚举
// ============================================================================

/// 供应商定义：描述一个 TTS 供应商的全部元信息
class TTSProviderDefinition {
  final String id; // 唯一标识，如 'glm_tts'
  final String label; // 显示名称，如 'GLM-TTS'
  final String? defaultBaseUrl;
  final List<String> supportedVoices;
  final List<String> supportedFormats;
  final double speedMin;
  final double speedMax;
  final double volumeMin;
  final double volumeMax;
  final int defaultSampleRate;
  final Map<String, dynamic> defaultConfig; // 供应商专属默认值（apiKey 等留空）

  const TTSProviderDefinition({
    required this.id,
    required this.label,
    this.defaultBaseUrl,
    this.supportedVoices = const [],
    this.supportedFormats = const ['wav', 'mp3', 'pcm'],
    this.speedMin = 0.5,
    this.speedMax = 2.0,
    this.volumeMin = 0.0,
    this.volumeMax = 2.0,
    this.defaultSampleRate = 24000,
    this.defaultConfig = const {},
  });
}

/// 供应商注册表
class TTSProviderRegistry {
  static final Map<String, TTSProviderDefinition> _registry = {};

  /// 注册一个供应商
  static void register(TTSProviderDefinition def) {
    _registry[def.id] = def;
  }

  /// 通过 id 获取定义
  static TTSProviderDefinition? get(String id) => _registry[id];

  /// 获取所有已注册的供应商
  static List<TTSProviderDefinition> getAll() =>
      _registry.values.toList(growable: false);

  /// 是否已注册
  static bool isRegistered(String id) => _registry.containsKey(id);

  /// 注销（用于测试）
  static void unregister(String id) => _registry.remove(id);
}

// ============================================================================
// 内置供应商注册
// ============================================================================

/// 在模块加载时注册所有内置供应商
void registerBuiltinProviders() {
  TTSProviderRegistry.register(TTSProviderDefinition(
    id: 'glm_tts',
    label: 'GLM-TTS',
    defaultBaseUrl: 'https://open.bigmodel.cn/api/paas/v4',
    supportedVoices: [
      'female',
      'tongtong',
      'xiaochen',
      'chuichui',
      'jam',
      'kazi',
      'douji',
      'luodo',
    ],
    supportedFormats: ['wav', 'mp3', 'pcm', 'flac'],
    speedMin: 0.5,
    speedMax: 2.0,
    volumeMin: 0.0,
    volumeMax: 2.0,
    defaultSampleRate: 24000,
    defaultConfig: {
      'trimMode': 'beep',
    },
  ));

  TTSProviderRegistry.register(TTSProviderDefinition(
    id: 'aihubmix_tts',
    label: 'AIHUBMIX-TTS',
    defaultBaseUrl: 'https://aihubmix.com/v1',
    supportedVoices: [
      'alloy',
      'echo',
      'fable',
      'onyx',
      'nova',
      'shimmer',
    ],
    supportedFormats: ['mp3', 'wav', 'pcm', 'flac'],
    speedMin: 0.25,
    speedMax: 4.0,
    volumeMin: 0.0,
    volumeMax: 2.0,
    defaultSampleRate: 24000,
    defaultConfig: {
      'model': 'gpt-4o-mini-tts',
      'voice': 'alloy',
    },
  ));
}

// ============================================================================
// 全局配置工具函数（基于注册表）
// ============================================================================

/// 获取指定供应商的音色列表
List<String> getSupportedVoices(String providerId) {
  final def = TTSProviderRegistry.get(providerId);
  return def != null ? List.from(def.supportedVoices) : [];
}

/// 获取指定供应商的格式列表
List<String> getSupportedFormats(String providerId) {
  final def = TTSProviderRegistry.get(providerId);
  return def != null ? List.from(def.supportedFormats) : [];
}

/// 获取指定供应商的语速范围
Map<String, double> getSpeedRange(String providerId) {
  final def = TTSProviderRegistry.get(providerId);
  if (def == null) return {'min': 0.5, 'max': 2.0};
  return {'min': def.speedMin, 'max': def.speedMax};
}

/// 获取指定供应商的音量范围
Map<String, double> getVolumeRange(String providerId) {
  final def = TTSProviderRegistry.get(providerId);
  if (def == null) return {'min': 0.0, 'max': 2.0};
  return {'min': def.volumeMin, 'max': def.volumeMax};
}

/// 验证语速
bool validateSpeed(String providerId, double speed) {
  final range = getSpeedRange(providerId);
  return speed >= range['min']! && speed <= range['max']!;
}

/// 验证音量
bool validateVolume(String providerId, double volume) {
  final range = getVolumeRange(providerId);
  return volume >= range['min']! && volume <= range['max']!;
}

/// 检查供应商是否受支持
bool isProviderSupported(String providerId) {
  return TTSProviderRegistry.isRegistered(providerId);
}

// ============================================================================
// GLM-TTS 特有类型
// ============================================================================

/// GLM-TTS 音频头部裁切模式
enum GlmTrimMode {
  none('none', '不裁切'),
  beep('beep', '滴滴声 (0.630s)'),
  buzzer('buzzer', '嘟嘟声 (1.830s)');

  const GlmTrimMode(this.value, this.label);
  final String value;
  final String label;

  static GlmTrimMode? fromValue(String? value) {
    for (final mode in GlmTrimMode.values) {
      if (mode.value == value) return mode;
    }
    return null;
  }
}

// ============================================================================
// 供应商配置（Map → 类型化包装器）
//
// Config 类既可以从 Map 构造（用于通用存储），也支持 toMap() 序列化。
// 新增供应商只需在下方添加对应的 Config 类，TTSConfigState 本身不感知。
// ============================================================================

/// 默认配置键名（所有供应商共用）
const _kApiKey = 'apiKey';
const _kBaseUrl = 'baseUrl';

// --------------------------------------------------------------------------
// GLM-TTS 配置
// --------------------------------------------------------------------------

class GlmConfig {
  final String? apiKey;
  final String? baseUrl;
  final GlmTrimMode trimMode;

  const GlmConfig({
    this.apiKey,
    this.baseUrl,
    this.trimMode = GlmTrimMode.beep,
  });

  /// 从通用 Map 构造
  factory GlmConfig.fromMap(Map<String, dynamic> map) {
    return GlmConfig(
      apiKey: map[_kApiKey] as String?,
      baseUrl: map[_kBaseUrl] as String?,
      trimMode:
          GlmTrimMode.fromValue(map['trimMode'] as String?) ?? GlmTrimMode.beep,
    );
  }

  Map<String, dynamic> toMap() => {
        _kApiKey: apiKey,
        _kBaseUrl: baseUrl,
        'trimMode': trimMode.value,
      };

  GlmConfig copyWith({
    String? apiKey,
    String? baseUrl,
    GlmTrimMode? trimMode,
  }) =>
      GlmConfig(
        apiKey: apiKey ?? this.apiKey,
        baseUrl: baseUrl ?? this.baseUrl,
        trimMode: trimMode ?? this.trimMode,
      );

  bool get isConfigured => apiKey?.isNotEmpty == true;

  @override
  String toString() =>
      'GlmConfig(apiKey: ${apiKey != null ? "***" : null}, baseUrl: $baseUrl, trimMode: $trimMode)';
}

// --------------------------------------------------------------------------
// AIHUBMIX-TTS 配置
// --------------------------------------------------------------------------

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

  factory AihubmixConfig.fromMap(Map<String, dynamic> map) {
    return AihubmixConfig(
      apiKey: map[_kApiKey] as String?,
      baseUrl: map[_kBaseUrl] as String?,
      model: map['model'] as String?,
      voice: map['voice'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        _kApiKey: apiKey,
        _kBaseUrl: baseUrl,
        'model': model,
        'voice': voice,
      };

  AihubmixConfig copyWith({
    String? apiKey,
    String? baseUrl,
    String? model,
    String? voice,
  }) =>
      AihubmixConfig(
        apiKey: apiKey ?? this.apiKey,
        baseUrl: baseUrl ?? this.baseUrl,
        model: model ?? this.model,
        voice: voice ?? this.voice,
      );

  String get defaultVoice =>
      supportedVoices.isNotEmpty ? supportedVoices.first : 'alloy';
  String get defaultModel => 'gpt-4o-mini-tts';
  bool get isConfigured => apiKey?.isNotEmpty == true;

  static const supportedVoices = [
    'alloy', 'echo', 'fable', 'onyx', 'nova', 'shimmer',
  ];

  @override
  String toString() =>
      'AihubmixConfig(apiKey: ${apiKey != null ? "***" : null}, baseUrl: $baseUrl, model: $model, voice: $voice)';
}
