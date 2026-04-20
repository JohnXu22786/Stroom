import 'dart:core';

/// TTS供应商类型枚举
///
/// 定义系统支持的TTS供应商类型。
/// 每个枚举值对应一个具体的供应商实现。
enum TTSProviderType {
  /// GLM-TTS供应商（智谱AI）
  glmTTS('glm_tts'),

  /// AIHUBMIX-TTS供应商（OpenAI兼容API）
  aihubmixTTS('aihubmix_tts');

  const TTSProviderType(this.value);

  /// 枚举值的字符串表示
  final String value;

  /// 从字符串值获取TTSProviderType枚举
  ///
  /// [value] 字符串值（如 "glm_tts"）
  /// 返回对应的TTSProviderType枚举，如果找不到则返回null
  static TTSProviderType? fromValue(String value) {
    for (final provider in TTSProviderType.values) {
      if (provider.value == value) {
        return provider;
      }
    }
    return null;
  }

  /// 获取供应商的显示名称
  String get displayName {
    switch (this) {
      case TTSProviderType.glmTTS:
        return 'GLM-TTS';
      case TTSProviderType.aihubmixTTS:
        return 'AIHUBMIX-TTS';
    }
  }
}

/// 供应商配置常量
class TTSProviderConfig {
  // 防止实例化
  TTSProviderConfig._();

  /// 支持的模型映射
  ///
  /// 键：供应商类型，值：该供应商支持的模型列表
  static const Map<TTSProviderType, List<String>> modelsByProvider = {
    TTSProviderType.glmTTS: ['glm-tts'],
    TTSProviderType.aihubmixTTS: ['tts-1', 'tts-1-hd'],
  };

  /// 供应商默认参数配置
  ///
  /// 每个供应商的默认参数设置
  static const Map<TTSProviderType, Map<String, dynamic>> providerDefaultParams = {
    TTSProviderType.glmTTS: {
      'voice': 'female',
      'speed': 1.0,
      'volume': 1.0,
      'format': 'wav',
      'streamFormat': 'pcm',
      'encodeFormat': 'base64',
      'sampleRate': 24000,
    },
    TTSProviderType.aihubmixTTS: {
      'voice': 'alloy',
      'speed': 1.0,
      'volume': 1.0,
      'format': 'mp3',
      'streamFormat': 'pcm',
      'encodeFormat': 'base64',
      'sampleRate': 24000,
      'model': 'tts-1',
    },
  };

  /// GLM-TTS支持的音色列表
  static const List<String> glmSupportedVoices = [
    'female', // 默认，对应彤彤
    'tongtong', // 彤彤
    'xiaochen', // 小陈
    'chuichui', // 锤锤
    'jam',
    'kazi',
    'douji',
    'luodo',
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

  /// 支持的音频格式列表（所有供应商通用）
  static const List<String> supportedFormats = [
    'pcm',
    'wav',
    'mp3',
    'flac',
  ];

  /// GLM-TTS参数范围限制
  static const Map<String, dynamic> glmParamRanges = {
    'speed': {'min': 0.5, 'max': 2.0},
    'volume': {'min': 0.0, 'max': 2.0},
    'sampleRate': 24000,
  };

  /// AIHUBMIX-TTS参数范围限制
  static const Map<String, dynamic> aihubmixParamRanges = {
    'speed': {'min': 0.25, 'max': 4.0},
    'volume': {'min': 0.0, 'max': 2.0},
    'sampleRate': 24000,
  };

  /// 获取供应商支持的模型列表
  ///
  /// [provider] 供应商类型
  /// 返回该供应商支持的模型列表
  static List<String> getSupportedModels(TTSProviderType provider) {
    return modelsByProvider[provider] ?? [];
  }

  /// 获取供应商的默认参数
  ///
  /// [provider] 供应商类型
  /// 返回该供应商的默认参数配置
  static Map<String, dynamic> getDefaultParams(TTSProviderType provider) {
    return Map<String, dynamic>.from(providerDefaultParams[provider] ?? {});
  }

  /// 获取供应商支持的音色列表
  ///
  /// [provider] 供应商类型
  /// 返回该供应商支持的音色列表
  static List<String> getSupportedVoices(TTSProviderType provider) {
    switch (provider) {
      case TTSProviderType.glmTTS:
        return List<String>.from(glmSupportedVoices);
      case TTSProviderType.aihubmixTTS:
        return List<String>.from(aihubmixSupportedVoices);
    }
  }

  /// 获取供应商的参数范围限制
  ///
  /// [provider] 供应商类型
  /// 返回该供应商的参数范围限制配置
  static Map<String, dynamic> getParamRanges(TTSProviderType provider) {
    switch (provider) {
      case TTSProviderType.glmTTS:
        return Map<String, dynamic>.from(glmParamRanges);
      case TTSProviderType.aihubmixTTS:
        return Map<String, dynamic>.from(aihubmixParamRanges);
    }
  }

  /// 验证参数是否在有效范围内
  ///
  /// [provider] 供应商类型
  /// [paramName] 参数名称
  /// [value] 参数值
  /// 如果参数有效返回true，否则返回false
  static bool validateParamRange(
    TTSProviderType provider,
    String paramName,
    dynamic value,
  ) {
    final ranges = getParamRanges(provider);
    final range = ranges[paramName];

    if (range == null) {
      // 没有范围限制的参数默认有效
      return true;
    }

    if (range is Map<String, dynamic>) {
      // 范围是min/max结构
      final min = range['min'];
      final max = range['max'];

      if (min != null && max != null && value is num) {
        return value >= min && value <= max;
      }
    } else if (range is num && value is num) {
      // 范围是固定值（如sampleRate）
      return value == range;
    }

    return true;
  }
}

/// TTS配置错误类型
class TTSConfigError implements Exception {
  final String message;
  final dynamic cause;

  const TTSConfigError(this.message, [this.cause]);

  @override
  String toString() {
    return 'TTSConfigError: $message${cause != null ? ' (Cause: $cause)' : ''}';
  }
}
