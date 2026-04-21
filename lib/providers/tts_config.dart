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

/// TTS配置管理器
class TTSConfig {
  /// GLM-TTS支持的音色列表
  static const List<String> glmSupportedVoices = [
    'female', // 默认，对应彤彤
    'tongtong', // 彤彤
    'xiaochen', // 小陈
    'chuichui', // 锤锤
    'jam', // jam
    'kazi', // kazi
    'douji', // douji
    'luodo', // luodo
  ];

  /// AIHUBMIX-TTS支持的音色列表
  static const List<String> aihubmixSupportedVoices = [
    'alloy', // 默认音色
    'echo', // 回声
    'fable', // 寓言
    'onyx', // 玛瑙
    'nova', // 新星
    'shimmer', // 闪烁
  ];

  /// GLM-TTS支持的音频格式
  static const List<String> glmSupportedFormats = ['wav', 'mp3', 'pcm', 'flac'];

  /// AIHUBMIX-TTS支持的音频格式
  static const List<String> aihubmixSupportedFormats = [
    'mp3',
    'wav',
    'pcm',
    'flac'
  ];

  /// GLM-TTS语速范围
  static const Map<String, double> glmSpeedRange = {
    'min': 0.5,
    'max': 2.0,
  };

  /// AIHUBMIX-TTS语速范围
  static const Map<String, double> aihubmixSpeedRange = {
    'min': 0.25,
    'max': 4.0,
  };

  /// GLM-TTS音量范围
  static const Map<String, double> glmVolumeRange = {
    'min': 0.0,
    'max': 2.0,
  };

  /// AIHUBMIX-TTS音量范围
  static const Map<String, double> aihubmixVolumeRange = {
    'min': 0.0,
    'max': 2.0,
  };

  /// GLM-TTS默认采样率
  static const int glmDefaultSampleRate = 24000;

  /// AIHUBMIX-TTS默认采样率
  static const int aihubmixDefaultSampleRate = 24000;

  /// AIHUBMIX-TTS默认API基础URL
  static const String aihubmixDefaultBaseUrl = 'https://aihubmix.com/v1';

  /// AIHUBMIX-TTS默认API密钥
  static const String aihubmixDefaultApiKey =
      'sk-jju5w22vNQHN0wy21f8eB0244f5047909bF4A3B387C37dB6';

  /// 全局默认参数
  static const String defaultVoice = 'female'; // GLM-TTS默认音色
  static const double defaultSpeed = 1.0; // 正常速度
  static const double defaultVolume = 1.0; // 正常音量
  static const String defaultFormat = 'wav'; // 默认音频格式（非流式）
  static const String defaultStreamFormat = 'pcm'; // 流式默认格式
  static const String defaultEncodeFormat = 'base64'; // 流式编码格式

  /// 获取指定供应商支持的音色列表
  static List<String> getSupportedVoices(TTSProvider provider) {
    switch (provider) {
      case TTSProvider.glmTts:
        return List.from(glmSupportedVoices);
      case TTSProvider.aihubmixTts:
        return List.from(aihubmixSupportedVoices);
    }
  }

  /// 获取指定供应商支持的格式列表
  static List<String> getSupportedFormats(TTSProvider provider) {
    switch (provider) {
      case TTSProvider.glmTts:
        return List.from(glmSupportedFormats);
      case TTSProvider.aihubmixTts:
        return List.from(aihubmixSupportedFormats);
    }
  }

  /// 获取指定供应商的语速范围
  static Map<String, double> getSpeedRange(TTSProvider provider) {
    switch (provider) {
      case TTSProvider.glmTts:
        return Map.from(glmSpeedRange);
      case TTSProvider.aihubmixTts:
        return Map.from(aihubmixSpeedRange);
    }
  }

  /// 获取指定供应商的音量范围
  static Map<String, double> getVolumeRange(TTSProvider provider) {
    switch (provider) {
      case TTSProvider.glmTts:
        return Map.from(glmVolumeRange);
      case TTSProvider.aihubmixTts:
        return Map.from(aihubmixVolumeRange);
    }
  }

  /// 验证指定供应商的语速是否在有效范围内
  static bool validateSpeed(TTSProvider provider, double speed) {
    final range = getSpeedRange(provider);
    return speed >= range['min']! && speed <= range['max']!;
  }

  /// 验证指定供应商的音量是否在有效范围内
  static bool validateVolume(TTSProvider provider, double volume) {
    final range = getVolumeRange(provider);
    return volume >= range['min']! && volume <= range['max']!;
  }

  /// 获取指定供应商的默认参数
  static ProviderConfig getDefaultParams(TTSProvider provider) {
    switch (provider) {
      case TTSProvider.glmTts:
        return ProviderConfig(
          provider: TTSProvider.glmTts,
          voice: defaultVoice,
          speed: defaultSpeed,
          volume: defaultVolume,
          format: defaultFormat,
          streamFormat: defaultStreamFormat,
          encodeFormat: defaultEncodeFormat,
          sampleRate: glmDefaultSampleRate,
        );
      case TTSProvider.aihubmixTts:
        return ProviderConfig(
          provider: TTSProvider.aihubmixTts,
          voice: 'alloy', // AIHUBMIX-TTS默认音色
          model: 'gpt-4o-mini-tts', // 默认模型
          speed: defaultSpeed,
          volume: defaultVolume,
          format: 'mp3', // AIHUBMIX-TTS默认格式
          streamFormat: defaultStreamFormat,
          encodeFormat: defaultEncodeFormat,
          sampleRate: aihubmixDefaultSampleRate,
          baseUrl: aihubmixDefaultBaseUrl,
          apiKey: aihubmixDefaultApiKey,
        );
    }
  }

  /// 检查供应商名称是否受支持
  static bool isProviderSupported(String providerName) {
    return TTSProvider.fromValue(providerName) != null;
  }
}

/// 供应商配置类
class ProviderConfig {
  final TTSProvider provider;
  final String voice;
  final String? model;
  final double speed;
  final double volume;
  final String format;
  final String streamFormat;
  final String encodeFormat;
  final int sampleRate;
  final String? baseUrl;
  final String? apiKey;

  ProviderConfig({
    required this.provider,
    required this.voice,
    this.model,
    required this.speed,
    required this.volume,
    required this.format,
    required this.streamFormat,
    required this.encodeFormat,
    required this.sampleRate,
    this.baseUrl,
    this.apiKey,
  });

  /// 将配置转换为Map，用于持久化存储
  Map<String, dynamic> toMap() {
    return {
      'provider': provider.value,
      'voice': voice,
      'model': model,
      'speed': speed,
      'volume': volume,
      'format': format,
      'streamFormat': streamFormat,
      'encodeFormat': encodeFormat,
      'sampleRate': sampleRate,
      'baseUrl': baseUrl,
      'apiKey': apiKey,
    };
  }

  /// 从Map创建配置
  factory ProviderConfig.fromMap(Map<String, dynamic> map) {
    final provider = TTSProvider.fromValue(map['provider'] as String) ??
        TTSProvider.glmTts;

    return ProviderConfig(
      provider: provider,
      voice: map['voice'] as String? ?? TTSConfig.defaultVoice,
      model: map['model'] as String?,
      speed: (map['speed'] as num?)?.toDouble() ?? TTSConfig.defaultSpeed,
      volume: (map['volume'] as num?)?.toDouble() ?? TTSConfig.defaultVolume,
      format: map['format'] as String? ?? TTSConfig.defaultFormat,
      streamFormat:
          map['streamFormat'] as String? ?? TTSConfig.defaultStreamFormat,
      encodeFormat:
          map['encodeFormat'] as String? ?? TTSConfig.defaultEncodeFormat,
      sampleRate: (map['sampleRate'] as num?)?.toInt() ??
          (provider == TTSProvider.glmTts
              ? TTSConfig.glmDefaultSampleRate
              : TTSConfig.aihubmixDefaultSampleRate),
      baseUrl: map['baseUrl'] as String?,
      apiKey: map['apiKey'] as String?,
    );
  }

  /// 将配置转换为JSON字符串
  String toJson() => jsonEncode(toMap());

  /// 从JSON字符串创建配置
  factory ProviderConfig.fromJson(String jsonString) {
    final map = jsonDecode(jsonString) as Map<String, dynamic>;
    return ProviderConfig.fromMap(map);
  }

  /// 创建配置的副本，可以更新部分字段
  ProviderConfig copyWith({
    TTSProvider? provider,
    String? voice,
    String? model,
    double? speed,
    double? volume,
    String? format,
    String? streamFormat,
    String? encodeFormat,
    int? sampleRate,
    String? baseUrl,
    String? apiKey,
  }) {
    return ProviderConfig(
      provider: provider ?? this.provider,
      voice: voice ?? this.voice,
      model: model ?? this.model,
      speed: speed ?? this.speed,
      volume: volume ?? this.volume,
      format: format ?? this.format,
      streamFormat: streamFormat ?? this.streamFormat,
      encodeFormat: encodeFormat ?? this.encodeFormat,
      sampleRate: sampleRate ?? this.sampleRate,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
    );
  }

  @override
  String toString() {
    return 'ProviderConfig(provider: ${provider.value}, voice: $voice, speed: $speed, volume: $volume, format: $format)';
  }
}
